import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/mode_config.dart';

/// Configuration-driven API client - Backend tells us what to do!
class ModeApiService {
  ModeApiService._internal();
  static final ModeApiService instance = ModeApiService._internal();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.backendBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    sendTimeout: AppConfig.sendTimeout,
  ));

  // Cache for mode configurations from backend
  Map<String, dynamic>? _modeConfigs;
  Map<String, dynamic>? _modelsConfig;

  /// Fetch mode configurations from backend
  Future<void> loadConfigurations() async {
    try {
      print('🌐 ModeApiService baseUrl: ${AppConfig.backendBaseUrl}');
      final response = await _dio.get('/api/config/modes');
      final data = response.data is Map ? response.data as Map : {};
      final raw = data['data'];
      if (raw is Map) {
        _modeConfigs = Map<String, dynamic>.from(raw);
      } else {
        _modeConfigs = {};
      }
    } catch (e) {
      print('⚠️ Failed to load mode configs, using defaults: $e (baseUrl=${AppConfig.backendBaseUrl})');
    }
  }

  /// Fetch models configuration (defaults, capabilities, available, pricing)
  Future<Map<String, dynamic>?> loadModelsConfig() async {
    try {
      if (_modelsConfig != null) return _modelsConfig;
      print('🌐 ModelsConfig fetch baseUrl: ${AppConfig.backendBaseUrl}');
      final response = await _dio.get('/api/config/models');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final raw = data['data'];
        if (raw is Map) {
          _modelsConfig = Map<String, dynamic>.from(raw);
        }
        return _modelsConfig;
      }
    } catch (e) {
      print('⚠️ Failed to load models config: $e (baseUrl=${AppConfig.backendBaseUrl})');
    }
    return null;
  }

  /// Get raw mode config for a specific mode from backend cache
  Future<Map<String, dynamic>?> getModeConfig(ChatMode mode) async {
    await _ensureConfigLoaded();
    final modeId = mode.toString().split('.').last;
    final config = _modeConfigs?[modeId];
    if (config is Map<String, dynamic>) return config;
    return null;
  }

  /// Convenience: get default model for a mode from backend config
  Future<String?> getDefaultModel(ChatMode mode) async {
    final cfg = await getModeConfig(mode);
    return cfg?['defaultModel'] as String? ?? cfg?['model'] as String?;
  }

  /// Convenience: display name for a mode
  Future<String> getModeDisplayName(ChatMode mode) async {
    final cfg = await getModeConfig(mode);
    return (cfg?['displayName'] as String?) ?? mode.toString().split('.').last;
  }

  /// Convenience: description for a mode
  Future<String> getModeDescription(ChatMode mode) async {
    final cfg = await getModeConfig(mode);
    return (cfg?['description'] as String?) ?? '';
  }

  /// Convenience: available models list for a mode
  Future<List<String>> getAvailableModelsForMode(ChatMode mode) async {
    final cfg = await getModeConfig(mode);
    final models = cfg?['availableModels'] ?? cfg?['models'];
    if (models is List) {
      return List<String>.from(models);
    }
    return const [];
  }

  /// Get endpoint for a mode (backend configuration driven)
  String _getEndpoint(ChatMode mode) {
    final modeId = mode.toString().split('.').last;
    final config = _modeConfigs?[modeId];
    return config?['endpoint'] ?? '/api/chat'; // Unified endpoint
  }

  /// Send chat request - Backend determines behavior based on mode parameter
  Future<Map<String, dynamic>> chat({
    required ChatMode mode,
    List<Map<String, dynamic>>? messages,
    String? query,
    String? model,
    double? temperature,
    int? maxTokens,
    bool stream = false,
  }) async {
    print('🚀 [CHAT] Starting chat request...');
    print('📋 [CHAT] Mode: $mode');
    print('🎯 [CHAT] Model: $model');
    print('💬 [CHAT] Messages: ${messages?.length ?? 0}');
    print('❓ [CHAT] Query: ${query?.substring(0, query.length > 50 ? 50 : query.length)}');
    
    await _ensureConfigLoaded();

    final endpoint = _getEndpoint(mode);
    final modeId = mode.toString().split('.').last;
    
    print('🌐 [CHAT] Endpoint: ${AppConfig.backendBaseUrl}$endpoint');
    print('🏷️  [CHAT] Mode ID: $modeId');

    final body = <String, dynamic>{
      'mode': modeId, // Backend uses this to determine behavior
      if (messages != null) 'messages': messages,
      if (query != null) 'query': query,
      if (model != null) 'model': model,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'maxTokens': maxTokens,
    };
    
    print('📦 [CHAT] Request body keys: ${body.keys.join(', ')}');
    print('📤 [CHAT] Sending POST request...');

    try {
      final resp = await _dio.post(
        endpoint,
        data: jsonEncode(body),
        options: Options(headers: {
          'Content-Type': 'application/json',
        }),
      );

      print('✅ [CHAT] Response received: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        print('✅ [CHAT] Success! Response data type: ${resp.data.runtimeType}');
        return {
          'response': resp.data,
          'streaming': false,
        };
      }
      
      print('❌ [CHAT] Non-200 status: ${resp.statusCode}');
      throw Exception('API failed: HTTP ${resp.statusCode}');
    } catch (e, stackTrace) {
      print('❌❌❌ [CHAT] REQUEST FAILED!');
      print('❌ [CHAT] Error type: ${e.runtimeType}');
      print('❌ [CHAT] Error message: $e');
      if (e is DioException) {
        print('❌ [CHAT] DioException type: ${e.type}');
        print('❌ [CHAT] DioException response: ${e.response?.statusCode} - ${e.response?.data}');
        print('❌ [CHAT] DioException message: ${e.message}');
      }
      print('❌ [CHAT] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stream chat responses - Backend handles everything
  Stream<Map<String, dynamic>> chatStream({
    required ChatMode mode,
    List<Map<String, dynamic>>? messages,
    String? query,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async* {
    await _ensureConfigLoaded();

    final endpoint = _getEndpoint(mode);
    final modeId = mode.toString().split('.').last;

    final body = <String, dynamic>{
      'mode': modeId, // Backend uses this to route to correct logic
      if (messages != null) 'messages': messages,
      if (query != null) 'query': query,
      if (model != null) 'model': model,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'maxTokens': maxTokens,
    };

    final resp = await _dio.post(
      endpoint,
      data: jsonEncode(body),
      options: Options(
        headers: { 'Content-Type': 'application/json' },
        responseType: ResponseType.stream,
      ),
    );

    if (resp.statusCode != 200) {
      throw Exception('Streaming API failed: HTTP ${resp.statusCode}');
    }

    final responseBody = resp.data as ResponseBody;
    await for (final chunk in responseBody.stream) {
      final text = utf8.decode(chunk);
      final lines = text.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') {
            yield { 'done': true, 'streaming': true };
            return;
          }
          try {
            final jsonData = jsonDecode(data);
            yield { 'chunk': jsonData, 'streaming': true };
          } catch (_) {
            // ignore non-JSON lines
          }
        }
      }
    }
  }

  Future<void> _ensureConfigLoaded() async {
    if (_modeConfigs == null) {
      await loadConfigurations();
    }
  }
}

