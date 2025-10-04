import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../config/tester_whitelist.dart';
import '../providers/firebase_auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/access_service.dart';

/// Tracks high-level access flags for the signed-in user.
///
/// Premium subscriptions have been sunset in favour of a token-based system,
/// so `hasPremiumAccess` now defaults to true for all authenticated users.
/// Testers remain whitelisted for internal tooling/experiments.
class AppAccessProvider extends ChangeNotifier {
  AppAccessProvider({
    required FirebaseAuthProvider authProvider,
    required SubscriptionProvider subscriptionProvider,
  })  : _auth = authProvider,
        _subs = subscriptionProvider {
    _auth.addListener(_evaluate);
    _subs.addListener(_evaluate);
    _evaluate();
  }

  final FirebaseAuthProvider _auth;
  final SubscriptionProvider _subs;

  bool _isTester = false;
  bool _hasPremiumAccess = true;

  bool get isTester => _isTester;
  bool get hasPremiumAccess => _hasPremiumAccess;

  String? get userEmail => _auth.user?.email;

  void _evaluate() {
    final email = _auth.user?.email;
    final tester = TesterWhitelist.isTesterEmail(email);

    // Tokens-based access is universal; testers still surfaced for diagnostics.
    const hasAccess = true;

    AccessService.instance.update(
      hasPremium: hasAccess,
      isTester: tester,
    );

    if (tester != _isTester || hasAccess != _hasPremiumAccess) {
      _isTester = tester;
      _hasPremiumAccess = hasAccess;
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
