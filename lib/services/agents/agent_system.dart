import 'dart:math' as math;

import '../../database/database_service.dart';
import '../../models/chat_source.dart';
import '../../models/chat_stream_event.dart';
import '../../models/message.dart';
import '../../models/tool_result.dart';
import '../../models/tool_spec.dart';
import 'executor_engine.dart';
import 'milestone_messages.dart';
import 'planner_agent.dart';
import 'writer_agent.dart';

/// Unified Agent System - Coordinates all agents
class AgentSystem {
  late PlannerAgent _plannerAgent;
  late ExecutorEngine _executorEngine;
  late WriterAgent _writerAgent;
  
  bool _initialized = false;
  final String _defaultModel = 'deepseek/deepseek-chat:free';

  Future<void> initialize({
    String plannerModel = 'deepseek/deepseek-chat:free',
    String writerModel = 'deepseek/deepseek-chat:free',
    String mode = 'chat',
  }) async {
    try {
      // Create agents with initial models
      _plannerAgent = PlannerAgent(modelName: plannerModel, mode: mode);
      _writerAgent = WriterAgent(modelName: writerModel, mode: mode);
      
      // Only initialize the executor engine since it manages tools
      _executorEngine = ExecutorEngine();
      await _executorEngine.initialize();

      _initialized = true;
    } catch (error) {
      print('❌ Agent System initialization failed: \$e');
      rethrow;
    }
  }

