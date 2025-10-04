// Session cost tracking stub
class SessionCostData {
  final double totalCost;
  final int messageCount;
  final Map<String, double> modelCosts;
  final double sessionCost;
  final double lastMessageCost;

  SessionCostData({
    this.totalCost = 0.0,
    this.messageCount = 0,
    this.modelCosts = const {},
    this.sessionCost = 0.0,
    this.lastMessageCost = 0.0,
  });
}

class SessionCostService {
  static final SessionCostService _instance = SessionCostService._internal();
  factory SessionCostService() => _instance;
  SessionCostService._internal();

  final Stream<SessionCostData> costUpdates = Stream.value(SessionCostData());

  int get messageCount => 0;
  double get totalCost => 0.0;

  void resetSession() {}
  void addCost(String model, double cost) {}
  Future<void> addGenerationIds(List<dynamic> ids, {String? sessionId}) async {}
  Future<void> recalculateSessionCosts() async {}
  Future<Map<String, dynamic>> getSessionSummary() async => {};
}
