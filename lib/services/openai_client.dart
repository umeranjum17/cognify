import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';


/// OpenAI API client as fallback option
class OpenAIClient {
  static final OpenAIClient _instance = OpenAIClient._internal();
  // API endpoints
  static const String baseUrl = 'https://api.openai.com/v1';
  static const String modelsEndpoint = '/models';

  static const String chatEndpoint = '/chat/completions';
  static const String completionsEndpoint = '/completions';

  static const String embeddingsEndpoint = '/embeddings';
  // Available models
  static const List<String> availableModels = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-4',
    'gpt-3.5-turbo',
    'gpt-3.5-turbo-16k',
  ];
  // Model pricing (per 1M tokens)
  static const Map<String, Map<String, double>> modelPricing = {
    'gpt-4o': {'input': 5.0, 'output': 15.0},
    'gpt-4o-mini': {'input': 0.15, 'output': 0.6},
    'gpt-4-turbo': {'input': 10.0, 'output': 30.0},
    'gpt-4': {'input': 30.0, 'output': 60.0},
    'gpt-3.5-turbo': {'input': 0.5, 'output': 1.5},
    'gpt-3.5-turbo-16k': {'input': 3.0, 'output': 4.0},
  };
  late final Dio _dio;
  bool _initialized = false;

  factory OpenAIClient() => _instance;

  OpenAIClient._internal();

  /// Send a chat completion request
  Future<Map<String, dynamic>> chatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    dynamic toolChoice,
  }) async {
    await _ensureInitialized();

    try {
      final apiKey = await AppConfig().openAiApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenAI API key not configured');
      }

      final requestData = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'stream': stream,
      };

      if (maxTokens != null) {
        requestData['max_tokens'] = maxTokens;
      }

      if (tools != null && tools.isNotEmpty) {
        requestData['tools'] = tools;
      }

      if (toolChoice != null) {
        requestData['tool_choice'] = toolChoice;
      }

      final response = await _dio.post(
        chatEndpoint,
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          responseType: stream ? ResponseType.stream : ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        if (stream) {
          return {'stream': response.data, 'model': model, 'streaming': true};
        } else {
          return {
            'response': response.data,
            'model': model,
            'streaming': false,
          };
        }
      } else {
        throw Exception('Chat completion failed: ${response.statusCode}');
      }
    } catch (e) {
      print('🤖 OpenAI chat completion failed: $e');
      rethrow;
    }
  }

  /// Send a streaming chat completion request
  Stream<Map<String, dynamic>> chatCompletionStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    dynamic toolChoice,
  }) async* {
    await _ensureInitialized();

    try {
      final apiKey = await AppConfig().openAiApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenAI API key not configured');
      }

      final requestData = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'stream': true,
      };

      if (maxTokens != null) {
        requestData['max_tokens'] = maxTokens;
      }

      if (tools != null && tools.isNotEmpty) {
        requestData['tools'] = tools;
      }

      if (toolChoice != null) {
        requestData['tool_choice'] = toolChoice;
      }

      final response = await _dio.post(
        chatEndpoint,
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200) {
        final stream = response.data as ResponseBody;

        await for (final chunk in stream.stream) {
          final text = utf8.decode(chunk);
          final lines = text.split('\n');

          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();

              if (data == '[DONE]') {
                return;
              }

              try {
                final json = jsonDecode(data);
                yield {'chunk': json, 'model': model, 'streaming': true};
              } catch (e) {
                // Skip invalid JSON chunks
                continue;
              }
            }
          }
        }
      } else {
        throw Exception(
          'Streaming chat completion failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('🤖 OpenAI streaming chat completion failed: $e');
      yield {'error': e.toString(), 'model': model, 'streaming': true};
    }
  }

  /// Generate embeddings for text
  Future<List<double>> generateEmbeddings({
    required String text,
    String model = 'text-embedding-3-small',
  }) async {
    await _ensureInitialized();

    try {
      final apiKey = await AppConfig().openAiApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenAI API key not configured');
      }

      final response = await _dio.post(
        embeddingsEndpoint,
        data: {'model': model, 'input': text},
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final embeddings = data['data'] as List;

        if (embeddings.isNotEmpty) {
          final embedding = embeddings.first['embedding'] as List;
          return embedding.cast<double>();
        } else {
          throw Exception('No embeddings returned');
        }
      } else {
        throw Exception('Embeddings generation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('🤖 OpenAI embeddings generation failed: $e');
      rethrow;
    }
  }

  /// Get the best available model (cheapest)
  String getBestModel({bool preferCheap = true}) {
    if (preferCheap) {
      return 'gpt-4o-mini'; // Cheapest option
    } else {
      return 'gpt-4o'; // Best performance
    }
  }

  /// Get available models
  Future<List<String>> getModels() async {
    await _ensureInitialized();

    try {
      final apiKey = await AppConfig().openAiApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        return availableModels;
      }

      final response = await _dio.get(
        modelsEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final models = data['data'] as List;

        return models
            .map((model) => model['id'] as String)
            .where((id) => id.startsWith('gpt-'))
            .toList();
      } else {
        return availableModels;
      }
    } catch (e) {
      print('🤖 Failed to fetch OpenAI models: $e');
      return availableModels;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _initialized = true;
    print('🤖 OpenAIClient initialized');
  }

  /// Check if API key is configured
  Future<bool> isConfigured() async {
    final apiKey = await AppConfig().openAiApiKey;
    return apiKey != null && apiKey.isNotEmpty;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
