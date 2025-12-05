import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mode_config.dart';
import '../services/mode_api_service.dart';

class ModeConfigProvider extends ChangeNotifier {
  static const _cacheKey = 'mode_configs_cache_v2';
  static const _overrideKey = 'mode_configs_overrides_v2';
  static const _cacheTimestampKey = 'mode_configs_cache_ts_v2';
  static const _cacheTtl = Duration(hours: 12);

  Map<ChatMode, ModeConfig> _configs = {};
  final Map<ChatMode, String> _userSelectedModels = {};
  bool _isLoading = false;
  DateTime? _lastRemoteFetch;

  ModeConfigProvider() {
    _hydrateCache();
    // Defer initial fetch to avoid notify during build
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

  Future<void> refresh({bool force = false}) async {
    await _loadConfigs(force: force);
  }

  Future<void> updateConfig(ChatMode mode, ModeConfig config) async {
    _configs[mode] = config;
    _userSelectedModels[mode] = config.model;
    await _saveCache();
    _scheduleNotify();
  }

  Future<void> updateConfigs(Map<ChatMode, ModeConfig> newConfigs) async {
    _configs = Map.from(newConfigs);
    for (final entry in newConfigs.entries) {
      _userSelectedModels[entry.key] = entry.value.model;
    }
    await _saveCache();
    _scheduleNotify();
  }

  Future<void> _hydrateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      final overridesRaw = prefs.getString(_overrideKey);
      final ts = prefs.getInt(_cacheTimestampKey);

      if (ts != null) {
        _lastRemoteFetch = DateTime.fromMillisecondsSinceEpoch(ts);
      }

      if (overridesRaw != null) {
        final decoded = jsonDecode(overridesRaw) as Map<String, dynamic>;
        decoded.forEach((modeKey, model) {
          final mode = _parseMode(modeKey);
          if (mode != null && model is String && model.isNotEmpty) {
            _userSelectedModels[mode] = model;
          }
        });
      }

      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final restored = <ChatMode, ModeConfig>{};
        data.forEach((modeKey, value) {
          final mode = _parseMode(modeKey);
          if (mode == null || value is! Map<String, dynamic>) return;
          try {
            restored[mode] = ModeConfig.fromJson(value);
          } catch (_) {}
        });
        if (restored.isNotEmpty) {
          _configs = restored;
          _scheduleNotify();
        }
      }
    } catch (e) {
      debugPrint('⚠️ ModeConfig cache hydrate failed: $e');
    }
  }

  Future<void> _loadConfigs({bool force = false}) async {
    if (_isLoading) return;
    final shouldSkipRemote = !force &&
        _configs.isNotEmpty &&
        _lastRemoteFetch != null &&
        DateTime.now().difference(_lastRemoteFetch!) < _cacheTtl;
    if (shouldSkipRemote) return;

    _isLoading = true;
    _scheduleNotify();

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
      _lastRemoteFetch = DateTime.now();

      // Re-apply any persisted overrides so user selections stick
      _userSelectedModels.forEach((mode, modelId) {
        final existing = _configs[mode];
        if (existing != null && modelId.isNotEmpty) {
          _configs[mode] = existing.copyWith(model: modelId);
        }
      });
      await _saveCache();
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
    _scheduleNotify();
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _configs.map((mode, config) => MapEntry(mode.toString(), config.toJson())),
      );
      final overridesEncoded = jsonEncode(
        _userSelectedModels.map((mode, model) => MapEntry(mode.toString(), model)),
      );
      await prefs.setString(_cacheKey, encoded);
      await prefs.setString(_overrideKey, overridesEncoded);
      await prefs.setInt(
        _cacheTimestampKey,
        _lastRemoteFetch?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('⚠️ ModeConfig cache save failed: $e');
    }
  }

  void _scheduleNotify() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  ChatMode? _parseMode(String key) {
    final normalized = key.contains('.')
        ? key.split('.').last
        : key;
    try {
      return ModeConfigManager.parseModeFromString(normalized);
    } catch (_) {
      return null;
    }
  }
}
