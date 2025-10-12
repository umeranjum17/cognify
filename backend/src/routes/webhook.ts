import express from 'express';
import crypto from 'crypto';
import { getAdminDb } from '../services/firebase.js';
import { RC_CREDIT_PRODUCTS, RC_WEBHOOK_CONFIG } from '../config/config-data.js';

export const webhookRouter = express.Router();

// RevenueCat can authenticate webhooks via Bearer secret or signature headers.
// We first accept Bearer for simplicity; if RC_SIGNATURE_SECRET is set, verify signature too.

// POST /api/rc/webhook - RevenueCat webhook handler
webhookRouter.post('/webhook', async (req, res) => {
  try {
    const authHeader = String(req.headers.authorization || '');
    const expectedSecret = process.env.RC_WEBHOOK_SECRET;
    const signatureHeader = String(req.headers['x-revenuecat-signature'] || '');
    const signatureSecret = process.env.RC_SIGNATURE_SECRET;
    if (!expectedSecret) {
      res.status(500).json({ error: 'Server misconfigured: RC_WEBHOOK_SECRET missing' });
      return;
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer' || parts[1] !== expectedSecret) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const payload = req.body as any;
    // Optional signature verification (if configured)
    if (signatureSecret && signatureHeader) {
      const computed = crypto
        .createHmac('sha256', signatureSecret)
        .update(JSON.stringify(payload))
        .digest('hex');
      if (computed !== signatureHeader) {
        res.status(401).json({ error: 'Invalid signature' });
        return;
      }
    }
    const event = payload?.event;
    const environment = String(payload?.environment || '');
    if (!event) {
      res.status(400).json({ error: 'Missing event' });
      return;
    }

    // Environment guard
    if (environment.toLowerCase() === 'sandbox' && !RC_WEBHOOK_CONFIG.allowSandbox) {
      res.status(202).json({ received: true, ignored: true, reason: 'sandbox disabled' });
      return;
    }

    const eventId: string = String(event?.id || '');
    const eventType: string = String(event?.type || '');
    const rcAppUserId: string = String(event?.app_user_id || '');
    const productIdentifier: string = String(event?.product_id || event?.product_identifier || '');
    const isRefund: boolean = String(eventType).includes('REFUND');

    if (!eventId || !rcAppUserId) {
      res.status(400).json({ error: 'Missing event id or app_user_id' });
      return;
    }

    // Map your RevenueCat appUserId to Firebase uid; often you set them equal.
    const uid = rcAppUserId;

    const db = getAdminDb();
    const balanceRef = db.collection('users').doc(uid).collection('credits').doc('balance');
    const eventsRef = db.collection('rc_events').doc(eventId);
    const ledgerRef = db.collection('users').doc(uid).collection('credits').doc('balance').collection('transactions').doc(`rc_${eventId}`);

    // Idempotency: skip if we've processed this eventId already
    const existing = await eventsRef.get();
    if (existing.exists) {
      res.status(200).json({ received: true, duplicated: true });
      return;
    }

    // Determine credits to grant/reverse
    const credits = RC_CREDIT_PRODUCTS[productIdentifier] ?? 0;
    if (credits <= 0) {
      // Unknown SKU: record and ack, but do not change balance
      await eventsRef.set({ processedAt: new Date().toISOString(), uid, eventType, productIdentifier, credits: 0, environment });
      res.status(200).json({ received: true, ignored: true, reason: 'unmapped_sku' });
      return;
    }

    // Ensure balance doc exists
    const snap = await balanceRef.get();
    if (!snap.exists) {
      await balanceRef.set({ balance: 0, lastUpdated: new Date().toISOString() });
    }

    // Compute delta (refund reverses)
    const delta = isRefund ? -credits : credits;

    // Update aggregate and record ledger entry
    const balanceSnap = await balanceRef.get();
    const currentBalance = Number((balanceSnap.data() as any)?.balance ?? 0);
    const newBalance = Math.max(0, currentBalance + delta);

    await balanceRef.set({ balance: newBalance, lastUpdated: new Date().toISOString() });
    await ledgerRef.set({
      type: isRefund ? 'refund' : 'grant',
      amount: Math.abs(delta),
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      sku: productIdentifier,
      rcEventId: eventId,
      environment,
      timestamp: new Date().toISOString(),
      metadata: { eventType },
    });

    await eventsRef.set({ processedAt: new Date().toISOString(), uid, eventType, productIdentifier, credits: Math.abs(delta), environment });

    res.status(200).json({ received: true, balance: newBalance, delta });
  } catch (error: any) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

