import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/subscription_credits_service.dart';
import 'firebase_auth_provider.dart';

/// Provider for user's subscription-based credits (monthly allowance).
/// Syncs with Firestore subscription data updated by RevenueCat webhook.
/// 
/// This replaces the old SharedPreferences-based quota system with a 
/// Firestore-backed system that syncs with RevenueCat subscriptions.
class UsageQuotaProvider extends ChangeNotifier {
  FirebaseAuthProvider? _auth;
  StreamSubscription<SubscriptionCredits>? _creditsSub;

  SubscriptionCredits? _credits;
  bool _loading = false;
  Object? _error;

  SubscriptionCredits? get credits => _credits;
  bool get isLoading => _loading;
  Object? get lastError => _error;
  
  // Legacy compatibility getters (for existing UI code)
  int get remainingTokens => _credits?.remaining ?? 0;
  int get remaining => _credits?.remaining ?? 0;
  bool get isExceeded => _credits?.isExceeded ?? false;
  bool get hasQuota => remaining > 0;
  int get limit => _credits?.monthlyAllowance ?? 0;
  int get used => _credits?.consumed ?? 0;
  double get percentUsed => _credits?.percentUsed ?? 0.0;
  SubscriptionCredits? get quota => _credits; // For compatibility

  String? get _uid => _auth?.uid;

  void attach({required FirebaseAuthProvider auth}) {
    final authChanged = _auth != auth;

    if (authChanged && _auth != null) {
      _auth!.removeListener(_handleAuthChange);
    }

    _auth = auth;

    if (authChanged) {
      auth.addListener(_handleAuthChange);
    }
    _startStreamIfPossible(force: true);
  }

  Future<SubscriptionCredits?> refresh() async {
    final uid = _uid;
    if (uid == null) return null;
    
    _loading = true;
    notifyListeners();
    
    try {
      final credits = await SubscriptionCreditsService.instance.fetchCredits(uid);
      _credits = credits;
      return credits;
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SubscriptionCredits> consume({int amount = 1}) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Cannot consume credits without a signed-in user');
    }
    
    try {
      final credits = await SubscriptionCreditsService.instance.consume(
        uid: uid,
        amount: amount,
      );
      _credits = credits;
      notifyListeners();
      return credits;
    } on QuotaExceededException catch (e) {
      _error = e;
      notifyListeners();
      rethrow;
    }
  }

  // Note: Refund is not supported in the new subscription-based system
  // Credits are managed by RevenueCat subscription lifecycle
  Future<void> refund({int amount = 1}) async {
    debugPrint('⚠️ [UsageQuotaProvider] Refund not supported in subscription-based credits');
  }

  void _handleAuthChange() {
    _startStreamIfPossible(force: true);
  }

  void _startStreamIfPossible({bool force = false}) {
    final uid = _uid;
    if (uid == null) {
      _creditsSub?.cancel();
      _creditsSub = null;
      _credits = null;
      notifyListeners();
      return;
    }

    if (!force && _creditsSub != null) {
      return;
    }

    _creditsSub?.cancel();
    _creditsSub = SubscriptionCreditsService.instance
        .watchCredits(uid)
        .listen(
          (credits) {
            _credits = credits;
            _loading = false;
            _error = null;
            notifyListeners();
            
            debugPrint('📊 [UsageQuotaProvider] Credits updated:');
            debugPrint('  - Status: ${credits.status}');
            debugPrint('  - Tier: ${credits.tier}');
            debugPrint('  - Remaining: ${credits.remaining}/${credits.monthlyAllowance}');
            debugPrint('  - Period: ${credits.currentPeriodStart.toIso8601String()} → ${credits.currentPeriodEnd.toIso8601String()}');
          },
          onError: (err) {
            _error = err;
            _loading = false;
            notifyListeners();
            debugPrint('❌ [UsageQuotaProvider] Stream error: $err');
          },
        );
  }

  @override
  void dispose() {
    _creditsSub?.cancel();
    _auth?.removeListener(_handleAuthChange);
    super.dispose();
  }
}
