import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // API Key storage keys
  static const String _openrouterApiKeyKey = 'openrouter_api_key';
  static const String _anthropicApiKeyKey = 'anthropic_api_key';
  static const String _googleApiKeyKey = 'google_api_key';
  static const String _groqApiKeyKey = 'groq_api_key';
  static const String _legacyApiKeyKey = 'api_key'; // For migration

  // Clear all API keys
  static Future<void> clearAllApiKeys() async {
    await _storage.delete(key: _openrouterApiKeyKey);
    await _storage.delete(key: _anthropicApiKeyKey);
    await _storage.delete(key: _googleApiKeyKey);
    await _storage.delete(key: _groqApiKeyKey);
    await _storage.delete(key: _legacyApiKeyKey);
  }

  // Clear all preferences
  static Future<void> clearAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Clear specific preference
  static Future<void> clearPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // Get all stored API keys
  static Future<Map<String, String?>> getAllApiKeys() async {
    return {
      'openrouter': await getOpenRouterApiKey(),
      'anthropic': await getAnthropicApiKey(),
      'google': await getGoogleApiKey(),
      'groq': await getGroqApiKey(),
    };
  }

  // Get all preference keys
  static Future<Set<String>> getAllPreferenceKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys();
  }

  // Get Anthropic API key
  static Future<String?> getAnthropicApiKey() async {
    return await _storage.read(key: _anthropicApiKeyKey);
  }

  // Get API key for specific provider
  static Future<String?> getApiKeyForProvider(String provider) async {
    switch (provider.toLowerCase()) {
      case 'openrouter':
      case 'openai':
        return await getOpenRouterApiKey();
      case 'anthropic':
        return await getAnthropicApiKey();
      case 'google':
        return await getGoogleApiKey();
      case 'groq':
        return await getGroqApiKey();
      default:
        return null;
    }
  }

  // Get boolean preference
  static Future<bool> getBoolPreference(String key, {bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  // Get double preference
  static Future<double> getDoublePreference(String key, {double defaultValue = 0.0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key) ?? defaultValue;
  }

  // Get Google API key
  static Future<String?> getGoogleApiKey() async {
    return await _storage.read(key: _googleApiKeyKey);
  }

  // Get Groq API key
  static Future<String?> getGroqApiKey() async {
    return await _storage.read(key: _groqApiKeyKey);
  }

  // Get integer preference
  static Future<int> getIntPreference(String key, {int defaultValue = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? defaultValue;
  }

  // Get OpenRouter API key
  static Future<String?> getOpenRouterApiKey() async {
    return await _storage.read(key: _openrouterApiKeyKey);
  }

  // Get primary API key (first available)
  static Future<String?> getPrimaryApiKey() async {
    final keys = await getAllApiKeys();
    
    // Priority order: OpenRouter, Anthropic, Google, Groq
    if (keys['openrouter'] != null) return keys['openrouter'];
    if (keys['anthropic'] != null) return keys['anthropic'];
    if (keys['google'] != null) return keys['google'];
    if (keys['groq'] != null) return keys['groq'];
    
    return null;
  }

  // Get list of strings preference
  static Future<List<String>> getStringListPreference(String key, {List<String>? defaultValue}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? defaultValue ?? [];
  }

  // Get user preference
  static Future<String?> getUserPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  // Check if any API keys are stored
  static Future<bool> hasAPIKeys() async {
    final openrouter = await getOpenRouterApiKey();
    final anthropic = await getAnthropicApiKey();
    final google = await getGoogleApiKey();
    final groq = await getGroqApiKey();
    
    return openrouter != null || anthropic != null || google != null || groq != null;
  }

  // Check if preference exists
  static Future<bool> hasPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  // Validate API key format
  static bool isValidApiKeyFormat(String apiKey, String provider) {
    switch (provider.toLowerCase()) {
      case 'openrouter':
        return apiKey.startsWith('sk-or-') && apiKey.length > 20;
      case 'openai':
        return apiKey.startsWith('sk-') && apiKey.length > 20;
      case 'anthropic':
        return apiKey.startsWith('sk-ant-') && apiKey.length > 20;
      case 'google':
        return apiKey.startsWith('AIza') && apiKey.length > 20;
      case 'groq':
        return apiKey.startsWith('gsk_') && apiKey.length > 20;
      default:
        return apiKey.isNotEmpty && apiKey.length > 10;
    }
  }

  // Migrate legacy API key from SharedPreferences to secure storage
  static Future<void> migrateLegacyKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyKey = prefs.getString('api_key');
      
      if (legacyKey != null && legacyKey.isNotEmpty) {
        // Check if it's already migrated
        final existingKey = await _storage.read(key: _legacyApiKeyKey);
        if (existingKey == null) {
          // Store in secure storage
          await _storage.write(key: _legacyApiKeyKey, value: legacyKey);
          
          // Determine which provider based on key format and store appropriately
          if (legacyKey.startsWith('sk-or-')) {
            await storeOpenRouterApiKey(legacyKey);
          } else if (legacyKey.startsWith('sk-ant-')) {
            await storeAnthropicApiKey(legacyKey);
          } else if (legacyKey.startsWith('AIza')) {
            await storeGoogleApiKey(legacyKey);
          } else {
            // Default to OpenRouter for unknown format
            await storeOpenRouterApiKey(legacyKey);
          }
          
          // Remove from SharedPreferences
          await prefs.remove('api_key');
        }
      }
    } catch (error) {
      print('Failed to migrate legacy API key: $error');
    }
  }

  // Store Anthropic API key
  static Future<void> storeAnthropicApiKey(String apiKey) async {
    await _storage.write(key: _anthropicApiKeyKey, value: apiKey);
  }

  // Store API key for specific provider
  static Future<void> storeApiKeyForProvider(String provider, String apiKey) async {
    switch (provider.toLowerCase()) {
      case 'openrouter':
      case 'openai':
        await storeOpenRouterApiKey(apiKey);
        break;
      case 'anthropic':
        await storeAnthropicApiKey(apiKey);
        break;
      case 'google':
        await storeGoogleApiKey(apiKey);
        break;
      case 'groq':
        await storeGroqApiKey(apiKey);
        break;
    }
  }

  // Store boolean preference
  static Future<void> storeBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Store double preference
  static Future<void> storeDoublePreference(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  // Store Google API key
  static Future<void> storeGoogleApiKey(String apiKey) async {
    await _storage.write(key: _googleApiKeyKey, value: apiKey);
  }

  // Store Groq API key
  static Future<void> storeGroqApiKey(String apiKey) async {
    await _storage.write(key: _groqApiKeyKey, value: apiKey);
  }

  // Store integer preference
  static Future<void> storeIntPreference(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  // Store OpenRouter API key
  static Future<void> storeOpenRouterApiKey(String apiKey) async {
    await _storage.write(key: _openrouterApiKeyKey, value: apiKey);
  }

  // Store list of strings preference
  static Future<void> storeStringListPreference(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  // Store user preferences (non-sensitive data)
  static Future<void> storeUserPreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
