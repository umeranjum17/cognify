import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connection_manager.dart';

/// Widget that handles background streaming and maintains connections
/// when the app is minimized or in the background
class BackgroundStreamHandler extends StatefulWidget {
  final Widget child;
  final bool enableBackgroundStreaming;
  final Function(String)? onStreamData;
  final Function(String)? onStreamError;
  final Function()? onConnectionStatusChanged;
  
  const BackgroundStreamHandler({
    super.key,
    required this.child,
    this.enableBackgroundStreaming = true,
    this.onStreamData,
    this.onStreamError,
    this.onConnectionStatusChanged,
  });

  @override
  State<BackgroundStreamHandler> createState() => _BackgroundStreamHandlerState();
}

/// Provider widget to access BackgroundStreamHandler in the widget tree
class BackgroundStreamProvider extends InheritedWidget {
  final _BackgroundStreamHandlerState handler;
  
  const BackgroundStreamProvider({
    super.key,
    required this.handler,
    required super.child,
  });

  @override
  bool updateShouldNotify(BackgroundStreamProvider oldWidget) {
    return handler != oldWidget.handler;
  }

  static _BackgroundStreamHandlerState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BackgroundStreamProvider>()?.handler;
  }
}

/// Connection status indicator widget for UI
class ConnectionStatusWidget extends StatelessWidget {
  final bool showWhenConnected;
  
