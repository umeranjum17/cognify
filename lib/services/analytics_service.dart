import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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

  Future<void> logScreenView({required String screenName, String? screenClass}) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (_) {}
  }
}

/// Navigator observer that reports screen transitions to AnalyticsService.
class AnalyticsRouteObserver extends NavigatorObserver {
  String? _currentScreen;

  void _sendScreen(Route<dynamic> route) {
    final settings = route.settings;
    final screenName = settings.name ?? settings.toString();
    if (screenName == _currentScreen) return;
    _currentScreen = screenName;
    AnalyticsService.instance.logScreenView(screenName: screenName);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sendScreen(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _sendScreen(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _sendScreen(previousRoute);
    }
  }
}