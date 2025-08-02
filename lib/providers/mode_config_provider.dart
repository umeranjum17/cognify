import 'package:flutter/material.dart';

import '../models/mode_config.dart';

class ModeConfigProvider extends ChangeNotifier {
  Map<ChatMode, ModeConfig> _configs = {};
  bool _isLoading = false;

  ModeConfigProvider() {
    _loadConfigs();
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
    print('🤖 ModeConfigProvider: Updating config for mode: $mode with model: ${config.model}');
    _configs[mode] = config;
    notifyListeners();
    print('🤖 ModeConfigProvider: Notified listeners for mode: $mode');

    try {
      await ModeConfigManager.saveConfigs(_configs);
      print('🤖 ModeConfigProvider: Saved configs successfully');
    } catch (e) {
      print('Error saving mode config: $e');
    }
  }

  Future<void> updateConfigs(Map<ChatMode, ModeConfig> newConfigs) async {
    _configs = Map.from(newConfigs);
    notifyListeners();

    try {
      await ModeConfigManager.saveConfigs(_configs);
    } catch (e) {
      print('Error saving mode configs: $e');
    }
  }

  Future<void> _loadConfigs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _configs = await ModeConfigManager.loadConfigs();
    } catch (e) {
      print('Error loading mode configs: $e');
      _configs = {
        ChatMode.chat: ModeConfigManager.getDefaultConfigForMode(ChatMode.chat),
        ChatMode.deepsearch: ModeConfigManager.getDefaultConfigForMode(ChatMode.deepsearch),
      };
    }

    _isLoading = false;
    notifyListeners();
  }
}