import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/model_service.dart';

enum ChatMode {
  chat,
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
  
  // Default configurations for each mode (will be updated from API)
  static final Map<ChatMode, ModeConfig> _defaultConfigs = {
    ChatMode.chat: const ModeConfig(
      mode: ChatMode.chat,
      model: 'google/gemini-2.5-flash-lite',
      displayName: 'Chat',
      description: 'Lightning fast responses with minimal search',
      defaultModel: 'google/gemini-2.5-flash-lite',
    ),
    ChatMode.deepsearch: const ModeConfig(
      mode: ChatMode.deepsearch,
      model: 'deepseek/deepseek-r1:free',
      displayName: 'DeepSearch',
      description: 'Ultra-comprehensive research with enhanced visual content and 4x more detailed responses (10x resources)',
      defaultModel: 'deepseek/deepseek-r1:free',
    ),
  };

  /// Clear all stored configurations (useful for fixing corruption)
  static Future<void> clearConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing mode configs: $e');
    }
  }

  // Models are now fetched from API via ModelService

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
      final modelData = await ModelService.getModelsByMode(mode);
      return List<String>.from(modelData['models'] ?? []);
    } catch (e) {
      print('Error fetching models for mode: $e');
      // Return fallback models
      switch (mode) {
        case ChatMode.chat:
          return [
            'mistralai/mistral-7b-instruct:free',
            'deepseek/deepseek-chat:free',
            'google/gemini-2.5-flash-lite',
          ];
        case ChatMode.deepsearch:
          return [
            'deepseek/deepseek-r1:free',
            'deepseek/deepseek-chat-v3-0324:free',
            'google/gemini-2.5-flash-lite',
          ];
      }
    }
  }

  static Future<ModeConfig> getConfigForMode(ChatMode mode) async {
    final configs = await loadConfigs();
    return configs[mode] ?? _defaultConfigs[mode]!;
  }

  static ModeConfig getDefaultConfigForMode(ChatMode mode) {
    return _defaultConfigs[mode]!;
  }

  static String getModeDescription(ChatMode mode) {
    return _defaultConfigs[mode]?.description ?? '';
  }

  static String getModeDisplayName(ChatMode mode) {
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
        mode = ChatMode.deepsearch;
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
    return model.endsWith(':free');
  }

  static bool isReasoningModel(String model) {
    return model.contains('deepseek-r1') || 
           model.contains('reasoning') ||
           model.contains('think');
  }

  static Future<Map<ChatMode, ModeConfig>> loadConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = prefs.getString(_storageKey);

      if (configsJson == null) {
        return Map.from(_defaultConfigs);
      }

      final configsMap = jsonDecode(configsJson) as Map<String, dynamic>;
      final configs = <ChatMode, ModeConfig>{};
      bool hasCorruptedData = false;

      for (final mode in ChatMode.values) {
        final modeKey = mode.toString();
        if (configsMap.containsKey(modeKey)) {
          try {
            final config = ModeConfig.fromJson(configsMap[modeKey]);
            // Validate model format - check for concatenated models
            if (config.model.contains('google/gemini-2.5-flash-lite-preview-06-17google/gemini-2.0-flash-exp:free') ||
                config.model.split('/').length > 2) {
              hasCorruptedData = true;
              configs[mode] = _defaultConfigs[mode]!;
            } else {
              configs[mode] = config;
            }
          } catch (e) {
            hasCorruptedData = true;
            configs[mode] = _defaultConfigs[mode]!;
          }
        } else {
          configs[mode] = _defaultConfigs[mode]!;
        }
      }

      // If corrupted data was found, save clean configs
      if (hasCorruptedData) {
        await saveConfigs(configs);
      }

      return configs;
    } catch (e) {
      print('Error loading mode configs: $e');
      // Clear corrupted storage and return defaults
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      return Map.from(_defaultConfigs);
    }
  }

  static ChatMode parseModeFromString(String modeString) {
    switch (modeString.toLowerCase()) {
      case 'deepsearch':
      case 'deep_search':
        return ChatMode.deepsearch;
      case 'chat':
      default:
        return ChatMode.chat;
    }
  }

  static Future<void> saveConfigs(Map<ChatMode, ModeConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsMap = <String, dynamic>{};

      for (final entry in configs.entries) {
        configsMap[entry.key.toString()] = entry.value.toJson();
      }

      await prefs.setString(_storageKey, jsonEncode(configsMap));
    } catch (e) {
      print('Error saving mode configs: $e');
    }
  }

  static Future<void> updateConfigForMode(ChatMode mode, ModeConfig config) async {
    final configs = await loadConfigs();
    configs[mode] = config;
    await saveConfigs(configs);
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
      case ChatMode.deepsearch:
        return Icons.search;
    }
  }
}
