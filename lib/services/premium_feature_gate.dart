import 'package:flutter/widgets.dart';

/// Top-level helper used throughout the app to check premium status.
/// Premium gating has been removed; access is token-based now.
bool isPremiumUnlocked(BuildContext context, {bool listen = true}) {
  // Always return true to avoid UI gating. Request sending is governed
  // by token presence/limits elsewhere in the app.
  return true;
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
