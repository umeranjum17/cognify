import 'dart:async';
import 'package:flutter/foundation.dart';

/// Event types that should trigger credit updates
enum CreditEventType {
  messageConsumed,
  messageCompleted,
  chatOpened,
  creditsPurchased,
  creditsRefunded,
  sessionReset,
}

/// Event data for credit updates
class CreditEvent {
  final CreditEventType type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const CreditEvent({
    required this.type,
    this.data,
    required this.timestamp,
  });
}

/// Service to manage event-driven credit updates
/// This replaces the need for frequent polling by triggering updates
/// only when specific events occur
class CreditEventService {
  CreditEventService._();
  static final CreditEventService instance = CreditEventService._();

  final StreamController<CreditEvent> _eventController = 
      StreamController<CreditEvent>.broadcast();

  /// Stream of credit events
  Stream<CreditEvent> get events => _eventController.stream;

  /// Emit a credit event
  void emitEvent(CreditEventType type, {Map<String, dynamic>? data}) {
    final event = CreditEvent(
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );
    
    if (!_eventController.isClosed) {
      _eventController.add(event);
      debugPrint('🔄 [CreditEvent] Emitted ${type.name} event with data: ${data?.toString() ?? 'none'}');
    } else {
      debugPrint('❌ [CreditEvent] Cannot emit ${type.name} event - controller is closed');
    }
  }

  /// Convenience methods for common events
  void emitMessageConsumed({
    required String requestId,
    required int amount,
    required String modelId,
    required String mode,
    double? dollarCost,
    int? inputTokens,
    int? outputTokens,
  }) {
    emitEvent(
      CreditEventType.messageConsumed,
      data: {
        'requestId': requestId,
        'amount': amount,
        'modelId': modelId,
        'mode': mode,
        'dollarCost': dollarCost,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
      },
    );
  }

  void emitMessageCompleted({
    required String requestId,
    required double messageCost,
    required double sessionCost,
    required int messageCount,
    Map<String, dynamic>? costBreakdown,
  }) {
    emitEvent(
      CreditEventType.messageCompleted,
      data: {
        'requestId': requestId,
        'messageCost': messageCost,
        'sessionCost': sessionCost,
        'messageCount': messageCount,
        'costBreakdown': costBreakdown,
      },
    );
  }

  void emitChatOpened({required String conversationId}) {
    emitEvent(
      CreditEventType.chatOpened,
      data: {'conversationId': conversationId},
    );
  }

  void emitCreditsPurchased({required int amount, required int newBalance}) {
    emitEvent(
      CreditEventType.creditsPurchased,
      data: {
        'amount': amount,
        'newBalance': newBalance,
      },
    );
  }

  void emitCreditsRefunded({required int amount, required int newBalance}) {
    emitEvent(
      CreditEventType.creditsRefunded,
      data: {
        'amount': amount,
        'newBalance': newBalance,
      },
    );
  }

  void emitSessionReset() {
    emitEvent(CreditEventType.sessionReset);
  }

  void dispose() {
    _eventController.close();
  }
}
