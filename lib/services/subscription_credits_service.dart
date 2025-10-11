import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Subscription-based credits service that syncs with RevenueCat via Firestore.
/// This is the single source of truth for monthly credit allowances and consumption.
/// 
/// Architecture:
/// - RevenueCat webhook updates Firestore subscription metadata
/// - This service watches Firestore and provides real-time balance
/// - Client detects period expiration and triggers reset
/// - All consumption is tracked in Firestore (not local storage)
class SubscriptionCreditsService {
  SubscriptionCreditsService._();
  static final SubscriptionCreditsService instance = SubscriptionCreditsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Map<String, StreamController<SubscriptionCredits>> _controllersByUid = {};
  final Map<String, StreamSubscription> _subscriptionsByUid = {};

  /// Watch subscription credits for a user
  Stream<SubscriptionCredits> watchCredits(String uid) {
    // Return existing stream if already watching
    if (_controllersByUid.containsKey(uid)) {
      return _controllersByUid[uid]!.stream;
    }

    // Create new broadcast controller
    final controller = StreamController<SubscriptionCredits>.broadcast();
    _controllersByUid[uid] = controller;

    // Watch Firestore subscription document
    final subscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('current')
        .snapshots()
        .listen(
      (snapshot) async {
        if (!snapshot.exists) {
          // No subscription data - treat as zero credits on client
          controller.add(SubscriptionCredits.zero(uid));
          return;
        }

        final data = snapshot.data()!;
        final credits = SubscriptionCredits.fromFirestore(data, uid);

        // Check if period has expired and subscription is still active
        if (credits.isPeriodExpired && credits.status == 'active') {
          debugPrint('🔄 [SubscriptionCredits] Period expired for $uid, triggering reset...');
          // Trigger period reset (will update Firestore, which will trigger this listener again)
          await _resetForNewPeriod(uid, credits);
          return; // Wait for Firestore update to trigger new event
        }

        controller.add(credits);
      },
      onError: (error) {
        debugPrint('❌ [SubscriptionCredits] Error watching credits for $uid: $error');
        // Emit free tier on error
        controller.add(SubscriptionCredits.free(uid));
      },
    );

    _subscriptionsByUid[uid] = subscription;
    return controller.stream;
  }

