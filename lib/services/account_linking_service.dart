import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../api/api.dart';

/// Service for handling account linking and credit restoration
class AccountLinkingService {
  static final AccountLinkingService instance = AccountLinkingService._();
  AccountLinkingService._();

  /// Link anonymous account to persistent account and restore credits
  /// This should be called when a user signs in with a persistent account
  /// after previously using the app anonymously
  Future<void> linkAccountAndRestoreCredits({
    required String anonymousUserId,
    required String persistentUserId,
  }) async {
    try {
      debugPrint('🔗 [AccountLinking] Starting account linking process');
      debugPrint('  - Anonymous UID: $anonymousUserId');
      debugPrint('  - Persistent UID: $persistentUserId');

      // Get current user to ensure we have a valid token
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != persistentUserId) {
        throw Exception('User not authenticated or UID mismatch');
      }

      // Call backend to link accounts and transfer credits
      await API.instance.linkAccountAndRestoreCredits(
        anonymousUserId: anonymousUserId,
        persistentUserId: persistentUserId,
      );

      debugPrint('✅ [AccountLinking] Account linking completed successfully');
    } catch (e) {
      debugPrint('❌ [AccountLinking] Failed to link account: $e');
      // Don't rethrow - this is a best-effort operation
      // The user can still use the app, they just won't get their anonymous credits restored
    }
  }

  /// Check if there are any anonymous credits to restore
  /// This can be used to show a notification to the user
  Future<bool> hasAnonymousCreditsToRestore(String anonymousUserId) async {
    try {
      // This would call the backend to check if there are credits to restore
      // For now, we'll return false as the backend implementation is needed
      return false;
    } catch (e) {
      debugPrint('❌ [AccountLinking] Failed to check anonymous credits: $e');
      return false;
    }
  }

  /// Link anonymous account to Apple account specifically
  /// This is a convenience method that calls the general account linking
  Future<void> linkAnonymousToApple({
    required String anonymousUserId,
    required String appleUserId,
  }) async {
    debugPrint('🍎 [AccountLinking] Linking anonymous account to Apple account');
    await linkAccountAndRestoreCredits(
      anonymousUserId: anonymousUserId,
      persistentUserId: appleUserId,
    );
  }
}
