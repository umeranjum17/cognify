import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/credits_stream_service.dart';
import '../api/api.dart';
import 'firebase_auth_provider.dart';

/// Provider for real-time credits management using SSE
class CreditsProvider extends ChangeNotifier {
  static const String _cacheKey = 'credits_balance_cache';
  static const String _cacheTimestampKey = 'credits_balance_timestamp';
  static const Duration _cacheTtl = Duration(hours: 1);

  // Static cache for instant access - populated by warmUp()
  static double? _preloadedBalance;
  static bool _preloadComplete = false;
  static Completer<void>? _warmUpCompleter;

  /// Call this early in app startup to preload cached credits.
  /// Returns a Future that completes when cache is loaded.
  static Future<void> warmUp() async {
    if (_warmUpCompleter != null) return _warmUpCompleter!.future;
    _warmUpCompleter = Completer<void>();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBalance = prefs.getDouble(_cacheKey);
      if (cachedBalance != null) {
        _preloadedBalance = cachedBalance;
        debugPrint('🔥 [CreditsProvider] Warm-up: preloaded balance $cachedBalance');
      }
    } catch (e) {
      debugPrint('⚠️ [CreditsProvider] Warm-up failed: $e');
    }
    _preloadComplete = true;
    _warmUpCompleter!.complete();
  }

  /// Get preloaded balance synchronously (returns null if not ready)
  static double? get preloadedBalance => _preloadedBalance;

  FirebaseAuthProvider? _auth;
  StreamSubscription<CreditsEvent>? _streamSubscription;
  Timer? _fallbackTimer;

  // Current state - start with preloaded value if available
  late double _balance;
  String? _lastUpdated;
  int _precision = 1;
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isFallback = false;
  String? _error;
  late bool _hasInitialData;
  late bool _cacheHydrated;

  CreditsProvider() {
    // Initialize from preloaded cache if available
    if (_preloadedBalance != null) {
      _balance = _preloadedBalance!;
      _hasInitialData = true;
      _isFallback = true;
      _cacheHydrated = true;
      debugPrint('✅ [CreditsProvider] Constructor: using preloaded balance $_balance');
    } else {
      _balance = 0.0;
      _hasInitialData = false;
      _cacheHydrated = false;
    }
  }

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
    
    // Hydrate cache first for instant display, then start stream
    _hydrateAndStart();
  }

  Future<void> _hydrateAndStart() async {
    // Check if preloaded value is available (from warmUp called earlier)
    if (!_hasInitialData && _preloadedBalance != null) {
      _balance = _preloadedBalance!;
      _hasInitialData = true;
      _isFallback = true;
      _cacheHydrated = true;
      debugPrint('✅ [CreditsProvider] Applied preloaded balance: $_balance');
      notifyListeners();
    }
    
    if (!_cacheHydrated) {
      await _hydrateCache();
    }
    _startStreamIfPossible(force: true);
  }

  /// Load cached balance from SharedPreferences for instant display
  Future<void> _hydrateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBalance = prefs.getDouble(_cacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);
      
      if (cachedBalance != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final isFresh = DateTime.now().difference(cacheTime) < _cacheTtl;
        
        _balance = cachedBalance;
        _hasInitialData = true;
        _isLoading = false; // We have data, no need to show loading
        _isFallback = !isFresh; // Mark as fallback if stale
        _cacheHydrated = true;
        
        debugPrint('✅ [CreditsProvider] Cache hydrated: $cachedBalance credits (fresh: $isFresh)');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ [CreditsProvider] Cache hydration failed: $e');
    }
    _cacheHydrated = true;
  }

  /// Save balance to SharedPreferences for next app start
  Future<void> _saveToCache(double balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_cacheKey, balance);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 [CreditsProvider] Saved balance to cache: $balance');
    } catch (e) {
      debugPrint('⚠️ [CreditsProvider] Failed to save cache: $e');
    }
  }

  void _handleAuthChange() {
    _startStreamIfPossible(force: true);
  }

  void _startStreamIfPossible({bool force = false}) {
    final uid = _uid;
    if (uid == null) {
      _stopStream();
      // DON'T reset state - keep cached balance visible while auth initializes
      // _resetState() was wiping out the preloaded/cached balance
      debugPrint('⏳ [CreditsProvider] Waiting for auth (keeping cached balance: $_balance)');
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
    
    // Only show loading spinner if we don't have cached data to display
    if (!_hasInitialData) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    // Initialize balance first (creates credits doc for new users), then start stream
    _initializeAndStartStream();
  }

  Future<void> _initializeAndStartStream() async {
    // Call /balance first - this auto-initializes credits for new users
    try {
      debugPrint('🔄 [CreditsProvider] Fetching initial balance (triggers init for new users)');
      final balance = await API.instance.getCreditsBalance();
      _balance = balance;
      _hasInitialData = true;
      _isFallback = false;
      _isLoading = false;
      
      // Cache for instant display on next app start
      _saveToCache(balance);
      
      debugPrint('✅ [CreditsProvider] Initial balance: $balance');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [CreditsProvider] Initial balance fetch failed: $e');
      // Continue anyway - stream will handle updates
    }

    // Now start SSE stream for real-time updates
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

    // Cache the balance for instant display on next app start
    if (!event.fallback) {
      _saveToCache(event.balance);
    }

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

      // Cache for instant display on next app start
      _saveToCache(balance);

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
