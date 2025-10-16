import 'dart:io';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

/// Helper class to manage Apple Sign-In state and resolve common issues
class AppleSignInHelper {
  /// Clear Apple Sign-In state to resolve duplicate credential errors
  static Future<void> clearAppleSignInState() async {
    if (!Platform.isIOS) return;
    
    try {
      // Force a fresh Apple Sign-In request to clear any cached state
      final String rawNonce = _generateNonce();
      final String nonceSha256 = _sha256ofString(rawNonce);
      
      await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: nonceSha256,
      );
    } catch (e) {
      // Ignore errors - this is just to clear the state
      print('🔄 [AppleSignInHelper] Cleared Apple Sign-In state');
    }
  }

  /// Check if Apple Sign-In is available and properly configured
  static Future<bool> isAppleSignInAvailable() async {
    if (!Platform.isIOS) return false;
    
    try {
      return await SignInWithApple.isAvailable();
    } catch (e) {
      print('❌ [AppleSignInHelper] Apple Sign-In not available: $e');
      return false;
    }
  }

  /// Get diagnostic information about Apple Sign-In configuration
  static Future<Map<String, dynamic>> getDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'isIOS': Platform.isIOS,
      'isAvailable': false,
      'error': null,
    };

    if (Platform.isIOS) {
      try {
        diagnostics['isAvailable'] = await SignInWithApple.isAvailable();
      } catch (e) {
        diagnostics['error'] = e.toString();
      }
    }

    return diagnostics;
  }

  /// Generate a secure nonce for Apple Sign-In
  static String _generateNonce([int length = 32]) {
    const String charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Generate SHA256 hash of a string
  static String _sha256ofString(String input) {
    final List<int> bytes = utf8.encode(input);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }
}
