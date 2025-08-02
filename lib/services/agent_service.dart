import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/chat_response.dart';
import '../models/chat_stream_event.dart';
import '../models/message.dart';
import '../models/tools_config.dart';
import 'agents.dart';
import 'tools.dart';

/// Agent Service - Main interface for the agent system in Flutter
class AgentService {
  static final AgentService _instance = AgentService._internal();
  late AgentSystem _agentSystem;
  late ToolsManager _toolsManager;

  bool _initialized = false;
  factory AgentService() => _instance;
  AgentService._internal();

  /// Execute a single tool directly
  Future<Map<String, dynamic>> executeTool({
    required String toolName,
    required Map<String, dynamic> input,
  }) async {
    if (!_initialized) {
      throw Exception('Agent Service not initialized');
    }

    final tool = _toolsManager.getToolByName(toolName);
    if (tool == null) {
      throw Exception('Tool $toolName not found');
    }

    try {
      print('🔧 Executing tool: $toolName');
      final result = await tool.invoke(input);
              print('✅ Tool $toolName completed successfully');
      return result;
    } catch (error) {
      print('❌ Tool $toolName failed: $error');
      rethrow;
    }
  }

  /// Get all tool information
  List<Map<String, dynamic>> getAllToolInfo() {
    return _toolsManager.allTools.map((tool) => {
      'name': tool.name,
      'description': tool.description,
      'schema': tool.schema,
    }).toList();
  }

  /// Get available tool names
  List<String> getAvailableToolNames() {
    return _toolsManager.getAvailableToolNames();
  }

