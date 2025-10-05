export const config = {
  runtime: 'edge',
};

/**
 * POST /api/usage/calculate
 *
 * Calculates accurate costs from OpenRouter generation IDs.
 * This moves cost calculation logic from Flutter's CostService to the backend.
 *
 * Request body:
 * {
 *   "generationIds": [
 *     { "id": "gen_123", "stage": "planner", "model": "google/gemini-2.5-flash-lite" },
 *     { "id": "gen_456", "stage": "writer", "model": "google/gemini-2.5-flash-lite" }
 *   ]
 * }
 *
 * Response:
 * {
 *   "success": true,
 *   "data": {
 *     "totalCost": 0.00123,
 *     "breakdown": {
 *       "planner": {
 *         "model": "google/gemini-2.5-flash-lite",
 *         "cost": 0.00056,
 *         "success": true,
 *         "generationId": "gen_123",
 *         "inputTokens": 500,
 *         "outputTokens": 300,
 *         "totalTokens": 800
 *       },
 *       ...
 *     },
 *     "hasAccurateCosts": true,
 *     "successfulFetches": 2,
 *     "failedFetches": 0,
 *     "accuracy": 1.0
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
    const generationIds = body?.generationIds as Array<{
      id: string;
      stage?: string;
      model?: string;
    }>;

    if (!generationIds || !Array.isArray(generationIds) || generationIds.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'No generation IDs provided',
          data: {
            totalCost: 0.0,
            breakdown: {},
            hasAccurateCosts: false,
          },
        }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    const openRouterApiKey = process.env.OPENROUTER_API_KEY;
    if (!openRouterApiKey) {
      throw new Error('OPENROUTER_API_KEY not configured');
    }

    // Fetch generation details from OpenRouter
    const generations: any[] = [];
    let successfulFetches = 0;
    let failedFetches = 0;

    for (const gen of generationIds) {
      try {
        const response = await fetch(`https://openrouter.ai/api/v1/generation?id=${gen.id}`, {
          headers: {
            Authorization: `Bearer ${openRouterApiKey}`,
            'Content-Type': 'application/json',
          },
        });

        if (response.ok) {
          const data = await response.json();
          generations.push({
            ...gen,
            success: true,
            costData: data.data,
            inputTokens: data.data?.tokens_prompt || 0,
            outputTokens: data.data?.tokens_completion || 0,
            totalTokens: (data.data?.tokens_prompt || 0) + (data.data?.tokens_completion || 0),
          });
          successfulFetches++;
        } else {
          generations.push({
            ...gen,
            success: false,
            costData: null,
            inputTokens: 0,
            outputTokens: 0,
            totalTokens: 0,
          });
          failedFetches++;
        }
      } catch (err) {
        console.error(`Failed to fetch generation ${gen.id}:`, err);
        generations.push({
          ...gen,
          success: false,
          costData: null,
          inputTokens: 0,
          outputTokens: 0,
          totalTokens: 0,
        });
        failedFetches++;
      }
    }

    // Calculate costs
    const breakdown: Record<string, any> = {};
    let totalCost = 0.0;

    for (const gen of generations) {
      const stage = gen.stage || 'unknown';
      const model = gen.model || 'unknown';
      const cost = gen.success
        ? parseFloat(gen.costData?.total_cost || '0') || 0.0
        : 0.0;

      breakdown[stage] = {
        model,
        cost,
        success: gen.success,
        generationId: gen.id,
        inputTokens: gen.inputTokens,
        outputTokens: gen.outputTokens,
        totalTokens: gen.totalTokens,
        costData: gen.costData,
      };

      totalCost += cost;
    }

    const accuracy = generationIds.length > 0 ? successfulFetches / generationIds.length : 0;

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          totalCost,
          breakdown,
          hasAccurateCosts: successfulFetches > 0,
          successfulFetches,
          failedFetches,
          accuracy,
        },
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      }
    );
  } catch (error) {
    console.error('Error calculating costs:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Failed to calculate costs',
        message: error instanceof Error ? error.message : 'Unknown error',
        data: {
          totalCost: 0.0,
          breakdown: {},
          hasAccurateCosts: false,
        },
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      }
    );
  }
}
