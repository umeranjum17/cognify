import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';



/// OpenRouter API client for direct LLM access
class OpenRouterClient {
  static final OpenRouterClient _instance = OpenRouterClient._internal();
  // API endpoints
  static const String baseUrl = 'https://openrouter.ai/api/v1';
  static const String modelsEndpoint = '/models';

  static const String chatEndpoint = '/chat/completions';
  static const String generationEndpoint = '/generations';

  // Default models
  static const String defaultModel = 'deepseek/deepseek-chat:free';
  static const String fallbackModel = 'mistralai/mistral-7b-instruct:free';
  late final Dio _dio;
  bool _initialized = false;

  // Retry logic for 401 errors
  static int _consecutive401Errors = 0;
  static DateTime? _lastSuccessfulCall;
  static const int _maxRetries = 3; // Total attempts: initial + 2 retries

  // Model pricing cache
  Map<String, Map<String, double>> _modelPricing = {};
  List<String> _availableModels = [];
  final List<Map<String, dynamic>> _cachedModelData = [];
  DateTime? _lastModelsFetch;

  factory OpenRouterClient() => _instance;
  OpenRouterClient._internal();

  /// Get available models list
  List<String> get availableModels => List.from(_availableModels);

  /// Get model pricing information
  Map<String, Map<String, double>> get modelPricing => Map.from(_modelPricing);

