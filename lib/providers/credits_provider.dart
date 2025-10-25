import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/credits_stream_service.dart';
import '../api/api.dart';
import 'firebase_auth_provider.dart';

/// Provider for real-time credits management using SSE
class CreditsProvider extends ChangeNotifier {
  FirebaseAuthProvider? _auth;
  StreamSubscription<CreditsEvent>? _streamSubscription;
  Timer? _fallbackTimer;

  // Current state
  double _balance = 0.0;
  String? _lastUpdated;
  int _precision = 1;
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isFallback = false;
  String? _error;
  bool _hasInitialData = false;

  // Getters
  double get balance => _balance;
  String? get lastUpdated => _lastUpdated;
  int get precision => _precision;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isFallback => _isFallback;
  String? get error => _error;
  bool get hasInitialData => _hasInitialData;

  // Formatted balance for display
  String get formattedBalance {
    if (_precision == 1) {
      return _balance.toStringAsFixed(1);
    }
    return _balance.toStringAsFixed(_precision);
  }

  // Credits remaining as integer (for compatibility)
  int get remainingCredits => _balance.toInt();

  String? get _uid => _auth?.uid;

  void attach({required FirebaseAuthProvider auth}) {
    final authChanged = _auth != auth;
    if (authChanged && _auth != null) {
      _auth!.removeListener(_handleAuthChange);
    }
    _auth = auth;
    if (authChanged) {
      auth.addListener(_handleAuthChange);
    }
    _startStreamIfPossible(force: true);
  }

  void _handleAuthChange() {
    _startStreamIfPossible(force: true);
  }

  void _startStreamIfPossible({bool force = false}) {
    final uid = _uid;
    if (uid == null) {
      _stopStream();
      _resetState();
      notifyListeners();
      return;
    }

    if (!force && _streamSubscription != null) {
      return;
    }

    _stopStream();
    _startStream();
  }

  void _startStream() {
    final uid = _uid;
    if (uid == null) return;

    debugPrint('🔄 [CreditsProvider] Starting credits stream for user: $uid');
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Start SSE stream
    CreditsStreamService.instance.start();
    
    // Subscribe to events
    _streamSubscription = CreditsStreamService.instance.events.listen(
      _handleCreditsEvent,
      onError: _handleStreamError,
    );

    // Fallback timer - if we don't get data within 10 seconds, try API fallback
    _fallbackTimer = Timer(const Duration(seconds: 10), () {
      if (!_hasInitialData) {
        debugPrint('⚠️ [CreditsProvider] No initial data received, trying API fallback');
        _fetchFromAPI();
      }
    });
  }

  void _stopStream() {
    debugPrint('🔄 [CreditsProvider] Stopping credits stream');
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    CreditsStreamService.instance.stop();
    _isConnected = false;
  }

  void _handleCreditsEvent(CreditsEvent event) {
    if (event.isError) {
      _handleStreamError(event.errorMessage ?? 'Unknown error');
      return;
    }

    debugPrint('💰 [CreditsProvider] Received credits event: ${event.balance} credits');

    // Don't update with fallback data if we have recent non-fallback data
    if (event.fallback && _hasInitialData && !_isFallback) {
      debugPrint('⚠️ [CreditsProvider] Ignoring fallback data, keeping current balance');
      return;
    }

    _balance = event.balance;
    _lastUpdated = event.lastUpdated;
    _precision = event.precision;
    _isFallback = event.fallback;
    _isLoading = false;
    _isConnected = true;
    _error = null;
    _hasInitialData = true;

    debugPrint('✅ [CreditsProvider] Updated balance: ${_balance} credits (fallback: $_isFallback)');
    notifyListeners();
  }

  void _handleStreamError(dynamic error) {
    debugPrint('❌ [CreditsProvider] Stream error: $error');
    _error = error.toString();
    _isLoading = false;
    _isConnected = false;
    notifyListeners();

    // Try API fallback
    _fetchFromAPI();
  }

  /// Fallback to API when SSE fails
  Future<void> _fetchFromAPI() async {
    try {
      debugPrint('🔄 [CreditsProvider] Fetching from API fallback...');
      final balance = await API.instance.getCreditsBalance();
      
      _balance = balance;
      _lastUpdated = DateTime.now().toUtc().toIso8601String();
      _precision = 1;
      _isFallback = false;
      _isLoading = false;
      _error = null;
      _hasInitialData = true;

      debugPrint('✅ [CreditsProvider] API fallback successful: $balance credits');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [CreditsProvider] API fallback failed: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manual refresh
  Future<void> refresh() async {
    debugPrint('🔄 [CreditsProvider] Manual refresh requested');
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Try API first for immediate response
    await _fetchFromAPI();
    
    // Then restart stream for real-time updates
    _startStreamIfPossible(force: true);
  }

  void _resetState() {
    _balance = 0.0;
    _lastUpdated = null;
    _precision = 1;
    _isLoading = false;
    _isConnected = false;
    _isFallback = false;
    _error = null;
    _hasInitialData = false;
  }

  @override
  void dispose() {
    _stopStream();
    _auth?.removeListener(_handleAuthChange);
    super.dispose();
  }
}
