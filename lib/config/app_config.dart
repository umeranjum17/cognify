import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/secure_storage.dart';

import '../database/database_service.dart';
import '../utils/logger.dart';

// ========== ENVIRONMENT ==========

enum AppEnvironment {
  production, // Free version for app store
  dev,        // Development version with premium features
  umer        // Umer's personal version with premium features
}

class EnvironmentConfig {
  static const AppEnvironment current = AppEnvironment.production;

  static bool get isFreeVersion => current == AppEnvironment.production;
  static bool get isPaidVersion => current == AppEnvironment.dev || current == AppEnvironment.umer;
  static bool get isDevVersion => current == AppEnvironment.dev;
  static bool get isUmerVersion => current == AppEnvironment.umer;

  static bool get enableWebSearch => isPaidVersion;
  static bool get showInternetGlobe => isPaidVersion;
  static bool get showTrendingTopics => isPaidVersion;
  static bool get showExportFeatures => isPaidVersion;
  static bool get showCustomThemes => isPaidVersion;
  static bool get enablePrioritySupport => isPaidVersion;

  static String get appName {
    switch (current) {
      case AppEnvironment.production: return 'Cognify';
      case AppEnvironment.dev: return 'Cognify Dev';
      case AppEnvironment.umer: return 'Cognify Umer';
    }
  }

  static String get appId {
    switch (current) {
      case AppEnvironment.production: return 'com.umerfarooq1995.cognify-flutter';
      case AppEnvironment.dev: return 'com.umerfarooq1995.cognify-flutter.dev';
      case AppEnvironment.umer: return 'com.umerfarooq1995.cognify-flutter.umer';
    }
  }
}

// ========== DEMO MODE ==========

class DemoModeConfig {
  // Enable demo mode for unauthenticated users (Apple Guideline 5.1.1)
  static const bool enabled = true;
  
  // Sample conversations to display in demo mode
  static const List<Map<String, String>> sampleConversations = [
    {
      'role': 'user',
      'content': 'What is artificial intelligence?',
    },
    {
      'role': 'assistant',
      'content': 'Artificial intelligence (AI) is the simulation of human intelligence processes by machines, especially computer systems. These processes include learning (acquiring information and rules for using it), reasoning (using rules to reach approximate or definite conclusions), and self-correction.\n\nModern AI systems can perform tasks like:\n• Understanding natural language\n• Recognizing patterns in images and data\n• Making decisions based on complex information\n• Learning from experience to improve over time\n\nAI powers many everyday technologies, from voice assistants and recommendation systems to autonomous vehicles and medical diagnostics.',
    },
    {
      'role': 'user',
      'content': 'Can you help me write a professional email?',
    },
    {
      'role': 'assistant',
      'content': 'Of course! I\'d be happy to help you draft a professional email. To get started, I\'ll need a few details:\n\n1. **Purpose**: What is the email about? (e.g., job application, meeting request, follow-up, etc.)\n2. **Recipient**: Who are you writing to? (e.g., colleague, manager, client, potential employer)\n3. **Key Points**: What are the main points you want to convey?\n4. **Tone**: Should it be formal, semi-formal, or friendly-professional?\n\nOnce you provide these details, I can help you create a well-structured, professional email!',
    },
    {
      'role': 'user',
      'content': 'How can AI help with creative writing?',
    },
    {
      'role': 'assistant',
      'content': 'AI can be a powerful tool for creative writing in several ways:\n\n**Brainstorming & Ideation**\n• Generate story ideas, plot twists, and character concepts\n• Explore different narrative directions\n• Overcome writer\'s block with creative prompts\n\n**Writing Assistance**\n• Help with dialogue and descriptive passages\n• Suggest alternative phrasings and word choices\n• Maintain consistency in tone and style\n\n**Editing & Refinement**\n• Catch grammar and spelling errors\n• Improve sentence structure and flow\n• Enhance clarity and readability\n\n**Research & World-Building**\n• Provide background information for settings\n• Help develop realistic technical details\n• Suggest historical or cultural context\n\nThe key is using AI as a collaborative tool that enhances your creativity rather than replacing it. Your unique voice, vision, and judgment remain essential to creating authentic, meaningful work.',
    },
  ];
}

// ========== SECRETS ==========

class AppSecrets {
  const AppSecrets._();

  static const String openRouterApiKey = 'sk-openrouter-hardcoded-placeholder';

  static const String braveSearchApiKey = String.fromEnvironment(
    'BRAVE_SEARCH_API_KEY',
    defaultValue: '',
  );

  // Note: Credits and pricing come from backend config; no frontend defaults
}

