/**
 * Authentication helpers for Edge runtime endpoints
 * 
 * Since Edge runtime cannot use Firebase Admin SDK directly,
 * these helpers provide authentication by calling the verify endpoint.
 */

export interface VerifyResult {
  success: boolean;
  uid?: string;
  email?: string;
  email_verified?: boolean;
  error?: string;
}

/**
 * Verifies authentication for Edge runtime endpoints.
 * Makes an internal call to /api/auth/verify (Node.js runtime).
 * 
 * @param req - The incoming request object
 * @returns VerifyResult with user info or error
 * 
 * @example
 * ```typescript
 * const auth = await verifyAuthForEdge(req);
 * if (!auth.success) {
 *   return new Response(
 *     JSON.stringify({ error: auth.error }),
 *     { status: 401, headers: { 'Content-Type': 'application/json' } }
 *   );
 * }
 * // Use auth.uid to proceed
 * ```
 */
export async function verifyAuthForEdge(req: Request): Promise<VerifyResult> {
  try {
    const authHeader = req.headers.get('authorization');
    if (!authHeader) {
      return { success: false, error: 'Missing Authorization header' };
    }

    // Extract base URL from the request
    const baseUrl = req.url.split('/api/')[0];
    
    // Call the verify endpoint
    const verifyResponse = await fetch(`${baseUrl}/api/auth/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
    });

    const result = await verifyResponse.json();
    
    if (!verifyResponse.ok || !result.success) {
      return {
        success: false,
        error: result.error || 'Authentication failed',
      };
    }

    return {
      success: true,
      uid: result.uid,
      email: result.email,
      email_verified: result.email_verified,
    };
  } catch (e) {
    return {
      success: false,
      error: e instanceof Error ? e.message : 'Authentication failed',
    };
  }
}

/**
 * Creates a standardized 401 Unauthorized response
 */
export function createUnauthorizedResponse(error: string = 'Unauthorized', corsHeaders?: Record<string, string>) {
  const headers = {
    'Content-Type': 'application/json',
    ...(corsHeaders || {}),
  };
  
  return new Response(
    JSON.stringify({ error }),
    { status: 401, headers }
  );
}

/**
 * Extracts Authorization header and validates format
 */
export function extractAuthHeader(req: Request): string | null {
  const authHeader = req.headers.get('authorization');
  if (!authHeader) return null;
  
  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') return null;
  
  return authHeader;
}

