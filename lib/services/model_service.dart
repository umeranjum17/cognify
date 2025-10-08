import '../models/mode_config.dart';
import '../models/file_attachment.dart';
import '../config/model_registry.dart';
import 'mode_api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

/// Service for managing AI models via backend
class ModelService {
  // Use backend mode API; eliminate direct OpenRouter client from frontend
  static final ModeApiService _modeApi = ModeApiService.instance;
  
  // Cache for models to avoid repeated API calls
  static Map<String, dynamic>? _cachedModels;
  static DateTime? _cacheTimestamp;
  static const Duration cacheExpiry = Duration(minutes: 30);

  // Enhanced cache for models
  static Map<String, dynamic>? _cachedEnhancedModels;
  static DateTime? _enhancedCacheTimestamp;

  /// Clear cache (useful for testing or manual refresh)
  static void clearCache() {
    _cachedModels = null;
    _cacheTimestamp = null;
    _cachedEnhancedModels = null;
    _enhancedCacheTimestamp = null;
  }

  /// Get available models (simple list)
  static Future<List<String>> getAvailableModels() async {
    try {
      final byMode = await _modeApi.getAvailableModelsForMode(ChatMode.chat);
      if (byMode.isNotEmpty) return byMode;
    } catch (e) {
      print('❌ Error fetching available models from backend: $e');
    }
    return _getFallbackModels();
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
      final models = await _modeApi.getAvailableModelsForMode(ChatMode.chat);
      final enhancedData = {
        'success': true,
        'data': models.map((modelId) => {
          'id': modelId,
          'name': _formatModelName(modelId),
          'description': _getModelDescription(modelId),
          'context_length': _getModelContextLength(modelId),
          'pricing': {},
          'top_provider': _getModelProvider(modelId),
          'per_request_limits': {},
        }).toList(),
      };
      _cachedEnhancedModels = enhancedData;
      _enhancedCacheTimestamp = DateTime.now();
      return enhancedData;
    } catch (e) {
      print('❌ Error fetching enhanced models: $e');
      return await getModels();
    }
  }

  /// Get enhanced models by mode (alias for getModelsByMode)
  static Future<Map<String, dynamic>> getEnhancedModelsByMode(ChatMode mode) async {
    return await getModelsByMode(mode);
  }

  /// Get full model data including pricing from backend (not yet provided)
  static Future<Map<String, dynamic>?> getModelData(String modelId) async {
    // Defer to enhanced models cache for now
    final enhanced = await getEnhancedModels();
    final list = (enhanced['data'] as List).cast<Map<String, dynamic>>();
    return list.firstWhere((m) => m['id'] == modelId, orElse: () => <String, dynamic>{});
  }

  /// Get model capabilities
  static Future<ModelCapabilities> getModelCapabilities(String modelId) async {
    try {
      final model = await getModelData(modelId) ?? {};
      final supportsImages = _modelSupportsImages(model);
      final supportsFiles = _modelSupportsFiles(model);
      return ModelCapabilities(
        inputModalities: supportsImages ? ['text', 'image'] : ['text'],
        outputModalities: ['text'],
        supportsImages: supportsImages,
        supportsFiles: supportsFiles,
        isMultimodal: supportsImages || supportsFiles,
        contextLength: model['context_length'] ?? 4096,
        maxCompletionTokens: model['context_length'] ?? 4096,
        pricing: model['pricing'] as Map<String, dynamic>?,
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
      final list = await getAvailableModels();
      final basicData = {
        'success': true,
        'data': list,
      };
      _cachedModels = basicData;
      _cacheTimestamp = DateTime.now();
      return basicData;
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
      // Load models config from backend
      Map<String, dynamic>? modelsConfig = await _modeApi.loadModelsConfig();
      // Hard fallback: direct HTTP call if Dio path failed for any reason
      if (modelsConfig == null) {
        try {
          final url = Uri.parse('${AppConfig.backendBaseUrl}/api/config/models');
          final resp = await http.get(url);
          if (resp.statusCode == 200) {
            final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
            final raw = decoded['data'];
            if (raw is Map) {
              modelsConfig = Map<String, dynamic>.from(raw);
            }
          }
        } catch (_) {}
      }
      List<String> ids = await _modeApi.getAvailableModelsForMode(mode);
      if (modelsConfig != null) {
        final dynamic pricingDyn = modelsConfig['pricing'];
        final dynamic capsDyn = modelsConfig['capabilities'];
        final dynamic quotaPricingDyn = modelsConfig['quotaPricing'];
        final Map<String, dynamic> pricing =
            pricingDyn is Map ? Map<String, dynamic>.from(pricingDyn) : {};
        final Map<String, dynamic> capabilities =
            capsDyn is Map ? Map<String, dynamic>.from(capsDyn) : {};
        final Map<String, dynamic> quotaPricing =
            quotaPricingDyn is Map ? Map<String, dynamic>.from(quotaPricingDyn) : {};

        // Extract pre-calculated request estimates
        final Map<String, dynamic> perRequestSampleChat =
            quotaPricing['perRequestSample']?['chat'] is Map
              ? Map<String, dynamic>.from(quotaPricing['perRequestSample']['chat'])
              : {};

        // If mode has no explicit ids, use all available → else derive from capabilities keys
        if (ids.isEmpty) {
          final availDyn = modelsConfig['available'];
          if (availDyn is List) {
            ids = availDyn.whereType<String>().toList();
          }
          if (ids.isEmpty && capabilities.isNotEmpty) {
            ids = capabilities.keys.whereType<String>().toList();
          }
        }
        final models = ids.map((id) {
          final cap = capabilities[id];
          final price = pricing[id];
          final requestEstimate = perRequestSampleChat[id];
          Map<String, dynamic> safeCap = cap is Map ? Map<String, dynamic>.from(cap) : {};
          Map<String, dynamic> safePrice = price is Map ? Map<String, dynamic>.from(price) : {};
          Map<String, dynamic> safeEstimate = requestEstimate is Map ? Map<String, dynamic>.from(requestEstimate) : {};

          // Determine free status only when pricing is explicitly provided and both input and output are zero
          final bool explicitlyFree = safePrice.containsKey('input') &&
              safePrice.containsKey('output') &&
              ((safePrice['input'] ?? 0.0) == 0.0) &&
              ((safePrice['output'] ?? 0.0) == 0.0);
          return {
          'id': id,
          'name': _formatModelName(id),
          'description': safeCap['description'] ?? _getModelDescription(id),
          'pricing': safePrice,
          'requestEstimate': safeEstimate, // Pre-calculated request cost
          'provider': (safeCap['provider']) ?? id.split('/').first,
          'isFree': explicitlyFree,
          'context_length': safeCap['maxTokens'] ?? 8192,
          'inputModalities': safeCap['inputModalities'] ?? ['text'],
          'outputModalities': safeCap['outputModalities'] ?? ['text'],
        };
        }).toList();
        return {'success': true, 'data': models};
      }

      // Fallback if config not available
      ids = ids.isEmpty ? _getFallbackModels() : ids;
      final models = ids.map((id) => {
        'id': id,
        'name': _formatModelName(id),
        'description': _getModelDescription(id),
      }).toList();
      return {'success': true, 'data': models};
    } catch (e) {
      print('❌ ModelService: Error fetching models for mode: $e');
      return _getFallbackModelsForMode(mode);
    }
  }

  /// Initialize the service
  static Future<void> initialize() async {}

  /// Format model name from ID
  static String _formatModelName(String modelId) {
    if (modelId.contains('/')) {
      return modelId.split('/').last.replaceAll(':free', '');
    }
    return modelId;
  }

  /// Fallback free models
  static List<String> _getFallbackFreeModels() {
    // Use centralized registry for fallback free models
    return ModelRegistry.getFreeModels();
  }

  /// Fallback models when API fails
  static List<String> _getFallbackModels() {
    final all = ModelRegistry.getAllModels();
    if (all.isNotEmpty) return all;
    // Minimal fallback
    return ModelRegistry.getFreeModels();
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
    final caps = ModelRegistry.getModelCapabilities(modelId);
    return caps.contextLength ?? 4096;
  }

  /// Get model description
  static String _getModelDescription(String modelId) {
    return ModelRegistry.getModelDescription(modelId);
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
    final id = model['id'] as String? ?? '';

    final inputModalities = model['input_modalities'] as List<dynamic>? ?? 
                           model['inputModalities'] as List<dynamic>? ?? 
                           model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
    if (inputModalities.isNotEmpty) {
      final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
      return modalities.contains('file');
    }
    return ModelRegistry.getModelCapabilities(id).supportsFiles;
  }

  /// Check if model supports images
  static bool _modelSupportsImages(Map<String, dynamic> model) {
    final id = model['id'] as String? ?? '';

    final inputModalities = model['input_modalities'] as List<dynamic>? ?? 
                           model['inputModalities'] as List<dynamic>? ?? 
                           model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
    if (inputModalities.isNotEmpty) {
      final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
      return modalities.contains('image');
    }
    return ModelRegistry.getModelCapabilities(id).supportsImages;
  }
}