  /// Send a chat completion request
  Future<Map<String, dynamic>> chatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    bool stream = false,
    Map<String, dynamic>? tools,
    String? toolChoice,
    BuildContext? context,
  }) async {
    await _ensureInitialized();

    return _retryOn401(
      context: context,
      apiCall: () async {
        final apiKey = await AppConfig().openRouterApiKey;
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('OpenRouter API key not configured');
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

        if (tools != null) {
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
            return {
              'stream': response.data,
              'model': model,
              'streaming': true,
            };
          } else {
            // Extract generation ID and usage information from response
            final responseData = response.data as Map<String, dynamic>;
            String? generationId;
            Map<String, dynamic>? usage;

            // Extract generation ID from response (aligned with server-side extractUsageFromResponse)
            if (responseData.containsKey('id')) {
              generationId = responseData['id'] as String?;
            } else if (responseData.containsKey('generation_id')) {
              generationId = responseData['generation_id'] as String?;
            }

            // Extract usage information (aligned with server-side)
            if (responseData.containsKey('usage')) {
              usage = responseData['usage'] as Map<String, dynamic>?;
            } else if (responseData.containsKey('response_metadata') && responseData['response_metadata'] is Map<String, dynamic>) {
              final metadata = responseData['response_metadata'] as Map<String, dynamic>;
              if (metadata.containsKey('usage')) {
                usage = metadata['usage'] as Map<String, dynamic>?;
              }
              // Also check for generation ID in response_metadata
              if (generationId == null && metadata.containsKey('id')) {
                generationId = metadata['id'] as String?;
              }
            }

            return {
              'response': responseData,
              'model': model,
              'streaming': false,
              'generationId': generationId,
              'usage': usage,
            };
          }
        } else {
          throw Exception('Chat completion failed: ${response.statusCode}');
        }
      },
    );
  }

  /// Send a streaming chat completion request
  Stream<Map<String, dynamic>> chatCompletionStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    Map<String, dynamic>? tools,
    String? toolChoice,
    BuildContext? context,
  }) async* {
    await _ensureInitialized();

    try {
      final apiKey = await AppConfig().openRouterApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenRouter API key not configured');
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

      if (tools != null) {
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
                yield {
                  'chunk': json,
                  'model': model,
                  'streaming': true,
                };
              } catch (e) {
                // Skip invalid JSON chunks
                continue;
              }
            }
          }
        }
      } else {
        throw Exception('Streaming chat completion failed: ${response.statusCode}');
      }

    } on DioException catch (e) {
      print('🤖 Streaming chat completion failed: $e');
      _handleHttpError(e, context);
      yield {
        'type': 'error',
        'error': e.toString(),
        'model': model,
        'streaming': true,
        'done': true,
      };
    } catch (e) {
      print('🤖 Streaming chat completion failed: $e');
      yield {
        'type': 'error',
        'error': e.toString(),
        'model': model,
        'streaming': true,
        'done': true,
      };
    }
  }

  /// Create chat completion (alias for chatCompletion)
  Future<Map<String, dynamic>> createChatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    bool stream = false,
    Map<String, dynamic>? tools,
    String? toolChoice,
  }) async {
    return await chatCompletion(
      model: model,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: stream,
      tools: tools,
      toolChoice: toolChoice,
    );
  }

  /// Create streaming chat completion
  Stream<Map<String, dynamic>> createChatCompletionStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    Map<String, dynamic>? tools,
    String? toolChoice,
    BuildContext? context,
  }) async* {
    try {
      final apiKey = await AppConfig().openRouterApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenRouter API key not configured');
      }

      final requestData = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'stream': true, // Always true for streaming
        'max_tokens': maxTokens ?? 2000,
      };

      if (tools != null) {
        requestData['tools'] = tools;
      }

      if (toolChoice != null) {
        requestData['tool_choice'] = toolChoice;
      }

      print('🔄 Creating streaming chat completion with stream: true');

      final response = await _dio.post(
        chatEndpoint,
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200) {
        final responseBody = response.data as ResponseBody;
        print('🔄 Stream response received, processing chunks...');

        // Track generation ID and usage from the first chunk
        String? generationId;
        Map<String, dynamic>? usage;
        bool hasEmittedMetadata = false;

        await for (final chunk in responseBody.stream) {
          final chunkStr = utf8.decode(chunk);
          final lines = chunkStr.split('\n');

          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();
              if (data == '[DONE]') {
                print('🔄 Stream completed');
                // Emit final metadata with generation ID and usage
                if (generationId != null || usage != null) {
                  yield {
                    'done': true,
                    'generationId': generationId,
                    'usage': usage,
                    'metadata': true,
                  };
                } else {
                  yield {'done': true};
                }
                break;
              }

              try {
                final jsonData = json.decode(data);

                // Extract generation ID and usage from the first chunk (aligned with server-side)
                if (!hasEmittedMetadata) {
                  // Check multiple locations for generation ID (aligned with server-side extractUsageFromResponse)
                  if (jsonData.containsKey('id')) {
                    generationId = jsonData['id'] as String?;
                    print('🔗 Streaming generation ID from id: $generationId');
                  } else if (jsonData.containsKey('generation_id')) {
                    generationId = jsonData['generation_id'] as String?;
                    print('🔗 Streaming generation ID from generation_id: $generationId');
                  }

                  // Check multiple locations for usage (aligned with server-side)
                  if (jsonData.containsKey('usage')) {
                    usage = jsonData['usage'] as Map<String, dynamic>?;
                    if (usage != null) {
                      print('💰 Streaming usage: ${usage['prompt_tokens'] ?? 0} input + ${usage['completion_tokens'] ?? 0} output = ${usage['total_tokens'] ?? 0} tokens');
                    }
                  } else if (jsonData.containsKey('response_metadata') && jsonData['response_metadata'] is Map<String, dynamic>) {
                    final metadata = jsonData['response_metadata'] as Map<String, dynamic>;
                    if (metadata.containsKey('usage')) {
                      usage = metadata['usage'] as Map<String, dynamic>?;
                      if (usage != null) {
                        print('💰 Streaming usage from response_metadata: ${usage['prompt_tokens'] ?? 0} input + ${usage['completion_tokens'] ?? 0} output = ${usage['total_tokens'] ?? 0} tokens');
                      }
                    }
                    // Also check for generation ID in response_metadata
                    if (generationId == null && metadata.containsKey('id')) {
                      generationId = metadata['id'] as String?;
                      print('🔗 Streaming generation ID from response_metadata.id: $generationId');
                    }
                  }

                  // Emit metadata chunk first
                  if (generationId != null || usage != null) {
                    yield {
                      'metadata': true,
                      'generationId': generationId,
                      'usage': usage,
                      'done': false,
                    };
                    hasEmittedMetadata = true;
                  }
                }

                // Process content chunks
                if (jsonData.containsKey('choices') && jsonData['choices'].isNotEmpty) {
                  final delta = jsonData['choices'][0]['delta'];
                  if (delta.containsKey('content') && delta['content'] != null) {
                    yield {
                      'content': delta['content'],
                      'done': false,
                    };
                  }
                }
              } catch (e) {
                // Skip invalid JSON
                continue;
              }
            }
          }
        }
      } else {
        throw Exception('Streaming chat completion failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('🚨 Streaming chat completion error: $e');
      print('🐛 DEBUG: OpenRouterClient.chatCompletionStream about to yield error event with type=error');
      _handleHttpError(e, context);
      yield {'type': 'error', 'error': e.toString(), 'done': true};
    } catch (e) {
      print('🚨 Streaming chat completion error: $e');
      print('🐛 DEBUG: OpenRouterClient.chatCompletionStream about to yield error event with type=error');
      yield {'type': 'error', 'error': e.toString(), 'done': true};
    }
  }

  /// Get the best available model based on pricing and availability
  Future<String> getBestModel({bool preferFree = true}) async {
    final modelsData = await getModels();
    final models = modelsData['models'] as List<String>;
    final pricing = modelsData['pricing'] as Map<String, Map<String, double>>;

    if (models.isEmpty) {
      return defaultModel;
    }

    if (preferFree) {
      // Find free models first
      for (final model in models) {
        final modelPricing = pricing[model];
        if (modelPricing != null &&
            modelPricing['input'] == 0.0 &&
            modelPricing['output'] == 0.0) {
          return model;
        }
      }
    }

    // Find cheapest model
    String? cheapestModel;
    double lowestCost = double.infinity;

    for (final model in models) {
      final modelPricing = pricing[model];
      if (modelPricing != null) {
        final totalCost = modelPricing['input']! + modelPricing['output']!;
        if (totalCost < lowestCost) {
          lowestCost = totalCost;
          cheapestModel = model;
        }
      }
    }

    return cheapestModel ?? models.first;
  }

  /// Get credits information from OpenRouter
  Future<Map<String, dynamic>?> getCredits({BuildContext? context}) async {
    await _ensureInitialized();

    try {
      return await _retryOn401(
        context: context,
        apiCall: () async {
          final apiKey = await AppConfig().openRouterApiKey;
          if (apiKey == null || apiKey.isEmpty) {
            throw Exception('OpenRouter API key not configured');
          }

          final response = await _dio.get(
            '/credits',
            options: Options(
              headers: {'Authorization': 'Bearer $apiKey'},
            ),
          );

          if (response.statusCode == 200) {
            final data = response.data as Map<String, dynamic>;
            print('🤖 Credits API Response: $data');

            if (data['data'] != null) {
              final creditsData = data['data'] as Map<String, dynamic>;
              return {
                'total_credits': creditsData['total_credits'] ?? 0.0,
                'total_usage': creditsData['total_usage'] ?? 0.0,
                'remaining_credits': (creditsData['total_credits'] ?? 0.0) - (creditsData['total_usage'] ?? 0.0),
                'fetched_at': DateTime.now().toIso8601String(),
              };
            }
          } else {
            throw Exception('Failed to fetch credits: ${response.statusCode}');
          }
          return null;
        },
      );
    } catch (e) {
      print('🤖 Failed to fetch credits from OpenRouter: $e');
      return null;
    }
  }

  /// Get cost data for a specific generation ID
  Future<Map<String, dynamic>?> getGenerationCost(String generationId) async {
    await _ensureInitialized();

    try {
      final apiKey = await AppConfig().openRouterApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenRouter API key not configured');
      }

      print('💰 Fetching cost for generation: $generationId');

      final response = await _dio.get(
        '$baseUrl/generation',
        queryParameters: {'id': generationId},
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData.containsKey('data')) {
          final generationData = responseData['data'] as Map<String, dynamic>;

          // Extract cost information
          final costData = {
            'id': generationData['id'],
            'total_cost': generationData['total_cost'] ?? 0.0,
            'model': generationData['model'],
            'tokens_prompt': generationData['tokens_prompt'] ?? 0,
            'tokens_completion': generationData['tokens_completion'] ?? 0,
            'created_at': generationData['created_at'],
            'usage': generationData['usage'] ?? 0,
            'cache_discount': generationData['cache_discount'] ?? 0,
            'upstream_inference_cost': generationData['upstream_inference_cost'] ?? 0,
            'finish_reason': generationData['finish_reason'],
            'provider_name': generationData['provider_name'],
            'latency': generationData['latency'],
            'generation_time': generationData['generation_time'],
          };

          final totalCost = (costData['total_cost'] ?? 0.0).toDouble();
          print('✅ Fetched cost for generation $generationId: \$${totalCost.toStringAsFixed(6)}');

          return costData;
        } else {
          print('❌ No data field in generation response for $generationId');
          return null;
        }
      } else if (response.statusCode == 404) {
        print('❌ Generation $generationId not found (404) - may be too recent or invalid');
        return null;
      } else {
        print('❌ Failed to fetch generation cost: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching generation cost for $generationId: $e');
      return null;
    }
  }

  /// Get available models and their pricing
  Future<Map<String, dynamic>> getModels({bool forceRefresh = false, BuildContext? context}) async {
    await _ensureInitialized();

    // Check cache validity (refresh every hour)
    if (!forceRefresh &&
        _lastModelsFetch != null &&
        DateTime.now().difference(_lastModelsFetch!).inHours < 1 &&
        _availableModels.isNotEmpty &&
        _cachedModelData.isNotEmpty) {
      return {
        'success': true,
        'data': _cachedModelData,
        'models': _availableModels,
        'pricing': _modelPricing,
        'cached': true,
      };
    }

    try {
      return await _retryOn401(
        context: context,
        apiCall: () async {
          final apiKey = await AppConfig().openRouterApiKey;
          if (apiKey == null || apiKey.isEmpty) {
            throw Exception('OpenRouter API key not configured');
          }

          final response = await _dio.get(
            modelsEndpoint,
            options: Options(
              headers: {'Authorization': 'Bearer $apiKey'},
            ),
          );

          if (response.statusCode == 200) {
            final data = response.data as Map<String, dynamic>;
            print('🤖 OpenRouter API Response structure: ${data.runtimeType}');

            if (data['data'] == null) {
              throw Exception('Invalid response structure from OpenRouter API');
            }

            final models = data['data'] as List;
            print('🤖 Found ${models.length} models in API response');

            _availableModels.clear();
            _modelPricing.clear();
            _cachedModelData.clear();

            for (final model in models) {
              try {
                final modelId = model['id'] as String;
                _availableModels.add(modelId);

                // Handle pricing data with better error handling
                final pricing = model['pricing'];
                if (pricing != null) {
                  print('🤖 Processing pricing for model $modelId: ${pricing.runtimeType} - $pricing');

              // Handle different pricing structures
              double promptPrice = 0.0;
              double completionPrice = 0.0;

              if (pricing is Map) {
                // Handle direct structure: pricing.prompt and pricing.completion
                if (pricing['prompt'] != null && pricing['completion'] != null) {
                  final promptData = pricing['prompt'];
                  final completionData = pricing['completion'];

                  // Handle direct numeric values
                  if (promptData is num) {
                    promptPrice = promptData.toDouble();
                  } else if (promptData is String) {
                    promptPrice = double.tryParse(promptData) ?? 0.0;
                  } else if (promptData is Map && promptData['unit'] != null) {
                    // Fallback for nested structure
                    final promptPriceRaw = promptData['unit'];
                    promptPrice = promptPriceRaw is num
                        ? promptPriceRaw.toDouble()
                        : double.tryParse(promptPriceRaw?.toString() ?? '0') ?? 0.0;
                  }

                  if (completionData is num) {
                    completionPrice = completionData.toDouble();
                  } else if (completionData is String) {
                    completionPrice = double.tryParse(completionData) ?? 0.0;
                  } else if (completionData is Map && completionData['unit'] != null) {
                    // Fallback for nested structure
                    final completionPriceRaw = completionData['unit'];
                    completionPrice = completionPriceRaw is num
                        ? completionPriceRaw.toDouble()
                        : double.tryParse(completionPriceRaw?.toString() ?? '0') ?? 0.0;
                  }
                }
              }

              _modelPricing[modelId] = {
                'input': (promptPrice * 1000000).toDouble(), // Convert per-token to per-million tokens
                'output': (completionPrice * 1000000).toDouble(),
              };

            } else {
              // No pricing data available
              _modelPricing[modelId] = {
                'input': 0.0,
                'output': 0.0,
              };
            }

            // Build full model data for UI
            final modelData = {
              'id': modelId,
              'name': _formatModelName(modelId),
              'description': model['description'] ?? _getModelDescription(modelId),
              'context_length': model['context_length'] ?? _getModelContextLength(modelId),
              'pricing': _modelPricing[modelId]!,
              'top_provider': _getModelProvider(modelId),
              'per_request_limits': model['per_request_limits'] ?? {},
              'architecture': model['architecture'] ?? {},
            };

                _cachedModelData.add(modelData);
              } catch (e) {
                print('🤖 Error processing model ${model['id'] ?? 'unknown'}: $e');
                // Continue processing other models
                continue;
              }
            }

            _lastModelsFetch = DateTime.now();

            print('🤖 Fetched ${_availableModels.length} models from OpenRouter');

            return {
              'success': true,
              'data': _cachedModelData,
              'models': _availableModels,
              'pricing': _modelPricing,
              'cached': false,
            };
          } else {
            throw Exception('Failed to fetch models: ${response.statusCode}');
          }
        },
      );

    } catch (e) {
      print('🤖 Failed to fetch models from OpenRouter: $e');

      // Return fallback models
      _availableModels = [defaultModel, fallbackModel];
      _modelPricing = {
        defaultModel: {'input': 0.0, 'output': 0.0},
        fallbackModel: {'input': 0.0, 'output': 0.0},
      };

      return {
        'success': false,
        'models': _availableModels,
        'pricing': _modelPricing,
        'cached': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://cognify.app',
        'X-Title': 'Cognify Flutter App',
      },
    ));

    _initialized = true;
    print('🤖 OpenRouterClient initialized');
  }


  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Retry wrapper for API calls with 401 error handling
  Future<T> _retryOn401<T>({
    required Future<T> Function() apiCall,
    required BuildContext? context,
  }) async {
    int attemptCount = 0;
    
    while (attemptCount < _maxRetries) {
      try {
        // Make the API call
        final result = await apiCall();
        
        // Success! Reset the error counter
        if (_consecutive401Errors > 0) {
          print('✅ API call succeeded, resetting 401 error counter');
          _consecutive401Errors = 0;
        }
        _lastSuccessfulCall = DateTime.now();
        
        return result;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          attemptCount++;
          _consecutive401Errors++;
          
          print('🔄 401 Error (attempt $attemptCount/$_maxRetries, total consecutive: $_consecutive401Errors)');
          
          if (attemptCount < _maxRetries) {
            // Still have retries left, wait with exponential backoff
            final delayMs = 500 * attemptCount; // 500ms, 1000ms, 1500ms
            print('⏳ Waiting ${delayMs}ms before retry...');
            await Future.delayed(Duration(milliseconds: delayMs));
            continue; // Retry
          } else {
            // Out of retries for this call
            print('❌ 401 Error persisted after $_maxRetries attempts');
            
            // Don't auto-clear the key, instead show popup for user to reconfigure
            print('⚠️ 401 error - prompting user to reconfigure OpenRouter');
            _show401ErrorDialog(context);
            rethrow;
          }
        } else {
          // Not a 401 error, reset the 401 counter and rethrow
          if (_consecutive401Errors > 0) {
            print('📊 Non-401 error occurred, resetting 401 counter');
            _consecutive401Errors = 0;
          }
          rethrow;
        }
      } catch (e) {
        // Non-DioException error, reset counter
        if (_consecutive401Errors > 0) {
          print('📊 Non-network error occurred, resetting 401 counter');
          _consecutive401Errors = 0;
        }
        rethrow;
      }
    }
    
    throw Exception('Retry logic failed - should not reach here');
  }

  /// Format model name from ID
  String _formatModelName(String modelId) {
    if (modelId.contains('/')) {
      return modelId.split('/').last.replaceAll(':free', '');
    }
    return modelId;
  }

  /// Get model context length
  int _getModelContextLength(String modelId) {
    // Estimate context length based on model patterns
    if (modelId.contains('gemini-2.0') || modelId.contains('flash')) {
      return 1000000; // 1M tokens
    } else if (modelId.contains('r1') || modelId.contains('reasoning')) {
      return 128000; // 128K tokens
    } else if (modelId.contains('claude') || modelId.contains('gpt-4')) {
      return 200000; // 200K tokens
    }
    return 4096; // Default 4K tokens
  }

  /// Get model description
  String _getModelDescription(String modelId) {
    // Simple description based on model ID patterns
    if (modelId.contains('deepseek')) {
      return 'DeepSeek AI model for reasoning and chat';
    } else if (modelId.contains('gemini')) {
      return 'Google Gemini multimodal AI model';
    } else if (modelId.contains('claude')) {
      return 'Anthropic Claude AI assistant';
    } else if (modelId.contains('gpt')) {
      return 'OpenAI GPT language model';
    }
    return 'AI language model';
  }

  /// Get model provider
  Map<String, dynamic> _getModelProvider(String modelId) {
    final parts = modelId.split('/');
    final provider = parts.isNotEmpty ? parts[0] : 'unknown';

    return {
      'name': provider,
      'human_name': provider,
    };
  }

  /// Show dialog for 401 errors prompting user to reconfigure OpenRouter
  void _show401ErrorDialog(BuildContext? context) {
    if (context == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('OpenRouter Authorization Error'),
          ],
        ),
        content: const Text(
          'We\'ve been receiving unauthorized errors from OpenRouter. This usually means:\n\n'
          '• Your API key has expired or been revoked\n'
          '• Your account credits have been exhausted\n'
          '• The key was deactivated externally\n\n'
          'Please reconfigure your OpenRouter API key to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to onboarding to reconfigure
              try {
                final router = GoRouter.of(context);
                router.go('/oauth-onboarding');
              } catch (e) {
                print('❌ Error navigating to onboarding: $e');
                // Fallback navigation
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/oauth-onboarding',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reconfigure OpenRouter'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for 429 rate limit errors suggesting model switch
  void _show429ErrorDialog(BuildContext? context) {
    if (context == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Rate Limited'),
          ],
        ),
        content: const Text(
          'The current model is being rate limited by OpenRouter. This usually happens when:\n\n'
          '• The model is experiencing high demand\n'
          '• You\'ve exceeded the request quota for this model\n'
          '• The provider has temporary restrictions\n\n'
          'Try switching to a different model or wait a few minutes before retrying.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Try Again Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // User can manually switch model using the model selector in the UI
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Use the model selector at the bottom to switch models'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Switch Model'),
          ),
        ],
      ),
    );
  }

  /// Handle HTTP errors and navigate/show appropriate messages
  /// Note: 401 errors are now handled by _retryOn401 wrapper
  void _handleHttpError(DioException error, BuildContext? context) {
    if (error.response?.statusCode == 429) {
      _show429ErrorDialog(context);
    }
    // 401 errors are handled by the retry logic
  }

}
