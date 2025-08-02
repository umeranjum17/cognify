import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../database/database_service.dart';
import 'openai_client.dart';
import 'openrouter_client.dart';

/// Unified LLM service with automatic fallback and model selection
class LLMService {
  static final LLMService _instance = LLMService._internal();
  final OpenRouterClient _openRouterClient = OpenRouterClient();
  final OpenAIClient _openAIClient = OpenAIClient();

  final DatabaseService _db = DatabaseService();
  bool _initialized = false;
  String? _currentModel;
  
  String _preferredProvider = 'openrouter'; // 'openrouter' or 'openai'
  // Usage tracking
  int _totalTokensUsed = 0;
  double _totalCostIncurred = 0.0;

  Map<String, int> _modelUsageCount = {};
  factory LLMService() => _instance;
  LLMService._internal();

  /// Send a chat completion request with automatic fallback
  Future<Map<String, dynamic>> chatCompletion({
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    dynamic toolChoice,
    BuildContext? context,
  }) async {
    await _ensureInitialized();
    
    final selectedModel = model ?? _currentModel ?? AppConfig.defaultModel;
    
    try {
      // Try primary provider first
      if (_preferredProvider == 'openrouter') {
        return await _openRouterClient.chatCompletion(
          model: selectedModel,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          stream: stream,
          tools: tools != null ? {'tools': tools} : null,
          toolChoice: toolChoice?.toString(),
          context: context,
        );
      } else {
        return await _openAIClient.chatCompletion(
          model: selectedModel,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          stream: stream,
          tools: tools,
          toolChoice: toolChoice,
        );
      }
    } catch (e) {
      print('🧠 Primary provider failed, trying fallback: $e');

      // Try fallback provider
      try {
        if (_preferredProvider == 'openrouter') {
          final fallbackModel = _openAIClient.getBestModel(preferCheap: true);
          return await _openAIClient.chatCompletion(
            model: fallbackModel,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: stream,
            tools: tools,
            toolChoice: toolChoice,
          );
        } else {
          final fallbackModel = await _openRouterClient.getBestModel(preferFree: true);
          return await _openRouterClient.chatCompletion(
            model: fallbackModel,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: stream,
            tools: tools != null ? {'tools': tools} : null,
            toolChoice: toolChoice?.toString(),
            context: context,
          );
        }
      } catch (fallbackError) {
        print('🧠 Both providers failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Send a streaming chat completion request
  Stream<Map<String, dynamic>> chatCompletionStream({
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    dynamic toolChoice,
    BuildContext? context,
  }) async* {
    await _ensureInitialized();
    
    final selectedModel = model ?? _currentModel ?? AppConfig.defaultModel;
    
    try {
      // Try primary provider first
      if (_preferredProvider == 'openrouter') {
        yield* _openRouterClient.chatCompletionStream(
          model: selectedModel,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          tools: tools != null ? {'tools': tools} : null,
          toolChoice: toolChoice?.toString(),
          context: context,
        );
      } else {
        yield* _openAIClient.chatCompletionStream(
          model: selectedModel,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          tools: tools,
          toolChoice: toolChoice,
        );
      }
    } catch (e) {
      print('🧠 Primary provider streaming failed, trying fallback: $e');
      
      // Try fallback provider
      try {
        if (_preferredProvider == 'openrouter') {
          final fallbackModel = _openAIClient.getBestModel(preferCheap: true);
          yield* _openAIClient.chatCompletionStream(
            model: fallbackModel,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            tools: tools,
            toolChoice: toolChoice,
          );
        } else {
          final fallbackModel = await _openRouterClient.getBestModel(preferFree: true);
          yield* _openRouterClient.chatCompletionStream(
            model: fallbackModel,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            tools: tools != null ? {'tools': tools} : null,
            toolChoice: toolChoice?.toString(),
            context: context,
          );
        }
      } catch (fallbackError) {
        yield {
          'error': 'Both providers failed: $fallbackError',
          'streaming': true,
        };
      }
    }
  }

  /// Generate embeddings for text
  Future<List<double>> generateEmbeddings(String text) async {
    await _ensureInitialized();
    
    try {
      // Try OpenAI first for embeddings (they have better embedding models)
      return await _openAIClient.generateEmbeddings(text: text);
    } catch (e) {
      print('🧠 Embeddings generation failed: $e');
      
      // Return a placeholder embedding vector
      // In a real implementation, you might want to use a local embedding model
      return List.filled(1536, 0.0); // OpenAI embedding dimension
    }
  }

  /// Get available models from all providers
  Future<Map<String, dynamic>> getAvailableModels({BuildContext? context}) async {
    await _ensureInitialized();

    final openRouterModels = await _openRouterClient.getModels(context: context);
    final openAIModels = await _openAIClient.getModels();

    return {
      'openrouter': {
        'models': openRouterModels['models'],
        'pricing': openRouterModels['pricing'],
      },
      'openai': {
        'models': openAIModels,
        'pricing': OpenAIClient.modelPricing,
      },
    };
  }

  /// Get the best available model across all providers
  Future<String> getBestModel({bool preferFree = true, bool preferCheap = true}) async {
    await _ensureInitialized();
    
    try {
      // Try OpenRouter first for free models
      if (preferFree) {
        final bestOpenRouter = await _openRouterClient.getBestModel(preferFree: true);
        return bestOpenRouter;
      }
      
      // Compare pricing across providers
      final openRouterModel = await _openRouterClient.getBestModel(preferFree: false);

      // For simplicity, prefer OpenRouter for cost-effectiveness
      return openRouterModel;
      
    } catch (e) {
      print('🧠 Failed to get best model: $e');
      return AppConfig.defaultModel;
    }
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

  Future<void> initialize() async {
    if (_initialized) return;

    await _db.initialize();
    await _openRouterClient.initialize();
    await _openAIClient.initialize();

    // Load current model from config
    _currentModel = await AppConfig().currentModel;

    // Load usage statistics
    await _loadUsageStats();

    _initialized = true;
    print('🧠 LLMService initialized with model: $_currentModel');
  }

  /// Check if any LLM provider is configured
  Future<bool> isConfigured() async {
    final openRouterKey = await AppConfig().openRouterApiKey;
    final openAIKey = await AppConfig().openAiApiKey;
    
    return (openRouterKey != null && openRouterKey.isNotEmpty) ||
           (openAIKey != null && openAIKey.isNotEmpty);
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

  /// Set the current model
  Future<void> setCurrentModel(String model) async {
    await _ensureInitialized();
    
    _currentModel = model;
    await AppConfig().setCurrentModel(model);
    
    print('🧠 Current model set to: $model');
  }

  /// Set the preferred provider
  Future<void> setPreferredProvider(String provider) async {
    await _ensureInitialized();
    
    if (provider == 'openrouter' || provider == 'openai') {
      _preferredProvider = provider;
      await _db.saveSetting('preferred_llm_provider', provider);
      
      print('🧠 Preferred provider set to: $provider');
    } else {
      throw ArgumentError('Invalid provider: $provider. Must be "openrouter" or "openai"');
    }
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
    
    // Save to database
    await _saveUsageStats();
    
    // Usage tracked silently
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
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
      
    } catch (e) {
      print('🧠 Failed to load usage stats: $e');
    }
  }

  /// Save usage statistics to database
  Future<void> _saveUsageStats() async {
    try {
      await _db.saveSetting('total_tokens_used', _totalTokensUsed);
      await _db.saveSetting('total_cost_incurred', _totalCostIncurred);
      await _db.saveSetting('model_usage_count', jsonEncode(_modelUsageCount));
    } catch (e) {
      print('🧠 Failed to save usage stats: $e');
    }
  }
}
