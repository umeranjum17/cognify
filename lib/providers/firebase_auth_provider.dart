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
  bool get isSignedIn => _user != null;
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
        _user = user;
        // Wire analytics user identity on change
        try {
          AnalyticsService.instance.setUserId(user?.uid).catchError((_) {});
        } catch (_) {}
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
        final cred = await _auth.signInWithPopup(googleProvider);
        _user = cred.user;
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
        final cred = await _auth.signInWithCredential(credential);
        _user = cred.user;
      }
      debugPrint('✅ [FirebaseAuth] Google sign-in successful');
      try {
        await AnalyticsService.instance.logLogin(method: 'google');
        await AnalyticsService.instance.setUserId(_user?.uid);
      } catch (_) {}
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

      final oauthProvider = fb.OAuthProvider('apple.com');
      final oauthCred = oauthProvider.credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
      );

      final cred = await _auth.signInWithCredential(oauthCred);
      _user = cred.user;
      debugPrint('✅ [FirebaseAuth] Apple sign-in successful');
      try {
        await AnalyticsService.instance.logLogin(method: 'apple');
        await AnalyticsService.instance.setUserId(_user?.uid);
      } catch (_) {}
      notifyListeners();
    } catch (e) {
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