import { getAdminDb } from '../shared/firebase-admin';

export const config = { runtime: 'nodejs18.x' };

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

  const secret = process.env.RC_WEBHOOK_SECRET;
  if (!secret) {
    return new Response('Server misconfigured', { status: 500, headers: corsHeaders });
  }

  const auth = req.headers.get('authorization') || '';
  if (auth !== `Bearer ${secret}`) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders });
  }

  const db = getAdminDb();

  try {
    const payload = await req.json();
    const eventId: string = payload?.event_id || payload?.id || '';
    if (!eventId) {
      return new Response('Bad Request', { status: 400, headers: corsHeaders });
    }

    const appUserId: string = payload?.app_user_id || payload?.event?.app_user_id || '';
    if (!appUserId) {
      return new Response('Bad Request', { status: 400, headers: corsHeaders });
    }

    const type: string = payload?.type || payload?.event?.type || '';

    const idempotencyRef = db.collection('revenuecat_events').doc(eventId);
    const userBalanceRef = db.collection('users').doc(appUserId).collection('credits').doc('balance');

    const result = await db.runTransaction(async (tx) => {
      const seen = await tx.get(idempotencyRef);
      if (seen.exists) {
        return { duplicated: true };
      }

      let delta = 0;
      // Handle minimal set: subscription initial/renewal grant 100; refund subtract 100.
      if (type.includes('INITIAL_PURCHASE') || type.includes('RENEWAL')) {
        delta = 100;
      } else if (type.includes('PRODUCT_REFUND') || type.includes('CANCELLATION')) {
        delta = -100;
      }

      // If delta is 0, just mark event handled
      if (delta === 0) {
        tx.set(idempotencyRef, { handledAt: new Date().toISOString(), appUserId, type, delta: 0 });
        return { duplicated: false };
      }

      const snap = await tx.get(userBalanceRef);
      const data = snap.exists ? (snap.data() as any) : { balance: 0 };
      const current = Number(data.balance ?? 0);
      const newBalance = Math.max(0, current + delta);

      tx.set(userBalanceRef, {
        balance: newBalance,
        plan: { tier: 'premium_monthly', allowance: 100 },
        // For reset policy, set nextReset to approximate 1 cycle out if payload has period_end
        nextReset: data.nextReset ?? null,
        updatedAt: new Date().toISOString(),
      }, { merge: true });

      tx.set(idempotencyRef, { handledAt: new Date().toISOString(), appUserId, type, delta });
      return { duplicated: false };
    });

    return new Response(JSON.stringify({ success: true, ...result }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ success: false, error: e?.message || 'Unhandled' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }
}


