// Agent service stub
class AgentService {
  Future<void> initialize() async {}

  Future<Map<String, dynamic>> executeTool({
    required String toolName,
    required Map<String, dynamic> input,
  }) async {
    return {};
  }

  Map<String, dynamic> getStatus() {
    return {};
  }

  List<Map<String, dynamic>> getAllToolInfo() {
    return [];
  }

  Future<Map<String, dynamic>> testTool(String toolName, Map<String, dynamic> input) async {
    return {};
  }
}
