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
    const requestId = String(body?.requestId ?? '');
    if (!requestId) {
      return new Response(
        JSON.stringify({ success: false, error: 'requestId required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    const db = getAdminDb();
    const balanceRef = db.collection('users').doc(uid).collection('credits').doc('balance');
    const consumptionRef = db.collection('users').doc(uid).collection('consumptions').doc(requestId);
    const refundRef = db.collection('users').doc(uid).collection('refunds').doc(requestId);

    const result = await db.runTransaction(async (tx: any) => {
      const consumedSnap = await tx.get(consumptionRef);
      if (!consumedSnap.exists) {
        throw new Error('NOT_CONSUMED');
      }
      const refundSnap = await tx.get(refundRef);
      if (refundSnap.exists) {
        const b = await tx.get(balanceRef);
        const bd = b.exists ? b.data() : { balance: 0 } as any;
        return { duplicated: true, balance: bd.balance ?? 0 };
      }

      const consumed = consumedSnap.data() as any;
      const amount = Number(consumed.amount ?? 0);
      if (!amount) {
        throw new Error('INVALID_CONSUMPTION');
      }

      const snap = await tx.get(balanceRef);
      const data = snap.exists ? (snap.data() as any) : { balance: 0 };
      const current = Number(data.balance ?? 0);
      const newBalance = current + amount;
      tx.set(balanceRef, {
        balance: newBalance,
        updatedAt: new Date().toISOString(),
      }, { merge: true });
      tx.set(refundRef, {
        amount,
        createdAt: new Date().toISOString(),
      });
      return { duplicated: false, balance: newBalance };
    });

    return new Response(
      JSON.stringify({ success: true, data: { balance: result.balance }, duplicated: result.duplicated }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (e: any) {
    const code = e?.message;
    const status = code === 'NOT_CONSUMED' ? 409 : 400;
    return new Response(
      JSON.stringify({ success: false, error: code || 'Bad Request' }),
      { status, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
}


