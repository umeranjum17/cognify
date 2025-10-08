import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../database/database_service.dart';
import 'mode_api_service.dart';
import 'cost_service.dart';
import 'usage_quota_service.dart';
import 'access_service.dart';
import 'request_usage_estimator.dart';
import '../models/message.dart';
import '../models/mode_config.dart';

/// Unified LLM service that calls backend Mode APIs
class LLMService {
  static final LLMService _instance = LLMService._internal();
  final ModeApiService _modeApi = ModeApiService.instance;

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

    // Call backend Mode API - server enforces credits and refunds on failure
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

    // Call backend Mode API - server enforces credits and handles refunds
    yield* _modeApi.chatStream(
      mode: resolvedMode ?? ChatMode.chat,
      messages: normalizedMessages,
      model: selectedModel,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Generate embeddings for text (placeholder - implement backend endpoint if needed)
  Future<List<double>> generateEmbeddings(String text) async {
    await _ensureInitialized();

    // TODO: Create backend endpoint for embeddings if needed
    print('⚠️ Embeddings not yet implemented in backend');
    return List.filled(1536, 0.0); // Placeholder
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

  /// Get available models from backend config
  Future<Map<String, dynamic>> getAvailableModels({
    BuildContext? context,
  }) async {
    await _ensureInitialized();

    // TODO: Fetch models from /api/config/models endpoint
    return {
      'models': [],
      'pricing': {},
    };
  }

  /// Get the best available model (from config or default)
  Future<String> getBestModel({
    bool preferFree = true,
    bool preferCheap = true,
  }) async {
    await _ensureInitialized();

    // Backend handles model selection, just return the default
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

  Future<void> initialize() async {
    if (_initialized) return;

    await _db.initialize();

    // Load current model from config
    _currentModel = await AppConfig().currentModel;

    // Load usage statistics
    await _loadUsageStats();

    _initialized = true;
    print('🧠 LLMService initialized with model: $_currentModel');
  }

  /// Check if backend is configured (always true for mode APIs)
  Future<bool> isConfigured() async {
    return AppConfig.backendBaseUrl.isNotEmpty;
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
    );
  }

  // Estimation now uses backend API
  Future<RequestUsageEstimate> _estimateUsageForModel({
    required String model,
    ChatMode? mode,
  }) async {
    try {
      // Use backend API for estimation (no local pricing needed)
      return await RequestUsageEstimator.estimate(
        modelId: model,
        mode: mode,
      );
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
  });

  final String uid;
  final int requestUnits;
  final String model;
}
