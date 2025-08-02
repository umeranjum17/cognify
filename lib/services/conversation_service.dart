import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';

/// Service for managing conversation history and automatic saving
class ConversationService {
  static final ConversationService _instance = ConversationService._internal();
  factory ConversationService() => _instance;
  ConversationService._internal();

  Timer? _autoSaveTimer;
  static const Duration _autoSaveInterval = Duration(seconds: 30); // Save every 30 seconds
  static const String _conversationsKey = 'conversations';
  static const int _maxConversations = 100; // Keep last 100 conversations

  /// Start automatic conversation saving
  void startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) {
      _performAutoSave();
    });
    print('🔄 [CONVERSATION] Auto-save started (every ${_autoSaveInterval.inSeconds}s)');
  }

  /// Stop automatic conversation saving
  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    print('⏹️ [CONVERSATION] Auto-save stopped');
  }

  /// Save a conversation manually
  Future<void> saveConversation({
    required String id,
    required String title,
    required List<Message> messages,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
      final conversations = jsonDecode(conversationsJson) as List;

      final conversationData = {
        'id': id,
        'title': title.isNotEmpty ? title : 'Untitled Conversation',
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messageCount': messages.length,
        'metadata': metadata,
      };

      // Update existing conversation or add new one
      final existingIndex = conversations.indexWhere((conv) => conv['id'] == id);
      if (existingIndex >= 0) {
        // Update existing conversation but preserve creation date
        final existing = conversations[existingIndex];
        conversationData['createdAt'] = existing['createdAt'] ?? conversationData['createdAt'];
        conversations[existingIndex] = conversationData;
      } else {
        conversations.insert(0, conversationData);
      }

      // Limit the number of stored conversations
      if (conversations.length > _maxConversations) {
        conversations.removeRange(_maxConversations, conversations.length);
      }

      await prefs.setString(_conversationsKey, jsonEncode(conversations));
      print('💾 [CONVERSATION] Saved conversation: $id (${messages.length} messages)');
    } catch (e) {
      print('❌ [CONVERSATION] Error saving conversation: $e');
    }
  }

  /// Load all conversations
  Future<List<Map<String, dynamic>>> loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
      final conversations = jsonDecode(conversationsJson) as List;
      
      return conversations.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ [CONVERSATION] Error loading conversations: $e');
      return [];
    }
  }

  /// Load a specific conversation by ID
  Future<Map<String, dynamic>?> loadConversation(String id) async {
    try {
      final conversations = await loadConversations();
      return conversations.firstWhere(
        (conv) => conv['id'] == id,
        orElse: () => {},
      );
    } catch (e) {
      print('❌ [CONVERSATION] Error loading conversation $id: $e');
      return null;
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
      final conversations = jsonDecode(conversationsJson) as List;
      
      conversations.removeWhere((conv) => conv['id'] == id);
      
      await prefs.setString(_conversationsKey, jsonEncode(conversations));
      print('🗑️ [CONVERSATION] Deleted conversation: $id');
    } catch (e) {
      print('❌ [CONVERSATION] Error deleting conversation: $e');
    }
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_conversationsKey);
      print('🧹 [CONVERSATION] Cleared all conversations');
    } catch (e) {
      print('❌ [CONVERSATION] Error clearing conversations: $e');
    }
  }

  /// Get conversation statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final conversations = await loadConversations();
      final totalMessages = conversations.fold<int>(
        0,
        (sum, conv) => sum + ((conv['messageCount'] as int?) ?? 0),
      );

      return {
        'totalConversations': conversations.length,
        'totalMessages': totalMessages,
        'oldestConversation': conversations.isNotEmpty
            ? conversations.last['createdAt']
            : null,
        'newestConversation': conversations.isNotEmpty
            ? conversations.first['updatedAt']
            : null,
      };
    } catch (e) {
      print('❌ [CONVERSATION] Error getting stats: $e');
      return {
        'totalConversations': 0,
        'totalMessages': 0,
        'oldestConversation': null,
        'newestConversation': null,
      };
    }
  }

  /// Search conversations by title or content
  Future<List<Map<String, dynamic>>> searchConversations(String query) async {
    try {
      final conversations = await loadConversations();
      final lowercaseQuery = query.toLowerCase();
      
      return conversations.where((conv) {
        final title = (conv['title'] as String? ?? '').toLowerCase();
        final messages = conv['messages'] as List? ?? [];
        
        // Search in title
        if (title.contains(lowercaseQuery)) return true;
        
        // Search in message content
        for (final message in messages) {
          final content = (message['content'] as String? ?? '').toLowerCase();
          if (content.contains(lowercaseQuery)) return true;
        }
        
        return false;
      }).toList();
    } catch (e) {
      print('❌ [CONVERSATION] Error searching conversations: $e');
      return [];
    }
  }

  /// Export conversations to JSON
  Future<String> exportConversations() async {
    try {
      final conversations = await loadConversations();
      return jsonEncode({
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'conversations': conversations,
      });
    } catch (e) {
      print('❌ [CONVERSATION] Error exporting conversations: $e');
      return '{}';
    }
  }

  /// Import conversations from JSON
  Future<bool> importConversations(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final importedConversations = data['conversations'] as List? ?? [];
      
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_conversationsKey) ?? '[]';
      final existingConversations = jsonDecode(existingJson) as List;
      
      // Merge conversations, avoiding duplicates
      final existingIds = existingConversations.map((c) => c['id']).toSet();
      final newConversations = importedConversations
          .where((c) => !existingIds.contains(c['id']))
          .toList();
      
      final mergedConversations = [...existingConversations, ...newConversations];
      
      // Limit total conversations
      if (mergedConversations.length > _maxConversations) {
        mergedConversations.removeRange(_maxConversations, mergedConversations.length);
      }
      
      await prefs.setString(_conversationsKey, jsonEncode(mergedConversations));
      print('📥 [CONVERSATION] Imported ${newConversations.length} conversations');
      return true;
    } catch (e) {
      print('❌ [CONVERSATION] Error importing conversations: $e');
      return false;
    }
  }

  /// Perform automatic save (called by timer)
  void _performAutoSave() {
    // This is a placeholder for auto-save logic
    // In practice, this would be called by the editor screen
    // when there are unsaved changes
    print('🔄 [CONVERSATION] Auto-save tick');
  }

  /// Dispose resources
  void dispose() {
    stopAutoSave();
  }
}
