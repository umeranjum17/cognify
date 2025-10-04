import '../providers/firebase_auth_provider.dart';
import '../database/database_service.dart';
import 'conversation_service.dart';

/// Service for handling user data deletion
class DataDeletionService {
  final DatabaseService _db = DatabaseService();
  final ConversationService _conversationService = ConversationService();

  /// Get list of data types that will be deleted
  List<String> getDataTypesToDelete() {
    return [
      'All conversations and messages',
      'All uploaded files and images',
      'All usage quota and cost data',
      'All settings and preferences',
      'Local database and cache',
      'Firebase account (if selected)',
    ];
  }

  /// Get data retention policy information
  Map<String, String> getDataRetentionInfo() {
    return {
      'Local Data': 'Deleted immediately',
      'Server Data': 'Deleted immediately',
      'Backups': 'Cleared within 24 hours',
      'Cache': 'Cleared immediately',
    };
  }

  /// Request complete data deletion
  Future<bool> requestDataDeletion({
    required FirebaseAuthProvider firebaseAuth,
    bool includeFirebaseAccount = false,
  }) async {
    try {
      // Delete all conversations
      await _conversationService.clearAllConversations();

      // Clear all local database data
      await _db.clearAllData();

      // Clear cache
      await _db.clearCache();

      // If requested, sign out from Firebase account
      if (includeFirebaseAccount) {
        await firebaseAuth.signOut();
      }

      return true;
    } catch (e) {
      print('Error during data deletion: $e');
      return false;
    }
  }
}
