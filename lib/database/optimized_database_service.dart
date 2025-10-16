import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/source.dart';
import '../utils/logger.dart';
import '../services/service_cache_manager.dart';

/// Optimized database service with lazy initialization and caching
class OptimizedDatabaseService {
  static final OptimizedDatabaseService _instance = OptimizedDatabaseService._internal();
  factory OptimizedDatabaseService() => _instance;
  OptimizedDatabaseService._internal();

  // Box names
  static const String _sourcesBox = 'sources';
  static const String _sourceContentBox = 'source_content';
  static const String _settingsBox = 'settings';
  static const String _cacheBox = 'cache';
  static const String _generationCostsBox = 'generation_costs';
  static const String _userSpendingBox = 'user_spending';
  static const String _sessionsBox = 'sessions';

  // Lazy-loaded boxes
  Box? _sources;
  Box? _sourceContent;
  Box? _settings;
  Box? _cache;
  Box? _generationCosts;
  Box? _userSpending;
  Box? _sessions;

  bool _initialized = true; // ALWAYS READY - no initialization needed!
  bool _initializing = false;
  final ServiceCacheManager _cacheManager = ServiceCacheManager();

  bool get isInitialized => _initialized;

  /// Initialize only the essential boxes first, others lazily
  Future<void> initializeEssential() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      // Initialize Hive if needed
      if (!kIsWeb) {
        try {
          await Hive.initFlutter();
        } catch (_) {
          // ignore if already initialized
        }
      }

      // Initialize only the most critical boxes first
      _settings = await Hive.openBox(_settingsBox);
      _cache = await Hive.openBox(_cacheBox);

      _initialized = true;
      Logger.info('✅ [DATABASE] Essential boxes initialized', tag: 'Database');
    } catch (e) {
      Logger.error('❌ [DATABASE] Failed to initialize essential boxes: $e', tag: 'Database');
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  /// Initialize all boxes (called lazily when needed)
  Future<void> _ensureAllBoxesInitialized() async {
    if (_sources != null && _sourceContent != null && _generationCosts != null && 
        _userSpending != null && _sessions != null) return;

    try {
      // Initialize remaining boxes in parallel
      final futures = <Future>[];
      
      if (_sources == null) {
        futures.add(Hive.openBox(_sourcesBox).then((box) => _sources = box));
      }
      if (_sourceContent == null) {
        futures.add(Hive.openBox(_sourceContentBox).then((box) => _sourceContent = box));
      }
      if (_generationCosts == null) {
        futures.add(Hive.openBox(_generationCostsBox).then((box) => _generationCosts = box));
      }
      if (_userSpending == null) {
        futures.add(Hive.openBox(_userSpendingBox).then((box) => _userSpending = box));
      }
      if (_sessions == null) {
        futures.add(Hive.openBox(_sessionsBox).then((box) => _sessions = box));
      }

      await Future.wait(futures);
      Logger.info('✅ [DATABASE] All boxes initialized', tag: 'Database');
    } catch (e) {
      Logger.error('❌ [DATABASE] Failed to initialize remaining boxes: $e', tag: 'Database');
    }
  }

  /// Get setting with caching
  Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    await initializeEssential();
    
    // Check cache first
    final cached = _cacheManager.getCachedData<T>('database', 'setting_$key');
    if (cached != null) {
      return cached;
    }

    // Load from database
    final value = _settings!.get(key, defaultValue: defaultValue) as T?;
    
    // Cache the result
    if (value != null) {
      await _cacheManager.setCachedData('database', 'setting_$key', value);
    }
    
    return value;
  }

  /// Set setting with cache invalidation
  Future<void> setSetting(String key, dynamic value) async {
    await initializeEssential();
    
    await _settings!.put(key, value);
    
    // Update cache
    await _cacheManager.setCachedData('database', 'setting_$key', value);
  }

  /// Get from cache with TTL
  Future<T?> getFromCache<T>(String key) async {
    await initializeEssential();
    
    // Check service cache first
    final cached = _cacheManager.getCachedData<T>('database', 'cache_$key');
    if (cached != null) {
      return cached;
    }

    // Load from Hive cache
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

    final value = data['value'] as T?;
    
    // Cache in service cache
    if (value != null) {
      await _cacheManager.setCachedData('database', 'cache_$key', value);
    }
    
    return value;
  }

  /// Set cache with TTL
  Future<void> setCache(String key, dynamic value, {Duration? ttl}) async {
    await initializeEssential();

    final cacheEntry = {
      'value': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl?.inMilliseconds,
    };

    await _cache!.put(key, cacheEntry);
    
    // Also cache in service cache
    await _cacheManager.setCachedData('database', 'cache_$key', value);
  }

  /// Get all sources (lazy load sources box)
  Future<List<Source>> getAllSources() async {
    await _ensureAllBoxesInitialized();
    final sources = <Source>[];

    for (final value in _sources!.values) {
      try {
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

  /// Get source (lazy load sources box)
  Future<Source?> getSource(String id) async {
    await _ensureAllBoxesInitialized();
    final data = _sources!.get(id);
    if (data != null) {
      return Source.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// Save source (lazy load sources box)
  Future<void> saveSource(Source source) async {
    await _ensureAllBoxesInitialized();
    await _sources!.put(source.id, source.toMap());
  }

  /// Get source content (lazy load source content box)
  Future<Map<String, dynamic>?> getSourceContent(String sourceId) async {
    await _ensureAllBoxesInitialized();
    final content = _sourceContent!.get(sourceId);
    if (content != null) {
      return Map<String, dynamic>.from(content);
    }
    return null;
  }

  /// Save source content (lazy load source content box)
  Future<void> saveSourceContent(String sourceId, Map<String, dynamic> content) async {
    await _ensureAllBoxesInitialized();
    await _sourceContent!.put(sourceId, content);
  }

  /// Clear cache
  Future<void> clearCache() async {
    await initializeEssential();
    await _cache!.clear();
    await _cacheManager.clearCache();
  }

  /// Dispose all boxes
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

  /// Get database statistics
  Future<Map<String, dynamic>> getStats() async {
    await _ensureAllBoxesInitialized();

    return {
      'sources': _sources?.length ?? 0,
      'sourceContent': _sourceContent?.length ?? 0,
      'settings': _settings?.length ?? 0,
      'cache': _cache?.length ?? 0,
      'generationCosts': _generationCosts?.length ?? 0,
      'userSpending': _userSpending?.length ?? 0,
      'sessions': _sessions?.length ?? 0,
      'totalSize': 0, // Simplified for now
    };
  }
}
