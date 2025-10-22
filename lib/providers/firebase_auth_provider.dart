import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

import '../services/analytics_service.dart';
import '../api/api.dart';
import '../config/app_config.dart';
import '../utils/apple_signin_helper.dart';

/// FirebaseAuthProvider()
/// Implements zero-friction start with anonymous auth by default.
/// Users can optionally sign in with Apple/Google/Email for cross-device sync.
class FirebaseAuthProvider extends ChangeNotifier {
  bool _initialized = false;
  bool _initializing = false;
  fb.User? _user;
  Object? _lastError;
  late final fb.FirebaseAuth _auth;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get isSignedIn {
    final result = _user != null;
    debugPrint('🔐 [FirebaseAuth] isSignedIn: $result, user: ${_user?.uid}, isAnonymous: ${_user?.isAnonymous}');
    return result;
  }
  String? get uid => _user?.uid;
  fb.User? get user => _user;
  Object? get lastError => _lastError;

  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Assume Firebase is initialized in main.dart; fail gracefully if not
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠️ [FirebaseAuth] Firebase not initialized before auth provider. Skipping auth setup.');
        _initialized = true;
        _initializing = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return;
      }

      _auth = fb.FirebaseAuth.instance;

      // Hydrate current user
      _user = _auth.currentUser;

      // Listen to auth state changes
      _auth.authStateChanges().listen((user) {
        final wasAnonymous = _user?.isAnonymous ?? false;
        _user = user;
        
        // Wire analytics user identity on change
        try {
          AnalyticsService.instance.setUserId(user?.uid).catchError((_) {});
        } catch (_) {}
        
        // Handle account linking: if user was anonymous and now has a persistent account
        if (wasAnonymous && user != null && !user.isAnonymous) {
          debugPrint('✅ [FirebaseAuth] Account linked from anonymous to persistent');
          // The AnonymousAccessProvider will be notified via the proxy provider
        }
        
        if (_initialized) { // Only notify if initialization is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        }
      });

      // Zero-friction start: sign in anonymously if no user
      if (_user == null) {
        try {
          await _auth.signInAnonymously();
          _user = _auth.currentUser;
          debugPrint('✅ [FirebaseAuth] Anonymous sign-in successful');
          // Log anonymous login
          try {
            await AnalyticsService.instance.logLogin(method: 'anonymous');
            await AnalyticsService.instance.setUserId(_user?.uid);
          } catch (_) {}
        } catch (e) {
          debugPrint('⚠️ [FirebaseAuth] Anonymous sign-in failed: $e');
          // Continue without anonymous auth - user can still use the app
        }
      }

      _initialized = true;
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Initialization error: $e');
      _initialized = true; // Mark as initialized even with error to prevent retry loops
    } finally {
      _initializing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }


  Future<void> signInWithGoogle() async {
    _lastError = null;
    try {
      // Guard: Google Sign-In not available on iOS in our setup unless GIDClientID is configured
      if (!kIsWeb && Platform.isIOS) {
        throw Exception('Google Sign-In is not configured on iOS. Use Sign in with Apple.');
      }
      if (kIsWeb) {
        final googleProvider = fb.GoogleAuthProvider();
        
        if (_auth.currentUser?.isAnonymous == true) {
          // Anonymous user - sign out and sign in fresh (no linking)
          debugPrint('🔄 [FirebaseAuth] Anonymous user - signing out and signing in with Google (web)');
          await _auth.signOut();
          final cred = await _auth.signInWithPopup(googleProvider);
          _user = cred.user;
        } else {
          // Authenticated user - try to link accounts (Apple ↔ Google)
          debugPrint('🔄 [FirebaseAuth] Authenticated user - attempting to link Google account (web)');
          try {
            final cred = await _auth.currentUser!.linkWithPopup(googleProvider);
            _user = cred.user;
            debugPrint('✅ [FirebaseAuth] Successfully linked Google account (web)');
          } on fb.FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
              // Account already linked - sign in with existing account
              debugPrint('🔄 [FirebaseAuth] Google account already linked - signing in with existing account (web)');
              final cred = await _auth.signInWithPopup(googleProvider);
              _user = cred.user;
            } else {
              rethrow;
            }
          }
        }
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        final GoogleSignInAccount? account = await googleSignIn.signIn();
        if (account == null) {
          throw Exception('Google sign-in canceled');
        }
        final GoogleSignInAuthentication auth = await account.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        );
        
        if (_auth.currentUser?.isAnonymous == true) {
          // Anonymous user - sign out and sign in fresh (no linking)
          debugPrint('🔄 [FirebaseAuth] Anonymous user - signing out and signing in with Google');
          await _auth.signOut();
          final signInRes = await _auth.signInWithCredential(credential);
          _user = signInRes.user;
        } else {
          // Authenticated user - try to link accounts (Apple ↔ Google)
          debugPrint('🔄 [FirebaseAuth] Authenticated user - attempting to link Google account');
          try {
            final linkRes = await _auth.currentUser!.linkWithCredential(credential);
            _user = linkRes.user;
            debugPrint('✅ [FirebaseAuth] Successfully linked Google account');
          } on fb.FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
              // Account already linked - sign in with existing account
              debugPrint('🔄 [FirebaseAuth] Google account already linked - signing in with existing account');
              final signInRes = await _auth.signInWithCredential(credential);
              _user = signInRes.user;
            } else {
              rethrow;
            }
          }
        }
      }
      debugPrint('✅ [FirebaseAuth] Google sign-in successful');
      try {
        await AnalyticsService.instance.logLogin(method: 'google');
        await AnalyticsService.instance.setUserId(_user?.uid);
      } catch (e) {
        debugPrint('⚠️ [GoogleSignIn] Failed to log analytics: $e');
      }
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Google sign-in error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    _lastError = null;
    try {
      if (!Platform.isIOS && !kIsWeb) {
        throw Exception('Sign in with Apple is only available on iOS');
      }

      if (kIsWeb) {
        // On web, Apple Sign-In via OAuth provider requires additional setup.
        // For now we can throw to make it explicit.
        throw Exception('Apple Sign-In on web is not configured.');
      }

      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('Sign in with Apple not available on this device');
      }

      // Nonce protects against replay attacks and is recommended for Firebase
      final String rawNonce = _generateNonce();
      final String nonceSha256 = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonceSha256,
      );

      // Detailed diagnostics without leaking sensitive token contents
      try {
        final opts = Firebase.apps.isNotEmpty ? Firebase.app().options : null;
        debugPrint(
          '🔎 [AppleSignIn] Diagnostics: '
          'idTokenPresent=${credential.identityToken != null} '
          'idTokenLen=${credential.identityToken?.length ?? 0} '
          'authCodePresent=${credential.authorizationCode != null} '
          'emailPresent=${credential.email != null} '
          'fullNamePresent=${(credential.givenName ?? credential.familyName) != null} '
          'userIdPresent=${credential.userIdentifier != null} '
          'firebaseProjectId=${opts?.projectId} appId=${opts?.appId}');

        // Decode JWT claims to inspect aud/nonce/iss without logging sensitive data
        if (credential.identityToken != null && credential.identityToken!.isNotEmpty) {
          final token = credential.identityToken!;
          final parts = token.split('.');
          if (parts.length >= 2) {
            String normalize(String s) => s.padRight(s.length + (4 - s.length % 4) % 4, '=');
            final payload = utf8.decode(base64Url.decode(normalize(parts[1])));
            final map = jsonDecode(payload) as Map<String, dynamic>;
            final aud = map['aud'];
            final iss = map['iss'];
            final sub = map['sub'];
            final nonceClaim = map['nonce'];
            final exp = map['exp'];
            final iat = map['iat'];
            debugPrint('🔎 [AppleSignIn] JWT: aud=$aud iss=$iss subPresent=${sub != null} '
                'nonceClaimPresent=${nonceClaim != null} nonceMatchesSha256=${nonceClaim == nonceSha256} '
                'exp=$exp iat=$iat');
          }
        }
      } catch (_) {}

      if (credential.identityToken == null || credential.identityToken!.isEmpty) {
        // Standard handling: do not fall back. Provide actionable guidance.
        throw Exception(
          'Apple did not return an identity token. On Simulator, sign into iCloud in Settings, '
          'ensure Keychain is enabled, and try again; or test on a real device. Also verify your '
          'bundle ID matches the Apple Developer configuration and that the Sign in with Apple capability is enabled.'
        );
      }

      final oauthProvider = fb.OAuthProvider('apple.com');
      final oauthCred = oauthProvider.credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
        accessToken: credential.authorizationCode,
      );

      try {
        if (_auth.currentUser == null) {
          // No user at all - direct sign in
          debugPrint('🔄 [FirebaseAuth] No current user - signing in with Apple');
          final signInRes = await _auth.signInWithCredential(oauthCred);
          _user = signInRes.user;
        } else if (_auth.currentUser!.isAnonymous) {
          // Anonymous user - sign out and sign in fresh (no linking)
          debugPrint('🔄 [FirebaseAuth] Anonymous user - signing out and signing in with Apple');
          await _auth.signOut();
          final signInRes = await _auth.signInWithCredential(oauthCred);
          _user = signInRes.user;
        } else {
          // Authenticated user - try to link accounts (Google ↔ Apple)
          debugPrint('🔄 [FirebaseAuth] Authenticated user - attempting to link Apple account');
          try {
            final linkRes = await _auth.currentUser!.linkWithCredential(oauthCred);
            _user = linkRes.user;
            debugPrint('✅ [FirebaseAuth] Successfully linked Apple account');
          } on fb.FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
              // Account already linked - sign in with existing account
              debugPrint('🔄 [FirebaseAuth] Apple account already linked - signing in with existing account');
              final signInRes = await _auth.signInWithCredential(oauthCred);
              _user = signInRes.user;
            } else {
              rethrow;
            }
          }
        }
        
        // Log the successful sign-in
        try {
          await AnalyticsService.instance.logLogin(method: 'apple');
          await AnalyticsService.instance.setUserId(_user?.uid);
        } catch (_) {}
      } on fb.FirebaseAuthException catch (fae) {
        debugPrint('❌ [FirebaseAuth] Apple sign-in FirebaseAuthException: code=${fae.code} message=${fae.message}');
        
        // Handle specific error cases with user-friendly messages
        if (fae.code == 'missing-or-invalid-nonce') {
          throw Exception('Apple Sign-In failed. Please try again.');
        } else if (fae.code == 'credential-already-in-use') {
          throw Exception('This Apple ID is already in use. Please try again.');
        } else if (fae.code == 'invalid-credential') {
          throw Exception('Invalid Apple credential. Please try signing in with Apple again.');
        } else if (fae.code == 'account-exists-with-different-credential') {
          throw Exception('An account already exists with this email. Please try again.');
        }
        
        rethrow;
      }
      debugPrint('✅ [FirebaseAuth] Apple sign-in successful');
      notifyListeners();
    } catch (e) {
      // Handle Apple Sign-In cancellation gracefully
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          debugPrint('ℹ️ [FirebaseAuth] Apple sign-in was canceled by user');
          _lastError = null; // Don't treat cancellation as an error
          notifyListeners();
          return; // Don't rethrow for user cancellation
        } else {
          debugPrint('❌ [FirebaseAuth] Apple sign-in authorization error: ${e.code} - ${e.message}');
          _lastError = e;
          notifyListeners();
          rethrow;
        }
      } else if (e.toString().contains('AuthorizationErrorCode.canceled') || 
                 e.toString().contains('error 1001')) {
        // Fallback for string-based error detection
        debugPrint('ℹ️ [FirebaseAuth] Apple sign-in was canceled by user (fallback detection)');
        _lastError = null;
        notifyListeners();
        return;
      }
      
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Apple sign-in error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _lastError = null;
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = cred.user;
      debugPrint('✅ [FirebaseAuth] Email sign-in successful');
      try {
        await AnalyticsService.instance.logLogin(method: 'email');
        await AnalyticsService.instance.setUserId(_user?.uid);
      } catch (_) {}
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Email sign-in error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createAccountWithEmail(String email, String password) async {
    _lastError = null;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = cred.user;
      debugPrint('✅ [FirebaseAuth] Account creation successful');
      try {
        await AnalyticsService.instance.logLogin(method: 'email_create');
        await AnalyticsService.instance.setUserId(_user?.uid);
      } catch (_) {}
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Account creation error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _lastError = null;
    try {
      await _auth.signOut();
      _user = null;
      debugPrint('✅ [FirebaseAuth] Sign out successful');
      try {
        await AnalyticsService.instance.setUserId(null);
      } catch (_) {}
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Sign out error: $e');
      notifyListeners();
    }
  }

  /// Clear Apple Sign-In state and force fresh authentication
  Future<void> clearAppleSignInState() async {
    try {
      await AppleSignInHelper.clearAppleSignInState();
      debugPrint('🔄 [FirebaseAuth] Apple Sign-In state cleared');
    } catch (e) {
      debugPrint('⚠️ [FirebaseAuth] Failed to clear Apple Sign-In state: $e');
    }
  }

  // Account linking removed - we just give 1 free message to anonymous users
  // and force them to sign in for more. No complex data transfer needed.

  /// Check if current user is anonymous
  bool get isAnonymous => _user?.isAnonymous ?? true;

  /// Get user's email (null for anonymous users)
  String? get userEmail => _user?.email;

  /// Get user's display name
  String? get displayName => _user?.displayName;

  /// Get user's photo URL
  String? get photoURL => _user?.photoURL;

  // Magic link sign-in removed

  /// Dev-only: Sign in using a custom token issued by backend.
  Future<void> devSignIn({String? uid, String? email, Map<String, dynamic>? claims}) async {
    _lastError = null;
    try {
      final signedUid = await API.instance.devSignIn(uid: uid, email: email, claims: claims);
      _user = _auth.currentUser;
      debugPrint('✅ [FirebaseAuth] Dev sign-in successful uid=$signedUid');
      try {
        await AnalyticsService.instance.logLogin(method: 'dev_custom_token');
        await AnalyticsService.instance.setUserId(_user?.uid);
      } catch (_) {}
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] devSignIn error: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Magic-link helpers removed

  String _generateNonce([int length = 32]) {
    const String charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final List<int> bytes = utf8.encode(input);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }
}
