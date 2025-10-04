import { CACHE_CONFIG } from '../shared/config-data';

export const config = {
  runtime: 'edge',
};

/**
 * GET /api/config/pricing
 *
 * Returns model pricing information (per 1 million tokens).
 * Fetches real-time pricing from OpenRouter API.
 * Used by CostService to calculate request costs.
 *
 * Response format:
 * {
 *   success: true,
 *   data: {
 *     "model-id": { input: 0.0, output: 0.0 },
 *     ...
 *   },
 *   cached_until: timestamp
 * }
 */
export default async function handler(req: Request) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  } as const;

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    // Fetch model data from OpenRouter
    const response = await fetch('https://openrouter.ai/api/v1/models', {
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`OpenRouter API error: ${response.status}`);
    }

    const openRouterData = await response.json();

    // Transform OpenRouter pricing to our format
    // OpenRouter pricing is per token, we need per 1 million tokens
    const pricing: Record<string, { input: number; output: number }> = {};

    if (openRouterData.data && Array.isArray(openRouterData.data)) {
      for (const model of openRouterData.data) {
        if (model.id && model.pricing) {
          pricing[model.id] = {
            input: parseFloat(model.pricing.prompt) * 1_000_000,
            output: parseFloat(model.pricing.completion) * 1_000_000,
          };
        }
      }
    }

    const cacheUntil = Date.now() + CACHE_CONFIG.pricingCacheDuration * 1000;

    return new Response(
      JSON.stringify({
        success: true,
        data: pricing,
        cached_until: cacheUntil,
        version: '1.0.0',
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': `public, s-maxage=${CACHE_CONFIG.pricingCacheDuration}, stale-while-revalidate=3600`,
          ...corsHeaders,
        },
      }
    );
  } catch (error) {
    console.error('Error fetching pricing from OpenRouter:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: 'Failed to fetch pricing data',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        },
      }
    );
  }
}
