import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/app_access_provider.dart';
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
    final access = context.read<AppAccessProvider>();

    // Ensure auth initialized
    if (!auth.initialized && !auth.initializing) {
      await auth.initialize();
    }

    // Initialize subscription provider early, optionally with uid
    if (!subs.initialized) {
      await subs.initialize(appUserId: auth.uid);
    }

    // If already has premium access (tester or entitlement), nothing to do
    if (access.hasPremiumAccess) {
      return;
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

    // Re-evaluate after sign-in
    if (access.hasPremiumAccess) {
      return; // Tester or now entitled due to previous purchases
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

  /// Direct native purchase flow for globe tap and modal upgrade
  /// Returns true if purchase was successful, false if cancelled/failed
  static Future<bool> showNativePurchaseFlow(BuildContext context) async {
    final auth = context.read<FirebaseAuthProvider>();
    final subs = context.read<SubscriptionProvider>();

    // Ensure SubscriptionProvider is initialized (fetches offerings)
    if (!subs.initialized) {
      await subs.initialize(appUserId: auth.uid);
    } else {
      await subs.refreshOfferings();
    }

    // Sign-in gate: enforce sign-in before purchase (as per approved flow)
    if (!auth.isSignedIn) {
      await auth.signInWithGoogle();
    }
    final uid = auth.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Sign-in failed: missing UID');
    }

    // Link RC to UID
    await RevenueCatService.instance.identify(uid);

    // Refresh offerings to ensure eligibility/pricing correctness
    await subs.refreshOfferings();

    // Choose a default package (first available)
    final offerings = subs.offerings;
    final pkg = offerings?.current?.availablePackages.isNotEmpty == true
        ? offerings!.current!.availablePackages.first
        : null;
    if (pkg == null) {
      throw Exception('No packages available');
    }

    // Purchase
    final result = await RevenueCatService.instance.purchasePackage(pkg);
    if (!result.success) {
      throw Exception(result.errorMessage ?? 'Purchase failed');
    }

    // Success
    return true;
  }
}