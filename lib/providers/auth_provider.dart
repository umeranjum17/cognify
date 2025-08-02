import 'package:flutter/foundation.dart';
import '../services/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  bool _hasApiKey = false;
  bool _isLoading = true;
  Map<String, String?> _apiKeys = {};
  String? _primaryProvider;

  bool get hasApiKey => _hasApiKey;
  bool get isLoading => _isLoading;
  Map<String, String?> get apiKeys => _apiKeys;
  String? get primaryProvider => _primaryProvider;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Migrate legacy keys first
      await SecureStorage.migrateLegacyKey();
      
      // Load all API keys
      await _loadApiKeys();
    } catch (error) {
      print('Failed to initialize auth: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadApiKeys() async {
    try {
      _apiKeys = await SecureStorage.getAllApiKeys();
      _hasApiKey = await SecureStorage.hasAPIKeys();
      
      // Determine primary provider
      if (_apiKeys['openai'] != null) {
        _primaryProvider = 'openai';
      } else if (_apiKeys['anthropic'] != null) {
        _primaryProvider = 'anthropic';
      } else if (_apiKeys['google'] != null) {
        _primaryProvider = 'google';
      } else if (_apiKeys['groq'] != null) {
        _primaryProvider = 'groq';
      } else {
        _primaryProvider = null;
      }
    } catch (error) {
      print('Failed to load API keys: $error');
      _hasApiKey = false;
      _apiKeys = {};
      _primaryProvider = null;
    }
  }

  Future<void> storeApiKey(String provider, String apiKey) async {
    try {
      // Validate API key format
      if (!SecureStorage.isValidApiKeyFormat(apiKey, provider)) {
        throw Exception('Invalid API key format for $provider');
      }

      await SecureStorage.storeApiKeyForProvider(provider, apiKey);
      await _loadApiKeys();
      notifyListeners();
    } catch (error) {
      print('Failed to store API key: $error');
      rethrow;
    }
  }

  Future<void> removeApiKey(String provider) async {
    try {
      await SecureStorage.storeApiKeyForProvider(provider, '');
      await _loadApiKeys();
      notifyListeners();
    } catch (error) {
      print('Failed to remove API key: $error');
      rethrow;
    }
  }

  Future<void> clearAllApiKeys() async {
    try {
      await SecureStorage.clearAllApiKeys();
      await _loadApiKeys();
      notifyListeners();
    } catch (error) {
      print('Failed to clear API keys: $error');
      rethrow;
    }
  }

  Future<String?> getApiKey(String provider) async {
    return await SecureStorage.getApiKeyForProvider(provider);
  }

  Future<String?> getPrimaryApiKey() async {
    return await SecureStorage.getPrimaryApiKey();
  }

  bool hasApiKeyForProvider(String provider) {
    final key = _apiKeys[provider.toLowerCase()];
    return key != null && key.isNotEmpty;
  }

  List<String> getAvailableProviders() {
    return _apiKeys.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => entry.key)
        .toList();
  }

  String getProviderDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'OpenAI';
      case 'anthropic':
        return 'Anthropic';
      case 'google':
        return 'Google';
      case 'groq':
        return 'Groq';
      default:
        return provider.toUpperCase();
    }
  }

  String getProviderDescription(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'GPT-4, GPT-3.5, and other OpenAI models';
      case 'anthropic':
        return 'Claude 3 and other Anthropic models';
      case 'google':
        return 'Gemini and other Google AI models';
      case 'groq':
        return 'Fast inference for open-source models';
      default:
        return 'AI model provider';
    }
  }

  String getApiKeyPlaceholder(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'sk-...';
      case 'anthropic':
        return 'sk-ant-...';
      case 'google':
        return 'AIza...';
      case 'groq':
        return 'gsk_...';
      default:
        return 'Enter API key...';
    }
  }

  Future<void> refreshAuth() async {
    _isLoading = true;
    notifyListeners();
    
    await _loadApiKeys();
    
    _isLoading = false;
    notifyListeners();
  }

  // Validate if the current auth state is valid
  bool isAuthValid() {
    return _hasApiKey && !_isLoading;
  }

  // Get masked API key for display
  String getMaskedApiKey(String provider) {
    final key = _apiKeys[provider.toLowerCase()];
    if (key == null || key.isEmpty) return '';
    
    if (key.length <= 8) return key;
    
    final start = key.substring(0, 4);
    final end = key.substring(key.length - 4);
    return '$start....$end';
  }

  // Check if API key is properly configured for a provider
  bool isProviderConfigured(String provider) {
    final key = _apiKeys[provider.toLowerCase()];
    return key != null && 
           key.isNotEmpty && 
           SecureStorage.isValidApiKeyFormat(key, provider);
  }

  // Get configuration status for all providers
  Map<String, bool> getProviderConfigurationStatus() {
    return {
      'openai': isProviderConfigured('openai'),
      'anthropic': isProviderConfigured('anthropic'),
      'google': isProviderConfigured('google'),
      'groq': isProviderConfigured('groq'),
    };
  }

  // Set primary provider
  Future<void> setPrimaryProvider(String provider) async {
    if (isProviderConfigured(provider)) {
      _primaryProvider = provider;
      await SecureStorage.storeUserPreference('primary_provider', provider);
      notifyListeners();
    }
  }

  // Load primary provider preference
  Future<void> loadPrimaryProvider() async {
    final saved = await SecureStorage.getUserPreference('primary_provider');
    if (saved != null && isProviderConfigured(saved)) {
      _primaryProvider = saved;
      notifyListeners();
    }
  }
}
