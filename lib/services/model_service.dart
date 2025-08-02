import '../models/file_attachment.dart';
import '../models/mode_config.dart';
import 'openrouter_client.dart';

/// Service for managing AI models using direct OpenRouter API integration
/// No longer depends on backend server - uses OpenRouter directly
class ModelService {
  // OpenRouter client for direct API access
  static final OpenRouterClient _openRouterClient = OpenRouterClient();
  
  // Cache for models to avoid repeated API calls
  static Map<String, dynamic>? _cachedModels;
  static DateTime? _cacheTimestamp;
  static const Duration cacheExpiry = Duration(minutes: 30);

  // Enhanced cache for OpenRouter models
  static Map<String, dynamic>? _cachedEnhancedModels;
  static DateTime? _enhancedCacheTimestamp;

  /// Clear cache (useful for testing or manual refresh)
  static void clearCache() {
    _cachedModels = null;
    _cacheTimestamp = null;
    _cachedEnhancedModels = null;
    _enhancedCacheTimestamp = null;
  }

  /// Clear OpenRouter models cache
  static Future<void> clearOpenRouterCache() async {
    try {
      // Clear local cache
      clearCache();
      print('✅ OpenRouter models cache cleared successfully');
    } catch (e) {
      print('❌ Error clearing OpenRouter cache: $e');
    }
  }

