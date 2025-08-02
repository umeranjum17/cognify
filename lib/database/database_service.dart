import 'package:hive_flutter/hive_flutter.dart';

import '../models/source.dart';

/// Local database service that replaces the server's JSON file storage
/// Uses Hive for all storage (web-compatible)
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  // Box names
  static const String _sourcesBox = 'sources';
  static const String _sourceContentBox = 'source_content';
  static const String _settingsBox = 'settings';
  static const String _cacheBox = 'cache';

  Box? _sources;
  Box? _sourceContent;
  Box? _settings;
  Box? _cache;
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
          print('Error parsing source: unexpected type ${value.runtimeType}');
          continue;
        }
        
        final source = Source.fromMap(sourceMap);
        sources.add(source);
      } catch (e) {
        print('Error parsing source: $e');
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

      _initialized = true;
      print('✅ [DATABASE] DatabaseService initialized successfully');
    } catch (e) {
      print('❌ [DATABASE] Failed to initialize: $e');
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
}