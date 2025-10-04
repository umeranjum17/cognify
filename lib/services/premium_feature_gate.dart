import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/app_access_provider.dart';

/// Top-level helper used throughout the app to check premium status.
bool isPremiumUnlocked(BuildContext context, {bool listen = true}) {
  try {
    final access = Provider.of<AppAccessProvider>(context, listen: listen);
    return access.hasPremiumAccess;
  } catch (_) {
    // If provider isn't available in the tree, default to unlocked
    return true;
  }
}

/// Feature visibility/enablement helper for UI gating.
class FeatureAccess {
  /// Whether a feature should be visible in the UI.
  static bool canShow(String featureName) {
    // All features visible by default; integrate flags here if needed.
    return true;
  }

  /// Whether a feature is enabled for the current user.
  static bool isEnabledForUser(BuildContext context, String featureName) {
    return isPremiumUnlocked(context, listen: true);
  }
}

