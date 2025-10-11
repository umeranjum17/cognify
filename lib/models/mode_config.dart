import 'dart:convert';

import 'package:flutter/material.dart';
// Frontend no longer owns mode configuration; it is fetched from backend.
// Keep only types and lightweight helpers. All dynamic data comes via ModeApiService.

import '../services/mode_api_service.dart';
import '../config/model_registry.dart';

enum ChatMode {
  chat,
  search,
  aipedia,
  deepsearch,
}

class ModeConfig {
  final ChatMode mode;
  final String model;
  final String displayName;
  final String description;
  final String defaultModel;

  const ModeConfig({
    required this.mode,
    required this.model,
    required this.displayName,
    required this.description,
    required this.defaultModel,
  });

  factory ModeConfig.fromJson(Map<String, dynamic> json) {
    return ModeConfig(
      mode: ChatMode.values.firstWhere(
        (e) => e.toString() == json['mode'],
        orElse: () => ChatMode.chat,
      ),
      model: json['model'] ?? '',
      displayName: json['displayName'] ?? '',
      description: json['description'] ?? '',
      defaultModel: json['defaultModel'] ?? '',
    );
  }

  ModeConfig copyWith({
    ChatMode? mode,
    String? model,
    String? displayName,
    String? description,
    String? defaultModel,
  }) {
    return ModeConfig(
      mode: mode ?? this.mode,
      model: model ?? this.model,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      defaultModel: defaultModel ?? this.defaultModel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.toString(),
      'model': model,
      'displayName': displayName,
      'description': description,
      'defaultModel': defaultModel,
    };
  }
}

class ModeConfigManager {
  static const String _storageKey = 'mode_configs';

  // MINIMAL emergency fallback only - Backend (/api/config/modes) is the source of truth
  static final Map<ChatMode, ModeConfig> _defaultConfigs = {
    ChatMode.chat: const ModeConfig(
      mode: ChatMode.chat,
      model: 'mistralai/mistral-7b-instruct:free',
      displayName: 'Chat',
      description: 'Emergency fallback - backend unavailable',
      defaultModel: 'mistralai/mistral-7b-instruct:free',
    ),
    ChatMode.search: const ModeConfig(
      mode: ChatMode.search,
      model: 'mistralai/mistral-7b-instruct:free',
      displayName: 'Search',
      description: 'Emergency fallback - backend unavailable',
      defaultModel: 'mistralai/mistral-7b-instruct:free',
    ),
    ChatMode.aipedia: const ModeConfig(
      mode: ChatMode.aipedia,
      model: 'mistralai/mistral-7b-instruct:free',
      displayName: 'AIpedia',
      description: 'Emergency fallback - backend unavailable',
      defaultModel: 'mistralai/mistral-7b-instruct:free',
    ),
    ChatMode.deepsearch: const ModeConfig(
      mode: ChatMode.deepsearch,
      model: 'mistralai/mistral-7b-instruct:free',
      displayName: 'DeepSearch',
      description: 'Emergency fallback - backend unavailable',
      defaultModel: 'mistralai/mistral-7b-instruct:free',
    ),
  };

  // Models and mode details are now fetched from backend via ModeApiService

  static String formatModelName(String model) {
    // Extract the model name from the full path
    final parts = model.split('/');
    if (parts.length >= 2) {
      return parts[1].replaceAll(':free', '');
    }
    return model;
  }

  static Future<List<String>> getAvailableModelsForMode(ChatMode mode) async {
    try {
      final models = await ModeApiService.instance.getAvailableModelsForMode(mode);
      if (models.isNotEmpty) return models;
    } catch (e) {
      print('Error fetching models for mode from backend: $e');
    }
    // Fallback to minimal defaults
    switch (mode) {
      case ChatMode.chat:
        return [ModelRegistry.defaults['CHAT_MODE']!];
      case ChatMode.search:
        return [ModelRegistry.defaults['CHAT_MODE']!];
      case ChatMode.aipedia:
        return [ModelRegistry.defaults['CHAT_MODE']!];
      case ChatMode.deepsearch:
        return [ModelRegistry.defaults['DEEPSEARCH_MODE']!];
    }
  }

  static Future<ModeConfig> getConfigForMode(ChatMode mode) async {
    try {
      final cfg = await ModeApiService.instance.getModeConfig(mode);
      if (cfg != null) {
        return ModeConfig(
          mode: mode,
          model: (cfg['model'] as String?) ?? (cfg['defaultModel'] as String?) ?? _defaultConfigs[mode]!.model,
          displayName: (cfg['displayName'] as String?) ?? mode.toString(),
          description: (cfg['description'] as String?) ?? '',
          defaultModel: (cfg['defaultModel'] as String?) ?? _defaultConfigs[mode]!.defaultModel,
        );
      }
    } catch (e) {
      print('Error fetching mode config from backend: $e');
    }
    return _defaultConfigs[mode]!;
  }

