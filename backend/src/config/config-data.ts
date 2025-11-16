/**
 * Centralized Configuration Data
 *
 * This is the single source of truth for all app configuration.
 * Update these values to instantly change app behavior without releases.
 *
 * Note: Model pricing and capabilities are fetched dynamically from OpenRouter API.
 * Only configuration defaults and feature flags are stored here.
 */

// ========== MODEL DEFAULTS ==========
// These are model IDs that will be used as defaults for different modes
// Ensure these models are available in OpenRouter

export const MODEL_DEFAULTS = {
  CHAT_MODE: 'google/gemini-2.5-flash-lite',
  DEEPSEARCH_MODE: 'deepseek/deepseek-r1:free',
  PLANNER_AGENT: 'google/gemini-2.5-flash-lite',
  WRITER_AGENT: 'google/gemini-2.5-flash-lite',
  CLOUD_FALLBACK: 'google/gemini-flash-1.5',
  BUDGET_MODEL: 'deepseek/deepseek-chat:free',
  FOLLOWUP_QUESTIONS: 'google/gemini-2.5-flash-lite',
} as const;

// ========== MODE CONFIGURATIONS ==========

export const MODE_CONFIGS = {
  chat: {
    id: 'chat',
    enabled: true, // Backend can enable/disable modes
    order: 1, // Display order in UI
    endpoint: '/api/chat', // Single unified endpoint
    model: 'google/gemini-2.5-flash-lite',
    displayName: 'Chat',
    description: 'Lightning fast responses with minimal search',
    icon: '💬',
    color: '#4A90E2', // UI color hint
    defaultModel: 'google/gemini-2.5-flash-lite',
    // Empty list means: allow all models from unified models config
    availableModels: [],
    capabilities: ['text', 'image'],
    temperature: 0.7,
    maxTokens: 8000, // Safety limit: 8k tokens max
    // UI hints - backend tells frontend how to display
    showInMainMenu: true,
    requiresPremium: false,
    badge: null, // 'NEW', 'BETA', null
  },
  search: {
    id: 'search',
    enabled: true,
    order: 2,
    endpoint: '/api/chat', // Same endpoint, different mode parameter
    model: 'google/gemini-2.5-flash-lite',
    displayName: 'Search',
    description: 'Perplexity-style quick web answers',
    icon: '🔍',
    color: '#50C878',
    defaultModel: 'google/gemini-2.5-flash-lite',
    availableModels: [
      'google/gemini-2.5-flash-lite',
    ],
    capabilities: ['text', 'web-search', 'image'],
    temperature: 0.7,
    maxTokens: 12000, // Safety limit: 12k tokens max
    showInMainMenu: true,
    requiresPremium: false,
    badge: null,
  },
  aipedia: {
    id: 'aipedia',
    enabled: true,
    order: 3,
    endpoint: '/api/chat', // Same endpoint, different mode parameter
    model: 'google/gemini-2.5-flash-lite',
    displayName: 'AIpedia',
    description: 'Wikipedia-style overviews with sources and images',
    icon: '📚',
    color: '#9B59B6',
    defaultModel: 'google/gemini-2.5-flash-lite',
    availableModels: [
      'google/gemini-2.5-flash-lite'
    ],
    capabilities: ['text', 'web-search', 'image-search', 'image'],
    temperature: 0.5,
    maxTokens: 16000, // Safety limit: 16k tokens max
    showInMainMenu: true,
    requiresPremium: false,
    badge: null,
  },
  deepsearch: {
    id: 'deepsearch',
    enabled: false, // Can disable if quota issues or testing
    order: 4,
    endpoint: '/api/chat', // Same endpoint, different mode parameter
    model: 'deepseek/deepseek-r1:free',
    displayName: 'DeepSearch',
    description: 'Ultra-comprehensive research with enhanced visual content',
    icon: '🔬',
    color: '#E74C3C',
    defaultModel: 'deepseek/deepseek-r1:free',
    availableModels: [
      'deepseek/deepseek-r1:free',
      'deepseek/deepseek-chat:free',
    ],
    capabilities: ['text', 'web-search', 'deep-research'],
    temperature: 0.6,
    maxTokens: 15000, // Safety limit: 15k tokens max (reasoning models charged 10x)
    showInMainMenu: true,
    requiresPremium: true, // Backend can gate premium features
    badge: 'BETA',
  },
} as const;

// ========== FEATURE FLAGS ==========

export const FEATURE_FLAGS = {
  enableWebSearch: true,
  showInternetGlobe: true,
  showTrendingTopics: false, // A/B test this
  showExportFeatures: true,
  showCustomThemes: true,
  enablePrioritySupport: true,
  enableDeepSearchMode: true, // Can disable if quota issues
} as const;

