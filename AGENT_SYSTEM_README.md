# Agent System for Flutter App

This document describes the implementation of the agent system in the Flutter app, which replicates the backend tools and agents functionality directly in the mobile application.

## Overview

The agent system consists of three main components:

1. **Tools** (`lib/services/tools.dart`) - Individual tools that can be executed
2. **Agents** (`lib/services/agents.dart`) - AI agents that coordinate tool execution
3. **Agent Service** (`lib/services/agent_service.dart`) - Main interface for the agent system

## Architecture

### Tools System

The tools system provides a unified interface for various capabilities:

- **BraveSearchTool** - Web search using Brave Search API
- **BraveSearchEnhancedTool** - Enhanced search with content extraction
- **SequentialThinkingTool** - Problem breakdown and analysis
- **WebFetchTool** - Content extraction from URLs
- **YouTubeTool** - YouTube video processing
- **BrowserRoadmapTool** - Learning roadmap access
- **ImageSearchTool** - Image search capabilities
- **KeywordExtractionTool** - Text keyword extraction
- **MemoryTool** - Conversation memory management
- **SourceQueryTool** - Source content querying
- **SourceContentTool** - Source content extraction
- **TimeTool** - Time and date information

### Agent System

The agent system consists of three specialized agents:

#### 1. Planner Agent
- Analyzes user queries
- Creates execution plans
- Determines which tools to use and in what order
- Uses LLM to make intelligent decisions

#### 2. Executor Agent
- Executes tools based on plans from Planner Agent
- Handles tool execution in sequence or parallel
- Provides progress updates and error handling
- Pure tool execution engine (no LLM required)

#### 3. Writer Agent
- Creates final responses from tool results
- Uses LLM to generate comprehensive answers
- Supports streaming responses
- Handles conversation context and personality

### Agent Service

The main interface that coordinates all components:

- Initializes the agent system
- Provides high-level API for chat processing
- Handles tool management and validation
- Integrates with existing Flutter app services

## Usage

### Basic Usage

```dart
// Initialize the agent service
final agentService = AgentService();
await agentService.initialize();

// Process a chat query
await for (final response in agentService.processChat(
  query: 'What is Flutter?',
  messages: conversationHistory,
  enabledTools: ToolsConfig(
    braveSearch: true,
    sequentialThinking: true,
  ),
)) {
  switch (response.type) {
    case 'status':
      print('Status: ${response.content}');
      break;
    case 'content':
      print('Response: ${response.content}');
      break;
    case 'complete':
      print('Completed');
      break;
  }
}
```

### Tool Testing

```dart
// Test a specific tool
final result = await agentService.testTool(
  toolName: 'brave_search',
  testInput: {'query': 'Flutter development', 'count': 3},
);

// Execute a tool directly
final result = await agentService.executeTool(
  toolName: 'time_tool',
  input: {'format': 'iso'},
);
```

### Integration with Unified API Service

The agent system is integrated with the existing `UnifiedApiService`:

```dart
final apiService = UnifiedApiService();

// Enable agent system
apiService.setAgentSystemEnabled(true);

// Use agent system for chat
await for (final response in apiService.streamChat(
  model: 'google/gemini-2.0-flash-exp:free',
  messages: messages,
  enabledTools: ToolsConfig(braveSearch: true),
)) {
  // Handle response
}
```

## Configuration

### Tools Configuration

Tools can be enabled/disabled through the `ToolsConfig` model:

```dart
final toolsConfig = ToolsConfig(
  braveSearch: true,
  sequentialThinking: true,
  webFetch: true,
  youtubeProcessor: false,
  browserRoadmap: true,
  imageSearch: false,
  keywordExtraction: true,
  memoryManager: true,
  sourceQuery: true,
  sourceContent: true,
  timeTool: true,
);
```

### Agent Models

The agent system uses different models for different tasks:

- **Planner Agent**: `google/gemini-2.0-flash-exp:free`
- **Writer Agent**: `google/gemini-2.0-flash-exp:free`

These can be configured during initialization:

```dart
await agentService.initialize(
  plannerModel: 'google/gemini-2.0-flash-exp:free',
  writerModel: 'google/gemini-2.0-flash-exp:free',
  mode: 'chat',
);
```

## Features

### 1. Tool Management
- Automatic tool discovery and validation
- Tool testing and debugging capabilities
- Schema-based tool definitions
- Error handling and fallbacks

### 2. Agent Coordination
- Intelligent query analysis and planning
- Sequential and parallel tool execution
- Progress tracking and status updates
- Comprehensive error handling

### 3. Response Generation
- Streaming responses for real-time feedback
- Context-aware response generation
- Personality and language customization
- File attachment support

### 4. Integration
- Seamless integration with existing Flutter app
- Backward compatibility with direct LLM calls
- Unified API interface
- Easy enable/disable functionality

## Testing

Run the test file to verify the agent system:

```bash
dart test_agent_system.dart
```

This will test:
- Agent service initialization
- Tool discovery and validation
- Individual tool execution
- Full agent system workflow
- Error handling and fallbacks

## Migration from Backend

The agent system replicates the backend functionality:

### Backend → Flutter Mapping

| Backend Component | Flutter Equivalent |
|------------------|-------------------|
| `tools.mjs` | `tools.dart` |
| `planner-agent-optimized.mjs` | `PlannerAgent` |
| `executor-agent.mjs` | `ExecutorAgent` |
| `writer-agent.mjs` | `WriterAgent` |
| Tool execution | `Tool.invoke()` |
| Agent coordination | `AgentSystem` |
| API endpoints | `AgentService` |

### Key Differences

1. **Language**: JavaScript → Dart
2. **Environment**: Node.js → Flutter
3. **APIs**: Direct API calls instead of backend endpoints
4. **Storage**: Local storage instead of server database
5. **Streaming**: Flutter streams instead of HTTP streams

## Benefits

1. **Standalone Operation**: No backend server required
2. **Reduced Latency**: Direct API calls from mobile device
3. **Offline Capability**: Some tools work offline
4. **Cost Reduction**: No server hosting costs
5. **Privacy**: Data stays on device
6. **Scalability**: No server scaling concerns

## Limitations

1. **API Limits**: Subject to mobile device API rate limits
2. **Processing Power**: Limited by mobile device capabilities
3. **Storage**: Limited by device storage
4. **Network**: Dependent on mobile network connectivity

## Future Enhancements

1. **Offline Tools**: More tools that work without internet
2. **Local Models**: On-device LLM inference
3. **Tool Plugins**: Dynamic tool loading
4. **Advanced Planning**: More sophisticated execution planning
5. **Multi-modal Support**: Better image and file processing

## Troubleshooting

### Common Issues

1. **Tool Initialization Failed**
   - Check API keys and network connectivity
   - Verify tool dependencies are available

2. **Agent System Not Responding**
   - Ensure agent system is enabled
   - Check LLM service connectivity
   - Verify tool configurations

3. **Streaming Issues**
   - Check network stability
   - Verify stream handling in UI
   - Monitor for timeout errors

### Debug Mode

Enable debug logging:

```dart
Logger.setLevel(LogLevel.debug);
```

This will provide detailed logs for troubleshooting agent system issues. 