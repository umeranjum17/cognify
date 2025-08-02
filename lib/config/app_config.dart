import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../providers/oauth_auth_provider.dart';

/// Application configuration management
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  // Environment variables and settings
  static const String _openRouterApiKeyKey = 'openrouter_api_key';
  static const String _openAiApiKeyKey = 'openai_api_key';
  static const String _braveSearchApiKeyKey = 'brave_search_api_key';

  static const String _defaultModelKey = 'default_model';
  static const String _logLevelKey = 'log_level';
  static const String _autoExecuteAiToolsKey = 'auto_execute_ai_tools';
  // Default values
  static const String defaultModel = 'deepseek/deepseek-chat:free';
  static const String fallbackModel = 'mistralai/mistral-7b-instruct:free';

  static const String defaultLogLevel = 'info';
  static const bool defaultAutoExecuteAiTools = true;
  // API endpoints
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openAiBaseUrl = 'https://api.openai.ai/v1';

  // App information
  static const String appName = 'Cognify';
  static const String appVersion = '1.0.0';

  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 120);

  static const Duration sendTimeout = Duration(seconds: 120);
  // Local storage keys
  static const String userIdKey = 'user_id';
  static const String userPreferencesKey = 'user_preferences';

  static const String appSettingsKey = 'app_settings';
  // Backward compatibility getters - now return empty/null since app is standalone
  static String get apiBaseUrl => ''; // Server eliminated - app is standalone
  static String get apiUrl => '';

  static String get baseUrl => '';
  // Debug settings
  static bool get enableLogging => kDebugMode;

  static bool get isDevelopment => kDebugMode;

  static bool get isProduction => kReleaseMode;
  bool _initialized = false;
  final DatabaseService _db = DatabaseService();

  factory AppConfig() => _instance;
  AppConfig._internal();
  // AI Tools Configuration
  Future<bool> get autoExecuteAiTools async {
    await _ensureInitialized();
    return await _db.getSetting<bool>(_autoExecuteAiToolsKey, defaultValue: defaultAutoExecuteAiTools) ?? defaultAutoExecuteAiTools;
  }



  Future<String?> get braveSearchApiKey async {
    await _ensureInitialized();
    return await _db.getSetting<String>(_braveSearchApiKeyKey);
  }

  // Model Configuration
  Future<String> get currentModel async {
    await _ensureInitialized();
    return await _db.getSetting<String>(_defaultModelKey, defaultValue: defaultModel) ?? defaultModel;
  }

  // Logging Configuration
  Future<String> get logLevel async {
    await _ensureInitialized();
    return await _db.getSetting<String>(_logLevelKey, defaultValue: defaultLogLevel) ?? defaultLogLevel;
  }

  Future<String?> get openAiApiKey async {
    await _ensureInitialized();
    return await _db.getSetting<String>(_openAiApiKeyKey);
  }

  // API Keys
  Future<String?> get openRouterApiKey async {
    // First try to get from OAuth provider (user's own key)
    try {
      final oauthProvider = OAuthAuthProvider();
      await oauthProvider.initialize();
      final userApiKey = oauthProvider.apiKey;
      if (userApiKey != null && userApiKey.isNotEmpty) {
        return userApiKey;
      }
    } catch (e) {
      print('Error getting OAuth API key: $e');
    }

    // Fallback to database storage
    await _ensureInitialized();
    return await _db.getSetting<String>(_openRouterApiKeyKey);
  }

  Future<void> initialize() async {
    if (_initialized) return;

    await _db.initialize();
    _initialized = true;
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _ensureInitialized();
    await _db.clearCache();

    await setCurrentModel(defaultModel);
    await setLogLevel(defaultLogLevel);
    await setAutoExecuteAiTools(defaultAutoExecuteAiTools);

    // Clear API keys for security
    await setOpenRouterApiKey(null);
    await setOpenAiApiKey(null);
    await setBraveSearchApiKey(null);
  }

  Future<void> setAutoExecuteAiTools(bool enabled) async {
    await _ensureInitialized();
    await _db.saveSetting(_autoExecuteAiToolsKey, enabled);
  }



  Future<void> setBraveSearchApiKey(String? apiKey) async {
    await _ensureInitialized();
    await _db.saveSetting(_braveSearchApiKeyKey, apiKey);
  }

  Future<void> setCurrentModel(String model) async {
    await _ensureInitialized();
    await _db.saveSetting(_defaultModelKey, model);
  }

  Future<void> setLogLevel(String level) async {
    await _ensureInitialized();
    await _db.saveSetting(_logLevelKey, level);
  }

  Future<void> setOpenAiApiKey(String? apiKey) async {
    await _ensureInitialized();
    await _db.saveSetting(_openAiApiKeyKey, apiKey);
  }

  Future<void> setOpenRouterApiKey(String? apiKey) async {
    await _ensureInitialized();
    await _db.saveSetting(_openRouterApiKeyKey, apiKey);
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
