import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../providers/firebase_auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/access_service.dart';
import '../config/subscriptions_config.dart';

/// Tracks high-level access flags for the signed-in user.
///
/// Now uses RevenueCat subscription status to determine premium access.
/// Premium access is granted when user has an active RevenueCat entitlement.
class AppAccessProvider extends ChangeNotifier {
  AppAccessProvider({
    required FirebaseAuthProvider authProvider,
    required SubscriptionProvider subscriptionProvider,
  }) : _auth = authProvider,
       _subs = subscriptionProvider {
    _auth.addListener(_evaluate);
    _subs.addListener(_evaluate);
    _evaluate();
  }

  final FirebaseAuthProvider _auth;
  final SubscriptionProvider _subs;

  bool _isTester = false;
  bool _hasPremiumAccess = false;

  bool get isTester => _isTester;
  bool get hasPremiumAccess => _hasPremiumAccess;

  String? get userEmail => _auth.user?.email;

  void _evaluate() {
    // Credit-based gating: ignore subscriptions when disabled
    final hasActiveSubscription = !SubscriptionsConfig.subscriptionsEnabled
        ? true
        : _subs.isEntitled;
    
    // No tester whitelist in production
    const tester = false;

    AccessService.instance.update(hasPremium: hasActiveSubscription, isTester: tester);

    if (tester != _isTester || hasActiveSubscription != _hasPremiumAccess) {
      _isTester = tester;
      _hasPremiumAccess = hasActiveSubscription;
      notifyListeners();
      
      debugPrint('🔐 [AppAccessProvider] Access updated:');
      debugPrint('  - Has premium: $hasActiveSubscription');
      debugPrint('  - Subscription state: ${_subs.state}');
      debugPrint('  - Is tester: $tester');
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_evaluate);
    _subs.removeListener(_evaluate);
    super.dispose();
  }
}
