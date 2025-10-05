import { QUOTA_CONFIG } from '../shared/config-data';

export const config = {
  runtime: 'edge',
};

/**
 * POST /api/usage/estimate
 *
 * Estimates request usage (units and dollar cost) for a given model and mode.
 * This moves all cost estimation logic from Flutter to the backend.
 *
 * Request body:
 * {
 *   "model": "google/gemini-2.5-flash-lite",
 *   "mode": "chat" | "search" | "aipedia" | "deepsearch",
 *   "inputTokens": 900,     // optional, defaults used if not provided
 *   "outputTokens": 1100    // optional, defaults used if not provided
 * }
 *
 * Response:
 * {
 *   "success": true,
 *   "data": {
 *     "requestUnits": 1,
 *     "dollarCost": 0.01,
 *     "inputTokens": 900,
 *     "outputTokens": 1100,
 *     "isFree": false
 *   }
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
    const body = await req.json();
    const modelId = body?.model as string;
    const mode = (body?.mode as string) || 'chat';
    const inputTokens = body?.inputTokens as number | undefined;
    const outputTokens = body?.outputTokens as number | undefined;

    if (!modelId) {
      return new Response(
        JSON.stringify({ success: false, error: 'Model ID is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Fetch pricing from OpenRouter
    const pricingResponse = await fetch('https://openrouter.ai/api/v1/models', {
      headers: { 'Content-Type': 'application/json' },
    });

    if (!pricingResponse.ok) {
      throw new Error(`Failed to fetch pricing: ${pricingResponse.status}`);
    }

    const openRouterData = await pricingResponse.json();
    const modelData = openRouterData.data?.find((m: any) => m.id === modelId);

    if (!modelData?.pricing) {
      return new Response(
        JSON.stringify({ success: false, error: 'Model pricing not found' }),
        { status: 404, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Calculate pricing per million tokens
    const inputPricePerMillion = parseFloat(modelData.pricing.prompt) * 1_000_000;
    const outputPricePerMillion = parseFloat(modelData.pricing.completion) * 1_000_000;

    // Check if free model
    const isFree = inputPricePerMillion === 0 && outputPricePerMillion === 0;

    if (isFree) {
      return new Response(
        JSON.stringify({
          success: true,
          data: {
            requestUnits: 0,
            dollarCost: 0,
            inputTokens: 0,
            outputTokens: 0,
            isFree: true,
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Mode-specific token multipliers (from Flutter's request_usage_estimator.dart)
    const modeMultipliers: Record<string, number> = {
      chat: 1.0,
      search: 1.3,
      aipedia: 1.5,
      deepsearch: 8.0,
    };

    const multiplier = modeMultipliers[mode] || 1.0;

    // Default token estimates (from Flutter)
    const DEFAULT_INPUT_TOKENS = 900;
    const DEFAULT_OUTPUT_TOKENS = 1100;

    // Calculate actual tokens with multiplier
    const resolvedInputTokens = Math.max(
      0,
      Math.round((inputTokens ?? DEFAULT_INPUT_TOKENS) * multiplier)
    );
    const resolvedOutputTokens = Math.max(
      0,
      Math.round((outputTokens ?? DEFAULT_OUTPUT_TOKENS) * multiplier)
    );

    // Calculate dollar cost
    const estimatedDollarCost =
      (resolvedInputTokens / 1_000_000) * inputPricePerMillion +
      (resolvedOutputTokens / 1_000_000) * outputPricePerMillion;

    if (estimatedDollarCost <= 0) {
      return new Response(
        JSON.stringify({
          success: true,
          data: {
            requestUnits: 0,
            dollarCost: 0,
            inputTokens: resolvedInputTokens,
            outputTokens: resolvedOutputTokens,
            isFree: true,
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Calculate request units
    const dollarsPerRequestUnit = QUOTA_CONFIG.dollarsPerRequestUnit;
    const requestUnits = Math.max(1, Math.ceil(estimatedDollarCost / dollarsPerRequestUnit));

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          requestUnits,
          dollarCost: estimatedDollarCost,
          inputTokens: resolvedInputTokens,
          outputTokens: resolvedOutputTokens,
          isFree: false,
        },
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      }
    );
  } catch (error) {
    console.error('Error estimating usage:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Failed to estimate usage',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      }
    );
  }
}
