import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Lightweight wrapper around Firebase Analytics to centralize usage.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      _initialized = true;
      if (kDebugMode) {
        debugPrint('✅ [Analytics] Firebase Analytics initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Analytics] Initialization failed: $e');
      }
    }
  }

  Future<void> setUserId(String? uid) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.setUserId(id: uid);
    } catch (_) {}
  }

  Future<void> logLogin({String? method}) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logLogin(loginMethod: method);
    } catch (_) {}
  }

  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
    } catch (_) {}
  }
}