  /// Get core tool names
  List<String> getCoreToolNames() {
    return _toolsManager.getCoreToolNames();
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _initialized,
      'availableTools': _toolsManager.allTools.length,
      'coreTools': _toolsManager.coreTools.length,
      'agentSystem': _initialized ? 'ready' : 'not_initialized',
    };
  }

  /// Get tool by name
  Tool? getToolByName(String name) {
    return _toolsManager.getToolByName(name);
  }

  /// Get tool information
  Map<String, dynamic> getToolInfo(String toolName) {
    final tool = _toolsManager.getToolByName(toolName);
    if (tool == null) {
      return {'error': 'Tool not found'};
    }

    return {
      'name': tool.name,
      'description': tool.description,
      'schema': tool.schema,
    };
  }

  /// Get tools by name
  List<Tool> getToolsByName(List<String> toolNames) {
    return _toolsManager.getToolsByName(toolNames);
  }

  /// Initialize the agent service
  Future<void> initialize({
    String plannerModel = 'deepseek/deepseek-chat:free',
    String writerModel = 'deepseek/deepseek-chat:free',
    String mode = 'chat',
  }) async {
    try {
      print('🚀 Initializing Agent Service');

      _agentSystem = AgentSystem();
      _toolsManager = ToolsManager();

      await _agentSystem.initialize(
        plannerModel: plannerModel,
        writerModel: writerModel,
        mode: mode,
      );

      // Validate tools
      final validationResults = _toolsManager.validateTools();
      final validTools = validationResults.where((r) => r['status'] == 'valid').length;
      print('✅ Agent Service initialized with $validTools valid tools');

      _initialized = true;
    } catch (error) {
      print('❌ Agent Service initialization failed: $error');
      rethrow;
    }
  }

  /// Process chat with agent system
  Stream<ChatResponse> processChat({
    required String query,
    required List<Message> messages,
    ToolsConfig? enabledTools,
    List<PlatformFile>? attachments,
    String? conversationId,
    bool isDeepSearchMode = false,
    bool isThinkMode = false,
    bool isOfflineMode = false,
    String? personality,
    String? language,
    String? mode,
    String? chatModel,
    String? deepsearchModel,
  }) async* {
    if (!_initialized) {
      yield ChatResponse(
        type: 'error',
        content: 'Agent Service is still initializing. Please wait a moment and try again.',
        conversationId: conversationId,
      );
      return;
    }

    try {
      final enabledToolNames = _getEnabledTools(enabledTools);
      final agentMode = isDeepSearchMode ? 'deepsearch' : (mode ?? 'chat');
      final agentAttachments = _convertAttachments(attachments);

      // Use the user's selected model instead of hardcoded model
      final selectedModel = isDeepSearchMode ? (deepsearchModel ?? 'deepseek/deepseek-r1:free') : (chatModel ?? 'google/gemini-2.0-flash-exp:free');
      
      print('🤖 Processing chat with ${enabledToolNames.length} enabled tools');
      print('🤖 Using model: $selectedModel for mode: $agentMode');
      print('🤖 Chat model provided: $chatModel');
      print('🤖 DeepSearch model provided: $deepsearchModel');
      print('🤖 Is DeepSearch mode: $isDeepSearchMode');
      print('🤖 AgentService: Model selection logic - isDeepSearchMode: $isDeepSearchMode, selectedModel: $selectedModel');

      // Stream the agent system response with the selected model
      await for (final event in _agentSystem.processQuery(
        query: query,
        enabledTools: enabledToolNames,
        mode: agentMode,
        attachments: agentAttachments,
        isIncognitoMode: isOfflineMode,
        personality: personality ?? 'Default',
        language: language ?? 'English',
        conversationHistory: messages,
        selectedModel: selectedModel, // Pass the selected model
        onToolProgress: (progress) {
          print('Tool progress: ${progress['tool']} - ${progress['message']}');
        },
        onToolResult: (result) {
          print('Tool result: ${result.tool} - ${result.failed ? 'FAILED' : 'SUCCESS'}');
        },
      )) {
        // Convert ChatStreamEvent to ChatResponse for backward compatibility
        switch (event.type) {
          case StreamEventType.milestone:
            yield ChatResponse(
              type: 'status',
              content: event.message ?? '',
              conversationId: conversationId,
              metadata: {
                'phase': event.metadata?['phase'] ?? 'processing',
                'progress': event.metadata?['progress'] ?? 0.0,
              },
            );
            break;

          case StreamEventType.sourcesReady:
            yield ChatResponse(
              type: 'sources_ready',
              content: event.message ?? '',
              conversationId: conversationId,
              sources: event.sources,
              metadata: {
                'images': event.images,
                'sourceCount': event.sources?.length ?? 0,
                'imageCount': event.images?.length ?? 0,
              },
            );
            break;

          case StreamEventType.content:
            yield ChatResponse(
              type: 'content',
              content: event.content ?? '',
              conversationId: conversationId,
              sources: event.sources,
              metadata: {
                'images': event.images,
                'model': event.model,
                'llmUsed': event.llmUsed,
              },
            );
            break;

          case StreamEventType.complete:
            yield ChatResponse(
              type: 'complete',
              content: event.message ?? '',
              conversationId: conversationId,
              sources: event.sources,
              metadata: {
                'images': event.images,
                'cost': event.metadata?['cost'],
                'generationIds': event.metadata?['generationIds'],
                'model': event.model,
                'llmUsed': event.llmUsed,
              },
            );
            break;

          case StreamEventType.error:
            yield ChatResponse(
              type: 'error',
              content: event.error ?? 'Unknown error',
              conversationId: conversationId,
            );
            break;

          default:
            print('Unknown agent event type: ${event.type}');
        }
      }

    } catch (error) {
      print('❌ Agent Service processing failed: $error');
      yield ChatResponse(
        type: 'error',
        content: 'An error occurred while processing your request: $error',
        conversationId: conversationId,
      );
    }
  }

  /// Test tool execution
  Future<Map<String, dynamic>> testTool({
    required String toolName,
    Map<String, dynamic>? testInput,
  }) async {
    if (!_initialized) {
      throw Exception('Agent Service not initialized');
    }

    final tool = _toolsManager.getToolByName(toolName);
    if (tool == null) {
      throw Exception('Tool $toolName not found');
    }

    // Generate test input if not provided
    final input = testInput ?? _generateTestInput(tool);
    
    try {
      print('🧪 Testing tool: $toolName');
      final startTime = DateTime.now();
      final result = await tool.invoke(input);
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      return {
        'tool': toolName,
        'input': input,
        'output': result,
        'executionTime': executionTime,
        'success': true,
      };
    } catch (error) {
      print('❌ Tool test failed: $error');
      return {
        'tool': toolName,
        'input': input,
        'error': error.toString(),
        'success': false,
      };
    }
  }

  /// Validate all tools
  List<Map<String, dynamic>> validateAllTools() {
    return _toolsManager.validateTools();
  }

  /// Convert file attachments to agent format
  List<Map<String, dynamic>> _convertAttachments(List<PlatformFile>? attachments) {
    if (attachments == null || attachments.isEmpty) {
      return [];
    }

    return attachments.map((file) {
      final bytes = file.bytes;
      final base64Data = bytes != null ? base64.encode(bytes) : '';
      
      return {
        'id': file.name, // Use filename as ID for now
        'name': file.name,
        'type': _getFileType(file.extension),
        'base64Data': base64Data,
        'size': file.size,
        'mimeType': _getMimeType(file.extension),
      };
    }).toList();
  }

  /// Generate test input for a tool
  Map<String, dynamic> _generateTestInput(Tool tool) {
    switch (tool.name) {
      case 'brave_search':
        return {'query': 'Flutter development', 'count': 3};
      case 'brave_search_enhanced':
        return {'query': 'AI tools', 'count': 2, 'extractContent': true};
      case 'sequential_thinking':
        return {'problem': 'How to build a mobile app', 'steps': 5};
      case 'web_fetch':
        return {'url': 'https://example.com', 'extractText': true};
      case 'youtube_processor':
        return {'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'};
      case 'browser_roadmap':
        return {'roadmapType': 'ai-engineer', 'action': 'fetch'};
      case 'image_search':
        return {'query': 'Flutter logo', 'count': 3};
      case 'keyword_extraction':
        return {'text': 'Flutter is a UI toolkit for building applications', 'maxKeywords': 5};
      case 'memory_manager':
        return {'action': 'store', 'key': 'test_key', 'value': 'test_value'};
      case 'source_query':
        return {'query': 'Flutter development'};
      case 'source_content':
        return {'sourceId': 'test-source', 'extractType': 'full'};
      case 'time_tool':
        return {'format': 'iso'};
      default:
        return {};
    }
  }

  /// Convert ToolsConfig to list of enabled tool names
  List<String> _getEnabledTools(ToolsConfig? toolsConfig) {
    if (toolsConfig == null) {
      return _toolsManager.getCoreToolNames();
    }

    final enabledTools = <String>[];
    
    if (toolsConfig.braveSearch ?? false) {
      enabledTools.add('brave_search');
      enabledTools.add('brave_search_enhanced');
    }
    
    if (toolsConfig.sequentialThinking ?? false) {
      enabledTools.add('sequential_thinking');
    }
    
    if (toolsConfig.webFetch ?? false) {
      enabledTools.add('web_fetch');
    }
    
    if (toolsConfig.youtubeProcessor ?? false) {
      enabledTools.add('youtube_processor');
    }
    
    if (toolsConfig.browserRoadmap ?? false) {
      enabledTools.add('browser_roadmap');
    }
    
    if (toolsConfig.imageSearch ?? false) {
      enabledTools.add('image_search');
    }
    
    if (toolsConfig.keywordExtraction ?? false) {
      enabledTools.add('keyword_extraction');
    }
    
    if (toolsConfig.memoryManager ?? false) {
      enabledTools.add('memory_manager');
    }
    
    if (toolsConfig.sourceQuery ?? false) {
      enabledTools.add('source_query');
    }
    
    if (toolsConfig.sourceContent ?? false) {
      enabledTools.add('source_content');
    }
    
    if (toolsConfig.timeTool ?? false) {
      enabledTools.add('time_tool');
    }

    // If no tools are explicitly enabled, use core tools
    if (enabledTools.isEmpty) {
      enabledTools.addAll(_toolsManager.getCoreToolNames());
    }

    return enabledTools;
  }

  /// Get file type from extension
  String _getFileType(String? extension) {
    if (extension == null) return 'file';
    
    final ext = extension.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return 'image';
    } else if (['txt', 'md', 'json', 'xml', 'csv'].contains(ext)) {
      return 'text';
    } else if (ext == 'pdf') {
      return 'pdf';
    } else {
      return 'file';
    }
  }

  /// Get MIME type from extension
  String _getMimeType(String? extension) {
    if (extension == null) return 'application/octet-stream';
    
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }
} 