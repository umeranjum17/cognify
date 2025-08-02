import '../models/file_attachment.dart';

/// Centralized Model Registry for Flutter
/// Mirrors the server-side model registry with enhanced capabilities
class ModelRegistry {
  // Default models for different purposes
  static const Map<String, String> defaults = {
    'CHAT_MODE': 'google/gemini-2.0-flash-exp:free',
    'DEEPSEARCH_MODE': 'deepseek/deepseek-r1:free',
    'PLANNER_AGENT': 'google/gemini-2.0-flash-exp:free',
    'WRITER_AGENT': 'google/gemini-2.0-flash-exp:free',
    'CLOUD_FALLBACK': 'google/gemini-flash-1.5',
    'BUDGET_MODEL': 'deepseek/deepseek-chat:free',
    'FOLLOWUP_QUESTIONS': 'google/gemini-2.0-flash-exp:free',
  };

  // Static model information for fallback
  static const Map<String, Map<String, dynamic>> fallbackModelInfo = {
    // Only keep minimal fallback for when API is unavailable
    'mistralai/mistral-7b-instruct:free': {
      'provider': 'mistral',
      'isFree': true,
      'isReasoning': false,
      'maxTokens': 4096,
      'description': 'Fast, lightweight model for quick responses',
      'inputModalities': ['text'],
      'outputModalities': ['text'],
      'supportsImages': false,
      'supportsFiles': false,
      'isMultimodal': false,
      'pricing': {'input': 0.0, 'output': 0.0},
    },
  };

  /// Filter models by criteria
  static List<String> filterModels({
    List<String>? inputModalities,
    bool? isFree,
    String? provider,
    int? minContextLength,
    bool? supportsImages,
    bool? supportsFiles,
    bool? isMultimodal,
  }) {
    return fallbackModelInfo.entries.where((entry) {
      final modelId = entry.key;
      final info = entry.value;

      // Filter by free/paid status
      if (isFree != null && info['isFree'] != isFree) return false;

      // Filter by provider
      if (provider != null && info['provider'] != provider) return false;

      // Filter by context length
      if (minContextLength != null) {
        final contextLength = info['maxTokens'] as int?;
        if (contextLength == null || contextLength < minContextLength) {
          return false;
        }
      }

      // Filter by image support
      if (supportsImages != null && info['supportsImages'] != supportsImages) {
        return false;
      }

      // Filter by file support
      if (supportsFiles != null && info['supportsFiles'] != supportsFiles) {
        return false;
      }

      // Filter by multimodal capability
      if (isMultimodal != null && info['isMultimodal'] != isMultimodal) {
        return false;
      }

      // Filter by input modalities
      if (inputModalities != null && inputModalities.isNotEmpty) {
        final modelModalities = List<String>.from(info['inputModalities'] ?? ['text']);
        if (!inputModalities.every((modality) => modelModalities.contains(modality))) {
          return false;
        }
      }

      return true;
    }).map((entry) => entry.key).toList();
  }

  /// Format model name for display
  static String formatModelName(String modelId) {
    final parts = modelId.split('/');
    if (parts.length >= 2) {
      return parts[1].replaceAll(':free', '');
    }
    return modelId;
  }

  /// Get all available models
  static List<String> getAllModels() {
    return fallbackModelInfo.keys.toList();
  }

  /// Get all unique providers
  static List<String> getAllProviders() {
    return fallbackModelInfo.values
        .map((info) => info['provider'] as String)
        .toSet()
        .toList()
        ..sort();
  }

  /// Get models that support files
  static List<String> getFileSupportModels() {
    return fallbackModelInfo.entries
        .where((entry) => entry.value['supportsFiles'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all free models
  static List<String> getFreeModels() {
    return fallbackModelInfo.entries
        .where((entry) => entry.value['isFree'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get models that support images
  static List<String> getImageSupportModels() {
    return fallbackModelInfo.entries
        .where((entry) => entry.value['supportsImages'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get model capabilities from static data
  static ModelCapabilities getModelCapabilities(String modelId) {
    final modelInfo = fallbackModelInfo[modelId];
    if (modelInfo == null) {
      return const ModelCapabilities(
        inputModalities: ['text'],
        outputModalities: ['text'],
        supportsImages: false,
        supportsFiles: false,
        isMultimodal: false,
      );
    }

    return ModelCapabilities(
      inputModalities: List<String>.from(modelInfo['inputModalities'] ?? ['text']),
      outputModalities: List<String>.from(modelInfo['outputModalities'] ?? ['text']),
      supportsImages: modelInfo['supportsImages'] ?? false,
      supportsFiles: modelInfo['supportsFiles'] ?? false,
      isMultimodal: modelInfo['isMultimodal'] ?? false,
      contextLength: modelInfo['maxTokens'],
    );
  }

  /// Get model description
  static String getModelDescription(String modelId) {
    final modelInfo = fallbackModelInfo[modelId];
    return modelInfo?['description'] ?? 'Model information not available';
  }

  /// Get model pricing
  static Map<String, double>? getModelPricing(String modelId) {
    final modelInfo = fallbackModelInfo[modelId];
    final pricing = modelInfo?['pricing'] as Map<String, dynamic>?;
    if (pricing != null) {
      return {
        'input': (pricing['input'] as num).toDouble(),
        'output': (pricing['output'] as num).toDouble(),
      };
    }
    return null;
  }

  /// Get model provider
  static String getModelProvider(String modelId) {
    final parts = modelId.split('/');
    return parts.isNotEmpty ? parts[0] : 'unknown';
  }

  /// Get models by provider
  static List<String> getModelsByProvider(String provider) {
    return fallbackModelInfo.entries
        .where((entry) => entry.value['provider'] == provider)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all multimodal models
  static List<String> getMultimodalModels() {
    return fallbackModelInfo.entries
        .where((entry) => entry.value['isMultimodal'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all paid models
  static List<String> getPaidModels() {
    return fallbackModelInfo.entries
        .where((entry) => entry.value['isFree'] != true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get provider display name
  static String getProviderDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'mistral':
      case 'mistralai':
        return 'Mistral AI';
      case 'deepseek':
        return 'DeepSeek';
      case 'google':
        return 'Google';
      case 'anthropic':
        return 'Anthropic';
      case 'openai':
        return 'OpenAI';
      case 'meta':
      case 'meta-llama':
        return 'Meta';
      case 'microsoft':
        return 'Microsoft';
      default:
        return provider.toUpperCase();
    }
  }

  /// Get provider icon/emoji
  static String getProviderIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'mistral':
      case 'mistralai':
        return '🌊';
      case 'deepseek':
        return '🔍';
      case 'google':
        return '🔵';
      case 'anthropic':
        return '🤖';
      case 'openai':
        return '🧠';
      case 'meta':
      case 'meta-llama':
        return '🦙';
      case 'microsoft':
        return '💻';
      default:
        return '⚡';
    }
  }

  /// Check if model is free
  static bool isModelFree(String modelId) {
    final modelInfo = fallbackModelInfo[modelId];
    return modelInfo?['isFree'] == true || modelId.endsWith(':free');
  }

  /// Check if model is reasoning model
  static bool isReasoningModel(String modelId) {
    final modelInfo = fallbackModelInfo[modelId];
    return modelInfo?['isReasoning'] == true ||
           modelId.contains('r1') ||
           modelId.contains('reasoning');
  }

  /// Check if model supports specific file type
  static bool modelSupportsFileType(String modelId, String fileType) {
    final capabilities = getModelCapabilities(modelId);
    return capabilities.supportsFileType(fileType);
  }
}