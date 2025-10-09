import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import {
  MODEL_DEFAULTS,
  MODE_CONFIGS,
  FEATURE_FLAGS,
  QUOTA_CONFIG,
  VERSION_CONFIG,
  TIMEOUT_CONFIG,
  CACHE_CONFIG,
} from '../config/config-data.js';

export const configRouter = express.Router();

// GET /api/config - Get all configuration
configRouter.get('/', requireAuth, async (req, res) => {
  try {
    // Fetch models from OpenRouter (public endpoint)
    const response = await fetch('https://openrouter.ai/api/v1/models', {
      headers: { 'Content-Type': 'application/json' },
    });
    if (!response.ok) throw new Error(`OpenRouter API error: ${response.status}`);

    const openRouterData: any = await response.json();

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

    const dollarsPerRequestUnit = QUOTA_CONFIG.dollarsPerRequestUnit;
    const quotaPricing = {
      dollarsPerRequestUnit,
      initialRequestAllocation: QUOTA_CONFIG.initialRequestAllocation,
      perModelSampleCosts: Object.fromEntries(
        Object.entries(pricing).map(([modelId, p]) => {
          const costPer1k = (1000 / 1_000_000) * (p.input + p.output);
          const requestUnits = costPer1k > 0 ? Math.max(1, Math.ceil(costPer1k / dollarsPerRequestUnit)) : 0;
          return [modelId, { per1kTokensDollarCost: costPer1k, per1kTokensRequestUnits: requestUnits }];
        })
      ),
    };

    res.json({
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
        CACHE_CONFIG.pricingCacheDuration,
      ) * 1000,
      version: '1.0.0',
    });
  } catch (error: any) {
    console.error('Unified config error:', error);
    res.status(500).json({ success: false, error: 'Failed to load configuration', message: error.message });
  }
});

// GET /api/config/app - App configuration
configRouter.get('/app', requireAuth, (req, res) => {
  res.json({
    features: FEATURE_FLAGS,
    version: VERSION_CONFIG,
    timeout: TIMEOUT_CONFIG,
    modelDefaults: MODEL_DEFAULTS,
  });
});

// GET /api/config/models - Available models
configRouter.get('/models', requireAuth, async (req, res) => {
  try {
    const response = await fetch('https://openrouter.ai/api/v1/models', {
      headers: { 'Content-Type': 'application/json' },
    });
    if (!response.ok) throw new Error(`OpenRouter API error: ${response.status}`);

    const openRouterData: any = await response.json();
    const capabilities: Record<string, any> = {};
    const pricing: Record<string, { input: number; output: number }> = {};
    const perModelSampleCosts: Record<string, { per1kTokensDollarCost: number; per1kTokensRequestUnits: number }> = {};
    const perRequestSampleChat: Record<string, { requestUnits: number; dollarCost: number; inputTokens: number; outputTokens: number }> = {};
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

        const p = pricing[model.id];
        if (p) {
          const dollarsPerRequestUnit = QUOTA_CONFIG.dollarsPerRequestUnit;
          const costPer1k = (1000 / 1_000_000) * (p.input + p.output);
          const unitsPer1k = costPer1k > 0 ? Math.max(1, Math.ceil(costPer1k / dollarsPerRequestUnit)) : 0;
          perModelSampleCosts[model.id] = {
            per1kTokensDollarCost: costPer1k,
            per1kTokensRequestUnits: unitsPer1k,
          };

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

    res.json({
      success: true,
      data: {
        defaults: MODEL_DEFAULTS,
        capabilities,
        available: availableModels,
        pricing,
        quotaPricing: {
          dollarsPerRequestUnit: QUOTA_CONFIG.dollarsPerRequestUnit,
          perModelSampleCosts,
          perRequestSample: { chat: perRequestSampleChat },
        },
      },
      cached_until: Date.now() + CACHE_CONFIG.modelsCacheDuration * 1000,
      version: '1.0.0',
    });
  } catch (error: any) {
    console.error('Error fetching models from OpenRouter:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch model data', message: error.message });
  }
});

// GET /api/config/modes - Available modes
configRouter.get('/modes', requireAuth, (req, res) => {
  res.json({ modes: MODE_CONFIGS });
});

// GET /api/config/pricing - Pricing information
configRouter.get('/pricing', requireAuth, (req, res) => {
  res.json({
    quota: QUOTA_CONFIG,
    cache: CACHE_CONFIG,
  });
});

