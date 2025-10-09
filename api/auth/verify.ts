import { getAdminAuth, verifyFirebaseIdToken } from '../shared/firebase-admin.js';

export const config = { runtime: 'nodejs' };

/**
 * POST /api/auth/verify
 * 
 * Lightweight authentication verification endpoint for use by Edge runtime functions.
 * Verifies Firebase ID token and returns user information.
 * 
 * Request:
 * - Headers: Authorization: Bearer <token>
 * 
 * Response (200):
 * {
 *   success: true,
 *   uid: "user-id",
 *   email: "user@example.com"
 * }
 * 
 * Response (401):
 * {
 *   success: false,
 *   error: "Unauthorized"
 * }
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
    return new Response(
      JSON.stringify({ success: false, error: 'Method not allowed' }),
      { status: 405, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  try {
    const authHeader = req.headers.get('authorization') ?? undefined;
    const decoded = await verifyFirebaseIdToken(authHeader);
    
    return new Response(
      JSON.stringify({
        success: true,
        uid: decoded.uid,
        email: decoded.email ?? null,
        email_verified: decoded.email_verified ?? false,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (e: any) {
    return new Response(
      JSON.stringify({
        success: false,
        error: e?.message ?? 'Unauthorized',
      }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
}

