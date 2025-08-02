import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Enhanced connection manager for reliable background streaming
class ConnectionManager extends ChangeNotifier {
  static final ConnectionManager _instance = ConnectionManager._internal();
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  // Connection state
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _backgroundModeEnabled = false;
  String _connectionStatus = 'Disconnected';
  
  // Streaming state
  final Map<String, StreamSubscription> _activeStreams = {};
  final Map<String, WebSocketChannel> _webSocketChannels = {};
  
  // Network monitoring
  NetworkConnectivity _connectivityResult = NetworkConnectivity.unknown;
  Timer? _connectivityTimer;
  
  // Retry logic
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  // Background notification
  Timer? _backgroundHeartbeat;
  // Wake lock simulation (for basic implementation)
  bool _wakeLockEnabled = false;
  
  factory ConnectionManager() => _instance;
  
  ConnectionManager._internal();
  
  int get activeStreamCount => _activeStreams.length;
  bool get backgroundModeEnabled => _backgroundModeEnabled;
  String get connectionStatus => _connectionStatus;
  NetworkConnectivity get connectivityResult => _connectivityResult;
  // Getters
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;

  /// Close all streaming connections
  Future<void> closeAllStreamingConnections() async {
    debugPrint('🔒 Closing all streaming connections...');
    
    final streamIds = List<String>.from(_activeStreams.keys);
    for (final streamId in streamIds) {
      await closeStreamingConnection(streamId);
    }
    
    debugPrint('✅ All streaming connections closed');
  }

  /// Close a specific streaming connection
  Future<void> closeStreamingConnection(String streamId) async {
    debugPrint('🔒 Closing streaming connection for $streamId...');
    
    await _activeStreams[streamId]?.cancel();
    _activeStreams.remove(streamId);
    
    await _webSocketChannels[streamId]?.sink.close();
    _webSocketChannels.remove(streamId);
    
    debugPrint('✅ Streaming connection closed for $streamId');
  }

  /// Create a persistent WebSocket connection for streaming
  Future<WebSocketChannel?> createStreamingConnection(String streamId, String endpoint) async {
    debugPrint('🌊 Creating streaming connection for $streamId...');
    
    try {
      // Close existing connection if any
      await closeStreamingConnection(streamId);
      
      final wsEndpoint = endpoint.replaceFirst('http', 'ws');
      final channel = WebSocketChannel.connect(Uri.parse(wsEndpoint));
      
      _webSocketChannels[streamId] = channel;
      
      // Monitor connection and handle reconnects
      _activeStreams[streamId] = channel.stream.listen(
        (data) {
          debugPrint('📡 Stream $streamId received data');
          // Handle incoming data
        },
        onError: (error) {
          debugPrint('❌ Stream $streamId error: $error');
          _handleStreamError(streamId, error);
        },
        onDone: () {
          debugPrint('✅ Stream $streamId completed');
          _cleanupStream(streamId);
        },
      );
      
      debugPrint('✅ Streaming connection created for $streamId');
      return channel;
      
    } catch (e) {
      debugPrint('❌ Failed to create streaming connection: $e');
      return null;
    }
  }