  /// Get available models (simple list)
  static Future<List<String>> getAvailableModels() async {
    try {
      await _openRouterClient.initialize();
      final modelsResponse = await _openRouterClient.getModels();

      // The getModels() method returns models as List<String> directly
      final models = modelsResponse['models'] as List<String>?;
      if (models != null) {
        return models;
      } else {
        throw Exception('Failed to fetch models: ${modelsResponse['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ Error fetching available models: $e');
      return _getFallbackModels();
    }
  }

  /// Get models with enhanced information
  static Future<Map<String, dynamic>> getEnhancedModels() async {
    // Check cache first
    if (_cachedEnhancedModels != null && 
        _enhancedCacheTimestamp != null &&
        DateTime.now().difference(_enhancedCacheTimestamp!) < cacheExpiry) {
      return _cachedEnhancedModels!;
    }

    try {
      await _openRouterClient.initialize();
      final modelsResponse = await _openRouterClient.getModels();

      // Check if the response has the new data structure with full model objects
      if (modelsResponse['success'] == true && modelsResponse['data'] != null) {
        // New format: full model data is already available
        final enhancedData = {
          'success': true,
          'data': modelsResponse['data'],
        };

        _cachedEnhancedModels = enhancedData;
        _enhancedCacheTimestamp = DateTime.now();
        return enhancedData;
      } else {
        // Fallback to old format for backward compatibility
        final models = modelsResponse['models'] as List<String>?;
        final pricing = modelsResponse['pricing'] as Map<String, Map<String, double>>?;

        if (models != null) {
          // Transform to enhanced format using available model IDs
          final enhancedData = {
            'success': true,
            'data': models.map((modelId) => {
              'id': modelId,
              'name': _formatModelName(modelId),
              'description': _getModelDescription(modelId),
              'context_length': _getModelContextLength(modelId),
              'pricing': pricing?[modelId] ?? {},
              'top_provider': _getModelProvider(modelId),
              'per_request_limits': {},
            }).toList(),
          };

          _cachedEnhancedModels = enhancedData;
          _enhancedCacheTimestamp = DateTime.now();
          return enhancedData;
        } else {
          throw Exception('Failed to fetch models: ${modelsResponse['error'] ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      print('❌ Error fetching enhanced models: $e');
      return await getModels();
    }
  }

  /// Get enhanced models by mode (alias for getModelsByMode)
  static Future<Map<String, dynamic>> getEnhancedModelsByMode(ChatMode mode) async {
    return await getModelsByMode(mode);
  }

  /// Get free models only
  static Future<List<String>> getFreeModels() async {
    try {
      await _openRouterClient.initialize();
      final modelsResponse = await _openRouterClient.getModels();
      
      if (modelsResponse['success'] == true) {
        final models = modelsResponse['models'] as List;
        
        // Filter for free models (those with :free suffix or zero pricing)
        final freeModels = models.where((model) {
          final id = model['id'] as String;
          final pricing = model['pricing'] as Map<String, dynamic>?;
          
          // Check if model ID contains :free
          if (id.contains(':free')) return true;
          
          // Check if pricing is zero or null
          if (pricing != null) {
            final prompt = pricing['prompt'];
            final completion = pricing['completion'];
            if (prompt == '0' || completion == '0') return true;
          }
          
          return false;
        }).toList();
        
        return freeModels.map((model) => model['id'] as String).toList();
      } else {
        throw Exception('Failed to fetch free models: ${modelsResponse['error']}');
      }
    } catch (e) {
      print('❌ Error fetching free models: $e');
      return _getFallbackFreeModels();
    }
  }

  /// Get model capabilities
  static Future<ModelCapabilities> getModelCapabilities(String modelId) async {
    try {
      print('🔍 ModelService: Getting capabilities for model: $modelId');
      await _openRouterClient.initialize();
      final modelsResponse = await _openRouterClient.getModels();
      
      if (modelsResponse['success'] == true) {
        final models = modelsResponse['data'] as List?;
        if (models != null) {
          print('🔍 ModelService: Found ${models.length} models');
          // Debug: Print first few model IDs to see what's available
          if (models.isNotEmpty) {
            print('🔍 ModelService: First 5 model IDs: ${models.take(5).map((m) => m['id']).toList()}');
          }
          // Try exact match first
          var model = models.cast<Map<String, dynamic>>().firstWhere(
            (m) => m['id'] == modelId,
            orElse: () => <String, dynamic>{},
          );
          
          // If not found, try matching without the :free suffix
          if (model.isEmpty && modelId.contains(':free')) {
            final baseModelId = modelId.replaceAll(':free', '');
            print('🔍 ModelService: Trying base model ID: $baseModelId');
            model = models.cast<Map<String, dynamic>>().firstWhere(
              (m) => m['id'] == baseModelId,
              orElse: () => <String, dynamic>{},
            );
          }
          
          // If still not found, try partial matching
          if (model.isEmpty) {
            print('🔍 ModelService: Trying partial match for: $modelId');
            model = models.cast<Map<String, dynamic>>().firstWhere(
              (m) => m['id'].toString().contains(modelId.split('/').last),
              orElse: () => <String, dynamic>{},
            );
          }

          if (model.isNotEmpty) {
            print('🔍 ModelService: Found model data: ${model.keys}');
            final supportsImages = _modelSupportsImages(model);
            final supportsFiles = _modelSupportsFiles(model);
            print('🔍 ModelService: Final capabilities - supportsImages: $supportsImages, supportsFiles: $supportsFiles');
            return ModelCapabilities(
              inputModalities: supportsImages ? ['text', 'image'] : ['text'],
              outputModalities: ['text'],
              supportsImages: supportsImages,
              supportsFiles: supportsFiles,
              isMultimodal: supportsImages || supportsFiles,
              contextLength: model['context_length'] ?? 4096,
              maxCompletionTokens: model['context_length'] ?? 4096,
            );
          } else {
            print('🔍 ModelService: Model not found in API response');
          }
        }
      }

      // Return default capabilities if model not found
      return const ModelCapabilities(
        inputModalities: ['text'],
        outputModalities: ['text'],
        supportsImages: false,
        supportsFiles: false,
        isMultimodal: false,
        contextLength: 4096,
        maxCompletionTokens: 4096,
      );
    } catch (e) {
      print('❌ Error fetching model capabilities: $e');
      return const ModelCapabilities(
        inputModalities: ['text'],
        outputModalities: ['text'],
        supportsImages: false,
        supportsFiles: false,
        isMultimodal: false,
        contextLength: 4096,
        maxCompletionTokens: 4096,
      );
    }
  }

  /// Get basic models list (cached)
  static Future<Map<String, dynamic>> getModels() async {
    // Check cache first
    if (_cachedModels != null && 
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < cacheExpiry) {
      return _cachedModels!;
    }

    try {
      await _openRouterClient.initialize();
      final modelsResponse = await _openRouterClient.getModels();
      
      if (modelsResponse['success'] == true) {
        final models = modelsResponse['models'] as List;
        
        final basicData = {
          'success': true,
          'data': models.map((model) => model['id']).toList(),
        };
        
        _cachedModels = basicData;
        _cacheTimestamp = DateTime.now();
        return basicData;
      } else {
        throw Exception('Failed to fetch models: ${modelsResponse['error']}');
      }
    } catch (e) {
      print('❌ Error fetching models: $e');
      return {
        'success': true,
        'data': _getFallbackModels(),
      };
    }
  }

  /// Get models for specific mode
  static Future<Map<String, dynamic>> getModelsByMode(ChatMode mode) async {
    try {
      print('🔄 ModelService: Getting models for mode: $mode');
      final allModels = await getEnhancedModels();

      if (allModels['success'] == true) {
        final models = allModels['data'] as List;
        print('✅ ModelService: Found ${models.length} models from enhanced models');

        // Filter models based on mode (for now, return all)
        // In the future, we could filter based on model capabilities
        final result = {
          'success': true,
          'data': models,
        };
        print('📦 ModelService: Returning ${models.length} models for mode $mode');
        return result;
      } else {
        throw Exception('Failed to fetch models for mode');
      }
    } catch (e) {
      print('❌ ModelService: Error fetching models for mode: $e');
      return _getFallbackModelsForMode(mode);
    }
  }

  /// Initialize the service
  static Future<void> initialize() async {
    await _openRouterClient.initialize();
  }

  /// Format model name from ID
  static String _formatModelName(String modelId) {
    if (modelId.contains('/')) {
      return modelId.split('/').last.replaceAll(':free', '');
    }
    return modelId;
  }

  /// Fallback free models
  static List<String> _getFallbackFreeModels() {
    return [
      'deepseek/deepseek-chat:free',
      'deepseek/deepseek-r1:free',
      'google/gemini-2.0-flash-exp:free',
      'mistralai/mistral-7b-instruct:free',
    ];
  }

  /// Fallback models when API fails
  static List<String> _getFallbackModels() {
    return [
      'deepseek/deepseek-chat:free',
      'deepseek/deepseek-r1:free',
      'google/gemini-2.0-flash-exp:free',
      'mistralai/mistral-7b-instruct:free',
      'google/gemini-flash-1.5',
      'openai/gpt-4o-mini',
      'anthropic/claude-3-haiku',
    ];
  }

  /// Fallback models for specific mode
  static Map<String, dynamic> _getFallbackModelsForMode(ChatMode mode) {
    final models = _getFallbackModels();
    return {
      'success': true,
      'data': models.map((id) => {
        'id': id,
        'name': id.split('/').last,
        'description': 'Fallback model',
      }).toList(),
    };
  }

  /// Get model context length
  static int _getModelContextLength(String modelId) {
    // Estimate context length based on model patterns
    if (modelId.contains('gemini-2.0') || modelId.contains('flash')) {
      return 1000000; // 1M tokens
    } else if (modelId.contains('r1') || modelId.contains('reasoning')) {
      return 128000; // 128K tokens
    } else if (modelId.contains('gpt-4')) {
      return 128000; // 128K tokens
    } else if (modelId.contains('claude')) {
      return 200000; // 200K tokens
    }
    return 4096; // Default 4K tokens
  }

  /// Get model description
  static String _getModelDescription(String modelId) {
    // Simple description based on model ID patterns
    if (modelId.contains('deepseek')) {
      return 'DeepSeek AI model for reasoning and chat';
    } else if (modelId.contains('gemini')) {
      return 'Google Gemini multimodal AI model';
    } else if (modelId.contains('gpt')) {
      return 'OpenAI GPT model for chat and reasoning';
    } else if (modelId.contains('claude')) {
      return 'Anthropic Claude AI assistant';
    } else if (modelId.contains('mistral')) {
      return 'Mistral AI language model';
    }
    return 'AI language model';
  }

  /// Get model provider
  static Map<String, dynamic> _getModelProvider(String modelId) {
    final parts = modelId.split('/');
    final provider = parts.isNotEmpty ? parts[0] : 'unknown';

    return {
      'name': provider,
      'id': provider,
    };
  }

  /// Check if model supports files
  static bool _modelSupportsFiles(Map<String, dynamic> model) {
    final id = model['id'] as String;
    print('🔍 Checking file support for model: $id');

    // Check input modalities from the model data first
    final inputModalities = model['input_modalities'] as List<dynamic>? ?? 
                           model['inputModalities'] as List<dynamic>? ?? 
                           model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
    
    if (inputModalities.isNotEmpty) {
      final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
      final supportsFiles = modalities.contains('file');
      print('🔍 Model has input modalities: $modalities, supportsFiles: $supportsFiles');
      return supportsFiles;
    }

    // Fallback: For now, assume models that support images also support files
    final supportsFiles = _modelSupportsImages(model);
    print('🔍 Fallback check for model $id: supportsFiles=$supportsFiles');
    return supportsFiles;
  }

  /// Check if model supports images
  static bool _modelSupportsImages(Map<String, dynamic> model) {
    final id = model['id'] as String;
    print('🔍 Checking image support for model: $id');

    // Check input modalities from the model data first
    final inputModalities = model['input_modalities'] as List<dynamic>? ?? 
                           model['inputModalities'] as List<dynamic>? ?? 
                           model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
    
    if (inputModalities.isNotEmpty) {
      final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
      final supportsImages = modalities.contains('image');
      print('🔍 Model has input modalities: $modalities, supportsImages: $supportsImages');
      return supportsImages;
    }

    // Fallback: Check against known multimodal models
    final multimodalModels = [
      'google/gemini-flash-1.5',
      'google/gemini-pro-vision',
      'google/gemini-2.0-flash-exp',
      'google/gemini-2.0-flash-exp:free',
      'openai/gpt-4o',
      'openai/gpt-4o-mini',
      'anthropic/claude-3-opus',
      'anthropic/claude-3-sonnet',
      'anthropic/claude-3-haiku',
    ];

    final supportsImages = multimodalModels.any((pattern) => id.contains(pattern.split('/').last));
    print('🔍 Fallback check for model $id: supportsImages=$supportsImages');
    return supportsImages;
  }
}


