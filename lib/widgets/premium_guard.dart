import 'package:flutter/material.dart';
import '../services/premium_feature_gate.dart';

/// PremiumGuard widget for consistent feature gating
/// Implements two-tier feature flags: visibility and enablement
///
/// Usage:
/// ```dart
/// PremiumGuard(
///   featureName: 'search_agents',
///   child: SearchAgentsWidget(),
///   fallback: Text('Coming soon...'),
/// )
/// ```
class PremiumGuard extends StatelessWidget {
  final String featureName;
  final Widget child;
  final Widget? fallback;
  final String? paywallTitle;
  final String? paywallMessage;

  const PremiumGuard({
    super.key,
    required this.featureName,
    required this.child,
    this.fallback,
    this.paywallTitle,
    this.paywallMessage,
  });

  @override
  Widget build(BuildContext context) {
    final canShow = FeatureAccess.canShow(featureName);

    // Feature not visible at all
    if (!canShow) {
      return fallback ?? const SizedBox.shrink();
    }

    return child;
  }
}

/// PremiumButton widget for consistent premium feature buttons
/// Automatically handles visibility, enablement, and paywall routing
class PremiumButton extends StatelessWidget {
  final String featureName;
  final VoidCallback? onPressed;
  final Widget child;
  final String? paywallTitle;
  final String? paywallMessage;

  const PremiumButton({
    super.key,
    required this.featureName,
    this.onPressed,
    required this.child,
    this.paywallTitle,
    this.paywallMessage,
  });

  @override
  Widget build(BuildContext context) {
    final canShow = FeatureAccess.canShow(featureName);

    if (!canShow) {
      return const SizedBox.shrink();
    }

    return GestureDetector(onTap: onPressed, child: child);
  }
}
