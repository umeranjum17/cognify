import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

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

  /// Ensure the Dio client is pointing at the current backend base URL.
  /// This is important because different platforms (Android emulator vs iOS/macOS)
  /// require different hosts (10.0.2.2 vs localhost), and hot-reload can keep
  /// a stale baseUrl inside Dio if it was constructed earlier.
  void _syncDioBaseUrl() {
    final desired = AppConfig.backendBaseUrl;
    if (_dio.options.baseUrl != desired) {
      _dio.options.baseUrl = desired;
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Cache for mode configurations from backend
  Map<String, dynamic>? _modeConfigs;
  Map<String, dynamic>? _modelsConfig;

  /// Fetch mode configurations from backend
  Future<void> loadConfigurations() async {
    try {
      _syncDioBaseUrl();
      print('🌐 ModeApiService baseUrl: ${AppConfig.backendBaseUrl}');
      print('📡 [MODE_CONFIG] Making GET request to /api/config/modes');
      print('🔗 [MODE_CONFIG] Full URL: ${AppConfig.backendBaseUrl}/api/config/modes');
      
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        '/api/config/modes',
        options: Options(headers: headers),
      );
      
      print('✅ [MODE_CONFIG] Response received - Status: ${response.statusCode}');
      print('📦 [MODE_CONFIG] Response data type: ${response.data.runtimeType}');
      print('📄 [MODE_CONFIG] Response data: ${response.data}');
      
      final data = response.data is Map ? response.data as Map : {};
      // Accept either {data: {modes: {...}}} or {modes: {...}}
      final fromData = (data['data'] is Map) ? (data['data'] as Map)['modes'] : null;
      final raw = (fromData is Map) ? fromData : (data['modes'] as Map?);
      if (raw is Map) {
        _modeConfigs = Map<String, dynamic>.from(raw);
        print('✅ [MODE_CONFIG] Successfully loaded ${_modeConfigs?.length} mode configs');
      } else {
        _modeConfigs = {};
        print('⚠️ [MODE_CONFIG] No valid data found in response, using empty config');
      }
    } catch (e) {
      print('❌ [MODE_CONFIG] Failed to load mode configs: $e');
      print('🔍 [MODE_CONFIG] Error type: ${e.runtimeType}');
      if (e is DioException) {
        print('🌐 [MODE_CONFIG] DioException details:');
        print('   - Type: ${e.type}');
        print('   - Message: ${e.message}');
        print('   - Response status: ${e.response?.statusCode}');
        print('   - Response data: ${e.response?.data}');
        print('   - Request URL: ${e.requestOptions.uri}');
      }
      print('🔄 [MODE_CONFIG] Using defaults (baseUrl=${AppConfig.backendBaseUrl})');
    }
  }

  /// Fetch models configuration (defaults, capabilities, available, pricing)
  Future<Map<String, dynamic>?> loadModelsConfig() async {
    try {
      if (_modelsConfig != null) return _modelsConfig;
      _syncDioBaseUrl();
      print('🌐 ModelsConfig fetch baseUrl: ${AppConfig.backendBaseUrl}');
      print('📡 [MODELS_CONFIG] Making GET request to /api/config/models');
      print('🔗 [MODELS_CONFIG] Full URL: ${AppConfig.backendBaseUrl}/api/config/models');
      
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        '/api/config/models',
        options: Options(headers: headers),
      );
      
      print('✅ [MODELS_CONFIG] Response received - Status: ${response.statusCode}');
      print('📦 [MODELS_CONFIG] Response data type: ${response.data.runtimeType}');
      print('📄 [MODELS_CONFIG] Response data: ${response.data}');
      
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final raw = data['data'];
        if (raw is Map) {
          _modelsConfig = Map<String, dynamic>.from(raw);
          print('✅ [MODELS_CONFIG] Successfully loaded models config with ${_modelsConfig?.length} entries');
        }
        return _modelsConfig;
      }
    } catch (e) {
      print('❌ [MODELS_CONFIG] Failed to load models config: $e');
      print('🔍 [MODELS_CONFIG] Error type: ${e.runtimeType}');
      if (e is DioException) {
        print('🌐 [MODELS_CONFIG] DioException details:');
        print('   - Type: ${e.type}');
        print('   - Message: ${e.message}');
        print('   - Response status: ${e.response?.statusCode}');
        print('   - Response data: ${e.response?.data}');
        print('   - Request URL: ${e.requestOptions.uri}');
      }
      print('🔄 [MODELS_CONFIG] Using fallback (baseUrl=${AppConfig.backendBaseUrl})');
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
    
    _syncDioBaseUrl();
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
      final headers = await _getAuthHeaders();
      final resp = await _dio.post(
        endpoint,
        data: jsonEncode(body),
        options: Options(headers: headers),
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
    print('🌊 [STREAM] Starting streaming chat request...');
    print('📋 [STREAM] Mode: $mode');
    print('🎯 [STREAM] Model: $model');
    print('💬 [STREAM] Messages: ${messages?.length ?? 0}');
    print('❓ [STREAM] Query: ${query?.substring(0, query != null && query.length > 50 ? 50 : query?.length ?? 0) ?? 'none'}');
    
    _syncDioBaseUrl();
    await _ensureConfigLoaded();

    final endpoint = _getEndpoint(mode);
    final modeId = mode.toString().split('.').last;
    
    print('🌐 [STREAM] Full URL: ${AppConfig.backendBaseUrl}$endpoint');
    print('🏷️  [STREAM] Mode ID: $modeId');

    final body = <String, dynamic>{
      'mode': modeId, // Backend uses this to route to correct logic
      if (messages != null) 'messages': messages,
      if (query != null) 'query': query,
      if (model != null) 'model': model,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'maxTokens': maxTokens,
    };
    
    print('📦 [STREAM] Request body: ${jsonEncode(body).substring(0, 200)}...');
    print('📤 [STREAM] Sending streaming POST request...');

    try {
      final headers = await _getAuthHeaders();
      final resp = await _dio.post(
        endpoint,
        data: jsonEncode(body),
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      print('✅ [STREAM] Response received: ${resp.statusCode}');
      
      if (resp.statusCode != 200) {
        print('❌ [STREAM] Non-200 status: ${resp.statusCode}');
        print('❌ [STREAM] Response data: ${resp.data}');
        throw Exception('Streaming API failed: HTTP ${resp.statusCode}');
      }

      print('✅ [STREAM] Stream connection established');
      final responseBody = resp.data as ResponseBody;
      int chunkCount = 0;
      String buffer = '';
      
      await for (final chunk in responseBody.stream) {
        chunkCount++;
        final text = utf8.decode(chunk);
        print('📨 [STREAM] Chunk #$chunkCount received (${text.length} bytes)');
        
        // Accumulate into buffer to handle partial lines across chunks
        buffer += text;
        int newlineIndex;
        while ((newlineIndex = buffer.indexOf('\n')) != -1) {
          var line = buffer.substring(0, newlineIndex);
          buffer = buffer.substring(newlineIndex + 1);

          // Normalize CRLF
          if (line.endsWith('\r')) line = line.substring(0, line.length - 1);

          if (line.isEmpty) {
            continue; // skip keep-alives / empty lines
          }

          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              print('✅ [STREAM] Stream completed [DONE] received');
              yield { 'done': true, 'streaming': true };
              return;
            }
            try {
              final jsonData = jsonDecode(data) as Map<String, dynamic>;
              final jsonString = jsonEncode(jsonData);
              final preview = jsonString.length > 100 ? jsonString.substring(0, 100) + '...' : jsonString;
              print('📦 [STREAM] Yielding chunk data: $preview');
              if (jsonData.containsKey('content')) {
                yield {
                  'type': 'content',
                  'content': jsonData['content'],
                  'streaming': true,
                };
              } else {
                yield { ...jsonData, 'streaming': true };
              }
            } catch (e) {
              // If JSON parse fails, it may be because this was still partial (shouldn't happen with newline-boundary), log and continue
              print('⚠️  [STREAM] Failed to parse JSON from line: $line (error: $e)');
            }
          } else {
            // Ignore other SSE fields; log short preview for debugging
            final preview = line.length > 50 ? line.substring(0, 50) : line;
            print('⚠️  [STREAM] Non-data line received: $preview');
          }
        }
      }
      // On stream end, ignore any trailing partial buffer (no terminating newline)
      
      print('✅ [STREAM] Stream ended naturally (no [DONE] marker)');
    } catch (e, stackTrace) {
      print('❌❌❌ [STREAM] STREAMING REQUEST FAILED!');
      print('❌ [STREAM] Error type: ${e.runtimeType}');
      print('❌ [STREAM] Error message: $e');
      if (e is DioException) {
        print('❌ [STREAM] DioException type: ${e.type}');
        print('❌ [STREAM] DioException response: ${e.response?.statusCode} - ${e.response?.data}');
        print('❌ [STREAM] DioException message: ${e.message}');
      }
      print('❌ [STREAM] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _ensureConfigLoaded() async {
    if (_modeConfigs == null) {
      await loadConfigurations();
    }
  }
}

