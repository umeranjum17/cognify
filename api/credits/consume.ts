import { getAdminDb, verifyFirebaseIdToken } from '../shared/firebase-admin';

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

  try {
    const authHeader = req.headers.get('authorization') ?? undefined;
    const decoded = await verifyFirebaseIdToken(authHeader);
    const uid = decoded.uid;

    const body = await req.json();
    const amount = Math.max(0, Number(body?.amount ?? 0));
    const reason = String(body?.reason ?? 'generic');
    const requestId = String(body?.requestId ?? '');
    if (!amount || !requestId) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid body' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
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
        reason,
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
      JSON.stringify({ success: true, data: { balance: result.balance } }),
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


