// Agent system stub
import '../../models/chat_stream_event.dart';

class AgentSystem {
  Future<void> initialize() async {}

  Stream<ChatStreamEvent> processQuery({
    required String query,
    required String modelId,
    Map<String, dynamic>? context,
    List<String>? enabledTools,
  }) async* {
    yield ChatStreamEvent(type: StreamEventType.complete);
  }

  Stream<ChatStreamEvent> processSourceGroundedQuery({
    required String query,
    required List<dynamic> sources,
    required String modelId,
    List<String>? sourceIds,
  }) async* {
    yield ChatStreamEvent(type: StreamEventType.complete);
  }
}
