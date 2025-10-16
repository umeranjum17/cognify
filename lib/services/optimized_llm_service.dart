import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../database/optimized_database_service.dart';
import 'mode_api_service.dart';
import 'cost_service.dart';
import 'usage_quota_service.dart';
import 'access_service.dart';
import 'request_usage_estimator.dart';
import 'service_cache_manager.dart';
import '../models/message.dart';
import '../models/mode_config.dart';

/// Optimized LLM service with caching and faster initialization
class OptimizedLLMService {
  static final OptimizedLLMService _instance = OptimizedLLMService._internal();
  final ModeApiService _modeApi = ModeApiService.instance;
  final OptimizedDatabaseService _db = OptimizedDatabaseService();
  final ServiceCacheManager _cacheManager = ServiceCacheManager();

  bool _initialized = true; // ALWAYS READY - no initialization needed!
  bool _initializing = false;
  String? _currentModel;
  String _preferredProvider = 'openrouter';
  
  // Usage tracking
  int _totalTokensUsed = 0;
  double _totalCostIncurred = 0.0;
  Map<String, int> _modelUsageCount = {};

  factory OptimizedLLMService() => _instance;
  OptimizedLLMService._internal();
  
  bool get isInitialized => _initialized;

  /// Fast initialization using cached data - NOW INSTANT!
  Future<void> initialize() async {
    // Service is always ready - just load data in background
    if (_initialized) return;
    
    // Set default model immediately
    _currentModel = AppConfig.defaultModel;
    _initialized = true;
    
    // Load data in background without blocking
    _loadDataInBackground();
  }
  
  /// Load data in background without blocking UI
  void _loadDataInBackground() {
    Future.microtask(() async {
      try {
        // Initialize cache manager
        await _cacheManager.initialize();
        
        // Initialize only essential database boxes
        await _db.initializeEssential();

        // Load cached data if available
        await _loadCachedData();

        // Load current model from config (cached)
        final model = await AppConfig().currentModel;
        if (model != null) {
          _currentModel = model;
        }
        
        print('🧠 OptimizedLLMService background data loaded with model: $_currentModel');
      } catch (e) {
        print('⚠️ OptimizedLLMService background loading error: $e');
        // Continue with defaults - service still works
      }
    });
  }

  /// Load data from cache to avoid database queries
  Future<void> _loadCachedData() async {
    try {
      // Check if we have valid cached data
      if (_cacheManager.isServiceCacheValid('llm_service')) {
        _totalTokensUsed = _cacheManager.getCachedData<int>('llm_service', 'totalTokensUsed') ?? 0;
        _totalCostIncurred = _cacheManager.getCachedData<double>('llm_service', 'totalCostIncurred') ?? 0.0;
        _preferredProvider = _cacheManager.getCachedData<String>('llm_service', 'preferredProvider') ?? 'openrouter';
        
        final usageCountJson = _cacheManager.getCachedData<String>('llm_service', 'modelUsageCount');
        if (usageCountJson != null) {
          final decoded = jsonDecode(usageCountJson) as Map<String, dynamic>;
          _modelUsageCount = decoded.map((key, value) => MapEntry(key, value as int));
        }
        
        print('✅ Loaded LLM service data from cache');
        return;
      }

      // Load from database if cache is invalid
      await _loadUsageStats();
    } catch (e) {
      print('⚠️ Failed to load cached data, using defaults: $e');
    }
  }

  /// Load usage statistics from database
  Future<void> _loadUsageStats() async {
    try {
      _totalTokensUsed = await _db.getSetting<int>('total_tokens_used', defaultValue: 0) ?? 0;
      _totalCostIncurred = await _db.getSetting<double>('total_cost_incurred', defaultValue: 0.0) ?? 0.0;

      final usageCountJson = await _db.getSetting<String>('model_usage_count');
      if (usageCountJson != null) {
        final decoded = jsonDecode(usageCountJson) as Map<String, dynamic>;
        _modelUsageCount = decoded.map((key, value) => MapEntry(key, value as int));
      }

      _preferredProvider = await _db.getSetting<String>('preferred_llm_provider', defaultValue: 'openrouter') ?? 'openrouter';
      
      // Cache the loaded data
      await _cacheManager.setCachedData('llm_service', 'totalTokensUsed', _totalTokensUsed);
      await _cacheManager.setCachedData('llm_service', 'totalCostIncurred', _totalCostIncurred);
      await _cacheManager.setCachedData('llm_service', 'preferredProvider', _preferredProvider);
      await _cacheManager.setCachedData('llm_service', 'modelUsageCount', jsonEncode(_modelUsageCount));
      await _cacheManager.markServiceUpdated('llm_service');
    } catch (e) {
      print('🧠 Failed to load usage stats: $e');
    }
  }

  /// Save usage statistics to cache and database
  Future<void> _saveUsageStats() async {
    try {
      // Save to cache immediately
      await _cacheManager.setCachedData('llm_service', 'totalTokensUsed', _totalTokensUsed);
      await _cacheManager.setCachedData('llm_service', 'totalCostIncurred', _totalCostIncurred);
      await _cacheManager.setCachedData('llm_service', 'modelUsageCount', jsonEncode(_modelUsageCount));
      await _cacheManager.markServiceUpdated('llm_service');
      
      // Save to database asynchronously
      _saveToDatabaseAsync();
    } catch (e) {
      print('🧠 Failed to save usage stats: $e');
    }
  }

