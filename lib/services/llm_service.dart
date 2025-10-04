import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../database/database_service.dart';
import 'openrouter_client.dart';
import 'cost_service.dart';
import 'usage_quota_service.dart';
import 'access_service.dart';
import '../models/message.dart';
import '../models/mode_config.dart';
import 'request_usage_estimator.dart';
import 'tools.dart';

/// Unified LLM service with automatic fallback and model selection
class LLMService {
  static final LLMService _instance = LLMService._internal();
  final OpenRouterClient _openRouterClient = OpenRouterClient();

  final DatabaseService _db = DatabaseService();
  bool _initialized = false;
  String? _currentModel;

  String _preferredProvider = 'openrouter';
  // Usage tracking
  int _totalTokensUsed = 0;
  double _totalCostIncurred = 0.0;

  Map<String, int> _modelUsageCount = {};
  factory LLMService() => _instance;
  LLMService._internal();
  bool get isInitialized => _initialized;

  /// Send a chat completion request with automatic fallback
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

    // Inject Brave search context for supported modes before sending to provider
    final augmentedMessages = await _maybeInjectSearchContext(
      normalizedMessages,
      chatMode,
    );
    final quotaUsage = await _reserveQuota(
      model: selectedModel,
      mode: chatMode,
    );

    try {
      // Try primary provider first
      if (_preferredProvider == 'openrouter') {
        return await _openRouterClient.chatCompletion(
          model: selectedModel,
          messages: augmentedMessages,
          temperature: temperature,
          maxTokens: maxTokens,
          stream: stream,
          tools: _convertTools(tools),
          toolChoice: toolChoice?.toString(),
          context: context,
        );
      }
    } catch (e) {
      print('🧠 Primary provider failed, trying fallback: $e');

      // Try fallback provider
      try {
        final fallbackModel = await _openRouterClient.getBestModel(
          preferFree: true,
        );
        return await _openRouterClient.chatCompletion(
          model: fallbackModel,
          messages: augmentedMessages,
          temperature: temperature,
          maxTokens: maxTokens,
          stream: stream,
          tools: _convertTools(tools),
          toolChoice: toolChoice?.toString(),
          context: context,
        );
      } catch (fallbackError) {
        await _refundQuota(quotaUsage);
        print('🧠 Fallback provider failed: $fallbackError');
        rethrow;
      }
    }
    // If we reach here, no provider matched; throw to satisfy non-null contract
    throw Exception('No LLM provider available');
  }

  /// Send a streaming chat completion request
  Stream<Map<String, dynamic>> chatCompletionStream({
    required List<dynamic> messages,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
    dynamic tools,
    dynamic toolChoice,
    BuildContext? context,
    // Additional optional parameters accepted for compatibility; ignored here
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
    final augmentedMessages = await _maybeInjectSearchContext(
      normalizedMessages,
      resolvedMode,
    );
    final quotaUsage = await _reserveQuota(
      model: selectedModel,
      mode: resolvedMode,
    );

    try {
      // Try primary provider first
      if (_preferredProvider == 'openrouter') {
        yield* _attachQuotaRefund(
          _openRouterClient.chatCompletionStream(
            model: selectedModel,
            messages: augmentedMessages,
            temperature: temperature,
            maxTokens: maxTokens,
            tools: _convertTools(tools),
            toolChoice: toolChoice?.toString(),
            context: context,
          ),
          quotaUsage,
        );
      }
    } catch (e) {
      print('🧠 Primary provider streaming failed, trying fallback: $e');

      // Try fallback provider
      try {
        final fallbackModel = await _openRouterClient.getBestModel(
          preferFree: true,
        );
        yield* _attachQuotaRefund(
          _openRouterClient.chatCompletionStream(
            model: fallbackModel,
            messages: augmentedMessages,
            temperature: temperature,
            maxTokens: maxTokens,
            tools: _convertTools(tools),
            toolChoice: toolChoice?.toString(),
            context: context,
          ),
          quotaUsage,
        );
      } catch (fallbackError) {
        await _refundQuota(quotaUsage);
        yield {
          'error': 'Fallback provider failed: $fallbackError',
          'streaming': true,
        };
      }
    }
  }

  /// Generate embeddings for text
  Future<List<double>> generateEmbeddings(String text) async {
    await _ensureInitialized();

    try {
      return await _openRouterClient.generateEmbeddings(text: text);
    } catch (e) {
      print('🧠 Embeddings generation failed: $e');

      // Return a placeholder embedding vector
      // In a real implementation, you might want to use a local embedding model
      return List.filled(1536, 0.0); // OpenAI embedding dimension
    }
  }

  List<Map<String, dynamic>> _normalizeMessages(List<dynamic> messages) {
    if (messages.isEmpty) return const [];
    if (messages.first is Map<String, dynamic>) {
      return List<Map<String, dynamic>>.from(messages);
    }
    if (messages.first is Message) {
      return (messages as List<Message>).map((m) => m.toJson()).toList();
    }
    // Fallback empty
    return const [];
  }

  Future<List<Map<String, dynamic>>> _maybeInjectSearchContext(
    List<Map<String, dynamic>> messages,
    ChatMode? mode,
  ) async {
    if (mode == null) return messages;
    final isSearch = mode == ChatMode.search;
    final isAipedia = mode == ChatMode.aipedia;
    if (!isSearch && !isAipedia) return messages;

    // Derive the user query from the last user message
    final userMessage = messages.lastWhere(
      (m) => (m['role'] == 'user'),
      orElse: () => const {'content': ''},
    );
    final query = (userMessage['content'] ?? '').toString().trim();
    if (query.isEmpty) return messages;

    try {
      // Perform web search (and image search for AIpedia)
      final braveTool = BraveSearchTool();
      final imageTool = ImageSearchTool();

      final webResult = await braveTool.invoke({
        'query': query,
        'count': isAipedia ? 6 : 5,
      });

      Map<String, dynamic>? imageResult;
      if (isAipedia) {
        imageResult = await imageTool.invoke({
          'query': query,
          'count': 3,
        });
      }

      final contextPayload = <String, dynamic>{
        'search': webResult,
        if (imageResult != null) 'images': imageResult,
        'mode': mode.name,
        'note': 'These are pre-fetched Brave search results to ground the answer.',
      };

      final systemContextMessage = {
        'role': 'system',
        'content': 'Context:\n' + jsonEncode(contextPayload),
      };

      // Prepend the system context before the user message for maximal grounding
      final augmented = <Map<String, dynamic>>[];
      // Keep any existing system messages first
      for (final m in messages) {
        if (m['role'] == 'system') {
          augmented.add(m);
        }
      }
      augmented.add(systemContextMessage);
      // Add the rest (non-system) preserving order
      for (final m in messages) {
        if (m['role'] != 'system') {
          augmented.add(m);
        }
      }
      return augmented;
    } catch (e) {
      // If search fails, proceed without augmentation
      return messages;
    }
  }

  Map<String, dynamic>? _convertTools(dynamic tools) {
    // Accept a pre-built tools map or ignore for now.
    if (tools == null) return null;
    if (tools is Map<String, dynamic>) return tools;
    // ToolsConfig or others can be converted here if needed.
    return null;
  }

  /// Get available models from all providers
  Future<Map<String, dynamic>> getAvailableModels({
    BuildContext? context,
  }) async {
    await _ensureInitialized();

    final openRouterModels = await _openRouterClient.getModels(
      context: context,
    );

    return {
      'openrouter': {
        'models': openRouterModels['models'],
        'pricing': openRouterModels['pricing'],
      },
    };
  }

  /// Get the best available model across all providers
  Future<String> getBestModel({
    bool preferFree = true,
    bool preferCheap = true,
  }) async {
    await _ensureInitialized();

    try {
      // Try OpenRouter first for free models
      if (preferFree) {
        final bestOpenRouter = await _openRouterClient.getBestModel(
          preferFree: true,
        );
        return bestOpenRouter;
      }

      // Compare pricing across providers
      final openRouterModel = await _openRouterClient.getBestModel(
        preferFree: false,
      );

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

    return (openRouterKey != null && openRouterKey.isNotEmpty);
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

    if (provider == 'openrouter') {
      _preferredProvider = provider;
      await _db.saveSetting('preferred_llm_provider', provider);

      print('🧠 Preferred provider set to: $provider');
    } else {
      throw ArgumentError('Invalid provider: $provider. Must be "openrouter"');
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

  Future<_QuotaUsage?> _reserveQuota({
    required String model,
    ChatMode? mode,
  }) async {
    if (AccessService.instance.isTester) {
      return null;
    }

    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No signed-in user available for quota tracking.');
    }

    final estimate = await _estimateUsageForModel(model: model, mode: mode);

    if (estimate.requestUnits == 0) {
      return null;
    }

    print(
      '🔒 Reserving ${estimate.requestUnits} request unit(s) for model $model '
      '(≈\$${estimate.dollarCost.toStringAsFixed(4)})',
    );

    await UsageQuotaService.instance.consumeRequests(
      uid: user.uid,
      amount: estimate.requestUnits,
      modelId: model,
      dollarCost: estimate.dollarCost,
      inputTokens: estimate.inputTokens,
      outputTokens: estimate.outputTokens,
    );

    return _QuotaUsage(
      uid: user.uid,
      requestUnits: estimate.requestUnits,
      model: model,
      estimate: estimate,
    );
  }

  Future<RequestUsageEstimate> _estimateUsageForModel({
    required String model,
    ChatMode? mode,
  }) async {
    try {
      final pricing = await CostService.getModelPricingById(model);
      return RequestUsageEstimator.estimate(pricing: pricing, mode: mode);
    } catch (e) {
      print('⚠️ Failed to determine request usage for $model: $e');
      return const RequestUsageEstimate.free();
    }
  }

  Future<void> _refundQuota(_QuotaUsage? usage) async {
    if (usage == null) return;
    await UsageQuotaService.instance.refund(
      uid: usage.uid,
      amount: usage.requestUnits,
    );
  }

  Stream<Map<String, dynamic>> _attachQuotaRefund(
    Stream<Map<String, dynamic>> base,
    _QuotaUsage? usage,
  ) {
    if (usage == null) return base;
    var refunded = false;
    return base.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
        },
        handleError: (error, stackTrace, sink) {
          if (!refunded) {
            refunded = true;
            print(
              '↩️ Refunding ${usage.requestUnits} request unit(s) for model ${usage.model} '
              'due to stream error: $error',
            );
            UsageQuotaService.instance
                .refund(uid: usage.uid, amount: usage.requestUnits)
                .catchError((_) {});
          }
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  ChatMode? _resolveChatMode(dynamic mode) {
    if (mode == null) {
      return null;
    }
    if (mode is ChatMode) {
      return mode;
    }
    if (mode is String) {
      final normalized = mode.toLowerCase();
      for (final candidate in ChatMode.values) {
        final enumName = candidate.name.toLowerCase();
        final enumString = candidate.toString().split('.').last.toLowerCase();
        final displayName = ModeConfigManager.getModeDisplayName(
          candidate,
        ).toLowerCase();
        if (normalized == enumName ||
            normalized == enumString ||
            normalized == displayName) {
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

  /// Load usage statistics from database
  Future<void> _loadUsageStats() async {
    try {
      _totalTokensUsed =
          await _db.getSetting<int>('total_tokens_used', defaultValue: 0) ?? 0;
      _totalCostIncurred =
          await _db.getSetting<double>(
            'total_cost_incurred',
            defaultValue: 0.0,
          ) ??
          0.0;

      final usageCountJson = await _db.getSetting<String>('model_usage_count');
      if (usageCountJson != null) {
        final decoded = jsonDecode(usageCountJson) as Map<String, dynamic>;
        _modelUsageCount = decoded.map(
          (key, value) => MapEntry(key, value as int),
        );
      }

      _preferredProvider =
          await _db.getSetting<String>(
            'preferred_llm_provider',
            defaultValue: 'openrouter',
          ) ??
          'openrouter';
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

class _QuotaUsage {
  const _QuotaUsage({
    required this.uid,
    required this.requestUnits,
    required this.model,
    required this.estimate,
  });

  final String uid;
  final int requestUnits;
  final String model;
  final RequestUsageEstimate estimate;
}
