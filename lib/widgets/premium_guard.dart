import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_access_provider.dart';
import '../screens/subscription/paywall_screen.dart';
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
    final appAccess = context.watch<AppAccessProvider>();
    final canShow = FeatureAccess.canShow(featureName);
    final isEnabled = FeatureAccess.isEnabledForUser(context, featureName);

    // Feature not visible at all
    if (!canShow) {
      return const SizedBox.shrink();
    }

    // Feature visible but not enabled (show teaser)
    if (!isEnabled) {
      return fallback ?? _buildPremiumGate(context);
    }

    // Feature enabled and user has premium access
    return child;
  }

  Widget _buildPremiumGate(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPaywall(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Premium Feature',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getFeatureDescription(featureName),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to upgrade',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const PaywallScreen(),
      ),
    );
  }

  String _getFeatureDescription(String feature) {
    switch (feature) {
      case 'search_agents':
        return 'Search agents can automatically find and analyze information from the web to answer your questions.';
      case 'knowledge_graph':
        return 'Build and explore knowledge graphs to visualize connections between concepts and ideas.';
      case 'advanced_exports':
        return 'Export your conversations and insights in multiple formats with advanced formatting options.';
      case 'bulk_operations':
        return 'Perform operations on multiple conversations and sources at once.';
      default:
        return 'This premium feature is coming soon.';
    }
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
    final isEnabled = FeatureAccess.isEnabledForUser(context, featureName);

    // Feature not visible
    if (!canShow) {
      return const SizedBox.shrink();
    }

    // Feature visible but not enabled
    if (!isEnabled) {
      return GestureDetector(
        onTap: () => _showPaywall(context),
        child: child,
      );
    }

    // Feature enabled and user has premium access
    return GestureDetector(
      onTap: onPressed,
      child: child,
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const PaywallScreen(),
      ),
    );
  }
} 