  const ConnectionStatusWidget({
    super.key,
    this.showWhenConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    final handler = context.backgroundStream;
    if (handler == null) return const SizedBox.shrink();
    
    return ListenableBuilder(
      listenable: handler._connectionManager,
      builder: (context, child) {
        final stats = handler.getConnectionStatus();
        final isConnected = stats['isConnected'] as bool;
        final status = stats['connectionStatus'] as String;
        final activeStreams = stats['activeStreams'] as int;
        
        if (isConnected && !showWhenConnected) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConnected ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isConnected ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: isConnected ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Connected ($activeStreams)' : status,
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundStreamHandlerState extends State<BackgroundStreamHandler>
    with WidgetsBindingObserver {
  
  final ConnectionManager _connectionManager = ConnectionManager();
  late StreamSubscription _connectionStatusSubscription;
  
  bool _isAppInBackground = false;
  bool _isStreamingActive = false;
  Timer? _backgroundActivityTimer;
  
  /// Get active stream count
  int get activeStreamCount => _connectionManager.activeStreamCount;

  /// Check if app is currently in background
  bool get isAppInBackground => _isAppInBackground;

  /// Check if background streaming is active
  bool get isBackgroundStreamingActive => 
      _connectionManager.backgroundModeEnabled && _isStreamingActive;

  @override
  Widget build(BuildContext context) {
    return BackgroundStreamProvider(
      handler: this,
      child: widget.child,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('� App lifecycle changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionStatusSubscription.cancel();
    _backgroundActivityTimer?.cancel();
    _connectionManager.dispose();
    super.dispose();
  }

  /// Get current connection status
  Map<String, dynamic> getConnectionStatus() {
    return _connectionManager.getConnectionStats();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBackgroundStreaming();
  }

  /// Start a streaming session
  Future<void> startStreaming(String streamId, String endpoint) async {
    try {
      debugPrint('🌊 Starting stream: $streamId');
      
      final channel = await _connectionManager.createStreamingConnection(streamId, endpoint);
      if (channel != null) {
        _isStreamingActive = true;
        
        // If app is already in background, enable background mode
        if (_isAppInBackground) {
          await _connectionManager.enableBackgroundMode();
        }
        
        debugPrint('✅ Stream started successfully: $streamId');
      } else {
        throw Exception('Failed to create streaming connection');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to start streaming: $e');
      widget.onStreamError?.call('Failed to start streaming: $e');
    }
  }

  /// Stop all streaming sessions
  Future<void> stopAllStreaming() async {
    try {
      debugPrint('🛑 Stopping all streams');
      
      await _connectionManager.closeAllStreamingConnections();
      _isStreamingActive = false;
      
      if (_connectionManager.backgroundModeEnabled) {
        await _connectionManager.disableBackgroundMode();
      }
      
      debugPrint('✅ All streams stopped successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to stop all streaming: $e');
      widget.onStreamError?.call('Failed to stop all streaming: $e');
    }
  }

  /// Stop a streaming session
  Future<void> stopStreaming(String streamId) async {
    try {
      debugPrint('🛑 Stopping stream: $streamId');
      
      await _connectionManager.closeStreamingConnection(streamId);
      
      // Check if this was the last active stream
      if (_connectionManager.activeStreamCount == 0) {
        _isStreamingActive = false;
        
        // Disable background mode if no active streams
        if (_connectionManager.backgroundModeEnabled) {
          await _connectionManager.disableBackgroundMode();
        }
      }
      
      debugPrint('✅ Stream stopped successfully: $streamId');
      
    } catch (e) {
      debugPrint('❌ Failed to stop streaming: $e');
      widget.onStreamError?.call('Failed to stop streaming: $e');
    }
  }

  /// Clean up background resources
  void _cleanupBackgroundResources() {
    _backgroundActivityTimer?.cancel();
    _connectionManager.closeAllStreamingConnections();
  }

  /// Handle app detached
  void _handleAppDetached() {
    debugPrint('💀 App detached');
    _cleanupBackgroundResources();
  }

  /// Handle app hidden
  void _handleAppHidden() {
    debugPrint('👻 App hidden');
    // Similar to inactive, app is hidden but not necessarily backgrounded
  }

  /// Handle app inactive
  void _handleAppInactive() {
    debugPrint('😴 App inactive');
    // App is temporarily inactive (e.g., phone call, notification panel)
    // Don't enable background mode yet, wait for paused state
  }

  /// Handle app paused (going to background)
  void _handleAppPaused() async {
    debugPrint('🌙 App paused - going to background');
    _isAppInBackground = true;
    
    if (widget.enableBackgroundStreaming && _isStreamingActive) {
      debugPrint('🔒 Enabling background mode for active streams');
      await _connectionManager.enableBackgroundMode();
      _startBackgroundActivityMonitoring();
    }
  }

  /// Handle app resumed from background
  void _handleAppResumed() async {
    debugPrint('🌟 App resumed from background');
    _isAppInBackground = false;
    _backgroundActivityTimer?.cancel();
    
    // Reconnect if needed
    if (!_connectionManager.isConnected) {
      debugPrint('🔄 Reconnecting after app resume...');
      // The connection manager will handle reconnection automatically
    }
    
    // Disable background mode if it was enabled
    if (_connectionManager.backgroundModeEnabled) {
      debugPrint('☀️ Disabling background mode - app is active');
      await _connectionManager.disableBackgroundMode();
    }
  }

  /// Initialize background streaming capabilities
  Future<void> _initializeBackgroundStreaming() async {
    try {
      await _connectionManager.initialize();
      
      // Listen to connection status changes
      _connectionStatusSubscription = _connectionManager.addListener(() {
        if (mounted) {
          widget.onConnectionStatusChanged?.call();
          setState(() {}); // Trigger rebuild for UI updates
        }
      }) as StreamSubscription;
      
      debugPrint('✅ Background streaming handler initialized');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize background streaming: $e');
      widget.onStreamError?.call('Failed to initialize background streaming: $e');
    }
  }

  /// Notify about background activity
  void _notifyBackgroundActivity(Map<String, dynamic> stats) {
    // This could trigger a system notification or update UI indicators
    debugPrint('📊 Background stats: ${stats['activeStreams']} active streams, ${stats['connectionStatus']}');
  }

  /// Start monitoring background activity
  void _startBackgroundActivityMonitoring() {
    _backgroundActivityTimer?.cancel();
    
    _backgroundActivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isAppInBackground && _connectionManager.backgroundModeEnabled) {
        final stats = _connectionManager.getConnectionStats();
        debugPrint('💓 Background activity check - ${stats['connectionStatus']}');
        
        // Send background activity notification
        _notifyBackgroundActivity(stats);
      } else {
        timer.cancel();
      }
    });
  }
}

/// Helper extension to easily access background streaming from any widget
extension BackgroundStreamContext on BuildContext {
  _BackgroundStreamHandlerState? get backgroundStream =>
      BackgroundStreamProvider.of(this);
}