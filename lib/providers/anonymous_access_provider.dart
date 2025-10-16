import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Manages anonymous user access and limitations
/// Tracks usage, enforces limits, and handles account linking
class AnonymousAccessProvider extends ChangeNotifier {
  static const String _usageKey = 'anonymous_usage';
  static const String _lastResetKey = 'anonymous_last_reset';
  static const int _maxFreeMessages = 1; // Allow 1 free message for anonymous users to try the app
  static const int _resetIntervalHours = 24; // Reset limits every 24 hours

  int _messagesUsed = 0;
  int _lastResetTimestamp = 0;
  bool _hasReachedLimit = false;
  String? _anonymousUserId;

  int get messagesUsed => _messagesUsed;
  int get messagesRemaining => (_maxFreeMessages - _messagesUsed).clamp(0, _maxFreeMessages);
  bool get hasReachedLimit => _hasReachedLimit;
  bool get canUseApp => !_hasReachedLimit;
  String? get anonymousUserId => _anonymousUserId;

  /// Initialize the provider with current user state
  Future<void> initialize(fb.User? user) async {
    final wasAnonymous = _anonymousUserId != null;
    final isNowAnonymous = user?.isAnonymous == true;
    
    debugPrint('🔍 [AnonymousAccess] Initialize called:');
    debugPrint('  - User: ${user?.uid}');
    debugPrint('  - Is anonymous: $isNowAnonymous');
    debugPrint('  - Was anonymous: $wasAnonymous');
    debugPrint('  - Current anonymous UID: $_anonymousUserId');
    
    // If we already have an anonymous user ID and the user is still anonymous, don't reset
    if (wasAnonymous && isNowAnonymous && user != null && _anonymousUserId == user.uid) {
      // Same anonymous user, just check limits
      debugPrint('✅ [AnonymousAccess] Same anonymous user, checking limits');
      _checkLimits();
      notifyListeners();
      return;
    }
    
    if (isNowAnonymous && user != null) {
      debugPrint('✅ [AnonymousAccess] New anonymous user, loading data');
      _anonymousUserId = user.uid;
      await _loadUsageData();
      _checkLimits();
    } else if (wasAnonymous && !isNowAnonymous) {
      // User was anonymous and now has a persistent account - just reset limits
      debugPrint('✅ [AnonymousAccess] User signed in - resetting anonymous limits');
      _reset();
    } else if (!isNowAnonymous) {
      // User is not anonymous, reset if we had anonymous state
      if (wasAnonymous) {
        debugPrint('🔄 [AnonymousAccess] User no longer anonymous, resetting');
        _reset();
      }
    }
    notifyListeners();
  }

  /// Record a message usage for anonymous users
  Future<bool> recordMessageUsage() async {
    if (_hasReachedLimit) return false;
    
    _messagesUsed++;
    _checkLimits();
    await _saveUsageData();
    notifyListeners();
    
    return !_hasReachedLimit;
  }

  /// Check if user can send a message
  bool canSendMessage() {
    return !_hasReachedLimit && _messagesUsed < _maxFreeMessages;
  }

  /// Get user-friendly limit message
  String getLimitMessage() {
    if (_hasReachedLimit) {
      return 'You\'ve used your free message! Sign in with Apple or Google to continue chatting.';
    }
    final remaining = messagesRemaining;
    if (remaining == 1) {
      return 'You have 1 free message to try the app. Sign in to continue chatting!';
    }
    return 'You have $remaining free messages remaining. Sign in to get more credits.';
  }

  // Account linking simplified - just reset limits when user signs in
  // No complex data transfer needed

  /// Reset usage data (for testing or manual reset)
  Future<void> resetUsage() async {
    _reset();
    await _clearUsageData();
    notifyListeners();
  }

  void _checkLimits() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceReset = (now - _lastResetTimestamp) / (1000 * 60 * 60);
    
    // Reset if 24 hours have passed
    if (hoursSinceReset >= _resetIntervalHours) {
      _messagesUsed = 0;
      _lastResetTimestamp = now;
      _hasReachedLimit = false;
    } else {
      _hasReachedLimit = _messagesUsed >= _maxFreeMessages;
    }
  }

  void _reset() {
    _messagesUsed = 0;
    _lastResetTimestamp = 0;
    _hasReachedLimit = false;
    _anonymousUserId = null;
  }

  Future<void> _loadUsageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usageJson = prefs.getString(_usageKey);
      final lastReset = prefs.getInt(_lastResetKey) ?? 0;
      
      if (usageJson != null) {
        final data = jsonDecode(usageJson) as Map<String, dynamic>;
        _messagesUsed = data['messagesUsed'] ?? 0;
        _lastResetTimestamp = lastReset;
      } else {
        _lastResetTimestamp = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      debugPrint('❌ [AnonymousAccess] Failed to load usage data: $e');
      _reset();
    }
  }

  Future<void> _saveUsageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'messagesUsed': _messagesUsed,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_usageKey, jsonEncode(data));
      await prefs.setInt(_lastResetKey, _lastResetTimestamp);
    } catch (e) {
      debugPrint('❌ [AnonymousAccess] Failed to save usage data: $e');
    }
  }

  Future<void> _clearUsageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_usageKey);
      await prefs.remove(_lastResetKey);
    } catch (e) {
      debugPrint('❌ [AnonymousAccess] Failed to clear usage data: $e');
    }
  }

  static const int maxFreeMessages = _maxFreeMessages;
}
