import 'package:hive_flutter/hive_flutter.dart';

import '../models/source.dart';
import '../utils/logger.dart';

/// Local database service that replaces the server's JSON file storage
/// Uses Hive for all storage (web-compatible)
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  // Box names
  static const String _sourcesBox = 'sources';
  static const String _sourceContentBox = 'source_content';
  static const String _settingsBox = 'settings';
  static const String _cacheBox = 'cache';
  static const String _generationCostsBox = 'generation_costs';
  static const String _userSpendingBox = 'user_spending';
  static const String _sessionsBox = 'sessions';

  Box? _sources;
  Box? _sourceContent;
  Box? _settings;
  Box? _cache;
  Box? _generationCosts;
  Box? _userSpending;
  Box? _sessions;
  bool _initialized = false;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool get isInitialized => _initialized;

  Future<void> clearAllData() async {
    await _ensureInitialized();

    await _sources!.clear();
    await _sourceContent!.clear();
    await _settings!.clear();
    await _cache!.clear();
    await _generationCosts!.clear();
    await _userSpending!.clear();
    await _sessions!.clear();
  }

  Future<void> clearCache() async {
    await _ensureInitialized();
    await _cache!.clear();
  }

  Future<void> deleteSetting(String key) async {
    await _ensureInitialized();
    await _settings!.delete(key);
  }

  Future<void> deleteSource(String id) async {
    await _ensureInitialized();
    await _sources!.delete(id);
    await _sourceContent!.delete(id);
  }

  Future<void> dispose() async {
    if (!_initialized) return;

    await _sources?.close();
    await _sourceContent?.close();
    await _settings?.close();
    await _cache?.close();
    await _generationCosts?.close();
    await _userSpending?.close();
    await _sessions?.close();

    _initialized = false;
  }

  Future<List<Source>> getAllSources() async {
    await _ensureInitialized();
    final sources = <Source>[];

    for (final value in _sources!.values) {
      try {
        // Handle different types that might be stored in Hive
        Map<String, dynamic> sourceMap;
        if (value is Map) {
          sourceMap = Map<String, dynamic>.from(value);
        } else if (value is Map<String, dynamic>) {
          sourceMap = value;
        } else {
          Logger.error('Error parsing source: unexpected type ${value.runtimeType}', tag: 'Database');
          continue;
        }
        
        final source = Source.fromMap(sourceMap);
        sources.add(source);
      } catch (e) {
        Logger.error('Error parsing source: $e', tag: 'Database');
      }
    }

    return sources;
  }

  Future<int> getDatabaseSize() async {
    await _ensureInitialized();

    // For web, we can't easily get file size, so return 0
    // In a real implementation, you might track this differently
    return 0;
  }

  Future<T?> getFromCache<T>(String key) async {
    await _ensureInitialized();

    final cacheEntry = _cache!.get(key);
    if (cacheEntry == null) return null;

    final data = Map<String, dynamic>.from(cacheEntry);
    final timestamp = data['timestamp'] as int;
    final ttl = data['ttl'] as int?;

    // Check if cache entry has expired
    if (ttl != null) {
      final expiryTime = timestamp + ttl;
      if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
        await _cache!.delete(key);
        return null;
      }
    }

    return data['value'] as T?;
  }

  Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    await _ensureInitialized();
    return _settings!.get(key, defaultValue: defaultValue) as T?;
  }

  Future<Source?> getSource(String id) async {
    await _ensureInitialized();
    final data = _sources!.get(id);
    if (data != null) {
      return Source.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<Map<String, dynamic>?> getSourceContent(String sourceId) async {
    await _ensureInitialized();
    final content = _sourceContent!.get(sourceId);
    if (content != null) {
      return Map<String, dynamic>.from(content);
    }
    return null;
  }

  // Database statistics
  Future<Map<String, dynamic>> getStats() async {
    await _ensureInitialized();

    return {
      'sources': _sources!.length,
      'sourceContent': _sourceContent!.length,
      'settings': _settings!.length,
      'cache': _cache!.length,
      'generationCosts': _generationCosts!.length,
      'userSpending': _userSpending!.length,
      'sessions': _sessions!.length,
      'totalSize': await getDatabaseSize(),
    };
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Open all Hive boxes
      _sources = await Hive.openBox(_sourcesBox);
      _sourceContent = await Hive.openBox(_sourceContentBox);
      _settings = await Hive.openBox(_settingsBox);
      _cache = await Hive.openBox(_cacheBox);
      _generationCosts = await Hive.openBox(_generationCostsBox);
      _userSpending = await Hive.openBox(_userSpendingBox);
      _sessions = await Hive.openBox(_sessionsBox);

      _initialized = true;
      Logger.info('✅ [DATABASE] DatabaseService initialized successfully', tag: 'Database');
    } catch (e) {
      Logger.error('❌ [DATABASE] Failed to initialize: $e', tag: 'Database');
      rethrow;
    }
  }

  // Source operations
  Future<void> insertSource(Source source) async {
    await _ensureInitialized();
    await _sources!.put(source.id, source.toMap());
  }

  // Source content operations
  Future<void> insertSourceContent(String sourceId, Map<String, dynamic> content) async {
    await _ensureInitialized();
    await _sourceContent!.put(sourceId, content);
  }

  Future<void> saveSetting(String key, dynamic value) async {
    await setSetting(key, value);
  }

  Future<void> saveSource(Source source) async {
    await insertSource(source);
  }

  Future<void> saveSourceContent(String sourceId, Map<String, dynamic> content) async {
    await insertSourceContent(sourceId, content);
  }

  // Cache operations
  Future<void> setCache(String key, dynamic value, {Duration? ttl}) async {
    await _ensureInitialized();

    final cacheEntry = {
      'value': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl?.inMilliseconds,
    };

    await _cache!.put(key, cacheEntry);
  }

  // Settings operations
  Future<void> setSetting(String key, dynamic value) async {
    await _ensureInitialized();
    await _settings!.put(key, value);
  }

  Future<void> updateSource(Source source) async {
    await _ensureInitialized();
    await _sources!.put(source.id, source.toMap());
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ===================
  // COST CACHE OPERATIONS
  // ===================

  /// Get cached generation cost data
  Future<Map<String, dynamic>?> getGenerationCost(String generationId) async {
    await _ensureInitialized();
    final data = _generationCosts!.get(generationId);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Cache generation cost data
  Future<void> saveGenerationCost(String generationId, Map<String, dynamic> costData) async {
    await _ensureInitialized();
    final cacheEntry = {
      ...costData,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _generationCosts!.put(generationId, cacheEntry);
  }

  /// Delete cached generation cost
  Future<void> deleteGenerationCost(String generationId) async {
    await _ensureInitialized();
    await _generationCosts!.delete(generationId);
  }

  /// Get multiple cached generation costs
  Future<Map<String, Map<String, dynamic>>> getGenerationCosts(List<String> generationIds) async {
    await _ensureInitialized();
    final results = <String, Map<String, dynamic>>{};
    
    for (final id in generationIds) {
      final data = await getGenerationCost(id);
      if (data != null) {
        results[id] = data;
      }
    }
    
    return results;
  }

  /// Clear old cached generation costs (older than specified days)
  Future<void> clearOldGenerationCosts({int olderThanDays = 30}) async {
    await _ensureInitialized();
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    final toDelete = <String>[];
    
    for (final key in _generationCosts!.keys) {
      final data = _generationCosts!.get(key);
      if (data != null) {
        final dataMap = Map<String, dynamic>.from(data);
        final cachedAt = dataMap['cachedAt'] as String?;
        if (cachedAt != null) {
          final cacheDate = DateTime.parse(cachedAt);
          if (cacheDate.isBefore(cutoffDate)) {
            toDelete.add(key as String);
          }
        }
      }
    }
    
    for (final key in toDelete) {
      await _generationCosts!.delete(key);
    }
    
    Logger.info('Cleared ${toDelete.length} old generation costs', tag: 'Database');
  }

  // ===================
  // USER SPENDING OPERATIONS
  // ===================

  /// Get user total spending
  Future<double> getUserTotalSpending() async {
    await _ensureInitialized();
    return _userSpending!.get('totalSpending', defaultValue: 0.0)?.toDouble() ?? 0.0;
  }

  /// Add to user total spending
  Future<void> addToUserSpending(double amount) async {
    await _ensureInitialized();
    final currentTotal = await getUserTotalSpending();
    final newTotal = currentTotal + amount;
    await _userSpending!.put('totalSpending', newTotal);
    
    // Also track spending history
    final spendingHistory = await getUserSpendingHistory();
    spendingHistory.add({
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _userSpending!.put('spendingHistory', spendingHistory);
  }

  /// Get user spending history
  Future<List<Map<String, dynamic>>> getUserSpendingHistory() async {
    await _ensureInitialized();
    final history = _userSpending!.get('spendingHistory');
    if (history != null) {
      return List<Map<String, dynamic>>.from(history);
    }
    return [];
  }

  /// Reset user spending
  Future<void> resetUserSpending() async {
    await _ensureInitialized();
    await _userSpending!.clear();
  }

  // ===================
  // SESSION OPERATIONS
  // ===================

  /// Save session data
  Future<void> saveSession(String sessionId, Map<String, dynamic> sessionData) async {
    await _ensureInitialized();
    await _sessions!.put(sessionId, sessionData);
  }

  /// Get session data
  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    await _ensureInitialized();
    final data = _sessions!.get(sessionId);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Delete session
  Future<void> deleteSession(String sessionId) async {
    await _ensureInitialized();
    await _sessions!.delete(sessionId);
  }

  /// Get all sessions
  Future<List<Map<String, dynamic>>> getAllSessions() async {
    await _ensureInitialized();
    final sessions = <Map<String, dynamic>>[];
    
    for (final value in _sessions!.values) {
      try {
        final sessionMap = Map<String, dynamic>.from(value);
        sessions.add(sessionMap);
      } catch (e) {
        Logger.error('Error parsing session: $e', tag: 'Database');
      }
    }
    
    return sessions;
  }

  /// Clear old sessions (older than specified days)
  Future<void> clearOldSessions({int olderThanDays = 7}) async {
    await _ensureInitialized();
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    final toDelete = <String>[];
    
    for (final key in _sessions!.keys) {
      final data = _sessions!.get(key);
      if (data != null) {
        final sessionMap = Map<String, dynamic>.from(data);
        final lastUpdated = sessionMap['lastUpdated'] as String?;
        if (lastUpdated != null) {
          final updateDate = DateTime.parse(lastUpdated);
          if (updateDate.isBefore(cutoffDate)) {
            toDelete.add(key as String);
          }
        }
      }
    }
    
    for (final key in toDelete) {
      await _sessions!.delete(key);
    }
    
    Logger.info('Cleared ${toDelete.length} old sessions', tag: 'Database');
  }
}