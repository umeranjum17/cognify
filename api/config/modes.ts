import { MODE_CONFIGS, CACHE_CONFIG } from '../shared/config-data';
import { verifyAuthForEdge, createUnauthorizedResponse } from '../shared/auth-helpers';

export const config = {
  runtime: 'edge',
};

/**
 * GET /api/config/modes
 *
 * Returns chat mode configurations (chat, search, aipedia, deepsearch).
 * Used by ModeConfigManager for mode selection and model assignment.
 * 
 * SECURITY: Requires authentication to prevent exposing business logic.
 *
 * Response format:
 * {
 *   success: true,
 *   data: {
 *     chat: {
 *       model: "...",
 *       displayName: "Chat",
 *       description: "...",
 *       defaultModel: "...",
 *       availableModels: ["model-1", ...]
 *     },
 *     ...
 *   }
 * }
 */
export default async function handler(req: Request) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } as const;

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // ============================================
  // AUTHENTICATION CHECK
  // ============================================
  const auth = await verifyAuthForEdge(req);
  if (!auth.success) {
    console.error('Modes config - Authentication failed:', auth.error);
    return createUnauthorizedResponse(auth.error || 'Unauthorized', corsHeaders);
  }

  const response = {
    success: true,
    data: MODE_CONFIGS,
    cached_until: Date.now() + CACHE_CONFIG.modesCacheDuration * 1000,
    version: '1.0.0',
  };

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': `public, s-maxage=${CACHE_CONFIG.modesCacheDuration}, stale-while-revalidate=3600`,
      ...corsHeaders,
    },
  });
}


