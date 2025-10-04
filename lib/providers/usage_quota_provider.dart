import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/usage_quota.dart';
import '../services/usage_quota_service.dart';
import 'firebase_auth_provider.dart';

/// Exposes realtime usage token information for the signed-in user.
class UsageQuotaProvider extends ChangeNotifier {
  FirebaseAuthProvider? _auth;
  StreamSubscription<UsageQuota>? _subscription;

  UsageQuota? _current;
  bool _loading = false;
  Object? _error;

  UsageQuota? get quota => _current;
  bool get isLoading => _loading;
  Object? get lastError => _error;
  bool get isExceeded => _current?.isExceeded ?? false;
  int get remainingTokens => _current?.remaining ?? 0;

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

  Future<UsageQuota?> refresh() async {
    final uid = _uid;
    if (uid == null) return null;
    _loading = true;
    notifyListeners();
    try {
      final quota = await UsageQuotaService.instance.fetchQuota(uid);
      _current = quota;
      return quota;
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
      final quota = await UsageQuotaService.instance.consume(
        uid: uid,
        amount: amount,
      );
      _current = quota;
      notifyListeners();
      return quota;
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
  }

  void _handleAuthChange() {
    _startStreamIfPossible(force: true);
  }

  void _startStreamIfPossible({bool force = false}) {
    final uid = _uid;
    if (uid == null) {
      _subscription?.cancel();
      _subscription = null;
      _current = null;
      notifyListeners();
      return;
    }

    if (!force && _subscription != null) {
      return;
    }

    _subscription?.cancel();
    _subscription = UsageQuotaService.instance
        .watchQuota(uid)
        .listen(
          (quota) {
            _current = quota;
            _loading = false;
            _error = null;
            notifyListeners();
          },
          onError: (err) {
            _error = err;
            _loading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _auth?.removeListener(_handleAuthChange);
    super.dispose();
  }
}
