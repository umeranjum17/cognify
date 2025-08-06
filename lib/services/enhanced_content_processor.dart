import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/message.dart';
import '../utils/logger.dart';
import 'llm_service.dart';
import 'openrouter_client.dart';
import 'trending_service.dart';

/// Enhanced content processor that uses direct API calls instead of backend server
/// No longer depends on localhost backend - uses OpenRouter and other direct APIs
class EnhancedContentProcessor {
  final LLMService _llmService = LLMService();
  final OpenRouterClient _openRouterClient = OpenRouterClient();
  final TrendingService _trendingService = TrendingService();
  bool _initialized = false;

  /// Enhanced chat completions with plugins (now uses direct LLM service)
  Future<Map<String, dynamic>> chatCompletionsWithPlugins({
    required String model,
    required List<Message> messages,
    Map<String, bool>? enabledTools,
    List<File>? attachments,
    bool? processAttachments,
    FormData? formData,
  }) async {
    await _ensureInitialized();
    
    try {
      Logger.info('🤖 EnhancedContentProcessor: Chat completions with plugins', tag: 'ContentProcessor');
      
      // Convert messages to OpenRouter format
      final openRouterMessages = messages.map((msg) => {
        'role': msg.role,
        'content': msg.content,
      }).toList();
      
      // Use direct LLM service
      final response = await _llmService.chatCompletion(
        model: model,
        messages: openRouterMessages,
        temperature: 0.7,
        maxTokens: 2000,
      );
      
      Logger.info('✅ EnhancedContentProcessor: Chat completion response received', tag: 'ContentProcessor');
      return response;
    } catch (error) {
      Logger.error('❌ EnhancedContentProcessor: Chat completions error: $error', tag: 'ContentProcessor');
      return {
        'error': error.toString(),
        'choices': [],
      };
    }
  }

  /// Check if services are available (checks API keys)
  Future<bool> checkServerHealth() async {
    await _ensureInitialized();
    
    try {
      // Check if OpenRouter API key is configured
      final apiKey = await AppConfig().openRouterApiKey;
      return apiKey != null && apiKey.isNotEmpty;
    } catch (error) {
      Logger.error('❌ Service health check failed: $error', tag: 'ContentProcessor');
      return false;
    }
  }

