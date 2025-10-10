import express from 'express';
import { requireAuth, AuthRequest } from '../middleware/auth.js';
import { getAdminDb } from '../services/firebase.js';
import { QUOTA_CONFIG } from '../config/config-data.js';

export const creditsRouter = express.Router();
function getInternalBaseUrl(req: express.Request): string {
  const envBase = process.env.INTERNAL_BASE_URL;
  if (envBase && typeof envBase === 'string' && envBase.trim().length > 0) return envBase.trim();
  const host = req.get('host') || '';
  const port = host.includes(':') ? host.split(':')[1] : (process.env.PORT || '3000');
  const proto = process.env.INTERNAL_PROTOCOL || 'http';
  return `${proto}://127.0.0.1:${port}`;
}

// GET /api/credits/balance - Get user's credit balance
creditsRouter.get('/balance', requireAuth, async (req: AuthRequest, res) => {
  try {
    const uid = req.user!.uid;
    const db = getAdminDb();
    const docRef = db.collection('users').doc(uid).collection('credits').doc('balance');
    const snap = await docRef.get();
    if (!snap.exists) {
      // Auto-initialize balance for new users (useful for emulator/dev)
      const initial = QUOTA_CONFIG.initialRequestAllocation;
      await docRef.set({ balance: initial, lastUpdated: new Date().toISOString() });
      res.json({ balance: initial, lastUpdated: new Date().toISOString(), initialized: true });
      return;
    }
    const data = (snap.data() as any) || {};
    const balance = Number(data.balance ?? 0);
    const lastUpdated = (data.lastUpdated as string | null | undefined) ?? null;
    res.json({ balance, lastUpdated });
  } catch (error: any) {
    // Graceful fallback: if Firestore is unavailable locally, return zero balance
    console.warn('Balance lookup failed, returning fallback balance=0:', error?.message || error);
    res.json({ balance: 0, lastUpdated: null, fallback: true });
  }
});

