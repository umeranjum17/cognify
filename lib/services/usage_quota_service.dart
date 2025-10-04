import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_secrets.dart';
import '../models/usage_quota.dart';
import '../utils/logger.dart';

/// Handles persistence of token balances per user in Firestore.
class UsageQuotaService {
  UsageQuotaService._();

  static final UsageQuotaService instance = UsageQuotaService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'usage_quotas';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection(_collection).doc(uid);

  int get _defaultAllocation => AppSecrets.initialTokenAllocation;

  /// Returns a stream of [UsageQuota] updates for the active user.
  Stream<UsageQuota> watchQuota(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UsageQuota.fromJson(
          snapshot.data()!,
          allocation: _defaultAllocation,
        );
      }
      return UsageQuota.initial(allocation: _defaultAllocation);
    });
  }

  /// Fetches the latest quota, creating a default record if necessary.
  Future<UsageQuota> fetchQuota(String uid) async {
    final ref = _doc(uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      final quota = UsageQuota.initial(allocation: _defaultAllocation);
      await ref.set(quota.toJson(), SetOptions(merge: true));
      return quota;
    }
    return UsageQuota.fromJson(snapshot.data()!, allocation: _defaultAllocation);
  }

  /// Consumes [amount] tokens. Throws [QuotaExceededException] when exhausted.
  Future<UsageQuota> consume({
    required String uid,
    int amount = 1,
  }) async {
    if (amount <= 0) {
      return fetchQuota(uid);
    }

    final now = DateTime.now().toUtc();

    return _firestore.runTransaction((transaction) async {
      final ref = _doc(uid);
      final snapshot = await transaction.get(ref);

      final state = _readSnapshot(snapshot);

      if (amount > state.remaining) {
        throw QuotaExceededException(
          limit: state.totalTokens,
          used: state.tokensConsumed,
          requested: amount,
        );
      }

      final updatedConsumed = state.tokensConsumed + amount;
      final updatedRemaining = state.totalTokens - updatedConsumed;

      transaction.set(ref, {
        'totalTokens': state.totalTokens,
        'tokensConsumed': updatedConsumed,
        'tokensRemaining': updatedRemaining,
        'createdAt': Timestamp.fromDate(state.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Logger.debug(
        '💾 Tokens consumed: $updatedConsumed/${state.totalTokens} (delta=$amount, uid=$uid)',
        tag: 'UsageQuota',
      );

      return UsageQuota(
        totalTokens: state.totalTokens,
        tokensConsumed: updatedConsumed,
        createdAt: state.createdAt,
        updatedAt: now,
      );
    });
  }

  /// Reverts a prior consumption in failure scenarios.
  Future<void> refund({
    required String uid,
    int amount = 1,
  }) async {
    if (amount <= 0) {
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final ref = _doc(uid);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        return;
      }

      final state = _readSnapshot(snapshot);
      if (state.tokensConsumed == 0) {
        return;
      }

      final updatedConsumed = math.max(0, state.tokensConsumed - amount);
      final updatedRemaining = state.totalTokens - updatedConsumed;

      transaction.set(ref, {
        'totalTokens': state.totalTokens,
        'tokensConsumed': updatedConsumed,
        'tokensRemaining': updatedRemaining,
        'createdAt': Timestamp.fromDate(state.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  _QuotaState _readSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final now = DateTime.now().toUtc();
    final data = snapshot.data();
    int total = _defaultAllocation;
    int consumed = 0;
    DateTime createdAt = now;

    if (data != null) {
      total = (data['totalTokens'] as num?)?.toInt() ?? total;
      consumed = (data['tokensConsumed'] as num?)?.toInt() ??
          (data['requestsUsed'] as num?)?.toInt() ??
          0;

      final remainingField = (data['tokensRemaining'] as num?)?.toInt();
      if (remainingField != null) {
        total = math.max(total, consumed + remainingField);
      }

      final createdField = data['createdAt'];
      if (createdField is Timestamp) {
        createdAt = createdField.toDate().toUtc();
      }
    }

    total = math.max(total, consumed);
    consumed = consumed.clamp(0, total);

    return _QuotaState(
      totalTokens: total,
      tokensConsumed: consumed,
      createdAt: createdAt,
    );
  }
}

class _QuotaState {
  _QuotaState({
    required this.totalTokens,
    required this.tokensConsumed,
    required this.createdAt,
  });

  final int totalTokens;
  final int tokensConsumed;
  final DateTime createdAt;

  int get remaining => (totalTokens - tokensConsumed).clamp(0, totalTokens);
}
