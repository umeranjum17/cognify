import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/firebase_auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/revenuecat_service.dart';

/// PaywallCoordinator()
class PaywallCoordinator {
  const PaywallCoordinator();

  /// Ensure the flow to get user premium:
  /// 1) If not signed in -> navigate to /sign-in
  /// 2) After sign-in -> fetch offerings and show paywall screen
  /// 3) On purchase success -> refresh entitlements and return
  Future<void> ensurePremiumFlow(BuildContext context) async {
    final auth = context.read<FirebaseAuthProvider>();
    final subs = context.read<SubscriptionProvider>();

    // Ensure auth initialized
    if (!auth.initialized && !auth.initializing) {
      await auth.initialize();
    }

    // Already premium -> nothing to do
    if (subs.initialized && subs.isEntitled) {
      return;
    }

    // Initialize subscription provider early, optionally with uid
    if (!subs.initialized) {
      await subs.initialize(appUserId: auth.uid);
    }

    // If not signed in -> route to sign-in first
    if (!auth.isSignedIn) {
      await Navigator.of(context).pushNamed('/sign-in');

      // Re-check auth state
      if (!auth.isSignedIn) {
        // User canceled
        return;
      }

      // Link RevenueCat to UID
      final uid = auth.uid;
      if (uid != null && uid.isNotEmpty) {
        await RevenueCatService.instance.identify(uid);
      }
    }

    // Fetch offerings
    await subs.refreshOfferings();

    // Navigate to paywall
    await Navigator.of(context).pushNamed('/paywall');

    // After returning from paywall, refresh entitlements
    await _refreshEntitlements(subs);
  }

  Future<void> _refreshEntitlements(SubscriptionProvider subs) async {
    try {
      final info = await Purchases.getCustomerInfo();
      // This will notify via the stream listener inside provider
      // Additionally, force internal state update:
      if (info.entitlements.active.isNotEmpty) {
        // no-op: stream will trigger provider updates
      }
    } catch (e) {
      debugPrint('Failed to refresh entitlements: $e');
    }
  }
}