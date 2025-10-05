import { getAdminDb, verifyFirebaseIdToken } from '../shared/firebase-admin';
import { QUOTA_CONFIG } from '../shared/config-data';

export const config = { runtime: 'nodejs18.x' };

/**
 * Enhanced /api/credits/consume endpoint
 *
 * Now calculates request units server-side based on model and mode.
 * Accepts either:
 * 1. Legacy: { amount, reason, requestId } - direct amount
 * 2. New: { modelId, mode, requestId, conversationId } - calculates amount
 */
export default async function handler(req: Request) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } as const;

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405, headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('authorization') ?? undefined;
    const decoded = await verifyFirebaseIdToken(authHeader);
    const uid = decoded.uid;

    const body = await req.json();
    const requestId = String(body?.requestId ?? '');

    if (!requestId) {
      return new Response(
        JSON.stringify({ success: false, error: 'requestId is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Calculate amount server-side if modelId provided, otherwise use legacy amount
    let amount: number;
    let calculatedMetadata: any = {};

    if (body?.modelId) {
      // New flow: calculate units based on model and mode
      const estimateResponse = await fetch(`${req.url.split('/api/')[0]}/api/usage/estimate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: body.modelId,
          mode: body.mode || 'chat',
          inputTokens: body.inputTokens,
          outputTokens: body.outputTokens,
        }),
      });

      if (!estimateResponse.ok) {
        throw new Error('Failed to estimate usage');
      }

      const estimateData = await estimateResponse.json();
      if (!estimateData.success) {
        throw new Error(estimateData.error || 'Estimation failed');
      }

      amount = estimateData.data.requestUnits;
      calculatedMetadata = {
        modelId: body.modelId,
        mode: body.mode || 'chat',
        dollarCost: estimateData.data.dollarCost,
        inputTokens: estimateData.data.inputTokens,
        outputTokens: estimateData.data.outputTokens,
        conversationId: body.conversationId,
        calculatedByBackend: true,
      };
    } else {
      // Legacy flow: use provided amount
      amount = Math.max(0, Number(body?.amount ?? 0));
      if (!amount) {
        return new Response(
          JSON.stringify({ success: false, error: 'Either modelId or amount is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
        );
      }
      calculatedMetadata = {
        reason: String(body?.reason ?? 'generic'),
        legacyFlow: true,
      };
    }

    const db = getAdminDb();
    const balanceRef = db.collection('users').doc(uid).collection('credits').doc('balance');
    const consumptionRef = db.collection('users').doc(uid).collection('consumptions').doc(requestId);

    const result = await db.runTransaction(async (tx) => {
      const existing = await tx.get(consumptionRef);
      if (existing.exists) {
        const b = await tx.get(balanceRef);
        const bd = b.exists ? b.data() : { balance: 0 } as any;
        return { duplicated: true, balance: bd.balance ?? 0 };
      }

      const snap = await tx.get(balanceRef);
      const data = snap.exists ? (snap.data() as any) : { balance: 0 };
      const current = Number(data.balance ?? 0);
      if (current < amount) {
        throw new Error('INSUFFICIENT_CREDITS');
      }

      const newBalance = current - amount;
      tx.set(balanceRef, {
        balance: newBalance,
        updatedAt: new Date().toISOString(),
        plan: data.plan ?? { tier: 'free', allowance: 0 },
        nextReset: data.nextReset ?? null,
      }, { merge: true });
      tx.set(consumptionRef, {
        amount,
        ...calculatedMetadata,
        createdAt: new Date().toISOString(),
      });
      return { duplicated: false, balance: newBalance };
    });

    if (result.duplicated) {
      return new Response(
        JSON.stringify({ success: true, data: { balance: result.balance }, duplicated: true }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          balance: result.balance,
          consumed: amount,
          ...calculatedMetadata,
        }
      }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (e: any) {
    if (e?.message === 'INSUFFICIENT_CREDITS') {
      return new Response(
        JSON.stringify({ success: false, code: 'INSUFFICIENT_CREDITS' }),
        { status: 409, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }
    return new Response(
      JSON.stringify({ success: false, error: e?.message ?? 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
}