  static ModeConfig getDefaultConfigForMode(ChatMode mode) {
    return _defaultConfigs[mode]!;
  }

  static String getModeDescription(ChatMode mode) {
    // Synchronous helper for quick labels; backend-aware UIs should fetch via ModeApiService
    return _defaultConfigs[mode]?.description ?? '';
  }

  static String getModeDisplayName(ChatMode mode) {
    // Synchronous helper for quick labels; backend-aware UIs should fetch via ModeApiService
    return _defaultConfigs[mode]?.displayName ?? mode.toString();
  }

  // Helper method to get the appropriate model based on mode and user input
  static Future<String> getModelForRequest({
    required String userInput,
    ChatMode? explicitMode,
  }) async {
    ChatMode mode = explicitMode ?? ChatMode.chat;
    
    // Auto-detect mode from user input if not explicitly set
    if (explicitMode == null) {
      final input = userInput.toLowerCase();
      if (input.contains('search') || input.contains('research') || input.contains('find')) {
        // Route generic search intents to the lightweight Search mode
        mode = ChatMode.search;
      }
    }
    
    final config = await getConfigForMode(mode);
    return config.model;
  }

  static String getModelProvider(String model) {
    final parts = model.split('/');
    if (parts.isNotEmpty) {
      return parts[0];
    }
    return 'unknown';
  }

  static Future<Map<String, dynamic>> getModeStats(ChatMode mode) async {
    final config = _defaultConfigs[mode]!;
    try {
      final availableModels = await getAvailableModelsForMode(mode);
      final freeModels = availableModels.where((m) => isFreeModel(m)).length;
      final reasoningModels = availableModels.where((m) => isReasoningModel(m)).length;

      return {
        'totalModels': availableModels.length,
        'freeModels': freeModels,
        'reasoningModels': reasoningModels,
        'defaultModel': formatModelName(config.defaultModel),
        'provider': getModelProvider(config.defaultModel),
      };
    } catch (e) {
      // Return fallback stats
      return {
        'totalModels': 3,
        'freeModels': 3,
        'reasoningModels': mode == ChatMode.deepsearch ? 1 : 0,
        'defaultModel': formatModelName(config.defaultModel),
        'provider': getModelProvider(config.defaultModel),
      };
    }
  }

  static bool isFreeModel(String model) {
    // Deprecated: pricing is backend-driven; never infer free from suffix.
    return false;
  }

  static bool isReasoningModel(String model) {
    return ModelRegistry.isReasoningModel(model);
  }

  // Local persistence removed; backend is the source of truth. Keep defaults only as fallback.

  static ChatMode parseModeFromString(String modeString) {
    switch (modeString.toLowerCase()) {
      case 'search':
        return ChatMode.search;
      case 'aipedia':
      case 'ai_pedia':
      case 'ai-pedia':
        return ChatMode.aipedia;
      case 'deepsearch':
      case 'deep_search':
        return ChatMode.deepsearch;
      case 'chat':
      default:
        return ChatMode.chat;
    }
  }

  static Future<void> saveConfigs(Map<ChatMode, ModeConfig> configs) async {
    // Persistence removed; backend is source of truth.
  }

  static Future<void> updateConfigForMode(ChatMode mode, ModeConfig config) async {
    // Persistence removed; backend is source of truth.
  }
}

// Extension to add convenience methods to ChatMode enum
extension ChatModeExtension on ChatMode {
  // Note: availableModels is now async, use ModeConfigManager.getAvailableModelsForMode(this)
  ModeConfig get defaultConfig => ModeConfigManager.getDefaultConfigForMode(this);
  String get description => ModeConfigManager.getModeDescription(this);
  String get displayName => ModeConfigManager.getModeDisplayName(this);
  
  String get icon {
    switch (this) {
      case ChatMode.chat:
        return '💬';
      case ChatMode.search:
        return '🔎';
      case ChatMode.aipedia:
        return '📚';
      case ChatMode.deepsearch:
        return '🔍';
    }
  }
  bool get isReasoningMode => this == ChatMode.deepsearch;
  bool get requiresPremium => this == ChatMode.deepsearch;
  
  bool get requiresSpecialHandling => isReasoningMode;
}

extension ChatModeMaterialIcon on ChatMode {
  IconData get iconData {
    switch (this) {
      case ChatMode.chat:
        return Icons.bolt;
      case ChatMode.search:
        return Icons.search;
      case ChatMode.aipedia:
        return Icons.menu_book;
      case ChatMode.deepsearch:
        return Icons.search;
    }
  }
}
