import 'dart:async';
import 'package:flutter/foundation.dart';
import 'credit_event_service.dart';

/// Immutable snapshot of session cost stats.
class SessionCostData {
  final double sessionCost;
  final double lastMessageCost;
  final int messageCount;

  const SessionCostData({
    required this.sessionCost,
    required this.lastMessageCost,
    required this.messageCount,
  });

  SessionCostData copyWith({
    double? sessionCost,
    double? lastMessageCost,
    int? messageCount,
  }) {
    return SessionCostData(
      sessionCost: sessionCost ?? this.sessionCost,
      lastMessageCost: lastMessageCost ?? this.lastMessageCost,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}

/// Lightweight service to aggregate and stream session cost updates.
///
/// This minimal implementation satisfies current UI usages:
/// - exposes a broadcast [Stream] of [SessionCostData]
/// - exposes current [messageCount]
/// - allows adding generation IDs (no-op placeholder) and resetting session
class SessionCostService {
  static final SessionCostService _instance = SessionCostService._internal();
  factory SessionCostService() => _instance;

  SessionCostService._internal() {
    _initializeEventListeners();
  }

  final StreamController<SessionCostData> _controller =
      StreamController<SessionCostData>.broadcast();
  StreamSubscription<CreditEvent>? _eventSubscription;

  double _sessionCost = 0.0;
  double _lastMessageCost = 0.0;
  int _messageCount = 0;

  Stream<SessionCostData> get costUpdates => _controller.stream;

  int get messageCount => _messageCount;

  /// Current snapshot for consumers that need immediate values
  SessionCostData get currentData => SessionCostData(
        sessionCost: _sessionCost,
        lastMessageCost: _lastMessageCost,
        messageCount: _messageCount,
      );

  /// Initialize event listeners for real-time updates
  void _initializeEventListeners() {
    _eventSubscription = CreditEventService.instance.events.listen((event) {
      switch (event.type) {
        case CreditEventType.messageCompleted:
          _handleMessageCompleted(event);
          break;
        case CreditEventType.sessionReset:
          resetSession();
          break;
        default:
          // Other events don't affect session cost directly
          break;
      }
    });
  }

  /// Handle message completed event
  void _handleMessageCompleted(CreditEvent event) {
    final data = event.data;
    if (data != null) {
      final messageCost = (data['messageCost'] as num?)?.toDouble() ?? 0.0;
      final sessionCost = (data['sessionCost'] as num?)?.toDouble() ?? 0.0;
      final messageCount = (data['messageCount'] as int?) ?? 0;
      
      // Update internal state
      _lastMessageCost = messageCost;
      _sessionCost = sessionCost;
      _messageCount = messageCount;
      
      debugPrint('💰 [SessionCost] Updated: message=\$${messageCost.toStringAsFixed(4)}, session=\$${sessionCost.toStringAsFixed(4)}, count=$messageCount');
      
      // Emit update
      _emit();
    }
  }

  /// Public API used by UI to register generation IDs for cost tracking.
  /// This is a no-op placeholder that just emits the current snapshot.
  Future<void> addGenerationIds(List<Map<String, dynamic>> ids) async {
    // Placeholder: In a fuller implementation, we'd fetch/compute costs
    // based on provided generation metadata. For now, just emit unchanged
    // snapshot so listeners remain functional.
    _emit();
  }

  /// Update costs explicitly.
  void updateCosts({required double lastMessageCostDelta}) {
    _lastMessageCost = lastMessageCostDelta;
    _sessionCost += lastMessageCostDelta;
    _messageCount += 1;
    _emit();
  }

  /// Reset session state and notify listeners.
  void resetSession() {
    _sessionCost = 0.0;
    _lastMessageCost = 0.0;
    _messageCount = 0;
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(SessionCostData(
      sessionCost: _sessionCost,
      lastMessageCost: _lastMessageCost,
      messageCount: _messageCount,
    ));
  }

  void dispose() {
    _eventSubscription?.cancel();
    _controller.close();
  }
}