  /// Save to database asynchronously to avoid blocking
  void _saveToDatabaseAsync() {
    Future.microtask(() async {
      try {
        await _db.setSetting('total_tokens_used', _totalTokensUsed);
        await _db.setSetting('total_cost_incurred', _totalCostIncurred);
        await _db.setSetting('model_usage_count', jsonEncode(_modelUsageCount));
      } catch (e) {
        print('⚠️ Failed to save usage stats to database: $e');
      }
    });
  }

  /// Send a chat completion request via Mode API
  Future<Map<String, dynamic>> chatCompletion({
    required List<dynamic> messages,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
    bool stream = false,
    dynamic tools,
    dynamic toolChoice,
    BuildContext? context,
    ChatMode? chatMode,
  }) async {
    await _ensureInitialized();

    final selectedModel = model ?? _currentModel ?? AppConfig.defaultModel;
    final normalizedMessages = _normalizeMessages(messages);
    final mode = chatMode ?? ChatMode.chat;

    return await _modeApi.chat(
      mode: mode,
      messages: normalizedMessages,
      model: selectedModel,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: stream,
    );
  }

  /// Send a streaming chat completion request via Mode API
  Stream<Map<String, dynamic>> chatCompletionStream({
    required List<dynamic> messages,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
    dynamic tools,
    dynamic toolChoice,
    BuildContext? context,
    String? conversationId,
    bool? isDeepSearchMode,
    String? personality,
    String? language,
    dynamic mode,
    String? chatModel,
    String? deepsearchModel,
    bool? isEntitled,
    ChatMode? chatMode,
  }) async* {
    await _ensureInitialized();

    final selectedModel = model ?? _currentModel ?? AppConfig.defaultModel;
    final normalizedMessages = _normalizeMessages(messages);
    final resolvedMode = chatMode ?? _resolveChatMode(mode);

    yield* _modeApi.chatStream(
      mode: resolvedMode ?? ChatMode.chat,
      messages: normalizedMessages,
      model: selectedModel,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  List<Map<String, dynamic>> _normalizeMessages(List<dynamic> messages) {
    if (messages.isEmpty) return const [];
    if (messages.first is Map<String, dynamic>) {
      return List<Map<String, dynamic>>.from(messages);
    }
    if (messages.first is Message) {
      return (messages as List<Message>).map((m) => m.toJson()).toList();
    }
    return const [];
  }

  /// Get available models from backend config
  Future<Map<String, dynamic>> getAvailableModels({BuildContext? context}) async {
    await _ensureInitialized();
    return {
      'models': [],
      'pricing': {},
    };
  }

  /// Get the best available model
  Future<String> getBestModel({bool preferFree = true, bool preferCheap = true}) async {
    await _ensureInitialized();
    return AppConfig.defaultModel;
  }

  /// Get usage statistics
  Map<String, dynamic> getUsageStats() {
    return {
      'totalTokensUsed': _totalTokensUsed,
      'totalCostIncurred': _totalCostIncurred,
      'modelUsageCount': Map.from(_modelUsageCount),
      'currentModel': _currentModel,
      'preferredProvider': _preferredProvider,
    };
  }

  /// Set the current model
  Future<void> setCurrentModel(String model) async {
    await _ensureInitialized();
    _currentModel = model;
    await AppConfig().setCurrentModel(model);
    print('🧠 Current model set to: $model');
  }

  /// Track token usage and cost
  Future<void> trackUsage({
    required String model,
    required int inputTokens,
    required int outputTokens,
    required double cost,
  }) async {
    await _ensureInitialized();

    _totalTokensUsed += inputTokens + outputTokens;
    _totalCostIncurred += cost;
    _modelUsageCount[model] = (_modelUsageCount[model] ?? 0) + 1;

    // Save to cache immediately, database asynchronously
    await _saveUsageStats();
  }

  /// Reset usage statistics
  Future<void> resetUsageStats() async {
    await _ensureInitialized();

    _totalTokensUsed = 0;
    _totalCostIncurred = 0.0;
    _modelUsageCount.clear();

    await _saveUsageStats();
    print('🧠 Usage statistics reset');
  }

  /// Check if backend is configured
  Future<bool> isConfigured() async {
    return AppConfig.backendBaseUrl.isNotEmpty;
  }

  ChatMode? _resolveChatMode(dynamic mode) {
    if (mode == null) return null;
    if (mode is ChatMode) return mode;
    if (mode is String) {
      final normalized = mode.toLowerCase();
      for (final candidate in ChatMode.values) {
        final enumName = candidate.name.toLowerCase();
        final enumString = candidate.toString().split('.').last.toLowerCase();
        final displayName = ModeConfigManager.getModeDisplayName(candidate).toLowerCase();
        if (normalized == enumName || normalized == enumString || normalized == displayName) {
          return candidate;
        }
      }
    }
    return null;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
