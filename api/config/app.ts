import {
  FEATURE_FLAGS,
  QUOTA_CONFIG,
  VERSION_CONFIG,
  TIMEOUT_CONFIG,
  CACHE_CONFIG,
} from '../shared/config-data';
import { verifyAuthForEdge, createUnauthorizedResponse } from '../shared/auth-helpers';

export const config = {
  runtime: 'edge',
};

/**
 * GET /api/config/app
 *
 * Returns app-level configuration including feature flags, quotas, and version info.
 * Used by AppConfig for dynamic feature management.
 * 
 * SECURITY: Requires authentication to prevent exposing business logic to competitors.
 * If you need public config for pre-authentication screens, create a separate endpoint.
 *
 * Response format:
 * {
 *   success: true,
 *   data: {
 *     features: { enableWebSearch: true, ... },
 *     quotas: { initialRequestAllocation: 1000, ... },
 *     version: { minSupportedVersion: "1.0.0", ... },
 *     timeouts: { connectTimeout: 60000, ... }
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
    console.error('App config - Authentication failed:', auth.error);
    return createUnauthorizedResponse(auth.error || 'Unauthorized', corsHeaders);
  }

  const response = {
    success: true,
    data: {
      features: FEATURE_FLAGS,
      quotas: QUOTA_CONFIG,
      version: VERSION_CONFIG,
      timeouts: TIMEOUT_CONFIG,
    },
    cached_until: Date.now() + CACHE_CONFIG.appConfigCacheDuration * 1000,
    version: '1.0.0',
  };

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      // Shorter cache for app config (5 minutes) to enable quick feature toggles
      'Cache-Control': `public, s-maxage=${CACHE_CONFIG.appConfigCacheDuration}, stale-while-revalidate=600`,
      ...corsHeaders,
    },
  });
}
