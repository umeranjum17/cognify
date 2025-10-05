import {
  FEATURE_FLAGS,
  QUOTA_CONFIG,
  VERSION_CONFIG,
  TIMEOUT_CONFIG,
  CACHE_CONFIG,
  MODEL_DEFAULTS,
} from '../shared/config-data';

export const config = {
  runtime: 'edge',
};

/**
 * GET /api/config
 *
 * Unified configuration endpoint combining:
 * - app: feature flags, quotas, version, timeouts
 * - models: defaults, capabilities, available
 * - pricing: per 1M tokens pricing for each model
 * - quotaPricing: derived costs in request units and dollar mapping
 *
 * The frontend should consume this and display without extra calculations.
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
    // Fetch OpenRouter models (for capabilities and pricing)
    const response = await fetch('https://openrouter.ai/api/v1/models', {
      headers: { 'Content-Type': 'application/json' },
    });

    if (!response.ok) {
      throw new Error(`OpenRouter API error: ${response.status}`);
    }

    const openRouterData = await response.json();

    const capabilities: Record<string, any> = {};
    const pricing: Record<string, { input: number; output: number }> = {};
    const availableModels: string[] = [];

    if (openRouterData.data && Array.isArray(openRouterData.data)) {
      for (const model of openRouterData.data) {
        if (!model.id) continue;

        availableModels.push(model.id);

        if (model.pricing) {
          pricing[model.id] = {
            input: parseFloat(model.pricing.prompt) * 1_000_000,
            output: parseFloat(model.pricing.completion) * 1_000_000,
          };
        }

        const isFree = pricing[model.id]?.input === 0 && pricing[model.id]?.output === 0;

        capabilities[model.id] = {
          provider: model.id.split('/')[0] || 'unknown',
          isFree,
          isReasoning: model.id.includes('r1') || model.id.includes('reasoning'),
          maxTokens: model.context_length || 8192,
          description: model.description || model.name || 'No description available',
          inputModalities: ['text'],
          outputModalities: ['text'],
          supportsImages: model.architecture?.modality?.includes('image') || false,
          supportsFiles: false,
          isMultimodal: model.architecture?.modality?.includes('image') || false,
        };
      }
    }

    // Derive quota-based helpers
    const dollarsPerRequestUnit = QUOTA_CONFIG.dollarsPerRequestUnit;
    const quotaPricing = {
      dollarsPerRequestUnit,
      initialRequestAllocation: QUOTA_CONFIG.initialRequestAllocation,
      // For each model, provide cost of 1k tokens in request units as a helpful UI aid
      perModelSampleCosts: Object.fromEntries(
        Object.entries(pricing).map(([modelId, p]) => {
          const costPer1k = (1000 / 1_000_000) * (p.input + p.output);
          const requestUnits = costPer1k > 0 ? Math.max(1, Math.ceil(costPer1k / dollarsPerRequestUnit)) : 0;
          return [modelId, { per1kTokensDollarCost: costPer1k, per1kTokensRequestUnits: requestUnits }];
        })
      ),
    };

    const payload = {
      success: true,
      data: {
        app: {
          features: FEATURE_FLAGS,
          quotas: QUOTA_CONFIG,
          version: VERSION_CONFIG,
          timeouts: TIMEOUT_CONFIG,
        },
        models: {
          defaults: MODEL_DEFAULTS,
          capabilities,
          available: availableModels,
        },
        pricing,
        quotaPricing,
      },
      cached_until: Date.now() + Math.min(
        CACHE_CONFIG.appConfigCacheDuration,
        CACHE_CONFIG.modelsCacheDuration,
        CACHE_CONFIG.pricingCacheDuration
      ) * 1000,
      version: '1.0.0',
    };

    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, s-maxage=${Math.min(
          CACHE_CONFIG.appConfigCacheDuration,
          CACHE_CONFIG.modelsCacheDuration,
          CACHE_CONFIG.pricingCacheDuration
        )}, stale-while-revalidate=3600`,
        ...corsHeaders,
      },
    });
  } catch (error) {
    console.error('Error building unified config:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Failed to load configuration',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      }
    );
  }
}


