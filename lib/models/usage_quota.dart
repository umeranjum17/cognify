import 'package:cloud_firestore/cloud_firestore.dart';

/// Request usage log entry for transparency and analytics.
class RequestUsageEntry {
  final DateTime timestamp;
  final String modelId;
  final int requestUnits; // number of requests deducted for this operation
  final double? dollarCost; // optional: approximate $ cost for this operation
  final int? inputTokens;
  final int? outputTokens;
  final String? conversationId;

  const RequestUsageEntry({
    required this.timestamp,
    required this.modelId,
    required this.requestUnits,
    this.dollarCost,
    this.inputTokens,
    this.outputTokens,
    this.conversationId,
  });

  factory RequestUsageEntry.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'];
    DateTime parsed;
    if (ts is Timestamp) {
      parsed = ts.toDate().toUtc();
    } else if (ts is String) {
      parsed = DateTime.tryParse(ts)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      parsed = DateTime.now().toUtc();
    }
    return RequestUsageEntry(
      timestamp: parsed,
      modelId: json['modelId'] as String? ?? 'unknown',
      requestUnits: (json['requestUnits'] as num?)?.toInt() ??
          (json['tokens'] as num?)?.toInt() ??
          0,
      dollarCost: (json['dollarCost'] as num?)?.toDouble(),
      inputTokens: (json['inputTokens'] as num?)?.toInt(),
      outputTokens: (json['outputTokens'] as num?)?.toInt(),
      conversationId: json['conversationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'modelId': modelId,
      'requestUnits': requestUnits,
      // Legacy key for any older consumers (optional)
      'tokens': requestUnits,
      if (dollarCost != null) 'dollarCost': dollarCost,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (conversationId != null) 'conversationId': conversationId,
    };
  }

  /// For Firestore serialization (uses Timestamp objects)
  Map<String, dynamic> toFirestoreJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp.toUtc()),
      'modelId': modelId,
      'requestUnits': requestUnits,
      'tokens': requestUnits,
      if (dollarCost != null) 'dollarCost': dollarCost,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (conversationId != null) 'conversationId': conversationId,
    };
  }
}

/// Represents the request-based balance for a user.
/// Backward compatible with legacy token-based fields.
class UsageQuota {
  UsageQuota({
    required this.totalRequests,
    required this.requestsConsumed,
    DateTime? createdAt,
    this.updatedAt,
    List<RequestUsageEntry>? usageHistory,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        usageHistory = usageHistory ?? const [];

  factory UsageQuota.initial({required int allocation}) {
    return UsageQuota(
      totalRequests: allocation,
      requestsConsumed: 0,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory UsageQuota.fromJson(
    Map<String, dynamic> json, {
    required int allocation,
  }) {
    final created = json['createdAt'];
    final updated = json['updatedAt'];

    // Prefer new request-based keys, fallback to legacy token fields
    final total = (json['totalRequests'] as num?)?.toInt() ??
        (json['totalTokens'] as num?)?.toInt() ??
        allocation;
    final consumed = (json['requestsConsumed'] as num?)?.toInt() ??
        (json['tokensConsumed'] as num?)?.toInt() ??
        0;
    final remainingNew = (json['requestsRemaining'] as num?)?.toInt();
    final remainingLegacy = (json['tokensRemaining'] as num?)?.toInt();
    final remaining = remainingNew ?? remainingLegacy;

    // If remaining was persisted, infer consumed accordingly for higher accuracy
    final inferredConsumed = remaining != null ? (total - remaining) : consumed;

    // Parse usage history if present
    final rawHistory = json['usageHistory'];
    final history = <RequestUsageEntry>[];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map<String, dynamic>) {
          history.add(RequestUsageEntry.fromJson(item));
        }
      }
    }

    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate().toUtc();
    } else if (created is String) {
      createdAt = DateTime.tryParse(created)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      createdAt = DateTime.now().toUtc();
    }

    DateTime? updatedAt;
    if (updated is Timestamp) {
      updatedAt = updated.toDate().toUtc();
    } else if (updated is String) {
      updatedAt = DateTime.tryParse(updated)?.toUtc();
    }

    return UsageQuota(
      totalRequests: total,
      requestsConsumed: inferredConsumed.clamp(0, total),
      createdAt: createdAt,
      updatedAt: updatedAt,
      usageHistory: history,
    );
  }

  final int totalRequests;
  final int requestsConsumed;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<RequestUsageEntry> usageHistory;

  int get remaining => (totalRequests - requestsConsumed).clamp(0, totalRequests);
  bool get isExceeded => remaining <= 0;
  double get percentUsed => totalRequests == 0 ? 1 : requestsConsumed / totalRequests;

  // Legacy accessors retained for backward compatibility with older UI code.
  int get limit => totalRequests;
  int get totalTokens => totalRequests; // legacy alias
  int get tokensConsumed => requestsConsumed; // legacy alias
  int get requestsUsed => requestsConsumed;

  Map<String, dynamic> toJson() {
    return {
      // New request-based keys
      'totalRequests': totalRequests,
      'requestsConsumed': requestsConsumed,
      'requestsRemaining': remaining,
      'usageHistory': usageHistory.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      // Legacy keys for backward compatibility
      'totalTokens': totalRequests,
      'tokensConsumed': requestsConsumed,
      'tokensRemaining': remaining,
    };
  }

  /// For Firestore serialization (uses Timestamp objects)
  Map<String, dynamic> toFirestoreJson() {
    return {
      'totalRequests': totalRequests,
      'requestsConsumed': requestsConsumed,
      'requestsRemaining': remaining,
      'usageHistory': usageHistory.map((e) => e.toFirestoreJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'totalTokens': totalRequests,
      'tokensConsumed': requestsConsumed,
      'tokensRemaining': remaining,
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
