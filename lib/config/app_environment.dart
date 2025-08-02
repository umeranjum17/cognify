/// App environment configuration for different builds
enum AppEnvironment {
  production, // Free version for app store
  dev,        // Development version with premium features
  umer        // Umer's personal version with premium features
}

/// Environment-based configuration management
class EnvironmentConfig {
  static const AppEnvironment current = AppEnvironment.production; // Change for builds

  // Environment checks
  static bool get isFreeVersion => current == AppEnvironment.production;
  static bool get isPaidVersion => current == AppEnvironment.dev || current == AppEnvironment.umer;
  static bool get isDevVersion => current == AppEnvironment.dev;
  static bool get isUmerVersion => current == AppEnvironment.umer;
  
  // Feature availability based on environment
  static bool get enableWebSearch => isPaidVersion;
  static bool get showInternetGlobe => isPaidVersion;
  static bool get showTrendingTopics => isPaidVersion;
  static bool get showExportFeatures => isPaidVersion;
  static bool get showCustomThemes => isPaidVersion;
  static bool get enablePrioritySupport => isPaidVersion;
  
  // Core features (always available)
  static bool get showBasicChat => true;
  static bool get showModelSelection => true;
  static bool get showModeSelection => true;
  static bool get showSourcesScreen => true;
  static bool get showSaveContent => true;
  static bool get showAllSettings => true;
  
  // App configuration based on environment
  static String get appName {
    switch (current) {
      case AppEnvironment.production:
        return 'Cognify';
      case AppEnvironment.dev:
        return 'Cognify Dev';
      case AppEnvironment.umer:
        return 'Cognify Umer';
    }
  }
  
  static String get appId {
    switch (current) {
      case AppEnvironment.production:
        return 'com.umerfarooq1995.cognify_flutter';
      case AppEnvironment.dev:
        return 'com.umerfarooq1995.cognify_flutter.dev';
      case AppEnvironment.umer:
        return 'com.umerfarooq1995.cognify_flutter.umer';
    }
  }
  
  static String get versionSuffix {
    switch (current) {
      case AppEnvironment.production:
        return '';
      case AppEnvironment.dev:
        return '-dev';
      case AppEnvironment.umer:
        return '-umer';
    }
  }
  
  // Feature descriptions for UI
  static String get featureDescription {
    if (isFreeVersion) {
      return '''
Free Version Features:
• Full AI chat with all OpenRouter models
• Mode selection and advanced chat options
• Sources screen and document management
• Save and bookmark conversations
• All app settings and configurations
• Offline AI functionality

Upgrade to unlock:
• Web search integration
• Real-time information access
• Trending topics
• Export features
• Custom themes
• Priority support
''';
    } else {
      return '''
Premium Features Unlocked:
• Full AI chat with all OpenRouter models
• Web search integration
• Real-time information access
• Trending topics and external content
• Export conversations to PDF/markdown
• Custom themes and UI customization
• Priority support
• All core features included
''';
    }
  }

  // Environment info for debugging
  static Map<String, dynamic> get environmentInfo {
    return {
      'environment': current.toString(),
      'isFreeVersion': isFreeVersion,
      'isPaidVersion': isPaidVersion,
      'appName': appName,
      'appId': appId,
      'versionSuffix': versionSuffix,
    };
  }
}
