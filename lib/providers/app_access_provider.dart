import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../config/tester_whitelist.dart';
import '../providers/firebase_auth_provider.dart';
import '../providers/subscription_provider.dart';

/// AppAccessProvider()
/// Single source of truth for premium access:
/// hasPremiumAccess = isTester (email whitelist) OR RevenueCat entitlement.
/// Fails closed when subscription state is unknown (i.e., locked by default).
class AppAccessProvider extends ChangeNotifier {
  AppAccessProvider({
    required FirebaseAuthProvider authProvider,
    required SubscriptionProvider subscriptionProvider,
  })  : _auth = authProvider,
        _subs = subscriptionProvider {
    // Listen for auth and subscription changes to re-evaluate access.
    _auth.addListener(_evaluate);
    _subs.addListener(_evaluate);
    _evaluate();
  }

  final FirebaseAuthProvider _auth;
  final SubscriptionProvider _subs;

  bool _isTester = false;
  bool _hasPremiumAccess = false; // true only for tester or active entitlement

  bool get isTester => _isTester;
  bool get hasPremiumAccess => _hasPremiumAccess;

  String? get userEmail => _auth.user?.email;

  // Features are gated by default when subscription state is unknown.
  // Testers always allowed regardless of RC state.
  void _evaluate() {
    final email = _auth.user?.email;
    final tester = TesterWhitelist.isTesterEmail(email);

    // Determine entitlement-based access using tri-state
    final subsState = _subs.state; // unknown | inactive | active
    final entitled = subsState == SubscriptionState.active;

    final newTester = tester;
    final newHasPremium = tester || entitled; // testers always allowed

    if (newTester != _isTester || newHasPremium != _hasPremiumAccess) {
      _isTester = newTester;
      _hasPremiumAccess = newHasPremium;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_evaluate);
    _subs.removeListener(_evaluate);
    super.dispose();
  }
}