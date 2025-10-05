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
    availableModels: [
      'google/gemini-2.5-flash-lite',
      'google/gemini-flash-1.5',
      'mistralai/mistral-7b-instruct:free',
    ],
    capabilities: ['text'],
    temperature: 0.7,
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
    capabilities: ['text', 'web-search'],
    temperature: 0.7,
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
      'google/gemini-2.5-flash-lite',
      'google/gemini-flash-1.5',
    ],
    capabilities: ['text', 'web-search', 'image-search'],
    temperature: 0.5,
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

export const QUOTA_CONFIG = {
  // Request-based allocation
  initialRequestAllocation: 1000,
  dollarsPerRequestUnit: 0.01,

  // Legacy token allocation (deprecated)
  initialTokenAllocation: 10,
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
