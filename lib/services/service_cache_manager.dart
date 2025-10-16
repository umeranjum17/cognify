import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Manages service initialization state and caching to reduce startup time
class ServiceCacheManager {
  static final ServiceCacheManager _instance = ServiceCacheManager._internal();
  factory ServiceCacheManager() => _instance;
  ServiceCacheManager._internal();

  static const String _cacheKey = 'service_initialization_cache';
  static const String _lastInitKey = 'last_service_init';
  static const Duration _cacheValidityDuration = Duration(hours: 24);

  bool _isInitialized = false;
  Map<String, dynamic>? _cachedData;

  bool get isInitialized => _isInitialized;

  /// Initialize the cache manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      final lastInit = prefs.getInt(_lastInitKey) ?? 0;

      // Check if cache is still valid
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = now - lastInit;

      if (cacheData != null && cacheAge < _cacheValidityDuration.inMilliseconds) {
        _cachedData = jsonDecode(cacheData) as Map<String, dynamic>;
        Logger.info('✅ Service cache loaded (age: ${(cacheAge / 1000 / 60).toStringAsFixed(1)}m)', tag: 'ServiceCache');
      } else {
        Logger.info('🔄 Service cache expired or missing, will rebuild', tag: 'ServiceCache');
        _cachedData = {};
      }

      _isInitialized = true;
    } catch (e) {
      Logger.error('❌ Failed to initialize ServiceCacheManager: $e', tag: 'ServiceCache');
      _cachedData = {};
      _isInitialized = true;
    }
  }

  /// Get cached data for a specific service
  T? getCachedData<T>(String serviceName, String key) {
    if (!_isInitialized || _cachedData == null) return null;
    
    final serviceData = _cachedData![serviceName] as Map<String, dynamic>?;
    if (serviceData == null) return null;
    
    return serviceData[key] as T?;
  }

  /// Set cached data for a specific service
  Future<void> setCachedData<T>(String serviceName, String key, T value) async {
    if (!_isInitialized) return;

    try {
      _cachedData ??= {};
      _cachedData![serviceName] ??= <String, dynamic>{};
      _cachedData![serviceName][key] = value;

      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cachedData));
      await prefs.setInt(_lastInitKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger.error('❌ Failed to cache data for $serviceName.$key: $e', tag: 'ServiceCache');
    }
  }

  /// Check if a service's cached data is still valid
  bool isServiceCacheValid(String serviceName) {
    if (!_isInitialized || _cachedData == null) return false;
    
    final serviceData = _cachedData![serviceName] as Map<String, dynamic>?;
    if (serviceData == null) return false;
    
    final lastUpdate = serviceData['_lastUpdate'] as int?;
    if (lastUpdate == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - lastUpdate;
    
    return age < _cacheValidityDuration.inMilliseconds;
  }

  /// Mark a service as having updated data
  Future<void> markServiceUpdated(String serviceName) async {
    await setCachedData(serviceName, '_lastUpdate', DateTime.now().millisecondsSinceEpoch);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastInitKey);
      _cachedData = {};
      Logger.info('🗑️ Service cache cleared', tag: 'ServiceCache');
    } catch (e) {
      Logger.error('❌ Failed to clear service cache: $e', tag: 'ServiceCache');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    if (!_isInitialized || _cachedData == null) {
      return {'services': 0, 'totalKeys': 0, 'isValid': false};
    }

    int totalKeys = 0;
    for (final serviceData in _cachedData!.values) {
      if (serviceData is Map<String, dynamic>) {
        totalKeys += serviceData.length;
      }
    }

    return {
      'services': _cachedData!.length,
      'totalKeys': totalKeys,
      'isValid': true,
    };
  }
}