  /// Process query with unified stream events - SINGLE ORCHESTRATOR
  Stream<ChatStreamEvent> processQuery({
    required String query,
    required List<String> enabledTools,
    String mode = 'chat',
    List<Map<String, dynamic>>? attachments,
    bool isIncognitoMode = false,
    String personality = 'Default',
    String language = 'English',
    List<Message> conversationHistory = const [],
    String? selectedModel,
    Function(Map<String, dynamic>)? onToolProgress,
    Function(ToolResult)? onToolResult,
  }) async* {
    if (!_initialized) {
      throw Exception('Agent System not initialized');
    }

    try {
      
      // Update agents with the selected model if provided
      if (selectedModel != null) {
        
        updateSelectedModel(selectedModel, mode: mode);
      }

      // Collect generation IDs for cost tracking
      final List<Map<String, dynamic>> generationIds = [];

      // Step 1: Planning
      yield ChatStreamEvent.milestone(
        message: MilestoneMessages.getRandomPlanningMessage(),
        phase: 'planning',
        progress: 0.1,
      );
      
      // Create execution plan
      final planResult = await _plannerAgent.createExecutionPlan(
        query: query,
        enabledTools: enabledTools,
        mode: mode,
        attachments: attachments,
      );

      // Extract tool specs and generation info from plan result
      final toolSpecs = planResult['toolSpecs'] as List<ToolSpec>;
      final plannerGenerationId = planResult['generationId'] as String?;
      final plannerUsage = planResult['usage'] as Map<String, dynamic>?;
      final plannerModel = planResult['model'] as String? ?? _defaultModel;

      // Add planner generation ID to collection
      if (plannerGenerationId != null) {
        generationIds.add({
          'id': plannerGenerationId,
          'stage': 'planning',
          'model': plannerModel,
          'inputTokens': plannerUsage?['prompt_tokens'] ?? 0,
          'outputTokens': plannerUsage?['completion_tokens'] ?? 0,
          'totalTokens': plannerUsage?['total_tokens'] ?? 0,
        });
        
      }

      yield ChatStreamEvent.milestone(
        message: '✅ Execution plan created with ${toolSpecs.length} tools',
        phase: 'planning',
        progress: 0.3,
      );

      // Step 2: Execute tools
      yield ChatStreamEvent.milestone(
        message: MilestoneMessages.getRandomExecutionMessage(),
        phase: 'execution',
        progress: 0.4,
      );
      
      final toolResults = await _executorEngine.executeTools(
        toolSpecs,
        onProgress: onToolProgress,
        onResult: onToolResult,
      );

      yield ChatStreamEvent.milestone(
        message: '✅ Tool execution completed',
        phase: 'execution',
        progress: 0.7,
      );

      // Step 2.5: Convert tool results to sources and emit immediately
      final sources = _convertToolResultsToSources(toolResults);
      final images = _convertToolResultsToImages(toolResults);
      
      if (sources.isNotEmpty || images.isNotEmpty) {
        yield ChatStreamEvent.sourcesReady(
          sources: sources,
          images: images,
        );
      }

      // Step 3: Writing - Use streaming to yield content chunks
      yield ChatStreamEvent.milestone(
        message: MilestoneMessages.getRandomWritingMessage(),
        phase: 'writing',
        progress: 0.8,
      );
      
      // Use streaming writer agent to yield content chunks
      String fullResponse = '';
      String? writerGenerationId;
      Map<String, dynamic>? writerUsage;
      
      await for (final event in _writerAgent.writeResponseStream(
        originalQuery: query,
        toolResults: toolResults,
        mode: mode,
        isIncognitoMode: isIncognitoMode,
        personality: personality,
        language: language,
        conversationHistory: conversationHistory,
        attachments: attachments ?? [],
      )) {
        // Handle different event types from writer agent
        switch (event.type) {
          case StreamEventType.content:
            // Yield content chunks as they arrive
            final contentChunk = event.content ?? '';
            fullResponse += contentChunk;
            
            if (contentChunk.isNotEmpty) {
              
            }
            yield event;
            break;

          case StreamEventType.complete:
            

            // Extract generation data from complete event metadata
            if (event.metadata != null && event.metadata!['generationIds'] != null) {
              final generationIds = event.metadata!['generationIds'] as List<dynamic>;
              if (generationIds.isNotEmpty) {
                final writerGenData = generationIds.first as Map<String, dynamic>;
                writerGenerationId = writerGenData['id'] as String?;
                // Note: Usage data is already included in the complete event
              }
            }

            // Preserve accumulated content - only use complete event content if we don't have accumulated content
            // This fixes the issue where complete event overwrites accumulated streaming content with empty content
            if (fullResponse.isEmpty) {
              if (event.message != null && event.message!.isNotEmpty) {
                fullResponse = event.message!;
                
              } else if (event.content != null && event.content!.isNotEmpty) {
                fullResponse = event.content!;
                
              } else {
                
              }
            } else {
              // We have accumulated content, prefer it over potentially empty complete event content
              

              // Optional: Use complete event content if it's significantly longer (indicates it might be more complete)
              final completeEventContent = event.message ?? event.content ?? '';
              if (completeEventContent.length > fullResponse.length * 1.1) {
                
                fullResponse = completeEventContent;
              }
            }
            // Don't yield the writer agent's complete event - we'll yield our own
            break;

          case StreamEventType.error:
            // Forward error events
            yield event;
            return; // Stop processing on error
            
          default:
            // Forward other events (milestones, etc.)
            yield event;
            break;
        }
      }

      // Add writer generation ID to collection if available
      if (writerGenerationId != null) {
        generationIds.add({
          'id': writerGenerationId,
          'stage': 'writing',
          'model': _defaultModel,
          'inputTokens': writerUsage?['prompt_tokens'] ?? 0,
          'outputTokens': writerUsage?['completion_tokens'] ?? 0,
          'totalTokens': writerUsage?['total_tokens'] ?? 0,
        });
        
      }

      
      if (fullResponse.isNotEmpty) {
        
      } else {
        
      }
      
      
      
      // Add generation IDs to final response for cost tracking
      yield ChatStreamEvent.complete(
        message: fullResponse,
        sources: sources,
        images: images,
        generationIds: generationIds,
      );

    } catch (error) {
      print('❌ Agent System initialization failed: \$e');
      yield ChatStreamEvent.error(
        error: 'An error occurred while processing your request: $error',
      );
    }
  }

