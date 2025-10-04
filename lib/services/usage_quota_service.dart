import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
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
        return UsageQuota.fromJson(data, allocation: AppSecrets.initialTokenAllocation);
      } catch (_) {}
    }

    // Initialize with default allocation
    final initial = UsageQuota.initial(allocation: AppSecrets.initialTokenAllocation);
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

  Future<UsageQuota> consume({required String uid, int amount = 1}) async {
    final current = await _load(uid);
    final requested = amount.clamp(0, 1 << 30);
    if (current.tokensConsumed + requested > current.totalTokens) {
      throw QuotaExceededException(
        limit: current.totalTokens,
        used: current.tokensConsumed,
        requested: requested,
      );
    }

    final updated = UsageQuota(
      totalTokens: current.totalTokens,
      tokensConsumed: current.tokensConsumed + requested,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _save(uid, updated);
    _controllersByUid[uid]?.add(updated);
    return updated;
  }

  Future<void> refund({required String uid, int amount = 1}) async {
    final current = await _load(uid);
    final refunded = (current.tokensConsumed - amount).clamp(0, current.totalTokens);
    final updated = UsageQuota(
      totalTokens: current.totalTokens,
      tokensConsumed: refunded,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _save(uid, updated);
    _controllersByUid[uid]?.add(updated);
  }
}

