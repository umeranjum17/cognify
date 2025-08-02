import 'package:flutter/foundation.dart';

/// Configuration service for managing app settings
class ConfigService {
  /// Check if we're in debug mode
  static bool get isDebug => kDebugMode;

  /// Check if we're running on web platform
  static bool get isWeb => kIsWeb;

  /// Get the Mermaid API base URL (no longer used - app is standalone)
  static String get mermaidApiUrl => '';

  /// Get the appropriate server URL (no longer used - app is standalone)
  static String get serverUrl => '';
}
