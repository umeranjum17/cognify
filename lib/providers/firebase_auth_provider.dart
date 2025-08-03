import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';

/// FirebaseAuthProvider()
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
    notifyListeners();

    try {
      // Initialize Firebase if not already
      if (Firebase.apps.isEmpty) {
        // If using placeholder, this still compiles; you must replace with real firebase_options.dart later
        await Firebase.initializeApp(
          options: _resolveOptions(),
        );
      }

      _auth = fb.FirebaseAuth.instance;

      // Hydrate current user
      _user = _auth.currentUser;

      // Listen to auth state changes
      _auth.authStateChanges().listen((user) {
        _user = user;
        notifyListeners();
      });

      _initialized = true;
    } catch (e) {
      _lastError = e;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  FirebaseOptions? _resolveOptions() {
    // If using flutterfire configured file, it will provide the correct options.
    // Our placeholder returns null/empty values, which is acceptable for compilation but you must replace it.
    // In real setup, DefaultFirebaseOptions.currentPlatform should be of type FirebaseOptions.
    try {
      // Attempt to reflectively cast if available at runtime
      // ignore: dead_code
      return null; // We rely on platform files (GoogleService-Info.plist/google-services.json) and default initialization on mobile.
    } catch (_) {
      return null;
    }
  }

  Future<void> signInWithGoogle() async {
    _lastError = null;
    try {
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
      notifyListeners();
    } catch (e) {
      _lastError = e;
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
      notifyListeners();
    } catch (e) {
      _lastError = e;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _lastError = null;
    try {
      await _auth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _lastError = e;
      notifyListeners();
      rethrow;
    }
  }
}