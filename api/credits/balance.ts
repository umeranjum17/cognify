import { getAdminDb, verifyFirebaseIdToken } from '../shared/firebase-admin';

export const config = { runtime: 'nodejs18.x' };

export default async function handler(req: Request) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } as const;

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'GET') {
    return new Response('Method Not Allowed', { status: 405, headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('authorization') ?? undefined;
    const decoded = await verifyFirebaseIdToken(authHeader);
    const uid = decoded.uid;

    // For MVP: read mirrored balance from Firestore if present.
    // If you later adopt RC REST balance reads, replace this lookup accordingly.
    const db = getAdminDb();
    const docRef = db.collection('users').doc(uid).collection('credits').doc('balance');
    const snap = await docRef.get();
    const data = snap.exists ? snap.data() : null;

    const balance = data?.balance ?? 0;
    const updatedAt = data?.updatedAt ?? null;
    const plan = data?.plan ?? { tier: 'free', allowance: 0 };
    const nextReset = data?.nextReset ?? null;

    return new Response(
      JSON.stringify({ success: true, data: { balance, plan, nextReset, updatedAt } }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (e: any) {
    return new Response(
      JSON.stringify({ success: false, error: e?.message ?? 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
}


