import 'dart:convert';

import 'package:cognify_flutter/config/app_config.dart';
import '../config/model_registry.dart';
import 'package:http/http.dart' as http;
import 'remote_config_service.dart';

class CostService {
  static final String baseUrl = AppConfig.apiUrl;

  // Cache for pricing to avoid repeated API calls
  static Map<String, Map<String, double>>? _cachedPricing;
  static DateTime? _cacheTimestamp;
  static const Duration cacheExpiry = Duration(hours: 1);

  /// Calculate accurate costs using generation IDs from OpenRouter API
  /// NOW USES BACKEND API - all calculation logic moved to /api/usage/calculate
  static Future<Map<String, dynamic>> calculateAccurateCosts(List<Map<String, dynamic>>? generationIds) async {
    if (generationIds == null || generationIds.isEmpty) {
      return {
        'totalCost': 0.0,
        'breakdown': <String, dynamic>{},
        'hasAccurateCosts': false,
        'error': 'No generation IDs provided',
      };
    }

    try {
      print('💰 Calculating accurate costs for ${generationIds.length} generation IDs via backend');

      final response = await http.post(
        Uri.parse('$baseUrl/api/usage/calculate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'generationIds': generationIds}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final data = result['data'];
          print('✅ Accurate costs calculated: \$${data['totalCost'].toStringAsFixed(6)}');
          return {
            'totalCost': (data['totalCost'] as num).toDouble(),
            'breakdown': data['breakdown'] ?? {},
            'hasAccurateCosts': data['hasAccurateCosts'] ?? true,
            'successfulFetches': data['successfulFetches'] ?? 0,
            'failedFetches': data['failedFetches'] ?? 0,
            'accuracy': data['accuracy'] ?? 0.0,
          };
        }
      }

      print('❌ Backend cost calculation failed: HTTP ${response.statusCode}');
      return {
        'totalCost': 0.0,
        'breakdown': <String, dynamic>{},
        'hasAccurateCosts': false,
        'error': 'Backend request failed',
      };
    } catch (e) {
      print('❌ Error calculating accurate costs via backend: $e');
      return {
        'totalCost': 0.0,
        'breakdown': <String, dynamic>{},
        'hasAccurateCosts': false,
        'error': e.toString(),
      };
    }
  }

  /// Calculate cost for given token usage
  static double calculateCost({
    required int inputTokens,
    required int outputTokens,
    required Map<String, double> pricing,
  }) {
    final inputCost = (inputTokens / 1000000) * (pricing['input'] ?? 0);
    final outputCost = (outputTokens / 1000000) * (pricing['output'] ?? 0);
    return inputCost + outputCost;
  }

  /// Clear cache (useful for testing or manual refresh)
  static void clearCache() {
    _cachedPricing = null;
    _cacheTimestamp = null;
  }

  /// Format cost for display
  static String formatCost(double cost, {bool showFree = true}) {
    if (cost == 0 && showFree) {
      return 'Free';
    }
    
    if (cost < 0.000001) {
      return '\$0.000001';
    }
    
    if (cost < 0.001) {
      return '\$${cost.toStringAsFixed(6)}';
    } else if (cost < 1) {
      return '\$${cost.toStringAsFixed(4)}';
    } else {
      return '\$${cost.toStringAsFixed(2)}';
    }
  }

  /// Format pricing for display (per 1M tokens)
  static String formatPricingPerMillion(double pricePerMillion) {
    if (pricePerMillion == 0) {
      return 'Free';
    }
    return '\$${pricePerMillion.toStringAsFixed(2)}/1M';
  }

  /// Get cost breakdown text
  static String getCostBreakdownText(Map<String, dynamic>? costBreakdown) {
    if (costBreakdown == null) return '';
    
    final inputTokens = costBreakdown['inputTokens'] ?? 0;
    final outputTokens = costBreakdown['outputTokens'] ?? 0;
    final totalCost = costBreakdown['totalCost'] ?? 0.0;
    
    return '${inputTokens + outputTokens} tokens • ${formatCost(totalCost)}';
  }

  /// Get model display name with cost info
  static Future<String> getModelDisplayWithCost(String modelId) async {
    final pricing = await getModelPricingById(modelId);
    final modelName = _formatModelName(modelId);
    
    if (pricing == null || (pricing['input'] == 0 && pricing['output'] == 0)) {
      return '$modelName (Free)';
    }
    
    final inputPrice = formatPricingPerMillion(pricing['input'] ?? 0);
    final outputPrice = formatPricingPerMillion(pricing['output'] ?? 0);
    return '$modelName (In: $inputPrice, Out: $outputPrice)';
  }

  /// Get model pricing information
  static Future<Map<String, Map<String, double>>> getModelPricing() async {
    // Return cached data if valid
    if (_isCacheValid()) {
      return _cachedPricing!;
    }

    // Try remote config service first
    try {
      final remoteConfig = RemoteConfigService();
      final remotePricing = await remoteConfig.fetchPricing();

      if (remotePricing != null && remotePricing.isNotEmpty) {
        _cachedPricing = remotePricing;
        _cacheTimestamp = DateTime.now();
        print('✅ Using pricing from remote config');
        return _cachedPricing!;
      }
    } catch (e) {
      print('⚠️ Failed to fetch pricing from remote config: $e');
    }

    // Fallback to legacy endpoint (deprecated)
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/pricing'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final pricingData = data['data'] as Map<String, dynamic>;
          _cachedPricing = pricingData.map((key, value) => MapEntry(
            key,
            Map<String, double>.from(value),
          ));
          _cacheTimestamp = DateTime.now();
          return _cachedPricing!;
        } else {
          throw Exception('API returned error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching model pricing from legacy endpoint: $e');
      // Return fallback pricing if API fails
      return _getFallbackPricing();
    }
  }

  /// Get pricing for a specific model
  static Future<Map<String, double>?> getModelPricingById(String modelId) async {
    final allPricing = await getModelPricing();
    return allPricing[modelId];
  }

  /// Get session cost summary
  static String getSessionCostSummary({
    required double sessionCost,
    required int messageCount,
  }) {
    if (sessionCost == 0) {
      return 'Session: Free ($messageCount messages)';
    }
    return 'Session: ' + formatCost(sessionCost) + ' (' + messageCount.toString() + ' messages)';
  }

  /// Check if a model is free
  static Future<bool> isModelFree(String modelId) async {
    final pricing = await getModelPricingById(modelId);
    if (pricing == null) return true; // Assume free if no pricing info
    return (pricing['input'] ?? 0) == 0 && (pricing['output'] ?? 0) == 0;
  }

  /// Format model name for display
  static String _formatModelName(String modelId) {
    final parts = modelId.split('/');
    if (parts.length >= 2) {
      return parts[1].replaceAll(':free', '');
    }
    return modelId;
  }

  /// Get fallback pricing data
  static Map<String, Map<String, double>> _getFallbackPricing() {
    // Build fallback pricing from ModelRegistry fallback info only
    final Map<String, Map<String, double>> pricing = {};
    for (final entry in ModelRegistry.fallbackModelInfo.entries) {
      final id = entry.key;
      final info = entry.value;
      final p = info['pricing'] as Map<String, dynamic>?;
      if (p != null) {
        final input = (p['input'] as num?)?.toDouble() ?? 0.0;
        final output = (p['output'] as num?)?.toDouble() ?? 0.0;
        pricing[id] = {'input': input, 'output': output};
      }
    }
    return pricing;
  }

  /// Check if cache is valid
  static bool _isCacheValid() {
    if (_cachedPricing == null || _cacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < cacheExpiry;
  }
}
