import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/feature_flags.dart';
import 'subscription_manager.dart';

/// Service for gating premium features and managing upgrade prompts
class PremiumFeatureGate {
  static final PremiumFeatureGate _instance = PremiumFeatureGate._internal();
  factory PremiumFeatureGate() => _instance;
  PremiumFeatureGate._internal();

  final SubscriptionManager _subscriptionManager = SubscriptionManager();

  /// Check if user can access premium feature
  Future<bool> canAccess(String feature) async {
    return await _subscriptionManager.canAccessFeature(feature);
  }

  /// Show upgrade prompt for premium features
  void showUpgradePrompt(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: feature,
        price: FeatureFlags.MONTHLY_SUBSCRIPTION_PRICE,
        benefits: FeatureFlags.SUBSCRIPTION_BENEFITS,
      ),
    );
  }

  /// Wrapper widget for premium features
  Widget premiumFeatureWrapper({
    required Widget child,
    required String featureName,
    required BuildContext context,
    Widget? lockedPlaceholder,
    bool showLockIcon = true,
  }) {
    return FutureBuilder<bool>(
      future: canAccess(featureName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == true) {
          return child;
        }

        // Feature is locked - show locked state
        return _buildLockedFeature(
          context: context,
          child: lockedPlaceholder ?? child,
          featureName: featureName,
          showLockIcon: showLockIcon,
        );
      },
    );
  }

  /// Build locked feature UI
  Widget _buildLockedFeature({
    required BuildContext context,
    required Widget child,
    required String featureName,
    required bool showLockIcon,
  }) {
    return GestureDetector(
      onTap: () => showUpgradePrompt(context, featureName),
      child: Stack(
        children: [
          Opacity(
            opacity: 0.5,
            child: AbsorbPointer(child: child),
          ),
          if (showLockIcon)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Check feature access and execute callback if allowed
  Future<void> executeIfAllowed({
    required String featureName,
    required BuildContext context,
    required VoidCallback onAllowed,
    VoidCallback? onDenied,
  }) async {
    final hasAccess = await canAccess(featureName);
    
    if (hasAccess) {
      onAllowed();
    } else {
      if (onDenied != null) {
        onDenied();
      } else {
        showUpgradePrompt(context, featureName);
      }
    }
  }

  /// Get feature display name for UI
  String getFeatureDisplayName(String featureName) {
    switch (featureName) {
      case FeatureFlags.FEATURE_WEB_SEARCH:
        return 'Web Search Integration';
      case FeatureFlags.FEATURE_INTERNET_GLOBE:
        return 'Online Mode Toggle';
      case FeatureFlags.FEATURE_TRENDING_TOPICS:
        return 'Trending Topics';
      case FeatureFlags.FEATURE_EXPORT:
        return 'Export Features';
      case FeatureFlags.FEATURE_CUSTOM_THEMES:
        return 'Custom Themes';
      case FeatureFlags.FEATURE_PRIORITY_SUPPORT:
        return 'Priority Support';
      default:
        return featureName.replaceAll('_', ' ').toUpperCase();
    }
  }
}

/// Dialog for prompting users to upgrade to premium
class UpgradePromptDialog extends StatelessWidget {
  final String feature;
  final double price;
  final String benefits;

  const UpgradePromptDialog({
    super.key,
    required this.feature,
    required this.price,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    final featureGate = PremiumFeatureGate();
    final featureDisplayName = featureGate.getFeatureDisplayName(feature);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.star, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unlock $featureDisplayName',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This feature is available in the Premium version.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Premium Benefits:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(benefits),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.price_check,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Only \$${price.toStringAsFixed(2)}/month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showSubscriptionScreen(context);
          },
          child: const Text('Upgrade Now'),
        ),
      ],
    );
  }

  void _showSubscriptionScreen(BuildContext context) {
    // Navigate to subscription screen
    context.push('/subscription');
  }
}

/// Mixin for widgets that need premium feature gating
mixin PremiumFeatureMixin {
  PremiumFeatureGate get featureGate => PremiumFeatureGate();

  /// Wrap a widget with premium feature gating
  Widget withPremiumGate({
    required Widget child,
    required String featureName,
    required BuildContext context,
    Widget? lockedPlaceholder,
    bool showLockIcon = true,
  }) {
    return featureGate.premiumFeatureWrapper(
      child: child,
      featureName: featureName,
      context: context,
      lockedPlaceholder: lockedPlaceholder,
      showLockIcon: showLockIcon,
    );
  }

  /// Check if feature is accessible
  Future<bool> canAccessFeature(String featureName) {
    return featureGate.canAccess(featureName);
  }

  /// Show upgrade prompt
  void showUpgrade(BuildContext context, String featureName) {
    featureGate.showUpgradePrompt(context, featureName);
  }
}
