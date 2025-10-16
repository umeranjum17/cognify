import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../models/usage_quota.dart';

/// Local UsageQuota service backed by SharedPreferences.
class UsageQuotaService {
  UsageQuotaService._internal();
  static final UsageQuotaService instance = UsageQuotaService._internal();

  final Map<String, StreamController<UsageQuota>> _controllersByUid = {};

  String _keyFor(String uid) => 'usage_quota_$uid';

  Future<UsageQuota> _load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyFor(uid));

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        return UsageQuota.fromJson(
          data,
          allocation: 0,
        );
      } catch (_) {}
    }

    // Initialize from backend balance (source of truth)
    final remoteBalance = await API.instance.getCreditsBalance();
    final initial = UsageQuota.initial(
      allocation: remoteBalance.toInt().clamp(0, 1 << 30),
    );
    await _save(uid, initial);
    return initial;
  }

  Future<void> _save(String uid, UsageQuota quota) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(quota.toJson());
    await prefs.setString(_keyFor(uid), jsonStr);
  }

  Stream<UsageQuota> watchQuota(String uid) async* {
    // Emit current value immediately
    yield await fetchQuota(uid);

    // Then subscribe to controller updates
    final controller = _controllersByUid.putIfAbsent(
      uid,
      () => StreamController<UsageQuota>.broadcast(),
    );
    yield* controller.stream;
  }

  Future<UsageQuota> fetchQuota(String uid) async {
    return await _load(uid);
  }

  /// Force-refresh the local quota cache from backend balance and notify listeners.
  /// This treats backend balance as the remaining requests. Consumed resets to 0.
  Future<UsageQuota> refreshFromBackend(String uid) async {
    try {
      final remoteBalance = await API.instance.getCreditsBalance();
      final refreshed = UsageQuota.initial(
        allocation: remoteBalance.toInt().clamp(0, 1 << 30),
      );
      await _save(uid, refreshed);
      
      // Notify all listeners immediately
      _controllersByUid[uid]?.add(refreshed);
      
      print('✅ [UsageQuota] Refreshed from backend: ${refreshed.remaining} credits remaining');
      return refreshed;
    } catch (e) {
      print('❌ [UsageQuota] Failed to refresh from backend: $e');
      rethrow;
    }
  }

  Future<UsageQuota> consume({required String uid, int amount = 1}) async {
    // Backward-compatible consume method (no logging). Prefer consumeRequests.
    final current = await _load(uid);
    final requested = amount.clamp(0, 1 << 30);
    if (current.requestsConsumed + requested > current.totalRequests) {
      throw QuotaExceededException(
        limit: current.totalRequests,
        used: current.requestsConsumed,
        requested: requested,
      );
    }

    final updated = UsageQuota(
      totalRequests: current.totalRequests,
      requestsConsumed: current.requestsConsumed + requested,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      usageHistory: current.usageHistory,
    );
    await _save(uid, updated);
    _controllersByUid[uid]?.add(updated);
    return updated;
  }

  /// Enhanced consumeRequests - NOW USES BACKEND CALCULATION
  /// Backend calculates request units based on modelId and mode
  Future<UsageQuota> consumeRequests({
    required String uid,
    int amount = 1, // Deprecated - backend calculates this
    String? modelId,
    String? mode,
    double? dollarCost,
    int? inputTokens,
    int? outputTokens,
    String? conversationId,
  }) async {
    // If modelId provided, use new backend flow (server calculates units)
    // Otherwise fall back to legacy local calculation
    if (modelId != null) {
      // Backend will calculate units - we just track the result
      print('⚡ Using backend-calculated request units for model: $modelId');

      final entry = RequestUsageEntry(
        timestamp: DateTime.now().toUtc(),
        modelId: modelId,
        requestUnits: 0, // Will be updated from backend response
        dollarCost: dollarCost,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        conversationId: conversationId,
      );

      final current = await _load(uid);
      final updatedHistory = List<RequestUsageEntry>.from(current.usageHistory)
        ..insert(0, entry);
      if (updatedHistory.length > 200) {
        updatedHistory.removeRange(200, updatedHistory.length);
      }

      final updated = UsageQuota(
        totalRequests: current.totalRequests,
        requestsConsumed: current.requestsConsumed + amount, // Backend provides actual amount
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
        usageHistory: updatedHistory,
      );
      await _save(uid, updated);
      _controllersByUid[uid]?.add(updated);
      return updated;
    }

    // Legacy flow: local calculation (deprecated)
    final current = await _load(uid);
    final requested = amount.clamp(0, 1 << 30);
    if (current.requestsConsumed + requested > current.totalRequests) {
      throw QuotaExceededException(
        limit: current.totalRequests,
        used: current.requestsConsumed,
        requested: requested,
      );
    }

    final entry = RequestUsageEntry(
      timestamp: DateTime.now().toUtc(),
      modelId: modelId ?? 'unknown',
      requestUnits: requested,
      dollarCost: dollarCost,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      conversationId: conversationId,
    );
    final updatedHistory = List<RequestUsageEntry>.from(current.usageHistory)
      ..insert(0, entry);
    if (updatedHistory.length > 200) {
      updatedHistory.removeRange(200, updatedHistory.length);
    }

    final updated = UsageQuota(
      totalRequests: current.totalRequests,
      requestsConsumed: current.requestsConsumed + requested,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      usageHistory: updatedHistory,
    );
    await _save(uid, updated);
    _controllersByUid[uid]?.add(updated);
    return updated;
  }

  Future<void> refund({required String uid, int amount = 1}) async {
    final current = await _load(uid);
    final refunded =
        (current.requestsConsumed - amount).clamp(0, current.totalRequests);
    final updated = UsageQuota(
      totalRequests: current.totalRequests,
      requestsConsumed: refunded,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      usageHistory: current.usageHistory,
    );
    await _save(uid, updated);
    _controllersByUid[uid]?.add(updated);
  }

  Future<void> logUsageEntry({
    required String uid,
    required RequestUsageEntry entry,
  }) async {
    final current = await _load(uid);
    final updatedHistory = List<RequestUsageEntry>.from(current.usageHistory)
      ..insert(0, entry);
    if (updatedHistory.length > 200) {
      updatedHistory.removeRange(200, updatedHistory.length);
    }
    final updated = UsageQuota(
      totalRequests: current.totalRequests,
      requestsConsumed: current.requestsConsumed,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      usageHistory: updatedHistory,
    );
    await _save(uid, updated);
    _controllersByUid[uid]?.add(updated);
  }
}
