import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

// Conditional import to access window.location only on web builds.
import 'src/web_location_stub.dart'
    if (dart.library.html) 'src/web_location_web.dart';

/// EnvironmentService
/// Detects current runtime environment and generates appropriate callback URLs.
/// On web: extracts scheme+host+port from window.location (via conditional import).
/// On mobile/desktop: returns configured custom scheme base (e.g., cognify://).
class EnvironmentService {
  // Whitelisted base origins. Extend with your production domains when needed.
  static const List<String> allowedOrigins = <String>[
    'http://localhost',
    'https://localhost',
    'http://127.0.0.1',
    'https://127.0.0.1',
    // Add production domains here, e.g.:
    // 'https://app.yourdomain.com',
  ];

  /// Returns the current origin (scheme://host[:port]) for web,
  /// or the app's custom scheme for mobile/desktop.
  static String getCurrentOrigin() {
    if (kIsWeb) {
      final wl = const WebLocation();
      return wl.origin;
    }
    // For native platforms, route back using custom URL schemes handled by App Links/Deep Links.
    // Adjust to your actual scheme(s).
    return 'cognify';
  }

  /// Returns true if we are in development (localhost/127.0.0.1 on web, or debug mode natively).
  static bool isDevelopment() {
    if (kIsWeb) {
      final wl = const WebLocation();
      final o = wl.origin;
      return o.contains('localhost') || o.contains('127.0.0.1');
    }
    return kDebugMode;
  }

  /// Returns the port on web if present, otherwise null.
  static int? getCurrentPort() {
    if (kIsWeb) {
      final wl = const WebLocation();
      final p = wl.port;
      return p.isEmpty ? null : int.tryParse(p);
    }
    return null;
  }

  /// Validates that an origin is allowed (prefix match with whitelist).
  static bool isOriginAllowed(String origin) {
    return allowedOrigins.any((allowed) => origin.startsWith(allowed));
  }

  /// Returns the OAuth callback path for the current platform.
  static String getCallbackPath() {
    if (kIsWeb) {
      return '/oauth/callback';
    }
    // Native platforms use scheme://host/path; we only return path here
    // and getCurrentOrigin() returns the scheme (e.g., cognify).
    return '://oauth/callback';
  }

  /// Builds a full callback URL for the current environment.
  /// Web: {origin}/oauth/callback
  /// Native: {scheme}://oauth/callback
  static String generateCallbackUrl() {
    final origin = getCurrentOrigin();
    final path = getCallbackPath();
    return '$origin$path';
  }
}