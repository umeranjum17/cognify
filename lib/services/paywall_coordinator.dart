import 'package:flutter/material.dart';

/// Minimal PaywallCoordinator stub to satisfy references.
class PaywallCoordinator {
  /// Show a native purchase flow.
  /// Returns true if the user completed a purchase.
  static Future<bool> showNativePurchaseFlow(BuildContext context) async {
    // Minimal UX: show a dialog that informs the user this is a stub.
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: const Text(
          'Purchase flow is not configured in this build.\n\n'
          'You can continue exploring all features freely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