  /// Fetch current credits snapshot (non-streaming)
  Future<SubscriptionCredits> fetchCredits(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscription')
          .doc('current')
          .get();

      if (!snapshot.exists) {
        // No subscription data - treat as zero credits
        return SubscriptionCredits.zero(uid);
      }

      final credits = SubscriptionCredits.fromFirestore(snapshot.data()!, uid);

      // Check and reset if needed
      if (credits.isPeriodExpired && credits.status == 'active') {
        return await _resetForNewPeriod(uid, credits);
      }

      return credits;
    } catch (e) {
      debugPrint('❌ [SubscriptionCredits] Error fetching credits: $e');
      return SubscriptionCredits.free(uid);
    }
  }

  /// Consume credits atomically in Firestore
  Future<SubscriptionCredits> consume({
    required String uid,
    int amount = 1,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('subscription')
          .doc('current');

      final result = await _firestore.runTransaction<SubscriptionCredits>((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (!snapshot.exists) {
          throw Exception('No subscription found');
        }

        final data = snapshot.data()!;
        final credits = SubscriptionCredits.fromFirestore(data, uid);

        // Check if period expired
        if (credits.isPeriodExpired) {
          throw Exception('Billing period expired - reset required');
        }

        // Check if enough credits available
        final remaining = credits.remaining;
        if (remaining < amount) {
          throw QuotaExceededException(
            limit: credits.monthlyAllowance,
            used: credits.consumed,
            requested: amount,
          );
        }

        // Update consumed count
        transaction.update(docRef, {
          'consumed': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Return updated credits
        return credits.copyWith(consumed: credits.consumed + amount);
      });

      debugPrint('✅ [SubscriptionCredits] Consumed $amount credits for $uid');
      return result;
    } catch (e) {
      debugPrint('❌ [SubscriptionCredits] Error consuming credits: $e');
      rethrow;
    }
  }

  /// Initialize subscription document with free tier
  Future<void> _initializeSubscription(String uid, SubscriptionCredits credits) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscription')
          .doc('current')
          .set(credits.toFirestore(), SetOptions(merge: true));
      
      debugPrint('✅ [SubscriptionCredits] Initialized subscription for $uid');
    } catch (e) {
      debugPrint('❌ [SubscriptionCredits] Error initializing subscription: $e');
    }
  }

  /// Reset credits for new billing period
  Future<SubscriptionCredits> _resetForNewPeriod(String uid, SubscriptionCredits oldCredits) async {
    try {
      final now = DateTime.now().toUtc();
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('subscription')
          .doc('current');

      // Calculate new period (1 month from old period end)
      final oldPeriodEnd = oldCredits.currentPeriodEnd;
      final newPeriodStart = oldPeriodEnd;
      final newPeriodEnd = DateTime(
        oldPeriodEnd.year,
        oldPeriodEnd.month + 1,
        oldPeriodEnd.day,
      ).toUtc();

      final newCredits = oldCredits.copyWith(
        consumed: 0,
        currentPeriodStart: newPeriodStart,
        currentPeriodEnd: newPeriodEnd,
      );

      await docRef.update({
        'consumed': 0,
        'currentPeriodStart': Timestamp.fromDate(newPeriodStart),
        'currentPeriodEnd': Timestamp.fromDate(newPeriodEnd),
        'lastSyncedFromRC': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ [SubscriptionCredits] Reset period for $uid: ${newPeriodStart.toIso8601String()} → ${newPeriodEnd.toIso8601String()}');
      return newCredits;
    } catch (e) {
      debugPrint('❌ [SubscriptionCredits] Error resetting period: $e');
      rethrow;
    }
  }

  /// Stop watching credits for a user
  void stopWatching(String uid) {
    _subscriptionsByUid[uid]?.cancel();
    _subscriptionsByUid.remove(uid);
    _controllersByUid[uid]?.close();
    _controllersByUid.remove(uid);
  }

  /// Dispose all watchers
  void dispose() {
    for (final sub in _subscriptionsByUid.values) {
      sub.cancel();
    }
    for (final controller in _controllersByUid.values) {
      controller.close();
    }
    _subscriptionsByUid.clear();
    _controllersByUid.clear();
  }
}

/// Represents subscription-based credits for a user
class SubscriptionCredits {
  final String uid;
  final String status; // 'active', 'cancelled', 'expired', 'refunded', 'free'
  final String tier; // 'premium_monthly', 'premium_annual', 'free'
  final String? productId;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final int monthlyAllowance;
  final int consumed;
  final DateTime? lastSyncedFromRC;

  SubscriptionCredits({
    required this.uid,
    required this.status,
    required this.tier,
    this.productId,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.monthlyAllowance,
    required this.consumed,
    this.lastSyncedFromRC,
  });

  factory SubscriptionCredits.zero(String uid) {
    final now = DateTime.now().toUtc();
    final periodEnd = DateTime(now.year, now.month + 1, now.day).toUtc();
    return SubscriptionCredits(
      uid: uid,
      status: 'free',
      tier: 'free',
      productId: null,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      monthlyAllowance: 0,
      consumed: 0,
      lastSyncedFromRC: null,
    );
  }

  factory SubscriptionCredits.free(String uid) {
    final now = DateTime.now().toUtc();
    final periodEnd = DateTime(now.year, now.month + 1, now.day).toUtc();
    
    return SubscriptionCredits(
      uid: uid,
      status: 'free',
      tier: 'free',
      productId: null,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      monthlyAllowance: 10,
      consumed: 0,
      lastSyncedFromRC: null,
    );
  }

  factory SubscriptionCredits.fromFirestore(Map<String, dynamic> data, String uid) {
    final periodStart = (data['currentPeriodStart'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc();
    final periodEnd = (data['currentPeriodEnd'] as Timestamp?)?.toDate() ?? 
        DateTime.now().add(const Duration(days: 30)).toUtc();
    final lastSynced = (data['lastSyncedFromRC'] as Timestamp?)?.toDate();

    return SubscriptionCredits(
      uid: uid,
      status: data['status'] as String? ?? 'free',
      tier: data['tier'] as String? ?? 'free',
      productId: data['productId'] as String?,
      currentPeriodStart: periodStart,
      currentPeriodEnd: periodEnd,
      monthlyAllowance: data['monthlyAllowance'] as int? ?? 10,
      consumed: data['consumed'] as int? ?? 0,
      lastSyncedFromRC: lastSynced,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status': status,
      'tier': tier,
      'productId': productId,
      'currentPeriodStart': Timestamp.fromDate(currentPeriodStart),
      'currentPeriodEnd': Timestamp.fromDate(currentPeriodEnd),
      'monthlyAllowance': monthlyAllowance,
      'consumed': consumed,
      'lastSyncedFromRC': lastSyncedFromRC != null 
          ? Timestamp.fromDate(lastSyncedFromRC!) 
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SubscriptionCredits copyWith({
    String? status,
    String? tier,
    String? productId,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    int? monthlyAllowance,
    int? consumed,
    DateTime? lastSyncedFromRC,
  }) {
    return SubscriptionCredits(
      uid: uid,
      status: status ?? this.status,
      tier: tier ?? this.tier,
      productId: productId ?? this.productId,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      monthlyAllowance: monthlyAllowance ?? this.monthlyAllowance,
      consumed: consumed ?? this.consumed,
      lastSyncedFromRC: lastSyncedFromRC ?? this.lastSyncedFromRC,
    );
  }

  int get remaining => (monthlyAllowance - consumed).clamp(0, monthlyAllowance);
  bool get isExceeded => remaining <= 0;
  bool get isPeriodExpired => DateTime.now().toUtc().isAfter(currentPeriodEnd);
  bool get isActive => status == 'active';
  bool get isPremium => tier.contains('premium');
  double get percentUsed => monthlyAllowance == 0 ? 1.0 : consumed / monthlyAllowance;
}

class QuotaExceededException implements Exception {
  final int limit;
  final int used;
  final int requested;

  QuotaExceededException({
    required this.limit,
    required this.used,
    required this.requested,
  });

  int get remaining => (limit - used).clamp(0, limit);

  @override
  String toString() => 'QuotaExceededException(limit: $limit, used: $used, requested: $requested)';
}
