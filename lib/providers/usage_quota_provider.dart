import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/usage_quota.dart';
import '../services/usage_quota_service.dart';
import 'firebase_auth_provider.dart';

/// Provider for user's request-based quota.
/// Backed by local storage via UsageQuotaService; independent of subscriptions.
class UsageQuotaProvider extends ChangeNotifier {
  FirebaseAuthProvider? _auth;
  StreamSubscription<UsageQuota>? _quotaSub;
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
    _startAutoRefresh();
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
    _startAutoRefresh();
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
          debugPrint('📊 [UsageQuota] ${q.requestsConsumed}/${q.totalRequests} used');
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

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    final uid = _uid;
    if (uid == null) return;
    // Immediately refresh from backend once
    UsageQuotaService.instance.refreshFromBackend(uid).catchError((_) {});
    // Then poll periodically to keep in sync with server-side changes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final currentUid = _uid;
      if (currentUid == null) return;
      UsageQuotaService.instance.refreshFromBackend(currentUid).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _quotaSub?.cancel();
    _refreshTimer?.cancel();
    _auth?.removeListener(_handleAuthChange);
    super.dispose();
  }
}