  /// Process source-grounded query (skips planner, uses extracted sources directly)
  Stream<ChatStreamEvent> processSourceGroundedQuery({
    required String query,
    required List<String> sourceIds,
    String mode = 'source_grounded',
    List<Map<String, dynamic>>? attachments,
    bool isIncognitoMode = false,
    String personality = 'Default',
    String language = 'English',
    List<Message> conversationHistory = const [],
    String? selectedModel,
  }) async* {
    if (!_initialized) {
      throw Exception('Agent System not initialized');
    }

    try {
      
      
      // Update agents with the selected model if provided
      if (selectedModel != null) {
        
        updateSelectedModel(selectedModel, mode: mode);
      }

      // Step 1: Extract source content (skip planning)
      yield ChatStreamEvent.milestone(
        message: '🔍 Extracting source content...',
        phase: 'extraction',
        progress: 0.2,
      );

      // Import database service to get source content
      final databaseService = DatabaseService();
      await databaseService.initialize();
      
      final sourceContents = <String>[];
      final sourceTitles = <String>[];
      
      for (final sourceId in sourceIds) {
        final content = await databaseService.getSourceContent(sourceId);
        final source = await databaseService.getSource(sourceId);
        
        if (content != null && content['content'] != null) {
          final sourceTitle = source?.title ?? 'Unknown Source';
          final sourceContent = content['content'] as String;
          sourceContents.add('Source: $sourceTitle\nContent: $sourceContent');
          sourceTitles.add(sourceTitle);
          
        }
      }

      if (sourceContents.isEmpty) {
        yield ChatStreamEvent.error(
          error: 'No source content available for analysis',
        );
        return;
      }

      yield ChatStreamEvent.milestone(
        message: '✅ Source content extracted',
        phase: 'extraction',
        progress: 0.4,
      );

      // Step 2: Create tool results from source content (simulate tool execution)
      final toolResults = <ToolResult>[];
      for (int i = 0; i < sourceContents.length; i++) {
        final sourceContent = sourceContents[i];
        final sourceTitle = i < sourceTitles.length ? sourceTitles[i] : 'Unknown Source';
        
        toolResults.add(ToolResult(
          tool: 'source_extraction',
          input: {'sourceId': sourceIds[i]},
          output: {
            'content': sourceContent,
            'title': sourceTitle,
            'type': 'source_content',
          },
          executionTime: 0,
          timestamp: DateTime.now().toIso8601String(),
          order: i,
          failed: false,
        ));
      }

      yield ChatStreamEvent.milestone(
        message: '✅ Source content prepared for analysis',
        phase: 'preparation',
        progress: 0.6,
      );

      // Step 3: Writing - Use streaming to yield content chunks
      yield ChatStreamEvent.milestone(
        message: MilestoneMessages.getRandomWritingMessage(),
        phase: 'writing',
        progress: 0.8,
      );
      
      // Use streaming writer agent to yield content chunks
      await for (final event in _writerAgent.writeResponseStream(
        originalQuery: query,
        toolResults: toolResults,
        mode: mode,
        isIncognitoMode: isIncognitoMode,
        personality: personality,
        language: language,
        conversationHistory: conversationHistory,
        attachments: attachments ?? [],
      )) {
        yield event;
      }

    } catch (e) {
      print('❌ Agent System initialization failed: \$e');
      yield ChatStreamEvent.error(
        error: e.toString(),
      );
    }
  }

  /// Update the selected model for stateless agents
  void updateSelectedModel(String model, {String mode = 'chat'}) {
    
    _plannerAgent = PlannerAgent(modelName: model, mode: mode);
    _writerAgent = WriterAgent(modelName: model, mode: mode);
    
  }