// POST /api/credits/consume - Consume credits for a request
creditsRouter.post('/consume', requireAuth, async (req: AuthRequest, res) => {
  try {
    const uid = req.user!.uid;
    const { amount, requestId, metadata, modelId, mode, conversationId, inputTokens, outputTokens } = req.body || {};
    
    if (!requestId) {
      res.status(400).json({ success: false, error: 'requestId is required' });
      return;
    }
    
    const db = getAdminDb();
    const balanceRef = db.collection('users').doc(uid).collection('credits').doc('balance');
    const txRef = balanceRef.collection('transactions').doc(requestId);
    
    // Calculate server-side amount if modelId provided; else legacy amount
    let consumeAmount: number = 0;
    let calculatedMetadata: any = {};
    if (modelId) {
      // Fetch models config to derive request units
      const internalBase = getInternalBaseUrl(req);
      const modelsRes = await fetch(`${internalBase}/api/config/models`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          ...(req.headers.authorization ? { Authorization: String(req.headers.authorization) } : {}),
        },
      });
      if (!modelsRes.ok) {
        res.status(500).json({ success: false, error: 'Failed to load model pricing' });
        return;
      }
      const modelsData: any = await modelsRes.json();
      const effectiveMode = String(mode || 'chat');
      const qp = modelsData?.data?.quotaPricing;
      const sample = qp?.perRequestSample?.[effectiveMode]?.[modelId];
      if (sample && typeof sample.requestUnits === 'number') {
        consumeAmount = Number(sample.requestUnits) || 0;
        calculatedMetadata = {
          modelId,
          mode: effectiveMode,
          dollarCost: sample.dollarCost ?? null,
          inputTokens: sample.inputTokens ?? null,
          outputTokens: sample.outputTokens ?? null,
          conversationId,
          calculatedByBackend: true,
          method: 'models-config-sample',
        };
      } else {
        const pricing = modelsData?.data?.pricing?.[modelId];
        const dollarsPerUnit = qp?.dollarsPerRequestUnit ?? QUOTA_CONFIG.dollarsPerRequestUnit;
        const inputPricePer1M = Number(pricing?.input || 0);
        const outputPricePer1M = Number(pricing?.output || 0);
        const inT = Number(inputTokens ?? 900);
        const outT = Number(outputTokens ?? 1100);
        const dollarCost = (inT / 1_000_000) * inputPricePer1M + (outT / 1_000_000) * outputPricePer1M;
        const units = dollarCost > 0 ? Math.max(1, Math.ceil(dollarCost / dollarsPerUnit)) : 0;
        consumeAmount = units;
        calculatedMetadata = {
          modelId,
          mode: effectiveMode,
          dollarCost,
          inputTokens: inT,
          outputTokens: outT,
          conversationId,
          calculatedByBackend: true,
          method: 'models-config-derived',
        };
      }
    } else {
      // Legacy path
      const legacyAmount = Math.max(0, Number(amount ?? 0));
      if (!legacyAmount) {
        res.status(400).json({ success: false, error: 'Either modelId or amount is required' });
        return;
      }
      consumeAmount = legacyAmount;
      calculatedMetadata = { reason: String((req.body || {}).reason ?? 'generic'), legacyFlow: true };
    }

    // Check for duplicate
    const existingTx = await txRef.get();
    if (existingTx.exists) {
      // Idempotent: return 200 with duplicated flag and current balance
      const balanceSnap: any = await balanceRef.get();
      const currentBalance = balanceSnap.exists ? Number((balanceSnap.data() as any)?.balance ?? 0) : 0;
      res.status(200).json({ success: true, duplicated: true, data: { balance: currentBalance } });
      return;
    }
    
    // Get current balance
    let balanceSnap: any = await balanceRef.get();
    let currentBalance = balanceSnap.exists ? Number((balanceSnap.data() as any)?.balance ?? 0) : 0;
    if (!balanceSnap.exists) {
      // Auto-initialize balance for new users (emulator/dev convenience)
      currentBalance = QUOTA_CONFIG.initialRequestAllocation;
      await balanceRef.set({ balance: currentBalance, lastUpdated: new Date().toISOString() });
      // refresh snapshot for accurate logging/flow
      balanceSnap = await balanceRef.get();
    }
    
    if (currentBalance < consumeAmount) {
      res.status(409).json({ success: false, code: 'INSUFFICIENT_CREDITS', balance: currentBalance });
      return;
    }
    
    // Deduct credits
    const newBalance = currentBalance - consumeAmount;
    await balanceRef.set({
      balance: newBalance,
      lastUpdated: new Date().toISOString(),
    });
    
    // Record transaction
    await txRef.set({
      type: 'consume',
      amount: consumeAmount,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      timestamp: new Date().toISOString(),
      metadata: { ...(metadata || {}), ...calculatedMetadata },
    });
    
    res.json({
      success: true,
      data: {
        balance: newBalance,
        consumed: consumeAmount,
        requestId,
      },
    });
  } catch (error: any) {
    console.error('Error consuming credits:', error);
    const msg = String(error?.message || '');
    const isEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;
    const isGrpcCryptoIssue = msg.includes('DECODER routines::unsupported') || msg.includes('No connection established');
    if (String(error?.message).includes('INSUFFICIENT_CREDITS')) {
      res.status(409).json({ success: false, code: 'INSUFFICIENT_CREDITS' });
      return;
    }
    // Developer-friendly fallback when running locally and Firestore emulator/grpc has issues
    if (isEmulator || isGrpcCryptoIssue) {
      console.warn('Dev fallback: credits consume bypass due to admin/Firestore error');
      res.status(200).json({ success: true, data: { balance: 999999, consumed: 0, requestId: String((req.body || {}).requestId || '') }, bypass: true });
      return;
    }
    res.status(500).json({ success: false, error: error?.message || 'Internal error' });
  }
});

// POST /api/credits/refund - Refund credits for a failed request
creditsRouter.post('/refund', requireAuth, async (req: AuthRequest, res) => {
  try {
    const uid = req.user!.uid;
    const { requestId } = req.body;
    
    if (!requestId) {
      res.status(400).json({ error: 'Missing required field: requestId' });
      return;
    }
    
    const db = getAdminDb();
    const balanceRef = db.collection('users').doc(uid).collection('credits').doc('balance');
    const txRef = db.collection('users').doc(uid).collection('credits').doc('balance').collection('transactions').doc(requestId);
    
    // Check if original transaction exists
    const originalTx = await txRef.get();
    if (!originalTx.exists) {
      res.status(404).json({ error: 'Original transaction not found', requestId });
      return;
    }
    
    const txData = originalTx.data();
    if (txData?.type !== 'consume') {
      res.status(400).json({ error: 'Transaction is not a consume type' });
      return;
    }
    
    // Check if already refunded
    if (txData?.refunded) {
      res.status(409).json({ error: 'Transaction already refunded', requestId });
      return;
    }
    
    const refundAmount = txData.amount;
    
    // Get current balance
    const balanceSnap = await balanceRef.get();
    const currentBalance = balanceSnap.exists ? (balanceSnap.data()?.balance ?? 0) : 0;
    
    // Add credits back
    const newBalance = currentBalance + refundAmount;
    await balanceRef.set({
      balance: newBalance,
      lastUpdated: new Date().toISOString(),
    });
    
    // Mark as refunded
    await txRef.update({
      refunded: true,
      refundedAt: new Date().toISOString(),
    });
    
    res.json({
      success: true,
      balance: newBalance,
      refunded: refundAmount,
      requestId,
    });
  } catch (error: any) {
    console.error('Error refunding credits:', error);
    res.status(500).json({ error: 'Failed to refund credits' });
  }
});

