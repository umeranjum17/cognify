// Legacy premium gate now acting as a thin feature-flag wrapper.
// Premium subscriptions have been replaced with a token-based system, so all
// entitlement checks return true when the feature is discoverable.

import 'package:flutter/material.dart';

import '../config/feature_flags.dart';

/// FeatureAccess - Unified feature access control
/// Centralized logic to answer "can show?" and "can execute?" for a feature name
/// Provides both context-aware (UI) and context-free (backend) variants
class FeatureAccess {
  /// Check if a feature should be discoverable/visible in UI
  /// Uses FeatureFlags to determine kill switch (discoverability)
  static bool canShow(String featureName) {
    return FeatureFlags.canShowFeature(featureName);
  }

  /// Check if a feature is enabled for the current user (UI context)
  /// Returns true if canShow(featureName) is true AND the user is entitled
  static bool isEnabledForUser(BuildContext context, String featureName) {
    if (!canShow(featureName)) return false;
    return true;
  }

  /// Check if a feature is enabled (backend context-free)
  /// Same as isEnabledForUser but accepts entitlement boolean directly
  static bool isEnabled(bool isEntitled, String featureName) {
    if (!canShow(featureName)) return false;
    return true;
  }

  /// Guard an action with feature access control
  /// Executes action if isEnabledForUser is true
  /// Otherwise triggers paywall flow, returns false
  static Future<bool> guardAction(
    BuildContext context,
    String featureName,
    VoidCallback action,
  ) async {
    if (!canShow(featureName)) {
      return false;
    }
    action();
    return true;
  }
}

/// isPremiumUnlocked()
/// Tiny helper for widgets/viewmodels to gate UI or actions.
/// Testers are already accounted for via AppAccessProvider.hasPremiumAccess.
bool isPremiumUnlocked(BuildContext context, {bool listen = true}) => true;

/// PremiumTier()
/// Extensible enum for future tiers/entitlements. Currently a single 'premium' tier.
enum PremiumTier { premium }

/// PremiumRequirement()
/// Wrapper to describe what entitlements/tiers are required.
/// Can be extended later for per-feature entitlements or multiple tiers.
class PremiumRequirement {
  final PremiumTier tier;
  const PremiumRequirement({this.tier = PremiumTier.premium});
}

/// PremiumGuard()
/// Wrap a screen/body with this to enforce premium access.
/// When locked, it redirects to /paywall by default, or shows [lockedBuilder] if provided.
class PremiumGuard extends StatelessWidget {
  final Widget child;
  final PremiumRequirement requirement;
  final WidgetBuilder? lockedBuilder;
  final bool redirectToPaywall;

  const PremiumGuard({
    super.key,
    required this.child,
    this.requirement = const PremiumRequirement(),
    this.lockedBuilder,
    this.redirectToPaywall = true,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// premiumGuardAction()
/// Wrap any feature action with this guard. If locked, navigates to /paywall.
/// Returns true if the action was executed, false if redirected.
Future<bool> premiumGuardAction(
  BuildContext context,
  VoidCallback action, {
  PremiumRequirement requirement = const PremiumRequirement(),
  bool redirectToPaywall = true,
}) async {
  action();
  return true;
}
