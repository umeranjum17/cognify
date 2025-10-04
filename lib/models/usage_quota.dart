import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the token balance for a user.
class UsageQuota {
  UsageQuota({
    required this.totalTokens,
    required this.tokensConsumed,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory UsageQuota.initial({required int allocation}) {
    return UsageQuota(
      totalTokens: allocation,
      tokensConsumed: 0,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory UsageQuota.fromJson(
    Map<String, dynamic> json, {
    required int allocation,
  }) {
    final created = json['createdAt'];
    final updated = json['updatedAt'];
    final total = (json['totalTokens'] as num?)?.toInt() ?? allocation;
    final consumed = (json['tokensConsumed'] as num?)?.toInt() ?? 0;
    final remaining = (json['tokensRemaining'] as num?)?.toInt();

    // tokensRemaining is optional redundancy; keep the greater precision value.
    final inferredConsumed = remaining != null ? (total - remaining) : consumed;

    return UsageQuota(
      totalTokens: total,
      tokensConsumed: inferredConsumed.clamp(0, total),
      createdAt: created is Timestamp
          ? created.toDate().toUtc()
          : DateTime.now().toUtc(),
      updatedAt: updated is Timestamp ? updated.toDate().toUtc() : null,
    );
  }

  final int totalTokens;
  final int tokensConsumed;
  final DateTime createdAt;
  final DateTime? updatedAt;

  int get remaining => (totalTokens - tokensConsumed).clamp(0, totalTokens);
  bool get isExceeded => remaining <= 0;
  double get percentUsed => totalTokens == 0 ? 1 : tokensConsumed / totalTokens;

  // Legacy accessors retained for backward compatibility with older UI code.
  int get limit => totalTokens;
  int get requestsUsed => tokensConsumed;

  Map<String, dynamic> toJson() {
    return {
      'totalTokens': totalTokens,
      'tokensConsumed': tokensConsumed,
      'tokensRemaining': remaining,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

class QuotaExceededException implements Exception {
  QuotaExceededException({
    required this.limit,
    required this.used,
    required this.requested,
  });

  final int limit;
  final int used;
  final int requested;

  int get remaining => (limit - used).clamp(0, limit);

  @override
  String toString() =>
      'QuotaExceededException(limit: $limit, used: $used, requested: $requested)';
}
