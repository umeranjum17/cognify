import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../providers/firebase_auth_provider.dart';
import '../services/revenuecat_service.dart';
import '../services/user_service.dart';
import '../utils/logger.dart';

class DataDeletionService {
  static final DataDeletionService _instance = DataDeletionService._internal();
  factory DataDeletionService() => _instance;
  DataDeletionService._internal();

  static const String _deletionRequestKey = 'data_deletion_requested';
  static const String _deletionCompletedKey = 'data_deletion_completed';

  /// Request complete data deletion for the current user
  /// This is the main method users will call to delete their data
  Future<bool> requestDataDeletion({
    FirebaseAuthProvider? firebaseAuth,
    bool includeFirebaseAccount = true,
  }) async {
    try {
      Logger.info('🗑️ [DATA_DELETION] Starting comprehensive data deletion...', tag: 'DataDeletion');

      // Mark deletion as requested
      await _markDeletionRequested();

      // 1. Export data before deletion (for logging purposes)
      Logger.info('📤 [DATA_DELETION] Starting data deletion process', tag: 'DataDeletion');

      // 2. Clear local user data
      await _clearUserData();

      // 3. Clear all app preferences and settings
      await _clearAppPreferences();

      // 4. Clear secure storage
      await _clearSecureStorage();

      // 5. Clear local databases
      await _clearLocalDatabases();

      // 6. Clear RevenueCat data
      await _clearRevenueCatData();

      // 7. Sign out and optionally delete Firebase account
      if (firebaseAuth != null) {
        await _handleFirebaseAccountDeletion(firebaseAuth, includeFirebaseAccount);
      }

      // Mark deletion as completed
      await _markDeletionCompleted();

      Logger.info('✅ [DATA_DELETION] Data deletion completed successfully', tag: 'DataDeletion');
      return true;

    } catch (e, stackTrace) {
      Logger.error('❌ [DATA_DELETION] Failed to delete user data: $e', tag: 'DataDeletion');
      Logger.error('Stack trace: $stackTrace', tag: 'DataDeletion');
      return false;
    }
  }

  /// Check if user has requested data deletion
  Future<bool> isDeletionRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_deletionRequestKey) ?? false;
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error checking deletion status: $e', tag: 'DataDeletion');
      return false;
    }
  }

  /// Get data types that will be deleted
  List<String> getDataTypesToDelete() {
    return [
      'User preferences and settings',
      'Conversation history',
      'Usage statistics and analytics',
      'Authentication tokens and sessions',
      'Cached data and temporary files',
      'Subscription and billing information',
      'Local databases and storage',
      'Firebase authentication data (optional)',
    ];
  }

  /// Get data retention information
  Map<String, String> getDataRetentionInfo() {
    return {
      'Local Data': 'Deleted immediately',
      'Firebase Auth': 'Deleted immediately (if requested)',
      'RevenueCat': 'Account logged out, subscription data retained per RevenueCat policy',
      'Third-party Services': 'Data deletion handled per each service\'s retention policy',
      'Backup Recovery': 'Not possible after deletion - this action is permanent',
    };
  }

  /// Mark deletion as requested (for tracking)
  Future<void> _markDeletionRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_deletionRequestKey, true);
      await prefs.setString('deletion_requested_at', DateTime.now().toIso8601String());
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error marking deletion requested: $e', tag: 'DataDeletion');
    }
  }

  /// Mark deletion as completed
  Future<void> _markDeletionCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_deletionCompletedKey, true);
      await prefs.setString('deletion_completed_at', DateTime.now().toIso8601String());
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error marking deletion completed: $e', tag: 'DataDeletion');
    }
  }

  /// Clear user data via UserService
  Future<void> _clearUserData() async {
    try {
      await UserService().resetUserData();
      Logger.info('✅ [DATA_DELETION] User data cleared', tag: 'DataDeletion');
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error clearing user data: $e', tag: 'DataDeletion');
    }
  }

  /// Clear all shared preferences except deletion tracking
  Future<void> _clearAppPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Preserve deletion tracking keys
      final preserveKeys = {_deletionRequestKey, _deletionCompletedKey, 'deletion_requested_at', 'deletion_completed_at'};
      
      for (final key in keys) {
        if (!preserveKeys.contains(key)) {
          await prefs.remove(key);
        }
      }
      
      Logger.info('✅ [DATA_DELETION] App preferences cleared', tag: 'DataDeletion');
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error clearing preferences: $e', tag: 'DataDeletion');
    }
  }

  /// Clear secure storage
  Future<void> _clearSecureStorage() async {
    try {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
      Logger.info('✅ [DATA_DELETION] Secure storage cleared', tag: 'DataDeletion');
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error clearing secure storage: $e', tag: 'DataDeletion');
    }
  }

  /// Clear local databases (Hive, SQLite)
  Future<void> _clearLocalDatabases() async {
    try {
      // Clear Hive boxes
      if (Hive.isBoxOpen('conversations')) {
        final box = Hive.box('conversations');
        await box.clear();
      }
      
      if (Hive.isBoxOpen('user_data')) {
        final box = Hive.box('user_data');
        await box.clear();
      }

      // Clear SQLite databases
      await _clearSQLiteDatabase();
      
      Logger.info('✅ [DATA_DELETION] Local databases cleared', tag: 'DataDeletion');
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error clearing databases: $e', tag: 'DataDeletion');
    }
  }

  /// Clear SQLite database
  Future<void> _clearSQLiteDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'cognify.db');
      
      // Delete the database file
      await deleteDatabase(path);
      Logger.info('✅ [DATA_DELETION] SQLite database cleared', tag: 'DataDeletion');
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error clearing SQLite: $e', tag: 'DataDeletion');
    }
  }

  /// Clear RevenueCat subscription data
  Future<void> _clearRevenueCatData() async {
    try {
      final revenueCat = RevenueCatService.instance;
      if (revenueCat.isConfigured) {
        await revenueCat.reset();
        Logger.info('✅ [DATA_DELETION] RevenueCat data cleared', tag: 'DataDeletion');
      }
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error clearing RevenueCat data: $e', tag: 'DataDeletion');
    }
  }

  /// Handle Firebase authentication deletion
  Future<void> _handleFirebaseAccountDeletion(
    FirebaseAuthProvider firebaseAuth, 
    bool deleteAccount
  ) async {
    try {
      if (deleteAccount && firebaseAuth.isSignedIn) {
        // Delete Firebase account completely
        final user = firebaseAuth.user;
        if (user != null) {
          await user.delete();
          Logger.info('✅ [DATA_DELETION] Firebase account deleted', tag: 'DataDeletion');
        }
      } else {
        // Just sign out
        await firebaseAuth.signOut();
        Logger.info('✅ [DATA_DELETION] Signed out of Firebase', tag: 'DataDeletion');
      }
    } catch (e) {
      Logger.error('❌ [DATA_DELETION] Error handling Firebase account: $e', tag: 'DataDeletion');
      // Continue with deletion even if Firebase fails
    }
  }
}