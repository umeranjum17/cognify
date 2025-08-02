import 'dart:isolate';

/// Tool execution result
class ToolResult {
  final String tool;
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;
  final int executionTime;
  final String timestamp;
  final int order;
  final bool failed;

  ToolResult({
    required this.tool,
    required this.input,
    required this.output,
    required this.executionTime,
    required this.timestamp,
    required this.order,
    required this.failed,
  });

  Map<String, dynamic> toJson() {
    return {
      'tool': tool,
      'input': input,
      'output': output,
      'executionTime': executionTime,
      'timestamp': timestamp,
      'order': order,
      'failed': failed,
    };
  }
}

/// Isolate result for tool execution
class ToolExecutionResult {
  final String toolName;
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;
  final int executionTime;
  final String timestamp;
  final int order;
  final bool failed;
  final String? error;

  ToolExecutionResult({
    required this.toolName,
    required this.input,
    required this.output,
    required this.executionTime,
    required this.timestamp,
    required this.order,
    required this.failed,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'input': input,
    'output': output,
    'executionTime': executionTime,
    'timestamp': timestamp,
    'order': order,
    'failed': failed,
    if (error != null) 'error': error,
  };
}

/// Isolate message for tool execution
class ToolExecutionMessage {
  final String toolName;
  final Map<String, dynamic> input;
  final int order;
  final String reasoning;

  ToolExecutionMessage({
    required this.toolName,
    required this.input,
    required this.order,
    required this.reasoning,
  });

  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'input': input,
    'order': order,
    'reasoning': reasoning,
  };
}

/// Isolate data structure for tool execution
class IsolateData {
  final ToolExecutionMessage message;
  final SendPort sendPort;

  IsolateData({
    required this.message,
    required this.sendPort,
  });
} 