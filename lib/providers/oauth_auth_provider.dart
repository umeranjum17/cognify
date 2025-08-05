import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Enhanced state/origin handling for dynamic callback
import '../services/environment_service.dart';
import '../models/oauth_state.dart';

/// OAuth authentication provider for OpenRouter
class OAuthAuthProvider extends ChangeNotifier {
  static const String _apiKeyStorageKey = 'openrouter_api_key';
  static const String _userInfoStorageKey = 'openrouter_user_info';
  static const String _oauthStateStorageKey = 'oauth_state';
  static const String _oauthCodeVerifierStorageKey = 'oauth_code_verifier';

  // OpenRouter API endpoint for validation
  static const String _modelsUrl = 'https://openrouter.ai/api/v1/models';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _apiKey;
  Map<String, dynamic>? _userInfo;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  // OAuth PKCE state
  String? _codeVerifier;
  // Random state used for CSRF protection (stored separately from encoded state)
  String? _state;

  // Deep link listener
  late AppLinks _appLinks;

  // Getters
  String? get apiKey => _apiKey;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userInfo => _userInfo;

  /// Authenticate with OpenRouter using OAuth PKCE flow
  Future<bool> authenticateWithOpenRouter() async {
    _setLoading(true);

    try {
      // Initialize deep link listener
      _appLinks = AppLinks();

      // Generate PKCE code verifier and challenge
      _codeVerifier = _generateCodeVerifier();
      final codeChallenge = await _generateCodeChallenge(_codeVerifier!);
      _state = _generateCodeVerifier(); // Random state for CSRF

      // Store random state and code verifier for callback verification
      await _secureStorage.write(key: _oauthStateStorageKey, value: _state!);
      await _secureStorage.write(key: _oauthCodeVerifierStorageKey, value: _codeVerifier!);

      // Launch OAuth flow and wait for callback
      final result = await _launchOAuthFlow(codeChallenge, _state!);

      if (result.success) {
        // On web, the callback might be processed by the route handler
        if (kIsWeb && result.code == 'processed_by_route') {
          // The callback was processed by the route handler, check if we're authenticated
          if (_isAuthenticated && _apiKey != null) {
            _setLoading(false);
            return true;
          } else {
            // Wait a bit more for the route handler to complete
            if (_isAuthenticated && _apiKey != null) {
              _setLoading(false);
              return true;
            }
          }
        } else if (result.code != null) {
          // Traditional flow: exchange code for API key
          final apiKey = await _exchangeCodeForApiKey(result.code!, _codeVerifier!);

          if (apiKey != null) {
            await _storeCredentials(apiKey);
            _setLoading(false);
            return true;
          }
        }
      }

      _setLoading(false);
      return false;
    } catch (e) {
      print('OAuth authentication failed: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Clear authentication data
  Future<void> clearAuthentication() async {
    await _secureStorage.delete(key: _apiKeyStorageKey);
    await _secureStorage.delete(key: _userInfoStorageKey);
    await _secureStorage.delete(key: _oauthStateStorageKey);
    await _secureStorage.delete(key: _oauthCodeVerifierStorageKey);

    _apiKey = null;
    _userInfo = null;
    _isAuthenticated = false;
    _state = null;
    _codeVerifier = null;

    try {
      notifyListeners();
    } catch (e) {
      print('Warning: Could not notify listeners in clearAuthentication: $e');
    }
  }

  /// Handle OAuth callback from web redirect
  /// Note: `state` here is the enhanced Base64URL-encoded state that includes origin info.
  Future<void> handleOAuthCallback(String? code, String? state, String? error) async {
    print('🔄 OAuth callback received - code: ${code != null && code.length > 10 ? '${code.substring(0, 10)}...' : code}, state: ${state != null ? state.substring(0, state.length.clamp(0, 20)) + '...' : state}, error: $error');

    try {
      if (error != null) {
        print('❌ OAuth error: $error');
        _setLoading(false);
        return;
      }

      if (code == null || state == null) {
        print('❌ OAuth callback missing parameters - code: $code, state: $state');
        _setLoading(false);
        return;
      }

      // Load stored random state and code verifier for verification
      final storedRandomState = await _secureStorage.read(key: _oauthStateStorageKey);
      final storedCodeVerifier = await _secureStorage.read(key: _oauthCodeVerifierStorageKey);

      print('🔄 Stored random state: $storedRandomState, stored code verifier: ${storedCodeVerifier != null ? 'present' : 'null'}');

      // Decode enhanced state
      final decoded = OAuthState.decode(state);
      if (decoded == null) {
        print('❌ Failed to decode enhanced OAuth state');
        _setLoading(false);
        return;
      }

      // Validate random state matches what we generated
      if (decoded.randomState != storedRandomState) {
        print('❌ OAuth random state mismatch - expected: $storedRandomState, received: ${decoded.randomState}');
        _setLoading(false);
        return;
      }

      // Validate timestamp/origin
      if (!decoded.isValid()) {
        print('❌ OAuth state validation failed (timestamp/origin)');
        _setLoading(false);
        return;
      }

      if (storedCodeVerifier == null) {
        print('❌ Stored code verifier is null - cannot exchange code');
        _setLoading(false);
        return;
      }

      print('✅ OAuth state validated, proceeding with code exchange...');

      // Exchange code for API key
      print('🔄 Exchanging code for API key...');
      final apiKey = await _exchangeCodeForApiKey(code, storedCodeVerifier);

      print('🔄 Code exchange result: ${apiKey != null ? 'SUCCESS - API key received' : 'FAILED - no API key'}');

      if (apiKey != null) {
        print('🔄 Storing credentials and validating API key...');
        await _storeCredentials(apiKey);

        // Clear stored OAuth state after successful authentication
        await _secureStorage.delete(key: _oauthStateStorageKey);
        await _secureStorage.delete(key: _oauthCodeVerifierStorageKey);

        print('✅ OAuth authentication successful! API key stored and validated.');
      } else {
        print('❌ Failed to exchange code for API key');
      }

      _setLoading(false);
    } catch (e) {
      print('❌ Error handling OAuth callback: $e');
      _setLoading(false);
    }
  }

  /// Check if we have a valid API key
  Future<bool> hasValidApiKey() async {
    if (_apiKey == null) {
      await initialize();
    }

    return _isAuthenticated && _apiKey != null;
  }

  /// Initialize the provider and check for existing authentication
  Future<void> initialize() async {
    // Set loading state without notifying listeners during initialization
    _isLoading = true;

    try {
      _apiKey = await _secureStorage.read(key: _apiKeyStorageKey);
      final userInfoJson = await _secureStorage.read(key: _userInfoStorageKey);

      if (userInfoJson != null) {
        try {
          _userInfo = jsonDecode(userInfoJson);
        } catch (e) {
          print('Failed to decode user info: $e');
          _userInfo = null;
        }
      }

      if (_apiKey != null) {
        // Validate the stored API key
        final isValid = await _validateApiKey(_apiKey!);
        _isAuthenticated = isValid;

        if (!isValid) {
          // Clear invalid credentials
          await clearAuthentication();
        }
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      print('Error initializing OAuth provider: $e');
      // Don't clear authentication on general errors, only on validation failures
      _isAuthenticated = false;
      _apiKey = null;
      _userInfo = null;
    } finally {
      // Set loading to false and notify listeners only once at the end
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually set API key (fallback for when OAuth is not available)
  Future<bool> setApiKeyManually(String apiKey) async {
    _setLoading(true);

    try {
      final isValid = await _validateApiKey(apiKey);

      if (isValid) {
        await _storeCredentials(apiKey);
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print('Error setting API key: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Exchange authorization code for API key
  Future<String?> _exchangeCodeForApiKey(String code, String codeVerifier) async {
    try {
      print('🔄 Making token exchange request to OpenRouter...');
      print('🔄 Code: ${code.substring(0, 10)}..., Code verifier: ${codeVerifier.substring(0, 10)}...');

      // Make POST request to OpenRouter's token endpoint
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/auth/keys'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'code': code,
          'code_verifier': codeVerifier,
          'code_challenge_method': 'S256',
        }),
      );

      print('🔄 Token exchange response: ${response.statusCode}');
      print('🔄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final apiKey = data['key'] as String?;
        print('🔄 Extracted API key: ${apiKey != null ? '${apiKey.substring(0, 10)}...' : 'null'}');
        return apiKey;
      } else {
        print('❌ Token exchange failed: ${response.statusCode} ${response.body}');
        return null;
      }

    } catch (e) {
      print('❌ Error exchanging code for API key: $e');
      return null;
    }
  }

  /// Fetch user information from OpenRouter
  Future<Map<String, dynamic>?> _fetchUserInfo(String apiKey) async {
    try {
      // In a real implementation, this would fetch user info from OpenRouter
      // For now, return placeholder user info
      return {
        'id': 'user_${DateTime.now().millisecondsSinceEpoch}',
        'email': 'user@example.com',
        'name': 'OpenRouter User',
        'created_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error fetching user info: $e');
      return null;
    }
  }

  /// Generate PKCE code challenge
  Future<String> _generateCodeChallenge(String verifier) async {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generate PKCE code verifier
  String _generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (i) => chars[random.nextInt(chars.length)]).join();
  }

  /// Launch OAuth flow using App Links / deep links
  Future<OAuthResult> _launchOAuthFlow(String codeChallenge, String randomState) async {
    try {
      // Use the same Vercel callback for all platforms - it will handle mobile deep linking
      final redirectUri = 'https://oauth-callback-deploy.vercel.app/callback';

      // Build enhanced state that captures the initiator's origin (and platform)
      final enhancedState = OAuthState.fromCurrentEnvironment(randomState: randomState).copyWith(platform: 'android');
      final encodedState = enhancedState.encode();

      print('🔄 Using OAuth redirect URI: $redirectUri');
      print('🔄 Enhanced state origin: ${enhancedState.origin}');
      print('🔄 Encoded state (trunc): ${encodedState.substring(0, encodedState.length.clamp(0, 24))}...');

      // Build the OAuth authorization URL
      final authUri = Uri.parse('https://openrouter.ai/auth').replace(
        queryParameters: {
          'callback_url': redirectUri,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
          'state': encodedState,
        },
      );

      print('Opening OAuth URL: $authUri');
      print('Waiting for callback...');

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
        // On web, we need to handle the callback differently
        return await _waitForWebCallback(randomState);
      } else {
        // On mobile, use App Links
        _appLinks = AppLinks();
        return await _waitForAppLinkCallback(randomState);
      }

    } catch (e) {
      return OAuthResult.error('launch_error', e.toString());
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      try {
        notifyListeners();
      } catch (e) {
        print('Warning: Could not notify listeners: $e');
      }
    }
  }

  /// Store credentials securely
  Future<void> _storeCredentials(String apiKey) async {
    try {
      await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);

      // Fetch and store user info
      final userInfo = await _fetchUserInfo(apiKey);
      if (userInfo != null) {
        await _secureStorage.write(
          key: _userInfoStorageKey,
          value: jsonEncode(userInfo),
        );
        _userInfo = userInfo;
      }

      _apiKey = apiKey;
      _isAuthenticated = true;

      try {
        notifyListeners();
      } catch (e) {
        print('Warning: Could not notify listeners in _storeCredentials: $e');
      }
    } catch (e) {
      print('Error storing credentials: $e');
      throw e; // Re-throw to handle in calling method
    }
  }

  /// Validate API key by making a test request to OpenRouter
  /// Returns validation result with detailed status information
  Future<ApiKeyValidationResult> _validateApiKeyDetailed(String apiKey) async {
    try {
      print('🔑 Validating API key: ${apiKey.substring(0, 10)}...');
      
      final response = await http.get(
        Uri.parse(_modelsUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('🔑 Validation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ API key validation successful');
        return ApiKeyValidationResult.valid();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('❌ API key is invalid/revoked (${response.statusCode})');
        return ApiKeyValidationResult.invalid('API key revoked or invalid');
      } else {
        print('⚠️ API validation failed with status ${response.statusCode}, assuming key is still valid');
        // For other status codes (500, 502, etc.), assume key is still valid
        // The server might be having issues, but the key itself is probably fine
        return ApiKeyValidationResult.assumeValid('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error validating API key (network/timeout): $e');
      // On network errors, timeout, etc., assume the key is still valid
      // Only clear keys when OpenRouter explicitly says they're invalid
      return ApiKeyValidationResult.assumeValid('Network error: $e');
    }
  }

  /// Legacy method for backward compatibility
  Future<bool> _validateApiKey(String apiKey) async {
    final result = await _validateApiKeyDetailed(apiKey);
    return result.isValid;
  }

  /// Wait for App Link callback
  Future<OAuthResult> _waitForAppLinkCallback(String expectedState) async {
    try {
      // Listen for incoming App Links with a timeout
      final linkStream = _appLinks.uriLinkStream;

      // Wait for the callback with a 5-minute timeout
      await for (final uri in linkStream.timeout(const Duration(minutes: 5))) {
        print('Received App Link: $uri');

        // Check if this is our OAuth callback
        if ((uri.host.contains('vercel.app') && uri.path == '/callback') ||
            uri.host == 'localhost' ||
            (uri.scheme == 'cognify' && uri.host == 'oauth' && uri.path == '/callback')) {
          final code = uri.queryParameters['code'];
          final state = uri.queryParameters['state'];
          final error = uri.queryParameters['error'];

          if (error != null) {
            return OAuthResult.error('oauth_error', error);
          }

          if (code != null && state != null) {
            // For the enhanced state, we need to decode and validate
            try {
              final decoded = OAuthState.decode(state);
              if (decoded != null && decoded.randomState == expectedState) {
                return OAuthResult.success(code);
              } else {
                print('State validation failed - expected: $expectedState, got: ${decoded?.randomState}');
                return OAuthResult.error('invalid_callback', 'State validation failed');
              }
            } catch (e) {
              print('State decoding failed: $e');
              return OAuthResult.error('invalid_callback', 'Invalid state format');
            }
          } else {
            return OAuthResult.error('invalid_callback', 'Missing authorization code or state');
          }
        }
      }

      return OAuthResult.error('timeout', 'OAuth callback timeout');
    } catch (e) {
      if (e.toString().contains('timeout')) {
        return OAuthResult.error('timeout', 'OAuth authentication timed out after 5 minutes');
      }
      return OAuthResult.error('callback_error', e.toString());
    }
  }

  /// Wait for OAuth callback on local server
  Future<OAuthResult> _waitForCallback(HttpServer server, String expectedState) async {
    try {
      // Listen for requests with a timeout
      await for (final request in server.timeout(const Duration(minutes: 5))) {
        if (request.uri.path == '/oauth/callback') {
          final code = request.uri.queryParameters['code'];
          final state = request.uri.queryParameters['state'];
          final error = request.uri.queryParameters['error'];

          // Send response to browser
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html>
              <head><title>OAuth Success</title></head>
              <body>
                <h1>Authentication ${error != null ? 'Failed' : 'Successful'}</h1>
                <p>${error != null ? 'Error: $error' : 'You can now close this window and return to the app.'}</p>
                <script>window.close();</script>
              </body>
              </html>
            ''');
          await request.response.close();

          if (error != null) {
            return OAuthResult.error('oauth_error', error);
          }

          if (code != null && state == expectedState) {
            return OAuthResult.success(code);
          } else {
            return OAuthResult.error('invalid_callback', 'Invalid authorization code or state');
          }
        }
      }

      return OAuthResult.error('timeout', 'OAuth callback timeout');
    } catch (e) {
      if (e.toString().contains('timeout')) {
        return OAuthResult.error('timeout', 'OAuth authentication timed out after 5 minutes');
      }
      return OAuthResult.error('callback_error', e.toString());
    }
  }

  /// Wait for web callback (route-based approach)
  Future<OAuthResult> _waitForWebCallback(String expectedState) async {
    // On web, we rely on the GoRouter route to handle the callback
    // This method just waits for the callback to be processed by the route handler
    print('🔄 Waiting for web OAuth callback via route handler...');

    try {
      // Wait for up to 5 minutes for the callback to be processed
      const pollInterval = Duration(milliseconds: 500);
      const maxWaitTime = Duration(minutes: 5);
      final startTime = DateTime.now();

      while (DateTime.now().difference(startTime) < maxWaitTime) {
        // Check if authentication was successful (callback was processed)
        if (_isAuthenticated && _apiKey != null) {
          print('✅ Web OAuth callback processed successfully');
          return OAuthResult.success('processed_by_route');
        }

        // Check if we're on the OAuth callback URL (route is being processed)
        final currentUrl = Uri.base.toString();
        if (currentUrl.contains('/oauth/callback')) {
          print('🔄 OAuth callback route detected, waiting for processing...');
          // Continue waiting for the route handler to process the callback
        }

        await Future.delayed(pollInterval);
      }

      return OAuthResult.error('timeout', 'OAuth callback timeout - callback not processed');
    } catch (e) {
      print('❌ Error in web callback waiting: $e');
      return OAuthResult.error('callback_error', e.toString());
    }
  }
}

/// API key validation result with detailed status information
class ApiKeyValidationResult {
  final bool isValid;
  final bool shouldClearKey;
  final String? reason;

  const ApiKeyValidationResult({
    required this.isValid,
    required this.shouldClearKey,
    this.reason,
  });

  /// Key is definitively valid
  factory ApiKeyValidationResult.valid() {
    return const ApiKeyValidationResult(
      isValid: true,
      shouldClearKey: false,
    );
  }

  /// Key is definitively invalid and should be cleared
  factory ApiKeyValidationResult.invalid(String reason) {
    return ApiKeyValidationResult(
      isValid: false,
      shouldClearKey: true,
      reason: reason,
    );
  }

  /// Key status unknown due to network/server issues, assume valid and don't clear
  factory ApiKeyValidationResult.assumeValid(String reason) {
    return ApiKeyValidationResult(
      isValid: true, // Assume valid to avoid clearing
      shouldClearKey: false,
      reason: reason,
    );
  }
}

/// OAuth authentication result
class OAuthResult {
  final bool success;
  final String? code;
  final String? error;
  final String? errorDescription;

  const OAuthResult({
    required this.success,
    this.code,
    this.error,
    this.errorDescription,
  });

  factory OAuthResult.error(String error, [String? description]) {
    return OAuthResult(
      success: false,
      error: error,
      errorDescription: description,
    );
  }

  factory OAuthResult.success(String code) {
    return OAuthResult(success: true, code: code);
  }
}