  /// Convert tool results to images format
  /// Uses pre-extracted and deduplicated images from executor agent
  List<Map<String, dynamic>> _convertToolResultsToImages(List<ToolResult> toolResults) {
    final images = <Map<String, dynamic>>[];
    final seenUrls = <String>{}; // Track seen URLs to avoid duplicates

    // First, try to get pre-extracted images from executor agent to avoid duplication
    for (final result in toolResults) {
      if (result.failed) continue;

      final data = result.output as Map<String, dynamic>?;
      if (data == null) continue;

      // Use pre-extracted images from executor agent (avoid re-processing)
      if (data['extractedImages'] != null && data['extractedImages'] is List) {
        final extractedImages = data['extractedImages'] as List<dynamic>;
        

        for (final item in extractedImages) {
          if (item is Map<String, dynamic>) {
            final imageUrl = item['url'] ?? '';

            // Skip if we've already seen this URL
            if (seenUrls.contains(imageUrl)) {
              
              continue;
            }

            seenUrls.add(imageUrl);

            images.add({
              'id': item['id'] ?? 'img_${DateTime.now().millisecondsSinceEpoch}',
              'url': imageUrl,
              'thumbnail': item['thumbnail'] ?? imageUrl,
              'title': item['title'] ?? 'Image',
              'description': item['description'] ?? '',
              'source': item['source'] ?? imageUrl,
              'width': item['width'],
              'height': item['height'],
              'timestamp': item['timestamp'] ?? DateTime.now().toIso8601String(),
              'toolSource': item['toolSource'] ?? result.tool
            });
            
          }
        }

        // If we found pre-extracted images, use only those (they're already deduplicated)
        if (images.isNotEmpty) {
          
          return images;
        }
      }
    }
    
    // Only fallback to direct processing if no pre-extracted images found
    if (images.isEmpty) {
      
      
      for (final result in toolResults) {
        if (result.failed) continue;
        
        final data = result.output as Map<String, dynamic>?;
        if (data == null) continue;
        
        
        
        // Handle different tool types that can produce images
        switch (result.tool) {
          case 'image_search':
            // Handle image search results
            List<dynamic>? imageResults;
            if (data['images'] != null && data['images'] is List) {
              imageResults = data['images'] as List<dynamic>;
              
              
              for (final item in imageResults) {
                if (item is Map<String, dynamic>) {
                  final title = item['title'] as String? ?? 'Image';
                  final url = item['url'] as String? ?? '';
                  final thumbnail = item['thumbnail'] as String? ?? url;
                  final description = item['description'] as String? ?? '';
                  
                  // Skip if we've already seen this URL
                  if (seenUrls.contains(url)) {
                    
                    continue;
                  }
                  
                  seenUrls.add(url);
                  
                  images.add({
                    'id': item['id'] ?? 'img_${DateTime.now().millisecondsSinceEpoch}',
                    'url': url,
                    'thumbnail': thumbnail,
                    'title': title,
                    'description': description,
                    'source': item['source'] ?? url,
                    'width': item['width'],
                    'height': item['height'],
                    'timestamp': DateTime.now().toIso8601String(),
                    'toolSource': result.tool
                  });
                  
                }
              }
            } else if (data['results'] != null && data['results'] is List) {
              // Fallback to results array for images
              final results = data['results'] as List<dynamic>;
              for (final item in results) {
                if (item is Map<String, dynamic>) {
                  final title = item['title'] as String? ?? 'Image';
                  final url = item['url'] as String? ?? '';
                  final thumbnail = item['thumbnail'] as String? ?? url;
                  final description = item['description'] as String? ?? '';
                  
                  // Skip if we've already seen this URL
                  if (seenUrls.contains(url)) {
                    
                    continue;
                  }
                  
                  seenUrls.add(url);
                  
                  images.add({
                    'id': item['id'] ?? 'img_${DateTime.now().millisecondsSinceEpoch}',
                    'url': url,
                    'thumbnail': thumbnail,
                    'title': title,
                    'description': description,
                    'source': item['source'] ?? url,
                    'width': item['width'],
                    'height': item['height'],
                    'timestamp': DateTime.now().toIso8601String(),
                    'toolSource': result.tool
                  });
                  
                }
              }
            }
            break;
            
          case 'brave_search':
          case 'brave_search_enhanced':
            // Check if any search results contain images
            List<dynamic>? results;
            if (data['results'] != null && data['results'] is List) {
              results = data['results'] as List<dynamic>;
              
              for (final item in results) {
                if (item is Map<String, dynamic>) {
                  final url = item['url'] as String? ?? '';
                  // Check if the result is an image (common image extensions)
                  if (url.isNotEmpty && RegExp(r'\.(jpg|jpeg|png|gif|webp|svg)$', caseSensitive: false).hasMatch(url)) {
                    // Skip if we've already seen this URL
                    if (seenUrls.contains(url)) {
                      
                      continue;
                    }
                    
                    seenUrls.add(url);
                    
                    final title = item['title'] as String? ?? 'Image';
                    final description = item['description'] as String? ?? '';
                    
                    images.add({
                      'id': 'img_${DateTime.now().millisecondsSinceEpoch}',
                      'url': url,
                      'thumbnail': url,
                      'title': title,
                      'description': description,
                      'source': url,
                      'timestamp': DateTime.now().toIso8601String(),
                      'toolSource': result.tool
                    });
                    print('🖼️ Added unique image from search: $title');
                  }
                }
              }
            }
            break;
        }
      }
    }
    
    
    return images;
  }

