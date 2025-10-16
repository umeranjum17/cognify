import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/usage_quota.dart';
import '../services/usage_quota_service.dart';
import '../services/credit_event_service.dart';
import 'firebase_auth_provider.dart';

/// Provider for user's request-based quota.
/// Backed by local storage via UsageQuotaService; independent of subscriptions.
class UsageQuotaProvider extends ChangeNotifier {
  FirebaseAuthProvider? _auth;
  StreamSubscription<UsageQuota>? _quotaSub;
  StreamSubscription<CreditEvent>? _creditEventSub;
  Timer? _refreshTimer;

  UsageQuota? _quota;
  bool _loading = false;
  Object? _error;

  UsageQuota? get quota => _quota;
  bool get isLoading => _loading;
  Object? get lastError => _error;

  // Compatibility getters for existing UI
  int get remainingTokens => _quota?.remaining ?? 0;
  int get remaining => _quota?.remaining ?? 0;
  bool get isExceeded => _quota?.isExceeded ?? false;
  bool get hasQuota => remaining > 0;
  int get limit => _quota?.limit ?? 0;
  int get used => _quota?.tokensConsumed ?? 0;
  double get percentUsed => _quota?.percentUsed ?? 0.0;

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
    _startEventDrivenUpdates();
  }

  Future<UsageQuota?> refresh() async {
    final uid = _uid;
    if (uid == null) return null;
    _loading = true;
    notifyListeners();
    try {
      final q = await UsageQuotaService.instance.fetchQuota(uid);
      _quota = q;
      return q;
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<UsageQuota> consume({int amount = 1}) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Cannot consume quota without a signed-in user');
    }
    try {
      final q = await UsageQuotaService.instance.consume(uid: uid, amount: amount);
      _quota = q;
      notifyListeners();
      return q;
    } on QuotaExceededException catch (e) {
      _error = e;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refund({int amount = 1}) async {
    final uid = _uid;
    if (uid == null) return;
    await UsageQuotaService.instance.refund(uid: uid, amount: amount);
    // Stream will update quota
  }

  void _handleAuthChange() {
    _startStreamIfPossible(force: true);
    _startEventDrivenUpdates();
  }

  void _startStreamIfPossible({bool force = false}) {
    final uid = _uid;
    if (uid == null) {
      _quotaSub?.cancel();
      _quotaSub = null;
      _quota = null;
      _refreshTimer?.cancel();
      notifyListeners();
      return;
    }
    if (!force && _quotaSub != null) {
      return;
    }
    _quotaSub?.cancel();
    _quotaSub = UsageQuotaService.instance.watchQuota(uid).listen(
      (q) {
        _quota = q;
        _loading = false;
        _error = null;
        notifyListeners();
        if (kDebugMode) {
          // Backend sync gives us remaining balance; log remaining for clarity
          debugPrint('📊 [UsageQuota] remaining: ${q.remaining}');
        }
      },
      onError: (err) {
        _error = err;
        _loading = false;
        notifyListeners();
        debugPrint('❌ [UsageQuota] Stream error: $err');
      },
    );
  }

  void _startEventDrivenUpdates() {
    _creditEventSub?.cancel();
    _refreshTimer?.cancel();
    
    final uid = _uid;
    if (uid == null) return;
    
    // Immediately refresh from backend once
    UsageQuotaService.instance.refreshFromBackend(uid).catchError((_) {});
    
    // Listen to credit events for real-time updates
    _creditEventSub = CreditEventService.instance.events.listen((event) {
      final currentUid = _uid;
      if (currentUid == null) {
        debugPrint('❌ [UsageQuota] No user ID available for credit event: ${event.type.name}');
        return;
      }
      
      debugPrint('📨 [UsageQuota] Received credit event: ${event.type.name}');
      
      // Refresh credits on relevant events
      switch (event.type) {
        case CreditEventType.messageConsumed:
        case CreditEventType.messageCompleted:
        case CreditEventType.creditsPurchased:
        case CreditEventType.creditsRefunded:
          debugPrint('🔄 [UsageQuota] Refreshing credits due to ${event.type.name} event');
          // Force immediate refresh and UI update
          UsageQuotaService.instance.refreshFromBackend(currentUid).then((quota) {
            debugPrint('✅ [UsageQuota] Backend refresh completed: ${quota.remaining} credits remaining');
            // Trigger a manual refresh to ensure UI updates
            refresh();
            debugPrint('✅ [UsageQuota] Manual refresh completed');
          }).catchError((error) {
            debugPrint('❌ [UsageQuota] Failed to refresh from backend: $error');
          });
          break;
        case CreditEventType.chatOpened:
        case CreditEventType.sessionReset:
          // These events don't require immediate refresh, but we can refresh
          // to ensure we have the latest data when opening a new chat
          debugPrint('ℹ️ [UsageQuota] Event ${event.type.name} received but no immediate refresh needed');
          break;
      }
    });
    
    // Keep a minimal fallback polling (every 5 minutes instead of 30 seconds)
    // This is just a safety net in case events are missed
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final currentUid = _uid;
      if (currentUid == null) return;
      debugPrint('🔄 [UsageQuota] Fallback refresh from backend');
      UsageQuotaService.instance.refreshFromBackend(currentUid).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _quotaSub?.cancel();
    _creditEventSub?.cancel();
    _refreshTimer?.cancel();
    _auth?.removeListener(_handleAuthChange);
    super.dispose();
  }
}
