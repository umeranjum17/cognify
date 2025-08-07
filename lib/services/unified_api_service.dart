import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';

import '../database/database_service.dart';
import '../models/chat_stream_event.dart';
import '../models/message.dart';
import '../models/source.dart';
import '../models/tools_config.dart';
import '../models/trending_topic.dart';
import 'agent_service.dart';
import 'agents/agent_system.dart';
import 'brave_search_service.dart';
import 'content_extractor.dart';
import 'daily_quotes_service.dart';
import 'document_processor.dart';
import 'file_upload_service.dart';
import 'llm_service.dart';
import 'openrouter_client.dart';
import 'trending_service.dart';

/// Unified API service that replaces the old backend-dependent ApiService
/// Uses direct API calls to OpenRouter, Brave Search, etc.
class UnifiedApiService {
  static final UnifiedApiService _instance = UnifiedApiService._internal();
  
  // Direct service clients
  final LLMService _llmService = LLMService();
  final OpenRouterClient _openRouterClient = OpenRouterClient();
  final BraveSearchService _braveSearchService = BraveSearchService();
  final ContentExtractor _contentExtractor = ContentExtractor();
  final DatabaseService _databaseService = DatabaseService();
  final DocumentProcessor _documentProcessor = DocumentProcessor();
  final FileUploadService _fileUploadService = FileUploadService();
  final AgentService _agentService = AgentService();
  final AgentSystem _agentSystem = AgentSystem();
  final TrendingService _trendingService = TrendingService();
  final DailyQuotesService _dailyQuotesService = DailyQuotesService();
  
  bool _initialized = false;
  bool _useAgentSystem = true; // Flag to switch between old and new system
  
  factory UnifiedApiService() => _instance;
  UnifiedApiService._internal();

  /// Get base URL (app is completely standalone)
  String get baseUrl => ''; // No backend server - app is standalone

  /// Add URL as source
  Future<Source?> addUrl({
    required String url,
    required String sourceType,
    required String userSelectedType,
  }) async {
    await _ensureInitialized();
    return await _fileUploadService.uploadFromUrl(url);
  }

  /// Add URL as source
  Future<Source?> addUrlSource(String url) async {
    await _ensureInitialized();
    return await _fileUploadService.uploadFromUrl(url);
  }

  /// Chat completion stream (alias for streamChat)
  Stream<ChatStreamEvent> chatCompletionStream({
    required String model,
    required List<Message> messages,
    ToolsConfig? enabledTools,
    List<PlatformFile>? attachments,
    String? textInput,
    String? conversationId,
    bool isDeepSearchMode = false,
    bool isThinkMode = false,
    bool isOfflineMode = false,
    String? personality,
    String? language,
    String? mode,
    String? chatModel,
    String? deepsearchModel,
    bool isEntitled = false,
  }) {
    return streamChat(
      model: model,
      messages: messages,
      enabledTools: enabledTools,
      attachments: attachments,
      textInput: textInput,
      conversationId: conversationId,
      isDeepSearchMode: isDeepSearchMode,
      isThinkMode: isThinkMode,
      isOfflineMode: isOfflineMode,
      personality: personality,
      language: language,
      mode: mode,
      chatModel: chatModel,
      deepsearchModel: deepsearchModel,
      isEntitled: isEntitled,
    );
  }

  /// Delete source
  Future<void> deleteSource(String sourceId) async {
    await _ensureInitialized();
    await _fileUploadService.deleteSource(sourceId);
  }

  /// Execute a tool directly
  Future<Map<String, dynamic>> executeTool({
    required String toolName,
    required Map<String, dynamic> input,
  }) async {
    await _ensureInitialized();
    
    if (!_useAgentSystem) {
      return {
        'success': false,
        'error': 'Agent system is disabled',
      };
    }
    
    return await _agentService.executeTool(
      toolName: toolName,
      input: input,
    );
  }

