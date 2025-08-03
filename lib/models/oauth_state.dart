import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

import '../services/environment_service.dart';

/// Enhanced OAuth state that encodes the initiator's origin for dynamic callbacks.
class OAuthState {
  final String randomState; // cryptographically random
  final String origin; // scheme://host[:port] or custom scheme (e.g., cognify)
  final int timestamp; // ms since epoch
  final String version; // schema version
  final String platform; // web/android/ios/windows/macos/linux/unknown

  const OAuthState({
    required this.randomState,
    required this.origin,
    required this.timestamp,
    required this.version,
    required this.platform,
  });

  factory OAuthState.fromCurrentEnvironment({
    required String randomState,
    String version = '1.0',
  }) {
    return OAuthState(
      randomState: randomState,
      origin: EnvironmentService.getCurrentOrigin(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      version: version,
      platform: _currentPlatform(),
    );
  }

  Map<String, dynamic> toJson() => {
        'randomState': randomState,
        'origin': origin,
        'timestamp': timestamp,
        'version': version,
        'platform': platform,
      };

  factory OAuthState.fromJson(Map<String, dynamic> json) {
    return OAuthState(
      randomState: json['randomState'] as String,
      origin: json['origin'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
      version: (json['version'] as String?) ?? '1.0',
      platform: (json['platform'] as String?) ?? 'unknown',
    );
  }

  /// Base64URL encode for transport in OAuth "state" param
  String encode() {
    final jsonString = jsonEncode(toJson());
    final bytes = utf8.encode(jsonString);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decode Base64URL encoded state
  static OAuthState? decode(String encoded) {
    try {
      var padded = encoded.replaceAll('-', '+').replaceAll('_', '/');
      // pad with '=' to make length % 4 == 0
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      final bytes = base64.decode(padded);
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return OAuthState.fromJson(map);
    } catch (e) {
      debugPrint('OAuthState.decode error: $e');
      return null;
    }
  }

  /// Validate timestamp window and allowed origins.
  bool isValid({
    Duration maxAge = const Duration(minutes: 10),
    List<String>? extraAllowedOrigins,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > maxAge.inMilliseconds) {
      return false;
    }

    // Merge allowed origins
    final allowed = <String>[
      ...EnvironmentService.allowedOrigins,
      if (extraAllowedOrigins != null) ...extraAllowedOrigins,
    ];

    final ok = allowed.any((a) => origin.startsWith(a));
    return ok;
  }

  /// Compute callback URL from this state context
  String callbackUrl() {
    final path = EnvironmentService.getCallbackPath();
    return '$origin$path';
  }

  static String _currentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  @override
  String toString() {
    final rs = randomState.length > 8 ? '${randomState.substring(0, 8)}...' : randomState;
    return 'OAuthState(randomState=$rs, origin=$origin, ts=$timestamp, ver=$version, pf=$platform)';
  }

  /// Create a copy of this OAuthState with the given fields replaced by new values.
  OAuthState copyWith({
    String? randomState,
    String? origin,
    int? timestamp,
    String? version,
    String? platform,
  }) {
    return OAuthState(
      randomState: randomState ?? this.randomState,
      origin: origin ?? this.origin,
      timestamp: timestamp ?? this.timestamp,
      version: version ?? this.version,
      platform: platform ?? this.platform,
    );
  }
}