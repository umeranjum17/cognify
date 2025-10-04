import 'dart:io' show Platform;
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
    debugPrint('🔓 Premium flow disabled: token-based access is now default.');
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
    debugPrint(
      '🛒 Purchases disabled: premium subscriptions replaced by tokens.',
    );
    return false;
  }
}
