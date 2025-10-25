import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../config/app_config.dart';

/// Real-time credits data from SSE stream
class CreditsEvent {
  final double balance;
  final String lastUpdated;
  final int precision;
  final bool fallback;
  final bool isError;
  final String? errorMessage;

  const CreditsEvent({
    required this.balance,
    required this.lastUpdated,
    required this.precision,
    this.fallback = false,
    this.isError = false,
    this.errorMessage,
  });

  factory CreditsEvent.fromJson(Map<String, dynamic> json) {
    return CreditsEvent(
      balance: (json['balance'] as num).toDouble(),
      lastUpdated: json['lastUpdated'] as String,
      precision: (json['precision'] as num?)?.toInt() ?? 1,
      fallback: json['fallback'] as bool? ?? false,
      isError: false,
    );
  }

  factory CreditsEvent.error(String message) {
    return CreditsEvent(
      balance: 0.0,
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
      precision: 1,
      isError: true,
      errorMessage: message,
    );
  }

  @override
  String toString() {
    if (isError) return 'CreditsEvent.error($errorMessage)';
    return 'CreditsEvent(balance: $balance, fallback: $fallback)';
  }
}

/// Server-Sent Events client for real-time credits updates
class CreditsStreamService {
  CreditsStreamService._();
  static final CreditsStreamService instance = CreditsStreamService._();

  StreamController<CreditsEvent>? _controller;
  StreamSubscription<String>? _subscription;
  http.Client? _client;
  String? _lastEventId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  /// Stream of credits events
  Stream<CreditsEvent> get events {
    _controller ??= StreamController<CreditsEvent>.broadcast();
    return _controller!.stream;
  }

  /// Start the SSE connection
  Future<void> start() async {
    if (_subscription != null) {
      debugPrint('🔄 [CreditsStream] Already connected');
      return;
    }

    debugPrint('🔄 [CreditsStream] Starting SSE connection...');
    await _connect();
  }

  /// Stop the SSE connection
  Future<void> stop() async {
    debugPrint('🔄 [CreditsStream] Stopping SSE connection...');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _reconnectAttempts = 0;
  }

  /// Connect to the SSE endpoint
  Future<void> _connect() async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ [CreditsStream] No authenticated user');
        _emitError('No authenticated user');
        return;
      }

      final token = await user.getIdToken(true);
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/credits/stream');
      
      debugPrint('🔄 [CreditsStream] Connecting to: $url');

      _client = http.Client();
      final request = http.Request('GET', url);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        if (_lastEventId != null) 'Last-Event-ID': _lastEventId!,
      });

      final streamedResponse = await _client!.send(request);
      
      if (streamedResponse.statusCode != 200) {
        throw Exception('SSE connection failed: ${streamedResponse.statusCode}');
      }

      debugPrint('✅ [CreditsStream] SSE connection established');
      _reconnectAttempts = 0;

      // Process the SSE stream
      _subscription = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleSSELine,
            onError: _handleError,
            onDone: _handleDisconnect,
          );

    } catch (e) {
      debugPrint('❌ [CreditsStream] Connection failed: $e');
      _handleError(e);
    }
  }

  /// Handle individual SSE lines
  void _handleSSELine(String line) {
    if (line.isEmpty) return;

    try {
      if (line.startsWith('event: ')) {
        final eventType = line.substring(7);
        _currentEventType = eventType;
      } else if (line.startsWith('data: ')) {
        final data = line.substring(6);
        _handleEventData(data);
      } else if (line.startsWith('id: ')) {
        _lastEventId = line.substring(4);
      }
    } catch (e) {
      debugPrint('❌ [CreditsStream] Error parsing line: $line - $e');
    }
  }

  String? _currentEventType;

  /// Handle SSE event data
  void _handleEventData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      
      switch (_currentEventType) {
        case 'connected':
          debugPrint('✅ [CreditsStream] Connected to server');
          break;
        case 'balance':
          final event = CreditsEvent.fromJson(json);
          debugPrint('💰 [CreditsStream] Balance update: ${event.balance} credits');
          _controller?.add(event);
          break;
        case 'ping':
          debugPrint('💓 [CreditsStream] Heartbeat received');
          break;
        case 'error':
          final errorMsg = json['error'] as String? ?? 'Unknown error';
          debugPrint('❌ [CreditsStream] Server error: $errorMsg');
          _emitError(errorMsg);
          break;
        default:
          debugPrint('⚠️ [CreditsStream] Unknown event type: $_currentEventType');
      }
    } catch (e) {
      debugPrint('❌ [CreditsStream] Error parsing event data: $data - $e');
    }
  }

  /// Handle connection errors
  void _handleError(dynamic error) {
    debugPrint('❌ [CreditsStream] Connection error: $error');
    _emitError(error.toString());
    _scheduleReconnect();
  }

  /// Handle disconnection
  void _handleDisconnect() {
    debugPrint('🔄 [CreditsStream] Connection closed');
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _scheduleReconnect();
  }

  /// Emit an error event
  void _emitError(String message) {
    _controller?.add(CreditsEvent.error(message));
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ [CreditsStream] Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: (_baseReconnectDelay.inMilliseconds * 
        (1 << (_reconnectAttempts - 1).clamp(0, 10))).clamp(
        _baseReconnectDelay.inMilliseconds,
        _maxReconnectDelay.inMilliseconds,
      ),
    );

    debugPrint('🔄 [CreditsStream] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      _connect();
    });
  }

  /// Dispose resources
  void dispose() {
    stop();
    _controller?.close();
    _controller = null;
  }
}