  /// Fetch roadmap data (mock implementation)
  Future<Map<String, dynamic>> fetchRoadmapFromUrl(String url) async {
    await _ensureInitialized();

    try {
      // Use content extractor to get the content
      final content = await _contentExtractor.extractFromUrl(url);

      return {
        'success': true,
        'data': {
          'content': content['content'] ?? '',
          'url': url,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Generate follow-up questions using direct LLM service
  Future<Map<String, dynamic>> generateFollowUpQuestions(
    String answer, {
    String? model,
    List<dynamic>? sources,
    List<dynamic>? messages,
    bool stream = false,
  }) async {
    await _ensureInitialized();
    
    try {
      final prompt = '''Based on this answer, generate 3-5 relevant follow-up questions that would help the user explore the topic deeper:

Answer: ${answer.length > 2000 ? answer.substring(0, 2000) : answer}

Generate questions that are:
1. Specific and actionable
2. Build upon the provided answer
3. Explore different aspects of the topic
4. Are genuinely helpful for learning

Return only the questions, one per line, without numbering.''';

      final response = await _llmService.chatCompletion(
        model: model ?? 'mistralai/mistral-7b-instruct:free',
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        temperature: 0.8,
        maxTokens: 300,
      );

      // Handle the response structure correctly
      final responseData = response['response'] as Map<String, dynamic>?;
      if (responseData == null) {
        throw Exception('Invalid response structure from LLM service');
      }
      final choices = responseData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('No choices in response');
      }
      final content = choices[0]['message']['content'] as String?;
      if (content == null) {
        throw Exception('No content in response');
      }

      final questions = content
          .split('\n')
          .where((q) => q.trim().isNotEmpty)
          .map((q) => q.trim())
          .toList();

      return {
        'success': true,
        'questions': questions,
      };
    } catch (e) {
      print('🚨 Follow-up questions error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'questions': [],
      };
    }
  }

  /// Generate images using Brave Search
  Future<Map<String, dynamic>> generateImageQuery(
    String answer, {
    String? query,
    int count = 5,
  }) async {
    await _ensureInitialized();
    
    try {
      // Generate search query if not provided
      String searchQuery = query ?? answer;
      
      // Use Brave Search to find images
      final searchResults = await _braveSearchService.searchImages(
        searchQuery,
        count: count,
      );
      
      if (searchResults['success'] == true && searchResults['images'] != null) {
        return {
          'success': true,
          'shouldShowImages': true,
          'images': searchResults['images'],
          'query': searchQuery,
        };
      } else {
        return {
          'success': false,
          'shouldShowImages': false,
          'images': [],
          'error': 'No images found',
        };
      }
    } catch (e) {
      print('🚨 Image generation error: $e');
      return {
        'success': false,
        'shouldShowImages': false,
        'images': [],
        'error': e.toString(),
      };
    }
  }

  /// Get agent system status
  Map<String, dynamic> getAgentSystemStatus() {
    if (!_useAgentSystem) {
      return {
        'enabled': false,
        'message': 'Agent system is disabled',
      };
    }

    if (!_initialized) {
      return {
        'enabled': false,
        'message': 'UnifiedApiService not initialized',
      };
    }

    final status = _agentService.getStatus();
    final isReady = status['initialized'] == true && _initialized;
    return {
      'enabled': isReady,
      'message': isReady ? 'Agent system ready' : 'Agent system not initialized',
      'details': status,
    };
  }

  /// Get all available tools
  List<Map<String, dynamic>> getAllTools() {
    if (!_useAgentSystem) {
      return [];
    }
    
    return _agentService.getAllToolInfo();
  }

  /// Get credits from OpenRouter
  Future<Map<String, dynamic>> getCredits() async {
    await _ensureInitialized();

    try {
      final creditsData = await _openRouterClient.getCredits();

      if (creditsData != null) {
        return {
          'success': true,
          'credits': creditsData,
        };
      } else {
        return {
          'success': false,
          'error': 'Unable to fetch credits from OpenRouter',
          'credits': {
            'total_credits': 0.0,
            'total_usage': 0.0,
            'remaining_credits': 0.0,
            'fetched_at': DateTime.now().toIso8601String(),
          },
        };
      }
    } catch (e) {
      print('🚨 Credits fetch error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'credits': {
          'total_credits': 0.0,
          'total_usage': 0.0,
          'remaining_credits': 0.0,
          'fetched_at': DateTime.now().toIso8601String(),
        },
      };
    }
  }

  /// Get daily quote using the new service
  Future<Map<String, dynamic>> getDailyQuote() async {
    await _ensureInitialized();

    try {
      final quote = await _dailyQuotesService.getDailyQuote();
      return {
        'success': true,
        'quote': quote.quote,
        'author': quote.author,
        'category': quote.category,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error fetching daily quote: $e');
      // Return fallback quote
      return {
        'success': true,
        'quote': 'The best way to predict the future is to invent it.',
        'author': 'Alan Kay',
        'category': 'Innovation',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get generation costs by calling the generation API for each generation ID
  Future<Map<String, dynamic>> getGenerationCosts(List<Map<String, dynamic>> generationIds) async {
    await _ensureInitialized();

    if (generationIds.isEmpty) {
      return {
        'success': true,
        'totalApiCost': 0.0,
        'successfulFetches': 0,
        'failedFetches': 0,
        'accuracy': 1.0,
        'generations': [],
      };
    }

    try {
      print('💰 Fetching generation costs for ${generationIds.length} generation IDs');
      
      final List<Map<String, dynamic>> processedGenerations = [];
      int successfulFetches = 0;
      int failedFetches = 0;
      double totalCost = 0.0;

      // Fetch costs for each generation ID
      for (final genInfo in generationIds) {
        final generationId = genInfo['id'] as String?;
        final stage = genInfo['stage'] as String? ?? 'unknown';
        final model = genInfo['model'] as String? ?? 'unknown';
        final inputTokens = genInfo['inputTokens'] as int? ?? 0;
        final outputTokens = genInfo['outputTokens'] as int? ?? 0;
        final totalTokens = genInfo['totalTokens'] as int? ?? 0;

        if (generationId == null) {
          print('⚠️ Skipping generation with null ID');
          failedFetches++;
          continue;
        }

        try {
          // Call OpenRouter generation API to get cost data
          final costData = await _openRouterClient.getGenerationCost(generationId);
          
          if (costData != null) {
            final cost = (costData['total_cost'] ?? 0.0).toDouble();
            totalCost += cost;
            successfulFetches++;
            
            processedGenerations.add({
              'id': generationId,
              'stage': stage,
              'model': model,
              'inputTokens': inputTokens,
              'outputTokens': outputTokens,
              'totalTokens': totalTokens,
              'success': true,
              'costData': costData,
              'fetchedAt': DateTime.now().toIso8601String(),
            });
            
            print('✅ Fetched cost for generation $generationId: \$${cost.toStringAsFixed(6)}');
          } else {
            failedFetches++;
            processedGenerations.add({
              'id': generationId,
              'stage': stage,
              'model': model,
              'inputTokens': inputTokens,
              'outputTokens': outputTokens,
              'totalTokens': totalTokens,
              'success': false,
              'costData': null,
              'error': 'No cost data returned from API',
              'fetchedAt': DateTime.now().toIso8601String(),
            });
            print('❌ No cost data for generation $generationId');
          }
        } catch (e) {
          failedFetches++;
          processedGenerations.add({
            'id': generationId,
            'stage': stage,
            'model': model,
            'inputTokens': inputTokens,
            'outputTokens': outputTokens,
            'totalTokens': totalTokens,
            'success': false,
            'costData': null,
            'error': e.toString(),
            'fetchedAt': DateTime.now().toIso8601String(),
          });
          print('❌ Failed to fetch cost for generation $generationId: $e');
        }
      }

      final accuracy = generationIds.isNotEmpty ? successfulFetches / generationIds.length : 1.0;
      
      print('💰 Generation cost summary: $successfulFetches successful, $failedFetches failed, total cost: \$${totalCost.toStringAsFixed(6)}');
      
      return {
        'success': true,
        'totalApiCost': totalCost,
        'successfulFetches': successfulFetches,
        'failedFetches': failedFetches,
        'accuracy': accuracy,
        'generations': processedGenerations,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Error fetching generation costs: $e');
      return {
        'success': false,
        'error': e.toString(),
        'totalApiCost': 0.0,
        'successfulFetches': 0,
        'failedFetches': generationIds.length,
        'accuracy': 0.0,
        'generations': [],
      };
    }
  }

  /// Get knowledge graph entities (mock implementation)
  Future<List<dynamic>> getKnowledgeGraphEntities() async {
    await _ensureInitialized();

    return [
      {
        'id': '1',
        'type': 'concept',
        'data': {
          'name': 'Flutter',
          'description': 'UI toolkit for building natively compiled applications',
        },
        'metadata': {
          'category': 'Technology',
          'importance': 0.9,
        },
      },
      {
        'id': '2',
        'type': 'concept',
        'data': {
          'name': 'Dart',
          'description': 'Programming language optimized for client development',
        },
        'metadata': {
          'category': 'Programming Language',
          'importance': 0.8,
        },
      },
      {
        'id': '3',
        'type': 'concept',
        'data': {
          'name': 'Mobile Development',
          'description': 'Development of applications for mobile devices',
        },
        'metadata': {
          'category': 'Development',
          'importance': 0.7,
        },
      },
    ];
  }

  /// Get available models from OpenRouter
  Future<Map<String, dynamic>> getModels() async {
    await _ensureInitialized();
    
    try {
      return await _openRouterClient.getModels();
    } catch (e) {
      print('🚨 Get models error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'models': [],
      };
    }
  }

  /// Get roadmap role by ID (mock implementation)
  Future<Map<String, dynamic>> getRoadmapRoleById(String roleId) async {
    await _ensureInitialized();

    final roles = {
      'frontend': {
        'id': 'frontend',
        'name': 'Frontend Developer',
        'description': 'Build user interfaces and client-side applications',
        'category': 'Development',
      },
      'backend': {
        'id': 'backend',
        'name': 'Backend Developer',
        'description': 'Build server-side logic and APIs',
        'category': 'Development',
      },
      'fullstack': {
        'id': 'fullstack',
        'name': 'Full Stack Developer',
        'description': 'Build complete web applications',
        'category': 'Development',
      },
    };

    final role = roles[roleId];
    if (role != null) {
      return {
        'success': true,
        'data': role,
      };
    } else {
      return {
        'success': false,
        'error': 'Role not found',
      };
    }
  }

  /// Get roadmap roles (mock implementation)
  Future<Map<String, dynamic>> getRoadmapRoles() async {
    await _ensureInitialized();

    return {
      'success': true,
      'data': {
        'roles': [
          {
            'id': 'frontend',
            'name': 'Frontend Developer',
            'description': 'Build user interfaces and client-side applications',
            'category': 'Development',
          },
          {
            'id': 'backend',
            'name': 'Backend Developer',
            'description': 'Build server-side logic and APIs',
            'category': 'Development',
          },
          {
            'id': 'fullstack',
            'name': 'Full Stack Developer',
            'description': 'Build complete web applications',
            'category': 'Development',
          },
        ],
      },
    };
  }

  /// Get all sources
  Future<List<Source>> getSources() async {
    await _ensureInitialized();
    return await _databaseService.getAllSources();
  }

  /// Get trending topics using the new service
  Future<List<TrendingTopic>> getTrendingTopics() async {
    await _ensureInitialized();

    try {
      return await _trendingService.getTrendingTopics();
    } catch (e) {
      print('❌ Error fetching trending topics: $e');
      // Return empty list on error
      return [];
    }
  }

  /// Initialize all services
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _llmService.initialize();
    await _openRouterClient.initialize();
    await _braveSearchService.initialize();
    await _contentExtractor.initialize();
    await _databaseService.initialize();
    await _fileUploadService.initialize();
    
    // Initialize agent system if enabled
    if (_useAgentSystem) {
      await _agentService.initialize();
      await _agentSystem.initialize();
    }
    
    _initialized = true;
    print('🚀 UnifiedApiService initialized with direct API clients');
    if (_useAgentSystem) {
      print('🤖 Agent system enabled');
    }
    print('📊 Trending and daily quotes services ready');
  }

  /// Retry source processing
  Future<Source?> retrySource(String sourceId) async {
    await _ensureInitialized();

    // Get the existing source
    final existingSource = await _databaseService.getSource(sourceId);
    if (existingSource == null) {
      throw Exception('Source not found');
    }

    // For now, just return the existing source
    // In a real implementation, this would retry the processing
    return existingSource;
  }

  /// Search roadmap roles (mock implementation)
  Future<Map<String, dynamic>> searchRoadmapRoles(String query) async {
    await _ensureInitialized();

    // Return mock roadmap roles
    return {
      'success': true,
      'roles': [
        {'id': '1', 'name': 'Frontend Developer', 'description': 'Build user interfaces'},
        {'id': '2', 'name': 'Backend Developer', 'description': 'Build server-side logic'},
        {'id': '3', 'name': 'Full Stack Developer', 'description': 'Build complete applications'},
      ],
    };
  }

  /// Enable/disable agent system
  void setAgentSystemEnabled(bool enabled) {
    _useAgentSystem = enabled;
    print('🤖 Agent system ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Source-grounded chat stream
  Stream<ChatStreamEvent> sourceGroundedChatStream({
    required String model,
    required List<Message> messages,
    required List<String> selectedSourceIds,
    ToolsConfig? enabledTools,
    List<PlatformFile>? attachments,
    String? textInput,
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
    await _ensureInitialized();

    try {
      print('🔍 Source-grounded chat started with ${selectedSourceIds.length} sources');
      
      // Get the query from text input or last message
      String query = '';
      if (textInput != null && textInput.isNotEmpty) {
        query = textInput;
      } else if (messages.isNotEmpty) {
        final lastUserMessage = messages.lastWhere(
          (msg) => msg.type == 'user',
          orElse: () => Message(
            id: 'fallback',
            type: 'user',
            content: '',
            timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
          ),
        );
        query = lastUserMessage.content;
      }

      if (query.isEmpty) {
        query = 'Please analyze the provided sources';
      }

      // Use agent system for source-grounded processing (skips planner)
      yield* _agentSystem.processSourceGroundedQuery(
        query: query,
        sourceIds: selectedSourceIds,
        mode: 'source_grounded',
        attachments: attachments?.map((f) => {
          'name': f.name,
          'size': f.size,
          'bytes': f.bytes,
        }).toList(),
        isIncognitoMode: false,
        personality: personality ?? 'Default',
        language: language ?? 'English',
        conversationHistory: messages,
        selectedModel: model,
      );

    } catch (e) {
      print('🚨 Source grounded chat streaming error: $e');
      yield ChatStreamEvent.error(
        error: e.toString(),
        conversationId: conversationId,
        model: model,
      );
    }
  }

  /// Chat completion using agent system or direct LLM service
  Stream<ChatStreamEvent> streamChat({
    required String model,
    required List<Message> messages,
    ToolsConfig? enabledTools,
    List<PlatformFile>? attachments,
    String? textInput,
    String? conversationId,
    bool isDeepSearchMode = false,
    bool isThinkMode = false,
    bool isOfflineMode = false,
    String? personality,
    String? language,
    String? mode,
    String? chatModel,
    String? deepsearchModel,
    bool isEntitled = false,
  }) async* {
    await _ensureInitialized();
    
    // Use agent system if enabled and tools are configured
    if (_useAgentSystem && enabledTools != null) {
      try {
        // Get the query from the last user message or text input
        String query = '';
        if (textInput != null && textInput.isNotEmpty) {
          query = textInput;
        } else if (messages.isNotEmpty) {
          final lastUserMessage = messages.lastWhere(
            (msg) => msg.type == 'user',
            orElse: () => Message(
              id: 'fallback',
              type: 'user',
              content: '',
              timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
            ),
          );
          query = lastUserMessage.content;
        }
        
        if (query.isNotEmpty) {
          print('🤖 Using agent system for query: ${query.substring(0, math.min(50, query.length))}...');
          print('🤖 UnifiedApiService: Model parameters - model: $model, chatModel: $chatModel, deepsearchModel: $deepsearchModel');
          print('🤖 UnifiedApiService: Passing selectedModel to agent system: $model');
          
          // Convert ToolsConfig to list of enabled tool names
          final enabledToolNames = <String>[];
          if (enabledTools.braveSearch == true) enabledToolNames.add('brave_search');
          if (enabledTools.webFetch == true) enabledToolNames.add('web_fetch');
          if (enabledTools.youtubeProcessor == true) enabledToolNames.add('youtube_processor');
          if (enabledTools.browserRoadmap == true) enabledToolNames.add('browser_roadmap');
          if (enabledTools.imageSearch == true) enabledToolNames.add('image_search');
          if (enabledTools.keywordExtraction == true) enabledToolNames.add('keyword_extraction');
          if (enabledTools.memoryManager == true) enabledToolNames.add('memory_manager');
          if (enabledTools.sourceQuery == true) enabledToolNames.add('source_query');
          if (enabledTools.sourceContent == true) enabledToolNames.add('source_content');
          if (enabledTools.timeTool == true) enabledToolNames.add('time_tool');
          
          // Convert attachments to the format expected by AgentSystem
          final agentAttachments = attachments?.map((file) => {
            'name': file.name,
            'size': file.size,
            'bytes': file.bytes,
            'type': 'file',
          }).toList();
          
          // Pass through AgentSystem stream - NO YIELDING HERE
          yield* _agentSystem.processQuery(
            query: query,
            enabledTools: enabledToolNames,
            mode: mode ?? 'chat',
            attachments: agentAttachments,
            isIncognitoMode: isOfflineMode,
            personality: personality ?? 'Default',
            language: language ?? 'English',
            conversationHistory: messages,
            selectedModel: model, // Pass the selected model to agent system
            isEntitled: isEntitled,
          );
          return;
        }
      } catch (e) {
        print('🚨 Agent system error: $e');
        yield ChatStreamEvent.error(
          error: 'Agent system error: $e',
          conversationId: conversationId,
          model: model,
          llmUsed: 'agent-system',
        );
        return;
      }
    }
    
    // Fallback to direct LLM service only if agent system is disabled
    if (!_useAgentSystem) {
      try {
        // Convert messages to OpenRouter format
        final openRouterMessages = messages.map((msg) => {
          'role': msg.type == 'user' ? 'user' : 'assistant',
          'content': msg.content,
        }).toList();
        
        // Add current text input if provided
        if (textInput != null && textInput.isNotEmpty) {
          openRouterMessages.add({
            'role': 'user',
            'content': textInput,
          });
        }
        
        // Use direct LLM service for streaming
        await for (final chunk in _llmService.chatCompletionStream(
          messages: openRouterMessages,
          model: model,
          temperature: 0.7,
          tools: _convertToolsConfigToList(enabledTools),
        )) {
          yield ChatStreamEvent.content(
            content: chunk['content'] ?? '',
            conversationId: conversationId,
            model: model,
            llmUsed: 'direct-llm',
          );
        }
      } catch (e) {
        print('🚨 Chat streaming error: $e');
        yield ChatStreamEvent.error(
          error: e.toString(),
          conversationId: conversationId,
          model: model,
          llmUsed: 'direct-llm',
        );
      }
    } else {
      // Agent system is enabled but no tools configured
      yield ChatStreamEvent.error(
        error: 'Agent system requires tools configuration',
        conversationId: conversationId,
        model: model,
        llmUsed: 'agent-system',
      );
    }
  }

  /// Test a specific tool
  Future<Map<String, dynamic>> testTool({
    required String toolName,
    Map<String, dynamic>? testInput,
  }) async {
    await _ensureInitialized();
    
    if (!_useAgentSystem) {
      return {
        'success': false,
        'error': 'Agent system is disabled',
      };
    }
    
    return await _agentService.testTool(
      toolName: toolName,
      testInput: testInput,
    );
  }

  /// Upload file (alias for uploadSource)
  Future<List<Source>> uploadFile(PlatformFile file) async {
    return await uploadSource(file);
  }

  /// Upload and process source files
  Future<List<Source>> uploadSource(PlatformFile file) async {
    await _ensureInitialized();

    // Use the pick and upload method with a single file
    return await _fileUploadService.pickAndUploadFiles(
      allowMultiple: false,
    );
  }

  /// Convert ToolsConfig to list format expected by LLM service
  List<Map<String, dynamic>>? _convertToolsConfigToList(ToolsConfig? toolsConfig) {
    if (toolsConfig == null) return null;

    // Since ToolsConfig is empty in the current implementation,
    // return null for now (no tools enabled)
    return null;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
