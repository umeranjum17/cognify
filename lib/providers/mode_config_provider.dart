import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/mode_config.dart';
import '../services/mode_api_service.dart';

class ModeConfigProvider extends ChangeNotifier {
  Map<ChatMode, ModeConfig> _configs = {};
  bool _isLoading = false;

  ModeConfigProvider() {
    // Defer initial load to post-frame to avoid notify during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadConfigs();
    });
  }
  Map<ChatMode, ModeConfig> get configs => Map.unmodifiable(_configs);

  bool get isLoading => _isLoading;

  ModeConfig? getConfigForMode(ChatMode mode) {
    return _configs[mode];
  }

  String getModelForMode(ChatMode mode) {
    return _configs[mode]?.model ??
           ModeConfigManager.getDefaultConfigForMode(mode).model;
  }

  Future<void> refresh() async {
    await _loadConfigs();
  }

  Future<void> updateConfig(ChatMode mode, ModeConfig config) async {
    _configs[mode] = config;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> updateConfigs(Map<ChatMode, ModeConfig> newConfigs) async {
    _configs = Map.from(newConfigs);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> _loadConfigs() async {
    _isLoading = true;
    // Only notify if not in build phase; scheduling avoids build-time notify
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Load backend configs per-mode; fall back to defaults when missing
      final api = ModeApiService.instance;
      final Map<ChatMode, ModeConfig> loaded = {};
      for (final mode in ChatMode.values) {
        final cfg = await api.getModeConfig(mode);
        if (cfg != null) {
          loaded[mode] = ModeConfig(
            mode: mode,
            model: (cfg['model'] as String?) ?? (cfg['defaultModel'] as String?) ?? ModeConfigManager.getDefaultConfigForMode(mode).model,
            displayName: (cfg['displayName'] as String?) ?? mode.toString(),
            description: (cfg['description'] as String?) ?? '',
            defaultModel: (cfg['defaultModel'] as String?) ?? ModeConfigManager.getDefaultConfigForMode(mode).defaultModel,
          );
        } else {
          loaded[mode] = ModeConfigManager.getDefaultConfigForMode(mode);
        }
      }
      _configs = loaded;
    } catch (e) {
      print('Error loading mode configs: $e');
      _configs = {
        ChatMode.chat: ModeConfigManager.getDefaultConfigForMode(ChatMode.chat),
        ChatMode.search: ModeConfigManager.getDefaultConfigForMode(ChatMode.search),
        ChatMode.aipedia: ModeConfigManager.getDefaultConfigForMode(ChatMode.aipedia),
        ChatMode.deepsearch: ModeConfigManager.getDefaultConfigForMode(ChatMode.deepsearch),
      };
    }

    _isLoading = false;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
