import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/mode_config.dart';

/// Thin client for per-mode backend APIs under /api/modes/*
class ModeApiService {
  ModeApiService._internal();
  static final ModeApiService instance = ModeApiService._internal();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    sendTimeout: AppConfig.sendTimeout,
  ));

  String get _baseUrl {
    final b = AppConfig.backendBaseUrl;
    return b.isNotEmpty ? '$b/api/modes' : '/api/modes';
  }

  Future<Map<String, dynamic>> chat({
    required ChatMode mode,
    List<Map<String, dynamic>>? messages,
    String? query,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
    bool stream = false,
  }) async {
    final path = _modePath(mode);
    final body = <String, dynamic>{
      if (messages != null) 'messages': messages,
      if (query != null) 'query': query,
      if (model != null) 'model': model,
      'temperature': temperature,
      if (maxTokens != null) 'maxTokens': maxTokens,
      'stream': stream,
    };

    final resp = await _dio.post(
      path,
      data: jsonEncode(body),
      options: Options(headers: {
        'Content-Type': 'application/json',
      }),
    );

    if (resp.statusCode == 200) {
      if (stream) {
        // For stream=true, the backend would normally return SSE; this code path
        // is kept for symmetry, though callers should use chatStream for SSE.
        return { 'streaming': true, 'raw': resp.data };
      }
      return {
        'response': resp.data,
        'streaming': false,
      };
    }
    throw Exception('Mode API failed: HTTP ${resp.statusCode}');
  }

  Stream<Map<String, dynamic>> chatStream({
    required ChatMode mode,
    List<Map<String, dynamic>>? messages,
    String? query,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
  }) async* {
    final path = _modePath(mode);
    final body = <String, dynamic>{
      if (messages != null) 'messages': messages,
      if (query != null) 'query': query,
      if (model != null) 'model': model,
      'temperature': temperature,
      if (maxTokens != null) 'maxTokens': maxTokens,
      'stream': true,
    };

    final resp = await _dio.post(
      path,
      data: jsonEncode(body),
      options: Options(
        headers: { 'Content-Type': 'application/json' },
        responseType: ResponseType.stream,
      ),
    );

    if (resp.statusCode != 200) {
      throw Exception('Streaming mode API failed: HTTP ${resp.statusCode}');
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

  String _modePath(ChatMode mode) {
    switch (mode) {
      case ChatMode.chat:
        return '/chat';
      case ChatMode.search:
        return '/search';
      case ChatMode.aipedia:
        return '/aipedia';
      default:
        return '/chat';
    }
  }
}

