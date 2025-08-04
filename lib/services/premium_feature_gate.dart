// A reusable, extensible premium gate for both screens and feature actions.
// It relies on AppAccessProvider.hasPremiumAccess and routes to /paywall when locked.
//
// Helper API isPremiumUnlocked() provides a simple check for UI to gate features.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_access_provider.dart';

/// isPremiumUnlocked()
/// Tiny helper for widgets/viewmodels to gate UI or actions.
/// Testers are already accounted for via AppAccessProvider.hasPremiumAccess.
bool isPremiumUnlocked(BuildContext context, {bool listen = true}) {
  final access = listen
      ? context.watch<AppAccessProvider>().hasPremiumAccess
      : context.read<AppAccessProvider>().hasPremiumAccess;
  return access;
}

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
    final access = context.watch<AppAccessProvider>().hasPremiumAccess;

    if (access) {
      return child;
    }

    // If a locked builder is provided, show it to allow custom UI.
    if (lockedBuilder != null) {
      return lockedBuilder!(context);
    }

    // Default behavior: redirect to paywall and render a minimal placeholder.
    if (redirectToPaywall) {
      // Using addPostFrameCallback to avoid calling Navigator during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pushNamed('/paywall');
        } else {
          Navigator.of(context).pushReplacementNamed('/paywall');
        }
      });
    }

    // Placeholder while navigating
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// premiumGuardAction()
/// Wrap any feature action with this guard. If locked, navigates to /paywall.
/// Returns true if the action was executed, false if redirected.
Future<bool> premiumGuardAction(BuildContext context, VoidCallback action,
    {PremiumRequirement requirement = const PremiumRequirement(),
    bool redirectToPaywall = true}) async {
  final access = context.read<AppAccessProvider>().hasPremiumAccess;
  if (access) {
    action();
    return true;
  }
  if (redirectToPaywall) {
    Navigator.of(context).pushNamed('/paywall');
  }
  return false;
}