// ========== APP CONFIG ==========

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  // Storage keys
  static const String _openAiApiKeyKey = 'openai_api_key';
  static const String _braveSearchApiKeyKey = 'brave_search_api_key';
  static const String _defaultModelKey = 'default_model';
  static const String _logLevelKey = 'log_level';
  static const String _autoExecuteAiToolsKey = 'auto_execute_ai_tools';
  static const String _verboseLoggingKey = 'verbose_logging';

  // Default values
  static const String defaultModel = 'google/gemini-2.5-flash-lite';
  static const String fallbackModel = 'mistralai/mistral-7b-instruct:free';
  static const String defaultLogLevel = 'info';
  static const bool defaultAutoExecuteAiTools = true;
  static const bool defaultVerboseLogging = false;

  // API endpoints
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openAiBaseUrl = 'https://api.openai.ai/v1';

  // Remote-configurable overrides
  static String? _overrideBackendBaseUrl;

  static String get backendBaseUrl {
    // 0) Prefer remote-config override when set and valid
    final override = _overrideBackendBaseUrl;
    if (override != null && override.isNotEmpty) {
      final uri = Uri.tryParse(override);
      if (uri != null && uri.hasScheme) return override;
    }
    // 1) Allow runtime override via dart-define (support both names)
    const overridden = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
    if (overridden.isNotEmpty) return overridden;
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;

    // 2) Default to sensible local dev hosts by platform
    //    - Android Emulator: 10.0.2.2
    //    - iOS Simulator/Web/macOS: localhost
    //    - Others: localhost
    if (kIsWeb) return 'http://localhost:3000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'http://localhost:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  /// Apply a Remote Config-provided backend base URL at runtime.
  static void setRemoteBackendBaseUrl(String? url) {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      _overrideBackendBaseUrl = url;
    }
  }

  // App information
  static String get appName => EnvironmentConfig.appName;
  static const String appVersion = '1.0.0';

  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 120);
  static const Duration sendTimeout = Duration(seconds: 120);

  // Backward compatibility getters
  static String get apiBaseUrl => '';
  static String get apiUrl => '';
  static String get baseUrl => '';

  // Debug settings
  static bool get enableLogging => kDebugMode;
  static bool get isDevelopment => kDebugMode;
  static bool get isProduction => kReleaseMode;

  // ===== Remote Config defaults (when RC unavailable) =====
  static const String defaultSoftMinVersion = '';
  static const String defaultMinSupportedVersion = '';
  static const String defaultUpdateUrlAndroid = '';
  static const String defaultUpdateUrlIOS = '';
  static const String defaultUpdateUrlWeb = '';
  static const int defaultRcFetchMinIntervalSec = 0; // 0 in dev; tune in prod

  bool _initialized = false;
  final DatabaseService _db = DatabaseService();

  Future<void> initialize() async {
    if (_initialized) return;
    await _db.initialize();
    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  // API Keys
  Future<String?> get openRouterApiKey async {
    // Prefer secure storage if the user has configured a key
    final storedKey = await SecureStorage.getOpenRouterApiKey();
    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }
    // Fallback to bundled secret for dev/demo builds
    if (AppSecrets.openRouterApiKey.isNotEmpty) {
      return AppSecrets.openRouterApiKey;
    }
    Logger.warn(
      '🔑 AppConfig: OPENROUTER_API_KEY not provided. Requests that depend on it will fail.',
      tag: 'AppConfig',
    );
    return null;
  }

  Future<String?> get openAiApiKey async {
    await _ensureInitialized();
    return await _db.getSetting<String>(_openAiApiKeyKey);
  }

  Future<void> setOpenAiApiKey(String? apiKey) async {
    await _ensureInitialized();
    await _db.saveSetting(_openAiApiKeyKey, apiKey);
  }

  Future<String?> get braveSearchApiKey async {
    if (AppSecrets.braveSearchApiKey.isNotEmpty) {
      return AppSecrets.braveSearchApiKey;
    }
    await _ensureInitialized();
    return await _db.getSetting<String>(_braveSearchApiKeyKey);
  }

  Future<void> setBraveSearchApiKey(String? apiKey) async {
    await _ensureInitialized();
    await _db.saveSetting(_braveSearchApiKeyKey, apiKey);
  }

  // Model Configuration
  Future<String> get currentModel async {
    await _ensureInitialized();
    return await _db.getSetting<String>(_defaultModelKey, defaultValue: defaultModel) ?? defaultModel;
  }

  Future<void> setCurrentModel(String model) async {
    await _ensureInitialized();
    await _db.saveSetting(_defaultModelKey, model);
  }

  // Logging Configuration
  Future<String> get logLevel async {
    await _ensureInitialized();
    return await _db.getSetting<String>(_logLevelKey, defaultValue: defaultLogLevel) ?? defaultLogLevel;
  }

  Future<void> setLogLevel(String level) async {
    await _ensureInitialized();
    await _db.saveSetting(_logLevelKey, level);
  }

  Future<bool> get verboseLogging async {
    await _ensureInitialized();
    return await _db.getSetting<bool>(_verboseLoggingKey, defaultValue: defaultVerboseLogging) ?? defaultVerboseLogging;
  }

  // AI Tools Configuration
  Future<bool> get autoExecuteAiTools async {
    await _ensureInitialized();
    return await _db.getSetting<bool>(_autoExecuteAiToolsKey, defaultValue: defaultAutoExecuteAiTools) ?? defaultAutoExecuteAiTools;
  }

  Future<void> setAutoExecuteAiTools(bool enabled) async {
    await _ensureInitialized();
    await _db.saveSetting(_autoExecuteAiToolsKey, enabled);
  }

  // Reset all settings
  Future<void> resetToDefaults() async {
    await _ensureInitialized();
    await _db.clearCache();
    await setCurrentModel(defaultModel);
    await setLogLevel(defaultLogLevel);
    await setAutoExecuteAiTools(defaultAutoExecuteAiTools);
    await setOpenAiApiKey(null);
    await setBraveSearchApiKey(null);
  }
}
