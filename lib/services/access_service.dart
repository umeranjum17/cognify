import 'package:flutter/foundation.dart';

/// Simple access flags singleton used by various UI gates.
class AccessService {
  AccessService._internal();
  static final AccessService instance = AccessService._internal();

  /// Whether the user has premium/unlocked access (token system now default true).
  bool hasPremium = true;

  /// Whether the user is a tester (bypasses some limits during development).
  bool isTester = false;

  /// Update flags atomically.
  void update({bool? hasPremium, bool? isTester}) {
    if (hasPremium != null) this.hasPremium = hasPremium;
    if (isTester != null) this.isTester = isTester;
    if (kDebugMode) {
      // Lightweight log for debugging
      // ignore: avoid_print
      print('AccessService.update(hasPremium: ${this.hasPremium}, isTester: ${this.isTester})');
    }
  }
}

