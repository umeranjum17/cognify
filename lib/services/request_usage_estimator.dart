import 'dart:convert';
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/mode_config.dart';

/// Estimates how many subscription request units a model invocation consumes.
/// NOW USES BACKEND API - all calculation logic moved to /api/usage/estimate
class RequestUsageEstimator {
  RequestUsageEstimator._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.backendBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
  ));

  /// Estimate request usage for a model - BACKEND API VERSION
  static Future<RequestUsageEstimate> estimate({
    required String modelId,
    ChatMode? mode,
    int? inputTokens,
    int? outputTokens,
    Map<String, dynamic>? pricing, // Deprecated, kept for backwards compatibility
  }) async {
    try {
      final modeStr = mode?.toString().split('.').last ?? 'chat';

      final response = await _dio.post(
        '/api/usage/estimate',
        data: jsonEncode({
          'model': modelId,
          'mode': modeStr,
          if (inputTokens != null) 'inputTokens': inputTokens,
          if (outputTokens != null) 'outputTokens': outputTokens,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        return RequestUsageEstimate(
          requestUnits: data['requestUnits'] ?? 0,
          dollarCost: (data['dollarCost'] ?? 0.0).toDouble(),
          inputTokens: data['inputTokens'] ?? 0,
          outputTokens: data['outputTokens'] ?? 0,
        );
      } else {
        throw Exception('Backend returned error: ${response.data['error']}');
      }
    } catch (e) {
      print('❌ Failed to estimate usage from backend: $e');
      // Fallback to free estimate on error
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
