import {
  MODEL_DEFAULTS,
  CACHE_CONFIG,
} from '../shared/config-data';

export const config = {
  runtime: 'edge',
};

/**
 * GET /api/config/models
 *
 * Returns available models, their capabilities, and default selections.
 * Fetches real-time model data from OpenRouter API.
 * Used by ModelRegistry and ModelService for model selection.
 *
 * Response format:
 * {
 *   success: true,
 *   data: {
 *     defaults: { CHAT_MODE: "...", DEEPSEARCH_MODE: "..." },
 *     capabilities: { "model-id": { ... } },
 *     available: ["model-id-1", "model-id-2", ...],
 *     pricing: { "model-id": { input: 0.0, output: 0.0 } }
 *   }
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

    const capabilities: Record<string, any> = {};
    const pricing: Record<string, { input: number; output: number }> = {};
    const availableModels: string[] = [];

    if (openRouterData.data && Array.isArray(openRouterData.data)) {
      for (const model of openRouterData.data) {
        if (!model.id) continue;

        availableModels.push(model.id);

        // Transform pricing (OpenRouter uses per-token pricing, we use per 1M tokens)
        if (model.pricing) {
          pricing[model.id] = {
            input: parseFloat(model.pricing.prompt) * 1_000_000,
            output: parseFloat(model.pricing.completion) * 1_000_000,
          };
        }

        // Transform capabilities
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

    // Build response
    const responseData = {
      success: true,
      data: {
        defaults: MODEL_DEFAULTS,
        capabilities,
        available: availableModels,
        pricing,
      },
      cached_until: Date.now() + CACHE_CONFIG.modelsCacheDuration * 1000,
      version: '1.0.0',
    };

    return new Response(JSON.stringify(responseData), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, s-maxage=${CACHE_CONFIG.modelsCacheDuration}, stale-while-revalidate=3600`,
        ...corsHeaders,
      },
    });
  } catch (error) {
    console.error('Error fetching models from OpenRouter:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: 'Failed to fetch model data',
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