  /// Convert tool results to ChatSource format
  /// Uses pre-extracted and deduplicated sources from executor agent
  List<ChatSource> _convertToolResultsToSources(List<ToolResult> toolResults) {
    final sources = <ChatSource>[];

    // First, try to use pre-extracted sources from executor agent (deduplicated)
    for (final result in toolResults) {
      if (result.failed) continue;

      final data = result.output as Map<String, dynamic>?;
      if (data == null) continue;

      // Check if this result has pre-extracted sources from executor agent
      if (data['extractedSources'] != null && data['extractedSources'] is List) {
        final extractedSources = data['extractedSources'] as List<dynamic>;
        

        for (final item in extractedSources) {
          if (item is Map<String, dynamic>) {
            final source = ChatSource.fromJson(item);
            sources.add(source);
            
          }
        }

        // If we found pre-extracted sources, use only those (they're already deduplicated)
        if (sources.isNotEmpty) {
          
          return sources;
        }
      }
    }

    // Fallback: Process individual tool results (for backward compatibility)
    

    for (final result in toolResults) {
      if (result.failed) continue;

      final data = result.output as Map<String, dynamic>?;
      if (data == null) continue;

      
      

      // Handle different tool types
      switch (result.tool) {
        case 'brave_search':
        case 'brave_search_enhanced':
          // Extract actual search results from the tool output
          List<dynamic>? results;
          if (data['results'] != null && data['results'] is List) {
            results = data['results'] as List<dynamic>;
            

            for (final item in results) {
              if (item is Map<String, dynamic>) {
                final title = item['title'] as String? ?? 'Search Result';
                final url = item['url'] as String? ?? '';
                final description = item['description'] as String? ?? '';

                // Search tools only provide URLs, no content scraping
                // Content will be extracted separately via web_fetch tools

                sources.add(ChatSource(
                  title: title,
                  url: url,
                  type: 'web',
                  description: description,
                  content: null, // No content from search tools
                  hasScrapedContent: false,
                ));
                print('🤖 Added source: $title');
              }
            }
          } else {
            
            
            // Try to create a source from the search terms
            final searchTerms = data['searchTerms'] as String?;
            if (searchTerms != null) {
                          sources.add(ChatSource(
              title: 'Search for: $searchTerms',
              url: '',
              type: 'web',
              description: 'Search results for: $searchTerms',
              content: data['content'] as String?, // ✅ Include any content if available
              hasScrapedContent: data['content'] != null && data['content'].toString().isNotEmpty,
            ));
            }
          }
          break;

        case 'web_fetch':
          final url = data['url'] as String?;
          final title = data['title'] as String?;
          final content = data['content'] as String?;
          if (url != null) {
            sources.add(ChatSource(
              title: title ?? 'Web Page',
              url: url,
              type: 'web',
              description: data['description'] as String?,
              content: content, // ✅ Include the actual scraped content
              hasScrapedContent: content != null && content.isNotEmpty,
            ));
            
          }
          break;

        case 'keyword_extraction':
          // For keyword extraction, create a source with the extracted keywords
          final keywords = data['keywords'] as List<dynamic>?;
          if (keywords != null && keywords.isNotEmpty) {
            sources.add(ChatSource(
              title: 'Extracted Keywords',
              url: '',
              type: 'text',
              description: keywords.join(', '),
              content: keywords.join(', '), // ✅ Use keywords as content
              hasScrapedContent: true,
            ));
          }
          break;

        case 'youtube_processor':
          // Handle YouTube video results
          if (data['url'] != null) {
            sources.add(ChatSource(
              title: data['title'] as String? ?? 'YouTube Video',
              url: data['url'] as String? ?? '',
              type: 'video',
              description: data['description'] as String? ?? 'YouTube video content',
              content: data['content'] as String?, // ✅ Include video content if available
              hasScrapedContent: data['content'] != null && data['content'].toString().isNotEmpty,
            ));
          }
          break;

        default:
          // For other tools, try to extract URL and title
          final url = data['url'] as String?;
          final title = data['title'] as String?;
          if (url != null) {
            sources.add(ChatSource(
              title: title ?? 'Tool Result',
              url: url,
              type: 'web',
              description: data['description'] as String?,
              content: data['content'] as String?, // ✅ Include content if available
              hasScrapedContent: data['content'] != null && data['content'].toString().isNotEmpty,
            ));
          }
      }
    }

    
    return sources;
  }
} 