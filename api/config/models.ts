import {
  MODEL_DEFAULTS,
  CACHE_CONFIG,
  QUOTA_CONFIG,
} from '../shared/config-data';
import { verifyAuthForEdge, createUnauthorizedResponse } from '../shared/auth-helpers';

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
 * SECURITY: Requires authentication to prevent exposing pricing and business logic.
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
  console.log('[MODELS API] Request received:', {
    method: req.method,
    url: req.url,
    headers: Array.from(req.headers.entries())
  });

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } as const;

  if (req.method === 'OPTIONS') {
    console.log('[MODELS API] Handling OPTIONS request');
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // ============================================
  // AUTHENTICATION CHECK
  // ============================================
  const auth = await verifyAuthForEdge(req);
  if (!auth.success) {
    console.error('[MODELS API] Authentication failed:', auth.error);
    return createUnauthorizedResponse(auth.error || 'Unauthorized', corsHeaders);
  }
  
  console.log(`[MODELS API] Authenticated request from user: ${auth.uid}`);

  try {
    console.log('[MODELS API] Fetching models from OpenRouter...');
    // Fetch model data from OpenRouter
    const response = await fetch('https://openrouter.ai/api/v1/models', {
      headers: {
        'Content-Type': 'application/json',
      },
    });

    console.log('[MODELS API] OpenRouter response status:', response.status);

    if (!response.ok) {
      throw new Error(`OpenRouter API error: ${response.status}`);
    }

    const openRouterData = (await response.json()) as any;

    const capabilities: Record<string, any> = {};
    const pricing: Record<string, { input: number; output: number }> = {};
    // Derived pricing helpers
    const perModelSampleCosts: Record<string, { per1kTokensDollarCost: number; per1kTokensRequestUnits: number }> = {};
    const perRequestSampleChat: Record<string, { requestUnits: number; dollarCost: number; inputTokens: number; outputTokens: number }> = {};
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
        // Derived helpers
        const p = pricing[model.id];
        if (p) {
          const dollarsPerRequestUnit = QUOTA_CONFIG.dollarsPerRequestUnit;
          const costPer1k = (1000 / 1_000_000) * (p.input + p.output);
          const unitsPer1k = costPer1k > 0 ? Math.max(1, Math.ceil(costPer1k / dollarsPerRequestUnit)) : 0;
          perModelSampleCosts[model.id] = {
            per1kTokensDollarCost: costPer1k,
            per1kTokensRequestUnits: unitsPer1k,
          };

          // Default chat estimate (900 in / 1100 out)
          const inT = 900;
          const outT = 1100;
          const chatDollar = (inT / 1_000_000) * p.input + (outT / 1_000_000) * p.output;
          const chatUnits = chatDollar > 0 ? Math.max(1, Math.ceil(chatDollar / dollarsPerRequestUnit)) : 0;
          perRequestSampleChat[model.id] = {
            requestUnits: chatUnits,
            dollarCost: chatDollar,
            inputTokens: inT,
            outputTokens: outT,
          };
        }
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
        quotaPricing: {
          dollarsPerRequestUnit: QUOTA_CONFIG.dollarsPerRequestUnit,
          perModelSampleCosts,
          perRequestSample: {
            chat: perRequestSampleChat,
          },
        },
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


