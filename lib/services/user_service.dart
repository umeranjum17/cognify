import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  static const String _userIdKey = 'cognify_user_id';
  static const String _userProfileKey = 'cognify_user_profile';

  final Uuid _uuid = const Uuid();
  String? _currentUserId;
  
  Map<String, dynamic>? _userProfile;
  factory UserService() => _instance;
  UserService._internal();

  /// Export user data (for backup/migration)
  Map<String, dynamic> exportUserData() {
    return {
      'userId': _currentUserId,
      'profile': _userProfile,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _currentUserId;
  }

  /// Get user preference
  T? getPreference<T>(String key, [T? defaultValue]) {
    try {
      if (_userProfile != null && _userProfile!['preferences'] != null) {
        return _userProfile!['preferences'][key] as T? ?? defaultValue;
      }
      return defaultValue;
    } catch (e) {
      Logger.error('❌ [USER] Error getting preference $key: $e', tag: 'UserService');
      return defaultValue;
    }
  }

  /// Get user stat
  T? getStat<T>(String key, [T? defaultValue]) {
    try {
      if (_userProfile != null && _userProfile!['stats'] != null) {
        return _userProfile!['stats'][key] as T? ?? defaultValue;
      }
      return defaultValue;
    } catch (e) {
      Logger.error('❌ [USER] Error getting stat $key: $e', tag: 'UserService');
      return defaultValue;
    }
  }

  /// Get current user profile
  Map<String, dynamic>? getUserProfile() {
    return _userProfile;
  }

  /// Import user data (for backup/migration)
  Future<void> importUserData(Map<String, dynamic> userData) async {
    try {
      if (userData['userId'] != null && userData['profile'] != null) {
        _currentUserId = userData['userId'];
        _userProfile = userData['profile'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userIdKey, _currentUserId!);
        await _saveUserProfile();
        
        Logger.info('📥 [USER] Imported user data', tag: 'UserService');
      }
    } catch (e) {
      Logger.error('❌ [USER] Error importing user data: $e', tag: 'UserService');
    }
  }

  /// Initialize user service and get/create user ID
  Future<String> initializeUser() async {
    if (_currentUserId != null) {
      return _currentUserId!;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Try to get existing user ID
    String? existingUserId = prefs.getString(_userIdKey);
    
    if (existingUserId != null && existingUserId.isNotEmpty) {
      _currentUserId = existingUserId;
      Logger.info('👤 [USER] Retrieved existing user ID: $_currentUserId', tag: 'UserService');
    } else {
      // Generate new user ID
      _currentUserId = _uuid.v4();
      await prefs.setString(_userIdKey, _currentUserId!);
      Logger.info('👤 [USER] Generated new user ID: $_currentUserId', tag: 'UserService');
    }

    // Load user profile
    await _loadUserProfile();
    
    return _currentUserId!;
  }

  /// Reset user data (for testing or user request)
  Future<void> resetUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userProfileKey);
      
      _currentUserId = null;
      _userProfile = null;
      
      Logger.info('🔄 [USER] Reset user data', tag: 'UserService');
    } catch (e) {
      Logger.error('❌ [USER] Error resetting user data: $e', tag: 'UserService');
    }
  }

  /// Update last active timestamp
  Future<void> updateLastActive() async {
    try {
      if (_userProfile != null) {
        _userProfile!['lastActiveAt'] = DateTime.now().toIso8601String();
        await _saveUserProfile();
      }
    } catch (e) {
      Logger.error('❌ [USER] Error updating last active: $e', tag: 'UserService');
    }
  }

  /// Update user preferences
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    try {
      if (_userProfile != null) {
        _userProfile!['preferences'] = {
          ..._userProfile!['preferences'],
          ...preferences,
        };
        _userProfile!['lastActiveAt'] = DateTime.now().toIso8601String();
        await _saveUserProfile();
        Logger.info('⚙️ [USER] Updated user preferences', tag: 'UserService');
      }
    } catch (e) {
      Logger.error('❌ [USER] Error updating preferences: $e', tag: 'UserService');
    }
  }

  /// Update user stats
  Future<void> updateStats({
    int? conversations,
    int? messages,
    double? cost,
  }) async {
    try {
      if (_userProfile != null) {
        final stats = _userProfile!['stats'] as Map<String, dynamic>;
        
        if (conversations != null) {
          stats['totalConversations'] = (stats['totalConversations'] ?? 0) + conversations;
        }
        if (messages != null) {
          stats['totalMessages'] = (stats['totalMessages'] ?? 0) + messages;
        }
        if (cost != null) {
          stats['totalCost'] = (stats['totalCost'] ?? 0.0) + cost;
        }
        
        _userProfile!['lastActiveAt'] = DateTime.now().toIso8601String();
        await _saveUserProfile();
        Logger.info('📊 [USER] Updated user stats', tag: 'UserService');
      }
    } catch (e) {
      Logger.error('❌ [USER] Error updating stats: $e', tag: 'UserService');
    }
  }

  /// Load user profile from local storage
  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_userProfileKey);
      
      if (profileJson != null) {
        _userProfile = jsonDecode(profileJson);
        Logger.info('👤 [USER] Loaded user profile from storage', tag: 'UserService');
      } else {
        // Create default profile
        _userProfile = {
          'id': _currentUserId,
          'createdAt': DateTime.now().toIso8601String(),
          'lastActiveAt': DateTime.now().toIso8601String(),
          'preferences': {
            'theme': 'system',
            'defaultModel': 'mistralai/mistral-7b-instruct:free',
            'personality': 'helpful',
          },
          'stats': {
            'totalConversations': 0,
            'totalMessages': 0,
            'totalCost': 0.0,
          },
        };
        await _saveUserProfile();
        Logger.info('👤 [USER] Created default user profile', tag: 'UserService');
      }
    } catch (e) {
      Logger.error('❌ [USER] Error loading user profile: $e', tag: 'UserService');
    }
  }

  /// Save user profile to local storage
  Future<void> _saveUserProfile() async {
    try {
      if (_userProfile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userProfileKey, jsonEncode(_userProfile));
      }
    } catch (e) {
      Logger.error('❌ [USER] Error saving user profile: $e', tag: 'UserService');
    }
  }
}