  /// Extract keywords from text using LLM
  Future<List<String>> extractKeywords(String text) async {
    await _ensureInitialized();
    
    try {
      final prompt = '''Extract 5-10 key terms and concepts from the following text. Return only the keywords, one per line, without numbering or formatting:

Text: ${text.length > 1000 ? text.substring(0, 1000) : text}

Keywords:''';

      final response = await _llmService.chatCompletion(
        model: 'mistralai/mistral-7b-instruct:free',
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        temperature: 0.3,
        maxTokens: 200,
      );

      final content = response['choices']?[0]?['message']?['content'] ?? '';
      final keywords = content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim())
          .toList();

      return keywords.take(10).toList();
    } catch (error) {
      Logger.error('❌ Failed to extract keywords: $error', tag: 'ContentProcessor');
      // Return simple fallback keywords
      return _extractSimpleKeywords(text);
    }
  }

  /// Utility method to extract YouTube video ID
  String? extractYouTubeVideoId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/.*[?&]v=([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Fetch trending topics (alias for getTrendingTopics)
  Future<Map<String, dynamic>> fetchTrendingTopics({bool forceRefresh = false}) async {
    return await getTrendingTopics();
  }

  /// Generate dynamic prompt using LLM
  Future<Map<String, dynamic>> generateDynamicPrompt(String topic) async {
    await _ensureInitialized();
    
    try {
      final prompt = '''Generate a comprehensive research prompt for the topic: "$topic"

Create a detailed prompt that would help someone research this topic thoroughly. Include:
1. Key questions to explore
2. Important aspects to consider
3. Potential subtopics to investigate

Format your response as a clear, actionable research prompt.''';

      final response = await _llmService.chatCompletion(
        model: 'mistralai/mistral-7b-instruct:free',
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        temperature: 0.7,
        maxTokens: 500,
      );

      final content = response['choices']?[0]?['message']?['content'] ?? '';
      
      return {
        'success': true,
        'prompt': content,
        'topic': topic,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      Logger.error('❌ Failed to generate dynamic prompt: $error', tag: 'ContentProcessor');
      return {
        'success': false,
        'error': error.toString(),
        'prompt': 'Research and analyze the topic: $topic',
        'topic': topic,
      };
    }
  }

  /// Get available models using OpenRouter
  Future<List<String>> getAvailableModels() async {
    await _ensureInitialized();
    
    try {
      final modelsResponse = await _openRouterClient.getModels();
      
      if (modelsResponse['success'] == true) {
        final models = modelsResponse['models'] as List;
        return models.map((model) => model['id'] as String).toList();
      } else {
        throw Exception('Failed to fetch models: ${modelsResponse['error']}');
      }
    } catch (error) {
      Logger.error('❌ Failed to get available models: $error', tag: 'ContentProcessor');
      return [
        'mistralai/mistral-7b-instruct:free',
        'deepseek/deepseek-chat:free',
        'deepseek/deepseek-chat-v3-0324:free',
        'deepseek/deepseek-r1:free',
        'google/gemini-2.0-flash-exp:free',
        'google/gemini-flash-1.5',
        'anthropic/claude-3-haiku',
        'openai/gpt-4o-mini',
      ];
    }
  }

  /// Get model pricing using OpenRouter
  Future<Map<String, Map<String, double>>> getModelsPricing() async {
    await _ensureInitialized();
    
    try {
      final modelsResponse = await _openRouterClient.getModels();

      // The getModels() method returns models as List<String> and pricing as Map
      final models = modelsResponse['models'] as List<String>?;
      final modelPricing = modelsResponse['pricing'] as Map<String, Map<String, double>>?;

      if (models != null && modelPricing != null) {
        final pricing = <String, Map<String, double>>{};

        for (final modelId in models) {
          final pricingData = modelPricing[modelId];
          if (pricingData != null) {
            pricing[modelId] = {
              'prompt': pricingData['input'] ?? 0.0,
              'completion': pricingData['output'] ?? 0.0,
            };
          }
        }

        return pricing;
      } else {
        throw Exception('Failed to fetch pricing: Invalid response structure');
      }
    } catch (error) {
      Logger.error('❌ Failed to get model pricing: $error', tag: 'ContentProcessor');
      return {}; // Return empty map on error
    }
  }

  /// Get service configuration (no longer server-dependent)
  Future<Map<String, dynamic>> getServerConfig() async {
    await _ensureInitialized();
    
    try {
      // Return mock configuration since we no longer use a server
      return {
        'success': true,
        'config': {
          'version': '2.0.0',
          'mode': 'standalone',
          'features': {
            'chat': true,
            'search': true,
            'image_generation': true,
            'file_upload': true,
          },
          'models': await getAvailableModels(),
          'pricing': await getModelsPricing(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      Logger.error('❌ Failed to get service config: $error', tag: 'ContentProcessor');
      return {
        'success': false,
        'error': error.toString(),
        'config': {
          'version': '2.0.0',
          'mode': 'standalone',
          'features': {
            'chat': true,
            'search': false,
            'image_generation': false,
            'file_upload': false,
          },
        },
      };
    }
  }

  /// Get trending topics using the new service
  Future<Map<String, dynamic>> getTrendingTopics() async {
    await _ensureInitialized();

    try {
      final topics = await _trendingService.getTrendingTopics();
      return {
        'success': true,
        'topics': topics.map((topic) => topic.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      Logger.error('❌ Error fetching trending topics: $e', tag: 'ContentProcessor');
      return {
        'success': false,
        'topics': [],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Initialize the processor
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _llmService.initialize();
    await _openRouterClient.initialize();
    _initialized = true;
    Logger.info('🚀 EnhancedContentProcessor initialized with direct APIs', tag: 'ContentProcessor');
  }

  /// Enhanced text rewriting using LLM
  Future<String> rewriteText(String text) async {
    await _ensureInitialized();
    
    try {
      final prompt = '''Rewrite the following text to make it clearer, more engaging, and better structured while preserving the original meaning:

Original text:
${text.length > 2000 ? text.substring(0, 2000) : text}

Rewritten text:''';

      final response = await _llmService.chatCompletion(
        model: 'mistralai/mistral-7b-instruct:free',
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        temperature: 0.7,
        maxTokens: 1000,
      );

      final content = response['choices']?[0]?['message']?['content'] ?? '';
      return content.isNotEmpty ? content : text;
    } catch (error) {
      Logger.error('❌ Failed to rewrite text: $error', tag: 'ContentProcessor');
      return text; // Return original text on failure
    }
  }

  /// Source-grounded chat (simplified implementation)
  Future<Map<String, dynamic>> sourceGroundedChat({
    required String model,
    required List<Message> messages,
    Map<String, bool>? enabledTools,
    List<File>? attachments,
    bool? processAttachments,
    FormData? formData,
    List<String>? sourceIds,
  }) async {
    await _ensureInitialized();
    
    try {
      Logger.info('🤖 EnhancedContentProcessor: Source-grounded chat completions', tag: 'ContentProcessor');
      
      // Convert messages to OpenRouter format
      final openRouterMessages = messages.map((msg) => {
        'role': msg.role,
        'content': msg.content,
      }).toList();
      
      // Use direct LLM service
      final response = await _llmService.chatCompletion(
        model: model,
        messages: openRouterMessages,
        temperature: 0.7,
        maxTokens: 2000,
      );
      
      Logger.info('✅ EnhancedContentProcessor: Source-grounded chat completion response received', tag: 'ContentProcessor');
      return response;
    } catch (error) {
      Logger.error('❌ EnhancedContentProcessor: Source-grounded chat error: $error', tag: 'ContentProcessor');
      return {
        'error': error.toString(),
        'choices': [],
      };
    }
  }

  /// Update feature flags (mock implementation)
  Future<Map<String, dynamic>> updateFeatureFlags({
    Map<String, bool>? plugins,
    Map<String, String>? routing,
  }) async {
    await _ensureInitialized();
    
    try {
      // Return mock success since we don't have a server
      return {
        'success': true,
        'message': 'Feature flags updated successfully',
        'plugins': plugins ?? {},
        'routing': routing ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      Logger.error('❌ Failed to update feature flags: $error', tag: 'ContentProcessor');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Simple keyword extraction fallback
  List<String> _extractSimpleKeywords(String text) {
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    final commonWords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'can', 'this', 'that', 'these', 'those'};
    
    final keywords = words
        .where((word) => word.length > 3 && !commonWords.contains(word))
        .toSet()
        .take(10)
        .toList();
    
    return keywords;
  }
}
