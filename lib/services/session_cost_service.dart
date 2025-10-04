import 'dart:async';

/// Lightweight session cost tracking used by the UI.
class SessionCostData {
  final double sessionCost;
  final double lastMessageCost;
  final int messageCount;

  const SessionCostData({
    required this.sessionCost,
    required this.lastMessageCost,
    required this.messageCount,
  });
}

class SessionCostService {
  static final SessionCostService _instance = SessionCostService._internal();
  factory SessionCostService() => _instance;
  SessionCostService._internal();

  final StreamController<SessionCostData> _controller =
      StreamController<SessionCostData>.broadcast();

  double _sessionCost = 0.0;
  double _lastCost = 0.0;
  int _messageCount = 0;

  Stream<SessionCostData> get costUpdates => _controller.stream;
  int get messageCount => _messageCount;

  void resetSession() {
    _sessionCost = 0.0;
    _lastCost = 0.0;
    _messageCount = 0;
    _emit();
  }

  /// Record a cost for last operation and update session totals.
  void addCost(double cost) {
    _lastCost = cost;
    _sessionCost += cost;
    _messageCount += 1;
    _emit();
  }

  /// Accepts generation metadata list and updates counters. Cost resolution is optional.
  Future<void> addGenerationIds(List<Map<String, dynamic>> items) async {
    // This stub doesn't resolve cost by generation ID; just increments counters.
    _messageCount += items.isEmpty ? 0 : 1;
    _emit();
  }

  void _emit() {
    _controller.add(
      SessionCostData(
        sessionCost: _sessionCost,
        lastMessageCost: _lastCost,
        messageCount: _messageCount,
      ),
    );
  }
}

