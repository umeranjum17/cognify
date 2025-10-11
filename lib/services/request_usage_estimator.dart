import '../models/mode_config.dart';
import './mode_api_service.dart';

/// Estimates how many subscription request units a model invocation consumes.
/// Uses cached config data from /api/config/models instead of separate API call
class RequestUsageEstimator {
  RequestUsageEstimator._();

  static final ModeApiService _modeApi = ModeApiService.instance;

  /// Estimate request usage for a model - uses cached config data
  static Future<RequestUsageEstimate> estimate({
    required String modelId,
    ChatMode? mode,
    int? inputTokens,
    int? outputTokens,
    Map<String, dynamic>? pricing, // Deprecated, kept for backwards compatibility
  }) async {
    try {
      // Load config (uses cache if available)
      final config = await _modeApi.loadModelsConfig();
      if (config == null) {
        return const RequestUsageEstimate.free();
      }

      final modeStr = mode?.toString().split('.').last ?? 'chat';

      // Attempt to resolve canonical model id (backend keys are full provider/model)
      String _resolveCanonicalId(String incomingId) {
        // Fast path: exact match
        final pricingMap = config['pricing'] as Map<String, dynamic>?;
        if (pricingMap != null && pricingMap.containsKey(incomingId)) {
          return incomingId;
        }
        // Try suffix match against pricing keys
        if (pricingMap != null) {
          for (final key in pricingMap.keys) {
            if (key is String) {
              final last = key.split('/').length > 1 ? key.split('/').last : key;
              if (last == incomingId) {
                return key;
              }
            }
          }
        }
        // Try against available models list
        final available = config['available'] as List<dynamic>? ?? config['models'] as List<dynamic>?;
        if (available != null) {
          for (final raw in available) {
            final key = raw.toString();
            final last = key.split('/').length > 1 ? key.split('/').last : key;
            if (last == incomingId) {
              return key;
            }
          }
        }
        // Fallback to incoming id
        return incomingId;
      }

      final canonicalId = _resolveCanonicalId(modelId);

      // Get pre-calculated estimate for chat mode
      final quotaPricing = config['quotaPricing'] as Map<String, dynamic>?;
      final perRequestSample = quotaPricing?['perRequestSample'] as Map<String, dynamic>?;
      final chatEstimates = perRequestSample?[modeStr] as Map<String, dynamic>?;
      final modelEstimate = chatEstimates?[canonicalId] as Map<String, dynamic>?;

      if (modelEstimate != null) {
        return RequestUsageEstimate(
          requestUnits: modelEstimate['requestUnits'] ?? 0,
          dollarCost: (modelEstimate['dollarCost'] ?? 0.0).toDouble(),
          inputTokens: modelEstimate['inputTokens'] ?? 0,
          outputTokens: modelEstimate['outputTokens'] ?? 0,
        );
      }

      // Fallback: calculate manually from pricing if estimate not available
      final pricingMap = config['pricing'] as Map<String, dynamic>?;
      final modelPricing = pricingMap?[canonicalId] as Map<String, dynamic>?;

      if (modelPricing != null) {
        final inputPrice = (modelPricing['input'] ?? 0.0) as double;
        final outputPrice = (modelPricing['output'] ?? 0.0) as double;

        if (inputPrice == 0 && outputPrice == 0) {
          return const RequestUsageEstimate.free();
        }

        // Mode multipliers
        const modeMultipliers = {
          'chat': 1.0,
          'search': 1.3,
          'aipedia': 1.5,
          'deepsearch': 8.0,
        };

        final multiplier = modeMultipliers[modeStr] ?? 1.0;
        const defaultInput = 900;
        const defaultOutput = 1100;

        final actualInput = ((inputTokens ?? defaultInput) * multiplier).round();
        final actualOutput = ((outputTokens ?? defaultOutput) * multiplier).round();

        final dollarCost = (actualInput / 1000000) * inputPrice +
            (actualOutput / 1000000) * outputPrice;

        if (dollarCost <= 0) {
          return const RequestUsageEstimate.free();
        }

        final dollarsPerUnit = quotaPricing?['dollarsPerRequestUnit'] ?? 0.01;
        final requestUnits = (dollarCost / dollarsPerUnit).ceil().clamp(1, 999999);

        return RequestUsageEstimate(
          requestUnits: requestUnits,
          dollarCost: dollarCost,
          inputTokens: actualInput,
          outputTokens: actualOutput,
        );
      }

      return const RequestUsageEstimate.free();
    } catch (e) {
      print('❌ Failed to estimate usage: $e');
      return const RequestUsageEstimate.free();
    }
  }

  /// Helper to present a human-friendly label for the request estimate.
  static String formatLabel(
    RequestUsageEstimate estimate, {
    bool compact = false,
  }) {
    if (estimate.isFree) {
      return 'Free';
    }

    final units = estimate.requestUnits;
    if (compact) {
      final suffix = units == 1 ? 'req' : 'reqs';
      return '~$units $suffix';
    }

    final suffix = units == 1 ? 'request' : 'requests';
    return '≈$units $suffix';
  }
}

class RequestUsageEstimate {
  const RequestUsageEstimate({
    required this.requestUnits,
    required this.dollarCost,
    required this.inputTokens,
    required this.outputTokens,
  });

  const RequestUsageEstimate.free()
    : requestUnits = 0,
      dollarCost = 0,
      inputTokens = 0,
      outputTokens = 0;

  final int requestUnits;
  final double dollarCost;
  final int inputTokens;
  final int outputTokens;

  bool get isFree => requestUnits == 0 || dollarCost == 0;
  int get totalTokens => inputTokens + outputTokens;
}
