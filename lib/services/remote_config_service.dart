import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Remote configuration service for fetching app configs from Vercel Edge Functions
///
/// This service fetches configuration data (pricing, models, features, etc.) from
/// the backend and caches it locally with SharedPreferences. Falls back to
/// hardcoded values when network is unavailable.
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  // Resolve base URL from dart-define at runtime, with sensible fallback
  static String get baseUrl {
    final configured = AppConfig.backendBaseUrl.trim();
    if (configured.isNotEmpty) return configured.endsWith('/api/config') ? configured : '$configured/api/config';
    // Fallback for development
    return 'http://localhost:3000/api/config';
  }

  static const Duration _cacheExpiry = Duration(hours: 1);
  static const Duration _requestTimeout = Duration(seconds: 10);

  // Cache keys
  static const String _unifiedCacheKey = 'remote_config_unified';
  static const String _unifiedTimestampKey = 'remote_config_unified_timestamp';
  static const String _pricingCacheKey = 'remote_config_pricing';
  static const String _modelsCacheKey = 'remote_config_models';
  static const String _appCacheKey = 'remote_config_app';
  static const String _modesCacheKey = 'remote_config_modes';

  static const String _pricingTimestampKey = 'remote_config_pricing_timestamp';
  static const String _modelsTimestampKey = 'remote_config_models_timestamp';
  static const String _appTimestampKey = 'remote_config_app_timestamp';
  static const String _modesTimestampKey = 'remote_config_modes_timestamp';

  bool _initialized = false;
  SharedPreferences? _prefs;

  /// Initialize the service (call once at app startup)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      Logger.info('🔧 RemoteConfigService initialized', tag: 'RemoteConfig');

      // Trigger background refresh if cache is stale
      _refreshIfStale();
    } catch (e) {
      Logger.error('Failed to initialize RemoteConfigService: $e', tag: 'RemoteConfig');
    }
  }

  /// Fetch model pricing from backend
  ///
  /// Returns Map<String, Map<String, double>> with format:
  /// { "model-id": { "input": 0.0, "output": 0.0 } }
  Future<Map<String, Map<String, double>>?> fetchPricing({
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();
    // Attempt unified first
    final unified = await _fetchUnified(forceRefresh: forceRefresh);
    if (unified != null) {
      final pricingData = (unified['pricing'] as Map?)?.cast<String, dynamic>();
      if (pricingData != null) {
        await _cacheData(_pricingCacheKey, _pricingTimestampKey, pricingData);
        Logger.info('✅ Pricing fetched from unified and cached', tag: 'RemoteConfig');
        return _parsePricing(pricingData);
      }
    }

    // Fallback: keep old behavior if unified failed
    return await _fetchPricingLegacy(forceRefresh: forceRefresh);
  }

  /// Fetch model configurations from backend
  Future<Map<String, dynamic>?> fetchModels({
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();
    final unified = await _fetchUnified(forceRefresh: forceRefresh);
    if (unified != null) {
      final modelsData = (unified['models'] as Map?)?.cast<String, dynamic>();
      if (modelsData != null) {
        await _cacheData(_modelsCacheKey, _modelsTimestampKey, modelsData);
        Logger.info('✅ Models fetched from unified and cached', tag: 'RemoteConfig');
        return modelsData;
      }
    }

    return await _fetchModelsLegacy(forceRefresh: forceRefresh);
  }

  /// Fetch app configuration (feature flags, quotas, version)
  Future<Map<String, dynamic>?> fetchAppConfig({
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();
    final unified = await _fetchUnified(forceRefresh: forceRefresh);
    if (unified != null) {
      final appData = (unified['app'] as Map?)?.cast<String, dynamic>();
      if (appData != null) {
        await _cacheData(_appCacheKey, _appTimestampKey, appData);
        Logger.info('✅ App config fetched from unified and cached', tag: 'RemoteConfig');
        return appData;
      }
    }

    return await _fetchAppLegacy(forceRefresh: forceRefresh);
  }

  /// Fetch mode configurations (chat, search, deepsearch, etc.)
  Future<Map<String, dynamic>?> fetchModes({
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();

    if (!forceRefresh) {
      final cached = await _getCachedData<Map<String, dynamic>>(
        _modesCacheKey,
        _modesTimestampKey,
      );
      if (cached != null) {
        Logger.debug('📦 Using cached modes config', tag: 'RemoteConfig');
        return cached;
      }
    }

    try {
      Logger.info('🌐 Fetching modes from backend...', tag: 'RemoteConfig');
      final response = await http
          .get(Uri.parse('$baseUrl/modes'))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final modesData = data['data'] as Map<String, dynamic>;
          await _cacheData(_modesCacheKey, _modesTimestampKey, modesData);
          Logger.info('✅ Modes fetched and cached', tag: 'RemoteConfig');
          return modesData;
        }
      }

      Logger.warn('Failed to fetch modes: HTTP ${response.statusCode}', tag: 'RemoteConfig');
      return null;
    } catch (e) {
      Logger.error('Error fetching modes: $e', tag: 'RemoteConfig');
      return null;
    }
  }

  /// Refresh all configurations in the background
  Future<void> refreshAll() async {
    Logger.info('🔄 Refreshing all remote configs...', tag: 'RemoteConfig');

    // Prefer unified refresh first, then modes
    final unified = await _fetchUnified(forceRefresh: true);
    if (unified != null) {
      final pricingData = (unified['pricing'] as Map?)?.cast<String, dynamic>();
      final modelsData = (unified['models'] as Map?)?.cast<String, dynamic>();
      final appData = (unified['app'] as Map?)?.cast<String, dynamic>();
      if (pricingData != null) {
        await _cacheData(_pricingCacheKey, _pricingTimestampKey, pricingData);
      }
      if (modelsData != null) {
        await _cacheData(_modelsCacheKey, _modelsTimestampKey, modelsData);
      }
      if (appData != null) {
        await _cacheData(_appCacheKey, _appTimestampKey, appData);
      }
    } else {
      await Future.wait([
        fetchPricing(forceRefresh: true),
        fetchModels(forceRefresh: true),
        fetchAppConfig(forceRefresh: true),
      ]);
    }

    await fetchModes(forceRefresh: true);

    Logger.info('✅ All configs refreshed', tag: 'RemoteConfig');
  }

  /// Clear all cached configuration data
  Future<void> clearCache() async {
    await _ensureInitialized();

    await Future.wait([
      _prefs!.remove(_unifiedCacheKey),
      _prefs!.remove(_unifiedTimestampKey),
      _prefs!.remove(_pricingCacheKey),
      _prefs!.remove(_modelsCacheKey),
      _prefs!.remove(_appCacheKey),
      _prefs!.remove(_modesCacheKey),
      _prefs!.remove(_pricingTimestampKey),
      _prefs!.remove(_modelsTimestampKey),
      _prefs!.remove(_appTimestampKey),
      _prefs!.remove(_modesTimestampKey),
    ]);

    Logger.info('🗑️ Remote config cache cleared', tag: 'RemoteConfig');
  }

  // ========== Private Helper Methods ==========

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<T?> _getCachedData<T>(String dataKey, String timestampKey) async {
    try {
      final cachedJson = _prefs!.getString(dataKey);
      final timestamp = _prefs!.getInt(timestampKey);

      if (cachedJson == null || timestamp == null) {
        return null;
      }

      // Check if cache is expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheExpiry.inMilliseconds) {
        Logger.debug('⏰ Cache expired for $dataKey', tag: 'RemoteConfig');
        return null;
      }

      return jsonDecode(cachedJson) as T;
    } catch (e) {
      Logger.error('Error reading cache for $dataKey: $e', tag: 'RemoteConfig');
      return null;
    }
  }

  Future<void> _cacheData(
    String dataKey,
    String timestampKey,
    Map<String, dynamic> data,
  ) async {
    try {
      await _prefs!.setString(dataKey, jsonEncode(data));
      await _prefs!.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger.error('Error caching data for $dataKey: $e', tag: 'RemoteConfig');
    }
  }

  Map<String, Map<String, double>> _parsePricing(Map<String, dynamic> data) {
    final result = <String, Map<String, double>>{};

    data.forEach((modelId, pricingData) {
      if (pricingData is Map) {
        result[modelId] = {
          'input': (pricingData['input'] as num?)?.toDouble() ?? 0.0,
          'output': (pricingData['output'] as num?)?.toDouble() ?? 0.0,
        };
      }
    });

    return result;
  }

  void _refreshIfStale() {
    // Trigger background refresh without blocking
    Future.delayed(Duration.zero, () async {
      try {
        final unifiedTimestamp = _prefs!.getInt(_unifiedTimestampKey);
        if (unifiedTimestamp == null ||
            DateTime.now().millisecondsSinceEpoch - unifiedTimestamp >
                _cacheExpiry.inMilliseconds) {
          await refreshAll();
        }
      } catch (e) {
        // Silently fail - not critical
        Logger.debug('Background refresh failed: $e', tag: 'RemoteConfig');
      }
    });
  }

  // Unified fetch and cache
  Future<Map<String, dynamic>?> _fetchUnified({ bool forceRefresh = false }) async {
    if (!forceRefresh) {
      final cached = await _getCachedData<Map<String, dynamic>>(
        _unifiedCacheKey,
        _unifiedTimestampKey,
      );
      if (cached != null) {
        Logger.debug('📦 Using cached unified config', tag: 'RemoteConfig');
        return cached;
      }
    }

    try {
      Logger.info('🌐 Fetching unified config from backend...', tag: 'RemoteConfig');
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final payload = (data['data'] as Map).cast<String, dynamic>();
          await _cacheData(_unifiedCacheKey, _unifiedTimestampKey, payload);
          return payload;
        }
      }

      Logger.warn('Failed to fetch unified config: HTTP ${response.statusCode}', tag: 'RemoteConfig');
      return null;
    } catch (e) {
      Logger.error('Error fetching unified config: $e', tag: 'RemoteConfig');
      return null;
    }
  }

  // Legacy fallbacks (can be removed after full migration)
  Future<Map<String, Map<String, double>>?> _fetchPricingLegacy({ bool forceRefresh = false }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/pricing'))
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final pricingData = data['data'] as Map<String, dynamic>;
          await _cacheData(_pricingCacheKey, _pricingTimestampKey, pricingData);
          return _parsePricing(pricingData);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchModelsLegacy({ bool forceRefresh = false }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/models'))
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final modelsData = data['data'] as Map<String, dynamic>;
          await _cacheData(_modelsCacheKey, _modelsTimestampKey, modelsData);
          return modelsData;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchAppLegacy({ bool forceRefresh = false }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/app'))
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final appData = data['data'] as Map<String, dynamic>;
          await _cacheData(_appCacheKey, _appTimestampKey, appData);
          return appData;
        }
      }
    } catch (_) {}
    return null;
  }
}
