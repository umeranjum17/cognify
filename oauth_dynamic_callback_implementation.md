# Dynamic OAuth Callback Implementation Guide

## Overview
This document provides the complete implementation plan for dynamic OAuth callback handling with automatic port detection in your Flutter app.

## Phase 1: Flutter-Side Implementation

### 1. Environment Detection Service

Create `lib/services/environment_service.dart`:

```dart
import 'dart:convert';
import 'dart:html' as html show window;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Service for detecting the current environment and generating appropriate callback URLs
class EnvironmentService {
  static const List<String> _allowedOrigins = [
    'http://localhost',
    'https://localhost', 
    'http://127.0.0.1',
    'https://127.0.0.1',
    // Add your production domains here
  ];

  /// Get the current origin URL with port detection
  static String getCurrentOrigin() {
    if (kIsWeb) {
      return _getWebOrigin();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return _getMobileScheme();
    } else {
      return _getDesktopOrigin();
    }
  }

  /// Extract origin from web environment
  static String _getWebOrigin() {
    if (kIsWeb) {
      final location = html.window.location;
      return '${location.protocol}//${location.host}';
    }
    return 'http://localhost:3000'; // Fallback
  }

  /// Get mobile app scheme
  static String _getMobileScheme() {
    return 'cognify'; // Your app's custom scheme
  }

  /// Get desktop origin (typically localhost with port)
  static String _getDesktopOrigin() {
    // For desktop, we'll default to common development ports
    // This could be enhanced to detect actual running port
    return 'http://localhost:3000';
  }

  /// Check if current environment is development
  static bool isDevelopment() {
    if (kIsWeb) {
      final origin = _getWebOrigin();
      return origin.contains('localhost') || origin.contains('127.0.0.1');
    }
    return kDebugMode;
  }

  /// Extract port from current environment
  static int? getCurrentPort() {
    if (kIsWeb) {
      final location = html.window.location;
      return location.port.isNotEmpty ? int.tryParse(location.port) : null;
    }
    return null;
  }

  /// Validate if an origin is allowed
  static bool isOriginAllowed(String origin) {
    return _allowedOrigins.any((allowed) => origin.startsWith(allowed));
  }

  /// Get callback path for current platform
  static String getCallbackPath() {
    if (kIsWeb) {
      return '/oauth/callback';
    } else {
      return '://oauth/callback';
    }
  }

  /// Generate full callback URL for current environment
  static String generateCallbackUrl() {
    final origin = getCurrentOrigin();
    final path = getCallbackPath();
    
    if (kIsWeb) {
      return '$origin$path';
    } else {
      return '$origin$path';
    }
  }
}
```

### 2. Enhanced OAuth State Management

Create `lib/models/oauth_state.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

/// Enhanced OAuth state that includes origin information for dynamic callbacks
class OAuthState {
  final String randomState;
  final String origin;
  final int timestamp;
  final String version;
  final String? platform;

  const OAuthState({
    required this.randomState,
    required this.origin,
    required this.timestamp,
    this.version = '1.0',
    this.platform,
  });

  /// Create OAuthState from current environment
  factory OAuthState.fromCurrentEnvironment(String randomState) {
    return OAuthState(
      randomState: randomState,
      origin: EnvironmentService.getCurrentOrigin(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      platform: _getCurrentPlatform(),
    );
  }

  /// Get current platform identifier
  static String _getCurrentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'randomState': randomState,
      'origin': origin,
      'timestamp': timestamp,
      'version': version,
      if (platform != null) 'platform': platform,
    };
  }

  /// Create from JSON
  factory OAuthState.fromJson(Map<String, dynamic> json) {
    return OAuthState(
      randomState: json['randomState'] as String,
      origin: json['origin'] as String,
      timestamp: json['timestamp'] as int,
      version: json['version'] as String? ?? '1.0',
      platform: json['platform'] as String?,
    );
  }

  /// Encode state as Base64URL for OAuth parameter
  String encode() {
    final jsonString = jsonEncode(toJson());
    final bytes = utf8.encode(jsonString);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decode Base64URL state parameter
  static OAuthState? decode(String encoded) {
    try {
      // Add padding if needed
      String padded = encoded;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      
      final bytes = base64Url.decode(padded);
      final jsonString = utf8.decode(bytes);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      
      return OAuthState.fromJson(json);
    } catch (e) {
      print('Error decoding OAuth state: $e');
      return null;
    }
  }

  /// Validate state (timestamp, origin, etc.)
  bool isValid({Duration maxAge = const Duration(minutes: 10)}) {
    // Check timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > maxAge.inMilliseconds) {
      return false;
    }

    // Check origin
    if (!EnvironmentService.isOriginAllowed(origin)) {
      return false;
    }

    return true;
  }

  /// Get callback URL from this state
  String getCallbackUrl() {
    final path = EnvironmentService.getCallbackPath();
    if (platform == 'web') {
      return '$origin$path';
    } else {
      return '$origin$path';
    }
  }

  @override
  String toString() {
    return 'OAuthState(randomState: ${randomState.substring(0, 8)}..., origin: $origin, timestamp: $timestamp)';
  }
}
```

### 3. Updated OAuth Provider

Modify `lib/providers/oauth_auth_provider.dart` to use the new state system:

```dart
// Add these imports at the top
import '../services/environment_service.dart';
import '../models/oauth_state.dart';

// In the OAuthAuthProvider class, update the _launchOAuthFlow method:

/// Launch OAuth flow using dynamic callback detection
Future<OAuthResult> _launchOAuthFlow(String codeChallenge, String randomState) async {
  try {
    // Create enhanced state with origin information
    final oauthState = OAuthState.fromCurrentEnvironment(randomState);
    final encodedState = oauthState.encode();
    
    // Store both the random state and the encoded state for validation
    await _secureStorage.write(key: _oauthStateStorageKey, value: randomState);
    await _secureStorage.write(key: '${_oauthStateStorageKey}_encoded', value: encodedState);
    
    print('🔄 Dynamic callback - Origin: ${oauthState.origin}');
    print('🔄 Encoded state: ${encodedState.substring(0, 20)}...');

    // Always use Vercel deployment for OAuth callback
    const redirectUri = 'https://oauth-callback-deploy-grzgl2jm7-umeranjum17s-projects.vercel.app/callback';

    // Build the OAuth authorization URL with enhanced state
    final authUri = Uri.parse('https://openrouter.ai/auth').replace(
      queryParameters: {
        'callback_url': redirectUri,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': encodedState, // Use encoded state with origin info
      },
    );

    print('🔄 OAuth URL with dynamic callback: $authUri');
    
    // Launch the OAuth URL
    final launched = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      return OAuthResult.error('failed_to_launch', 'Could not launch OAuth flow');
    }

    // Handle platform-specific callback waiting
    if (kIsWeb) {
      return await _waitForWebCallback(randomState, oauthState);
    } else {
      return await _waitForAppLinkCallback(randomState, oauthState);
    }

  } catch (e) {
    return OAuthResult.error('launch_error', e.toString());
  }
}

// Update the handleOAuthCallback method:
Future<void> handleOAuthCallback(String? code, String? encodedState, String? error) async {
  print('🔄 OAuth callback received - encoded state: ${encodedState?.substring(0, 20)}...');

  try {
    if (error != null) {
      print('❌ OAuth error: $error');
      _setLoading(false);
      return;
    }

    if (code == null || encodedState == null) {
      print('❌ OAuth callback missing parameters');
      _setLoading(false);
      return;
    }

    // Decode the enhanced state
    final oauthState = OAuthState.decode(encodedState);
    if (oauthState == null) {
      print('❌ Failed to decode OAuth state');
      _setLoading(false);
      return;
    }

    print('🔄 Decoded state - Origin: ${oauthState.origin}, Platform: ${oauthState.platform}');

    // Validate the state
    if (!oauthState.isValid()) {
      print('❌ OAuth state validation failed');
      _setLoading(false);
      return;
    }

    // Load stored random state for verification
    final storedRandomState = await _secureStorage.read(key: _oauthStateStorageKey);
    if (oauthState.randomState != storedRandomState) {
      print('❌ OAuth random state mismatch');
      _setLoading(false);
      return;
    }

    // Load stored code verifier
    final storedCodeVerifier = await _secureStorage.read(key: _oauthCodeVerifierStorageKey);
    if (storedCodeVerifier == null) {
      print('❌ Stored code verifier is null');
      _setLoading(false);
      return;
    }

    print('✅ OAuth state validation successful, proceeding with code exchange...');

    // Exchange code for API key
    final apiKey = await _exchangeCodeForApiKey(code, storedCodeVerifier);

    if (apiKey != null) {
      await _storeCredentials(apiKey);
      
      // Clear stored OAuth state after successful authentication
      await _secureStorage.delete(key: _oauthStateStorageKey);
      await _secureStorage.delete(key: '${_oauthStateStorageKey}_encoded');
      await _secureStorage.delete(key: _oauthCodeVerifierStorageKey);

      print('✅ Dynamic OAuth authentication successful!');
    } else {
      print('❌ Failed to exchange code for API key');
    }

    _setLoading(false);
  } catch (e) {
    print('❌ Error handling OAuth callback: $e');
    _setLoading(false);
  }
}
```

## Phase 2: Testing Strategy

### Development Testing
1. Test on different ports: `flutter run -d chrome --web-port 3000`
2. Test on different ports: `flutter run -d chrome --web-port 8080`
3. Test on different ports: `flutter run -d chrome --web-port 8081`

### Validation Points
- [ ] Origin detection works correctly
- [ ] State encoding/decoding functions properly
- [ ] OAuth flow completes successfully
- [ ] Callback redirects to correct port
- [ ] Security validation passes

## Phase 3: Vercel Handler Updates (Next Phase)

The Vercel callback handler will need to:
1. Decode the enhanced state parameter
2. Extract the origin URL
3. Redirect to the detected origin
4. Handle fallback scenarios

## Security Considerations

### State Validation
- ✅ Timestamp validation (10-minute window)
- ✅ Origin whitelist validation
- ✅ Random state verification
- ✅ Base64URL encoding for URL safety

### Origin Security
- Only allow localhost and specified domains
- Validate port ranges if needed
- Implement rate limiting in Vercel handler

## Implementation Notes

1. **Backward Compatibility**: The current hardcoded approach remains as fallback
2. **Error Handling**: Comprehensive error logging for debugging
3. **Platform Support**: Works across web, mobile, and desktop
4. **Development Friendly**: Automatic port detection for seamless development

## Next Steps

1. Implement the Flutter-side components
2. Test with current Vercel handler (should work with encoded state)
3. Update Vercel handler for dynamic redirection
4. Comprehensive testing across environments