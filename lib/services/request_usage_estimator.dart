import 'dart:math' as math;

import '../config/app_config.dart';
import '../models/mode_config.dart';

/// Estimates how many subscription request units a model invocation consumes.
class RequestUsageEstimator {
  RequestUsageEstimator._();

  static const int _defaultInputTokens = 900;
  static const int _defaultOutputTokens = 1100;

  static const Map<ChatMode, double> _modeTokenMultipliers = {
    ChatMode.chat: 1.0,
    ChatMode.search: 1.3,
    ChatMode.aipedia: 1.5,
    // DeepSearch responses are intentionally heavier – mirror product copy ("10x resources")
    ChatMode.deepsearch: 8.0,
  };

  /// Estimate request usage for a model based on pricing and optional heuristics.
  static RequestUsageEstimate estimate({
    required Map<String, dynamic>? pricing,
    ChatMode? mode,
    int? inputTokens,
    int? outputTokens,
    double? costPerRequestUnit,
  }) {
    if (pricing == null) {
      return const RequestUsageEstimate.free();
    }

    final inputPrice = _parsePrice(pricing['input'] ?? pricing['prompt']);
    final outputPrice = _parsePrice(pricing['output'] ?? pricing['completion']);

    if (inputPrice <= 0 && outputPrice <= 0) {
      return const RequestUsageEstimate.free();
    }

    final tokenPair = _resolveTokens(
      mode: mode,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );

    final double perRequestCost =
        costPerRequestUnit ?? AppSecrets.dollarsPerRequestUnit;
    if (perRequestCost <= 0) {
      // Avoid division by zero; treat as free if configuration is invalid.
      return const RequestUsageEstimate.free();
    }

    final double estimatedDollarCost =
        (tokenPair.input / 1e6) * inputPrice +
        (tokenPair.output / 1e6) * outputPrice;

    if (estimatedDollarCost <= 0) {
      return RequestUsageEstimate(
        requestUnits: 0,
        dollarCost: 0,
        inputTokens: tokenPair.input,
        outputTokens: tokenPair.output,
      );
    }

    final int requestUnits = math.max(
      1,
      (estimatedDollarCost / perRequestCost).ceil(),
    );

    return RequestUsageEstimate(
      requestUnits: requestUnits,
      dollarCost: estimatedDollarCost,
      inputTokens: tokenPair.input,
      outputTokens: tokenPair.output,
    );
  }

  static _TokenPair _resolveTokens({
    ChatMode? mode,
    int? inputTokens,
    int? outputTokens,
  }) {
    final multiplier = _modeTokenMultipliers[mode] ?? 1.0;
    final resolvedInput = (inputTokens ?? _defaultInputTokens).toDouble();
    final resolvedOutput = (outputTokens ?? _defaultOutputTokens).toDouble();

    return _TokenPair(
      input: math.max(0, (resolvedInput * multiplier).round()),
      output: math.max(0, (resolvedOutput * multiplier).round()),
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    if (value is Map) {
      final unitValue = value['unit'];
      if (unitValue is num) return unitValue.toDouble();
      if (unitValue is String) {
        return double.tryParse(unitValue) ?? 0;
      }
    }
    return 0;
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

class _TokenPair {
  const _TokenPair({required this.input, required this.output});

  final int input;
  final int output;
}