// ========== QUOTA CONFIGURATION ==========

// Pricing/credits economics – adjust these to tune margins
const CREDIT_ECONOMY = {
  // Reference pack you sell: 500 credits for $5 gross
  packCredits: 500,
  packGrossPrice: 5, // USD
  // App Store fee rate (e.g., 0.30 = 30%)
  storeFeeRate: 0.30,
  // Target profit margin on base (provider) cost: 3x markup (200% markup)
  targetProfitMargin: 1.6, // 200% markup = 3x the provider cost
} as const;

// Derived unit economics
// Net revenue per credit after store fees
const NET_PER_CREDIT =
  (CREDIT_ECONOMY.packGrossPrice * (1 - CREDIT_ECONOMY.storeFeeRate)) /
  CREDIT_ECONOMY.packCredits; // e.g., 3.50 / 500 = $0.007

// Each request unit (credit) should cover provider base cost plus margin
// units = dollarCost / dollarsPerRequestUnit
// Set dollarsPerRequestUnit to the provider cost per unit that yields the desired margin
// With 200% markup (3x), this becomes: NET_PER_CREDIT / 3.0
const DOLLARS_PER_REQUEST_UNIT =
  NET_PER_CREDIT / (1 + CREDIT_ECONOMY.targetProfitMargin);

export const QUOTA_CONFIG = {
  // Request-based allocation
  initialRequestAllocation: 5,
  // Provider base-cost per unit (credit) so that selling price achieves target margin
  // Example with values above: 0.007 / 3.0 = $0.0023 per unit (3x markup)
  dollarsPerRequestUnit: Number(DOLLARS_PER_REQUEST_UNIT.toFixed(6)),
  // Allow fractional request units and define rounding behavior
  // Smallest debit step (e.g., 0.1 = one tenth of a unit)
  requestUnitStep: 0.1,
  // Enforce a minimum debit per request to avoid free calls
  minRequestUnits: 0.1,
  // Rate for models marked as "free" (0 input/output pricing) - still charge a small amount
  freeModelRate: 0.1,

  // Legacy token allocation (deprecated)
  initialTokenAllocation: 10,
  
  // CRITICAL SAFETY: Global maximum token limit (hard cap for all models)
  // This prevents runaway token generation that could cost thousands
  globalMaxTokens: 50000, // Absolute maximum ANY model can generate
} as const;

// ========== VERSION CONTROL ==========

export const VERSION_CONFIG = {
  minSupportedVersion: '1.0.0',
  latestVersion: '1.0.0',
  forceUpdateBelow: '0.9.0',
  recommendedVersion: '1.0.0',
} as const;

// ========== API TIMEOUTS ==========

export const TIMEOUT_CONFIG = {
  connectTimeout: 60000, // ms
  receiveTimeout: 120000, // ms
  sendTimeout: 120000, // ms
} as const;

// ========== CACHE CONFIGURATION ==========

export const CACHE_CONFIG = {
  // How long to cache config responses (in seconds)
  pricingCacheDuration: 3600, // 1 hour
  modelsCacheDuration: 3600, // 1 hour
  appConfigCacheDuration: 300, // 5 minutes
  modesCacheDuration: 3600, // 1 hour
} as const;

// ========== REVENUECAT PRODUCT → CREDIT MAPPING ==========

// Map store product identifiers (RevenueCat product_id / storeProduct.identifier)
// to the number of credits to grant on purchase/renewal.
// Keep this config in source control and update alongside RC dashboard changes.
export const RC_CREDIT_PRODUCTS: Record<string, number> = {
  // Example mappings – update to your actual product IDs
  'premium_monthly': 100, // 100 credits per monthly purchase
  'premium_annual': 1500, // 1500 credits per annual purchase
  // Add more SKUs as needed, e.g., one-off top-up packs
  'credits_100': 100,
  'credits_500': 500,
  'credits_1000': 1000,
  'credits_2000': 2000,
  'credits_5000': 5000,
  // Common iOS-style bundle identifiers (adjust to your actual App Store IDs)
  'com.cognify.credits.100': 100,
  'com.cognify.credits.500': 500,
  'com.cognify.credits.1000': 1000,
  'com.cognify.credits.2000': 2000,
  'com.cognify.credits.5000': 5000,
};

// Control which RC environments are accepted by the webhook handler
export const RC_WEBHOOK_CONFIG = {
  allowSandbox: true, // set to false in production if desired
} as const;
