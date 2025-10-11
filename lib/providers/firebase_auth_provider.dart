import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';
import '../utils/logger.dart';
import '../api/api.dart';
import 'package:flutter/material.dart' show TextEditingController; // for UI helpers

/// FirebaseAuthProvider()
/// Implements zero-friction start with anonymous auth by default.
/// Users can optionally sign in with Apple/Google/Email for cross-device sync.
class FirebaseAuthProvider extends ChangeNotifier {
  bool _initialized = false;
  bool _initializing = false;
  fb.User? _user;
  Object? _lastError;
  late final fb.FirebaseAuth _auth;
  final TextEditingController magicEmailController = TextEditingController();

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get isSignedIn => _user != null;
  String? get uid => _user?.uid;
  fb.User? get user => _user;
  Object? get lastError => _lastError;

  Future<void> initialize() async {
    Logger.debug('🔐 FirebaseAuthProvider.initialize() called', tag: 'FirebaseAuth');
    if (_initialized || _initializing) {
      Logger.debug('🔐 Already initialized or initializing, skipping', tag: 'FirebaseAuth');
      return;
    }
    _initializing = true;
    Logger.debug('🔐 Setting _initializing = true', tag: 'FirebaseAuth');
    
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.debug('🔐 Notifying listeners (initializing = true)', tag: 'FirebaseAuth');
      notifyListeners();
    });

    try {
      // Initialize Firebase if not already
      if (Firebase.apps.isEmpty) {
        Logger.debug('🔐 Firebase apps empty, initializing Firebase...', tag: 'FirebaseAuth');
        try {
          // Use the real Firebase options from firebase_options.dart
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          Logger.debug('🔐 Firebase initialization successful', tag: 'FirebaseAuth');
        } catch (e) {
          Logger.error('🔐 Firebase initialization failed: $e', tag: 'FirebaseAuth');
          debugPrint('❌ [FirebaseAuth] Firebase initialization failed: $e');
          debugPrint('⚠️ [FirebaseAuth] App will continue without Firebase - some features may be limited');
          _lastError = e;
          _initialized = true; // Mark as initialized to prevent retry loops
          _initializing = false;
          Logger.debug('🔐 Setting _initialized = true, _initializing = false (Firebase failed)', tag: 'FirebaseAuth');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Logger.debug('🔐 Notifying listeners (Firebase failed)', tag: 'FirebaseAuth');
            notifyListeners();
          });
          return; // Exit early if Firebase can't be initialized
        }
      } else {
        Logger.debug('🔐 Firebase already initialized', tag: 'FirebaseAuth');
      }

      _auth = fb.FirebaseAuth.instance;
      Logger.debug('🔐 FirebaseAuth instance obtained', tag: 'FirebaseAuth');

      // Hydrate current user
      _user = _auth.currentUser;
      Logger.debug('🔐 Current user: ${_user?.uid ?? "null"}', tag: 'FirebaseAuth');

      // Listen to auth state changes
      _auth.authStateChanges().listen((user) {
        Logger.debug('🔐 Auth state changed: ${user?.uid ?? "null"}', tag: 'FirebaseAuth');
        _user = user;
        if (_initialized) { // Only notify if initialization is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Logger.debug('🔐 Notifying listeners (auth state change)', tag: 'FirebaseAuth');
            notifyListeners();
          });
        }
      });

      // Zero-friction start: sign in anonymously if no user
      if (_user == null) {
        Logger.debug('🔐 No current user, signing in anonymously...', tag: 'FirebaseAuth');
        try {
          await _auth.signInAnonymously();
          _user = _auth.currentUser;
          Logger.debug('🔐 Anonymous sign-in successful: ${_user?.uid}', tag: 'FirebaseAuth');
          debugPrint('✅ [FirebaseAuth] Anonymous sign-in successful');
        } catch (e) {
          Logger.error('🔐 Anonymous sign-in failed: $e', tag: 'FirebaseAuth');
          debugPrint('⚠️ [FirebaseAuth] Anonymous sign-in failed: $e');
          // Continue without anonymous auth - user can still use the app
        }
      } else {
        Logger.debug('🔐 User already exists, skipping anonymous sign-in', tag: 'FirebaseAuth');
      }

      _initialized = true;
      Logger.debug('🔐 Setting _initialized = true (success)', tag: 'FirebaseAuth');
    } catch (e) {
      _lastError = e;
      Logger.error('🔐 Initialization error: $e', tag: 'FirebaseAuth');
      debugPrint('❌ [FirebaseAuth] Initialization error: $e');
      _initialized = true; // Mark as initialized even with error to prevent retry loops
      Logger.debug('🔐 Setting _initialized = true (error)', tag: 'FirebaseAuth');
    } finally {
      _initializing = false;
      Logger.debug('🔐 Setting _initializing = false (finally)', tag: 'FirebaseAuth');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Logger.debug('🔐 Notifying listeners (finally)', tag: 'FirebaseAuth');
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

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthProvider = fb.OAuthProvider('apple.com');
      final oauthCred = oauthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final cred = await _auth.signInWithCredential(oauthCred);
      _user = cred.user;
      debugPrint('✅ [FirebaseAuth] Apple sign-in successful');
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
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Account creation error: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Dev-only: request a custom token from backend and sign in
  Future<void> devSignIn({String? uid, String? email}) async {
    _lastError = null;
    try {
      final signedUid = await API.instance.devSignIn(uid: uid, email: email);
      _user = _auth.currentUser;
      debugPrint('✅ [FirebaseAuth] Dev sign-in successful: $signedUid');
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] Dev sign-in error: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Send sign-in link to email (magic link)
  Future<void> sendSignInLinkToEmail(String email) async {
    _lastError = null;
    try {
      // Configure ActionCodeSettings:
      // Use app's bundle ID for iOS and android package for Android; URL must be authorized in Firebase.
      final actionCodeSettings = fb.ActionCodeSettings(
        url: 'https://cognify-eb0a2.firebaseapp.com/__/auth/action',
        handleCodeInApp: true,
        iOSBundleId: DefaultFirebaseOptions.ios.iosBundleId,
        androidPackageName: null,
        androidInstallApp: false,
      );
      await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: actionCodeSettings);
      debugPrint('✅ [FirebaseAuth] Magic link sent to $email');
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] sendSignInLinkToEmail error: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Complete sign-in with email link (paste-in flow on simulator)
  Future<void> signInWithEmailLink({required String email, required String emailLink}) async {
    _lastError = null;
    try {
      final isValid = _auth.isSignInWithEmailLink(emailLink);
      if (!isValid) {
        throw Exception('Invalid sign-in link');
      }
      final cred = await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
      _user = cred.user;
      debugPrint('✅ [FirebaseAuth] Magic link sign-in successful');
      notifyListeners();
    } catch (e) {
      _lastError = e;
      debugPrint('❌ [FirebaseAuth] signInWithEmailLink error: $e');
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
}