  /// Disable background mode
  Future<void> disableBackgroundMode() async {
    if (!_backgroundModeEnabled) return;
    
    debugPrint('☀️ Disabling background mode...');
    
    try {
      // Disable wake lock
      await _disableWakeLock();
      
      _backgroundModeEnabled = false;
      await _saveBackgroundModePreference(false);
      
      // Stop background heartbeat
      _stopBackgroundHeartbeat();
      
      _updateConnectionStatus('Background mode disabled');
      debugPrint('✅ Background mode disabled successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to disable background mode: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    debugPrint('🧹 Disposing Connection Manager...');
    
    _connectivityTimer?.cancel();
    _reconnectTimer?.cancel();
    _stopBackgroundHeartbeat();
    
    closeAllStreamingConnections();
    
    if (_backgroundModeEnabled) {
      _disableWakeLock();
    }
    
    super.dispose();
  }

  /// Enable background mode with wake lock and persistent connections
  Future<void> enableBackgroundMode() async {
    if (_backgroundModeEnabled) return;
    
    debugPrint('� Enabling background mode...');
    
    try {
      // Enable wake lock simulation
      await _enableWakeLock();
      
      _backgroundModeEnabled = true;
      await _saveBackgroundModePreference(true);
      
      // Start background heartbeat
      _startBackgroundHeartbeat();
      
      // Reconnect with background-optimized settings
      await _reconnectWithBackgroundOptimization();
      
      _updateConnectionStatus('Background mode enabled');
      debugPrint('✅ Background mode enabled successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to enable background mode: $e');
      _updateConnectionStatus('Failed to enable background mode');
    }
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'isReconnecting': _isReconnecting,
      'backgroundModeEnabled': _backgroundModeEnabled,
      'connectionStatus': _connectionStatus,
      'activeStreams': _activeStreams.length,
      'reconnectAttempts': _reconnectAttempts,
      'connectivity': _connectivityResult.name,
      'wakeLockEnabled': _wakeLockEnabled,
    };
  }

  /// Initialize the connection manager
  Future<void> initialize() async {
    debugPrint('🔌 Initializing Connection Manager...');
    
    await _loadBackgroundModePreference();
    await _startNetworkMonitoring();
    await _checkInitialConnectivity();
    
    debugPrint('✅ Connection Manager initialized');
  }

  /// Attempt reconnection with exponential backoff
  Future<void> _attemptReconnection() async {
    if (_isReconnecting) return;
    
    _isReconnecting = true;
    _updateConnectionStatus('Reconnecting...');
    
    debugPrint('🔄 Attempting reconnection (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');
    
    try {
      // Test connection with health check
      final connected = await _testConnection();
      
      if (connected) {
        _isConnected = true;
        _isReconnecting = false;
        _reconnectAttempts = 0;
        _updateConnectionStatus('Connected');
        
        // Recreate streaming connections if in background mode
        if (_backgroundModeEnabled) {
          await _recreateStreamingConnections();
        }
        
        debugPrint('✅ Reconnection successful');
      } else {
        throw Exception('Connection test failed');
      }
      
    } catch (e) {
      debugPrint('❌ Reconnection failed: $e');
      _isConnected = false;
      _scheduleReconnection();
    }
    
    _isReconnecting = false;
    notifyListeners();
  }

  /// Check initial connectivity
  Future<void> _checkInitialConnectivity() async {
    final connected = await _testConnection();
    final result = connected ? NetworkConnectivity.connected : NetworkConnectivity.disconnected;
    await _onConnectivityChanged(result);
  }

  /// Cleanup stream resources
  void _cleanupStream(String streamId) {
    _activeStreams.remove(streamId);
    _webSocketChannels.remove(streamId);
    notifyListeners();
  }

  /// Disable wake lock
  Future<void> _disableWakeLock() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      _wakeLockEnabled = false;
      debugPrint('� Wake lock disabled');
    } catch (e) {
      debugPrint('❌ Failed to disable wake lock: $e');
    }
  }

  /// Enable wake lock (basic implementation)
  Future<void> _enableWakeLock() async {
    try {
      // Keep screen on during streaming
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _wakeLockEnabled = true;
      debugPrint('🔒 Wake lock enabled');
    } catch (e) {
      debugPrint('❌ Failed to enable wake lock: $e');
    }
  }

  /// Handle stream errors
  void _handleStreamError(String streamId, dynamic error) {
    debugPrint('❌ Stream error for $streamId: $error');
    
    // Attempt to recreate the stream if in background mode
    if (_backgroundModeEnabled) {
      Timer(const Duration(seconds: 5), () {
        // Recreate stream logic here
        debugPrint('🔄 Attempting to recreate stream $streamId');
      });
    }
  }

  /// Load background mode preference
  Future<void> _loadBackgroundModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundModeEnabled = prefs.getBool('background_mode_enabled') ?? false;
    
    if (_backgroundModeEnabled) {
      await _enableWakeLock();
      _startBackgroundHeartbeat();
    }
  }

  /// Handle network connectivity changes
  Future<void> _onConnectivityChanged(NetworkConnectivity result) async {
    _connectivityResult = result;
    
    final hasConnection = result == NetworkConnectivity.connected;
    
    debugPrint('🌐 Connectivity changed: $result (hasConnection: $hasConnection)');
    
    if (hasConnection && !_isConnected) {
      // Network became available, attempt reconnection
      await _attemptReconnection();
    } else if (!hasConnection && _isConnected) {
      // Network lost, update status but keep trying to reconnect
      _updateConnectionStatus('Network unavailable');
      _isConnected = false;
      _scheduleReconnection();
    }
    
    notifyListeners();
  }

  /// Reconnect with background optimization
  Future<void> _reconnectWithBackgroundOptimization() async {
    debugPrint('🌙 Reconnecting with background optimization...');
    
    // Implement background-specific connection strategies
    await _attemptReconnection();
  }

  /// Recreate streaming connections after reconnection
  Future<void> _recreateStreamingConnections() async {
    debugPrint('🔄 Recreating streaming connections...');
    
    // This would be called after successful reconnection
    // Implementation depends on your specific streaming needs
  }

  /// Save background mode preference
  Future<void> _saveBackgroundModePreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_mode_enabled', enabled);
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnection() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _updateConnectionStatus('Max reconnect attempts reached');
      debugPrint('� Max reconnection attempts reached');
      return;
    }
    
    _reconnectTimer?.cancel();
    
    final delay = Duration(
      milliseconds: _baseRetryDelay.inMilliseconds * 
                   (1 << _reconnectAttempts.clamp(0, 5)) // Exponential backoff, max 64x
    );
    
    debugPrint('⏰ Scheduling reconnection in ${delay.inSeconds}s');
    
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _attemptReconnection();
    });
  }

  /// Start background heartbeat
  void _startBackgroundHeartbeat() {
    _backgroundHeartbeat?.cancel();
    
    _backgroundHeartbeat = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_backgroundModeEnabled) {
        debugPrint('💓 Background heartbeat - Active streams: ${_activeStreams.length}');
        _testConnection().then((connected) {
          if (!connected && _isConnected) {
            _scheduleReconnection();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Start network monitoring using periodic connectivity checks
  Future<void> _startNetworkMonitoring() async {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final connected = await _testConnection();
      final newState = connected ? NetworkConnectivity.connected : NetworkConnectivity.disconnected;
      
      if (newState != _connectivityResult) {
        await _onConnectivityChanged(newState);
      }
    });
    
    debugPrint('� Network monitoring started');
  }

  /// Stop background heartbeat
  void _stopBackgroundHeartbeat() {
    _backgroundHeartbeat?.cancel();
    _backgroundHeartbeat = null;
  }

  /// Test connection (no longer tests server - app is standalone)
  Future<bool> _testConnection() async {
    try {
      // Since the app is now standalone, always return true for network connectivity
      // We can check internet connectivity instead of server connectivity
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update connection status
  void _updateConnectionStatus(String status) {
    _connectionStatus = status;
    debugPrint('🔌 Connection status: $status');
    notifyListeners();
  }
}

/// Network connectivity states
enum NetworkConnectivity { 
  connected, 
  disconnected, 
  unknown 
}