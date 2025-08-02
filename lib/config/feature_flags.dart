import 'app_environment.dart';

/// Feature flags for controlling app functionality
/// Set based on build flavor and user's subscription status
class FeatureFlags {
  // Core features (always available - no brave_searchtool dependency)
  static const bool SHOW_BASIC_CHAT = true;

  static const bool SHOW_MODEL_SELECTION = true;
  static const bool SHOW_MODE_SELECTION = true; // Free feature
  static const bool SHOW_SOURCES_SCREEN = true; // Free feature
  static const bool SHOW_SAVE_CONTENT = true; // Free feature
  static const bool SHOW_ALL_SETTINGS = true; // Free feature
  static const bool REQUIRE_OPENROUTER_API_KEY = true; // All users need their own key

  // Onboarding behavior
  static const bool USE_STREAMLINED_ONBOARDING = true;
  // Pricing
  static const double MONTHLY_SUBSCRIPTION_PRICE = 7.99;
  static const String SUBSCRIPTION_BENEFITS = '''
• Web search integration (online AI responses)
• Internet globe toggle for real-time information
• Access to trending topics
• Export conversations to PDF/markdown
• Custom themes and UI customization
• Priority support
''';
  static const String FREE_FEATURES_DESCRIPTION = '''
• Full AI chat with all OpenRouter models
• Mode selection and advanced chat options
• Sources screen and document management
• Save and bookmark conversations
• All app settings and configurations
• Offline AI functionality
''';
  // Feature names for subscription checks
  static const String FEATURE_WEB_SEARCH = 'web_search_integration';
  static const String FEATURE_INTERNET_GLOBE = 'internet_globe_toggle';
  static const String FEATURE_TRENDING_TOPICS = 'trending_topics';

  static const String FEATURE_EXPORT = 'export_features';
  static const String FEATURE_CUSTOM_THEMES = 'custom_themes';

  static const String FEATURE_PRIORITY_SUPPORT = 'priority_support';
  // Free features list
  static const List<String> FREE_FEATURES = [
    'basic_chat',
    'model_selection',
    'mode_selection',
    'sources_screen',
    'save_content',
    'all_settings',
    'conversation_management',
    'offline_ai_chat'
  ];

  // Premium features list
  static const List<String> PREMIUM_FEATURES = [
    FEATURE_WEB_SEARCH,
    FEATURE_INTERNET_GLOBE,
    FEATURE_TRENDING_TOPICS,
    FEATURE_EXPORT,
    FEATURE_CUSTOM_THEMES,
    FEATURE_PRIORITY_SUPPORT,
  ];

  static bool get ENABLE_PRIORITY_SUPPORT => EnvironmentConfig.enablePrioritySupport;
  // Premium feature toggles (features that use brave_searchtool)
  static bool get ENABLE_WEB_SEARCH => EnvironmentConfig.enableWebSearch;
  // Build-time constants - set based on environment and user subscription
  static bool get IS_FREE_VERSION => EnvironmentConfig.isFreeVersion;
  static bool get SHOW_CUSTOM_THEMES => EnvironmentConfig.showCustomThemes;
  static bool get SHOW_EXPORT_FEATURES => EnvironmentConfig.showExportFeatures;
  static bool get SHOW_INTERNET_GLOBE => EnvironmentConfig.showInternetGlobe;

  static bool get SHOW_TRENDING_TOPICS => EnvironmentConfig.showTrendingTopics;

  static bool get SHOW_UPGRADE_PROMPTS => IS_FREE_VERSION;

  /// Get all available features for current version
  static List<String> getAvailableFeatures() {
    if (IS_FREE_VERSION) {
      return FREE_FEATURES;
    } else {
      return [...FREE_FEATURES, ...PREMIUM_FEATURES];
    }
  }

  /// Get premium features that are locked in free version
  static List<String> getLockedFeatures() {
    return IS_FREE_VERSION ? PREMIUM_FEATURES : [];
  }

  /// Check if a feature is available in the current version
  static bool isFeatureEnabled(String featureName) {
    if (FREE_FEATURES.contains(featureName)) {
      return true;
    }
    
    if (PREMIUM_FEATURES.contains(featureName)) {
      return !IS_FREE_VERSION;
    }
    
    return false;
  }
}
