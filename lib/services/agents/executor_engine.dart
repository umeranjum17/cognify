import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';

import '../../models/chat_source.dart';
import '../../models/tool_result.dart';
import '../../models/tool_spec.dart';
import '../tool_result_processor.dart';
import '../tools.dart';

/// Tool execution isolate function (top-level for isolate spawning)
void _toolExecutionIsolate(IsolateData data) async {
  try {
    final startTime = DateTime.now();
    print('🔧 Isolate: Starting tool execution for ${data.message.toolName}');

    // Initialize tools manager in isolate
    final toolsManager = ToolsManager();
    print('🔧 Isolate: ToolsManager created, available tools: ${toolsManager.allTools.length}');

    final tool = toolsManager.getToolByName(data.message.toolName);
    print('🔧 Isolate: Tool lookup for ${data.message.toolName}: ${tool != null ? 'found' : 'not found'}');

    if (tool == null) {
      throw Exception('Tool ${data.message.toolName} not found in isolate. Available tools: ${toolsManager.allTools.map((t) => t.name).join(', ')}');
    }

    print('🔧 Isolate: Executing tool ${data.message.toolName} with input: ${data.message.input}');
    // Execute tool (await the async operation)
    final toolResult = await tool.invoke(data.message.input);
    print('🔧 Isolate: Tool execution completed, result keys: ${toolResult.keys.join(', ')}');

    final executionTime = DateTime.now().difference(startTime).inMilliseconds;
    print('🔧 Isolate: Execution time: ${executionTime}ms');

    final result = ToolExecutionResult(
      toolName: data.message.toolName,
      input: data.message.input,
      output: toolResult,
      executionTime: executionTime,
      timestamp: DateTime.now().toIso8601String(),
      order: data.message.order,
      failed: false,
    );

    print('🔧 Isolate: Sending result back to main isolate');
    // Send result back to main isolate
    data.sendPort.send(result);
  } catch (error) {
    print('🔧 Isolate: Error executing tool ${data.message.toolName}: $error');
    final result = ToolExecutionResult(
      toolName: data.message.toolName,
      input: data.message.input,
      output: {'error': error.toString()},
      executionTime: 0,
      timestamp: DateTime.now().toIso8601String(),
      order: data.message.order,
      failed: true,
      error: error.toString(),
    );

    print('🔧 Isolate: Sending error result back to main isolate');
    data.sendPort.send(result);
  }
}

/// Progress callback for tool execution
typedef ToolProgressCallback = void Function(Map<String, dynamic> progress);

/// Result callback for tool execution
typedef ToolResultCallback = void Function(ToolResult result);

/// Executor Engine - Executes tools based on plans from Planner Agent
class ExecutorEngine {
  static const int _maxCacheSize = 50; // Limit cache size
  // Thread pool for isolate management
  static const int _maxConcurrentIsolates = 4; // Limit concurrent isolates
  final Map<String, Tool> _toolMap = {};
  
  late ToolsManager _toolsManager;
  bool _initialized = false;
  
  // Simple cache for tool results (key: toolName + input hash)
  final Map<String, ToolResult> _resultCache = {};
  final List<Isolate> _activeIsolates = [];
  final Queue<Future<void>> _isolateQueue = Queue<Future<void>>();
  


  /// Execute a single tool
  Future<ToolResult> executeTool(
    ToolSpec toolSpec, {
    ToolProgressCallback? onProgress,
    ToolResultCallback? onResult,
  }) async {
    try {
      // Check cache first
      final cachedResult = _getCachedResult(toolSpec.name, toolSpec.input);
      if (cachedResult != null) {
        if (onProgress != null) {
          onProgress({
            'tool': toolSpec.name,
            'message': '⚡ Using cached result for ${toolSpec.name}',
            'stage': 'cached'
          });
        }
        return cachedResult;
      }

      final startTime = DateTime.now();
      print('🔧 Executing single tool: ${toolSpec.name}');

      if (onProgress != null) {
        onProgress({
          'tool': toolSpec.name,
          'message': '🔧 Starting ${toolSpec.name}...',
          'stage': 'starting'
        });
      }

      final tool = _toolsManager.getToolByName(toolSpec.name);
      if (tool == null) {
        throw Exception('Tool ${toolSpec.name} not found');
      }

      final toolResult = await tool.invoke(toolSpec.input);
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      print('✅ Tool ${toolSpec.name} completed in ${executionTime}ms');

      final result = ToolResult(
        tool: toolSpec.name,
        input: toolSpec.input,
        output: toolResult,
        executionTime: executionTime,
        timestamp: DateTime.now().toIso8601String(),
        order: toolSpec.order,
        failed: false,
      );

      // Cache the result
      _cacheResult(toolSpec.name, toolSpec.input, result);

      if (onProgress != null) {
        onProgress({
          'tool': toolSpec.name,
          'message': '✅ ${toolSpec.name} completed',
          'stage': 'completed',
          'result': result.toJson()
        });
      }

      if (onResult != null) {
        onResult(result);
      }

      return result;

    } catch (toolError) {
      print('❌ Tool ${toolSpec.name} failed: $toolError');

      final result = ToolResult(
        tool: toolSpec.name,
        input: toolSpec.input,
        output: {'error': toolError.toString()},
        executionTime: 0,
        timestamp: DateTime.now().toIso8601String(),
        order: toolSpec.order,
        failed: true,
      );

      if (onProgress != null) {
        onProgress({
          'tool': toolSpec.name,
          'message': '❌ ${toolSpec.name} failed: $toolError',
          'stage': 'failed',
          'result': result.toJson()
        });
      }

      if (onResult != null) {
        onResult(result);
      }

      return result;
    }
  }

  /// Execute tools in parallel using isolates (true multi-threading)
  Future<List<ToolResult>> executeTools(
    List<ToolSpec> toolSpecs,
    {
      void Function(Map<String, dynamic>)? onProgress,
      void Function(ToolResult)? onResult,
    }
  ) async {
    if (!_initialized) {
      throw Exception('Executor Engine not initialized');
    }

    final planStartTime = DateTime.now();
    print('⚡ Executing plan with ${toolSpecs.length} tools using two-phase execution');

    // Phase 1: Execute search tools in parallel
    final searchTools = toolSpecs.where((spec) => 
      spec.name == 'brave_search' || 
      spec.name == 'brave_search_enhanced' || 
      spec.name == 'image_search' ||
      spec.name == 'keyword_extraction' ||
      spec.name == 'youtube_processor'
    ).toList();

    final fetchTools = toolSpecs.where((spec) => 
      spec.name == 'web_fetch' || 
      spec.name == 'source_content' ||
      spec.name == 'source_query'
    ).toList();

    final otherTools = toolSpecs.where((spec) => 
      !searchTools.contains(spec) && !fetchTools.contains(spec)
    ).toList();

    print('🔍 Phase 1: ${searchTools.length} search tools, ${fetchTools.length} fetch tools, ${otherTools.length} other tools');

    // Execute search tools in parallel
    final searchResults = <ToolResult>[];
    if (searchTools.isNotEmpty) {
      final searchStartTime = DateTime.now();
      print('⏱️ [TIMING] Search phase started at ${searchStartTime.toIso8601String()}');

      final searchMessages = searchTools.map((spec) => ToolExecutionMessage(
        toolName: spec.name,
        input: spec.input,
        order: spec.order,
        reasoning: spec.reasoning,
      )).toList();

      final searchFutures = searchMessages.map((message) async {
        if (onProgress != null) {
          onProgress({
            'tool': message.toolName,
            'message': '🔍 Starting search: ${message.toolName}...',
            'stage': 'search_starting'
          });
        }

        // Try isolate execution first, fallback to main thread if it fails
        final result = await _executeToolWithFallback(message);

        if (onProgress != null) {
          onProgress({
            'tool': message.toolName,
            'message': result.failed ? '❌ Search failed: ${message.toolName}' : '✅ Search completed: ${message.toolName}',
            'stage': result.failed ? 'search_failed' : 'search_completed',
            'result': result.toJson()
          });
        }

        return result;
      }).toList();

      final settledSearchResults = await Future.wait(searchFutures);
      
      // Convert to ToolResult
      for (final result in settledSearchResults) {
        final toolResult = ToolResult(
          tool: result.toolName,
          input: result.input,
          output: result.output,
          executionTime: result.executionTime,
          timestamp: result.timestamp,
          order: result.order,
          failed: result.failed,
        );
        searchResults.add(toolResult);
      }

      final searchEndTime = DateTime.now();
      final searchTime = searchEndTime.difference(searchStartTime).inMilliseconds;
      print('⏱️ [TIMING] Search phase completed in ${searchTime}ms at ${searchEndTime.toIso8601String()}');
      
      // Extract unique URLs from search results for content fetching
      final urlsToFetch = await _extractUrlsFromSearchResults(searchResults);
      final processedUrls = <String>{};
      
      // Add web_fetch tools for unique URLs only
      for (final url in urlsToFetch) {
        if (!processedUrls.contains(url)) {
          print('🔗 Adding web_fetch for URL: $url');
          fetchTools.add(ToolSpec(
            name: 'web_fetch',
            input: {'url': url, 'extractText': true},
            order: 100, // High order to run after searches
            reasoning: 'Content extraction for URL found in search results',
          ));
          processedUrls.add(url);
        }
      }
    }

    // Phase 2: Execute fetch tools in parallel (after searches complete)
    final fetchResults = <ToolResult>[];
    if (fetchTools.isNotEmpty) {
      final fetchStartTime = DateTime.now();
      print('⏱️ [TIMING] Fetch phase started at ${fetchStartTime.toIso8601String()}');

      final fetchMessages = fetchTools.map((spec) => ToolExecutionMessage(
        toolName: spec.name,
        input: spec.input,
        order: spec.order,
        reasoning: spec.reasoning,
      )).toList();

      final fetchFutures = fetchMessages.map((message) async {
        if (onProgress != null) {
          onProgress({
            'tool': message.toolName,
            'message': '📄 Starting fetch: ${message.toolName}...',
            'stage': 'fetch_starting'
          });
        }

        // Always use isolates for tool execution to prevent UI blocking
        final result = await _executeToolInIsolate(message);

        if (onProgress != null) {
          onProgress({
            'tool': message.toolName,
            'message': result.failed ? '❌ Fetch failed: ${message.toolName}' : '✅ Fetch completed: ${message.toolName}',
            'stage': result.failed ? 'fetch_failed' : 'fetch_completed',
            'result': result.toJson()
          });
        }

        return result;
      }).toList();

      final settledFetchResults = await Future.wait(fetchFutures);
      
      // Convert to ToolResult
      for (final result in settledFetchResults) {
        final toolResult = ToolResult(
          tool: result.toolName,
          input: result.input,
          output: result.output,
          executionTime: result.executionTime,
          timestamp: result.timestamp,
          order: result.order,
          failed: result.failed,
        );
        fetchResults.add(toolResult);
      }

      final fetchEndTime = DateTime.now();
      final fetchTime = fetchEndTime.difference(fetchStartTime).inMilliseconds;
      print('⏱️ [TIMING] Fetch phase completed in ${fetchTime}ms at ${fetchEndTime.toIso8601String()}');
    }

    // Execute other tools in parallel (can run anytime)
    final otherResults = <ToolResult>[];
    if (otherTools.isNotEmpty) {
      final otherStartTime = DateTime.now();
      print('⏱️ [TIMING] Other tools phase started at ${otherStartTime.toIso8601String()}');

      final otherMessages = otherTools.map((spec) => ToolExecutionMessage(
        toolName: spec.name,
        input: spec.input,
        order: spec.order,
        reasoning: spec.reasoning,
      )).toList();

      final otherFutures = otherMessages.map((message) async {
        if (onProgress != null) {
          onProgress({
            'tool': message.toolName,
            'message': '🔧 Starting tool: ${message.toolName}...',
            'stage': 'other_starting'
          });
        }

        // Try isolate execution first, fallback to main thread if it fails
        final result = await _executeToolWithFallback(message);

        if (onProgress != null) {
          onProgress({
            'tool': message.toolName,
            'message': result.failed ? '❌ Tool failed: ${message.toolName}' : '✅ Tool completed: ${message.toolName}',
            'stage': result.failed ? 'other_failed' : 'other_completed',
            'result': result.toJson()
          });
        }

        return result;
      }).toList();

      final settledOtherResults = await Future.wait(otherFutures);
      
      // Convert to ToolResult
      for (final result in settledOtherResults) {
        final toolResult = ToolResult(
          tool: result.toolName,
          input: result.input,
          output: result.output,
          executionTime: result.executionTime,
          timestamp: result.timestamp,
          order: result.order,
          failed: result.failed,
        );
        otherResults.add(toolResult);
      }

      final otherEndTime = DateTime.now();
      final otherTime = otherEndTime.difference(otherStartTime).inMilliseconds;
      print('⏱️ [TIMING] Other tools phase completed in ${otherTime}ms at ${otherEndTime.toIso8601String()}');
    }

    // Combine all results
    final allResults = <ToolResult>[];
    allResults.addAll(searchResults);
    allResults.addAll(fetchResults);
    allResults.addAll(otherResults);

    // Process results and extract sources/images
    final processingStartTime = DateTime.now();
    print('⏱️ [TIMING] Result processing started at ${processingStartTime.toIso8601String()}');

    final executedTools = <String>[];
    final allSources = <ChatSource>[];
    final allImages = <Map<String, dynamic>>[];

    for (final result in allResults) {
      if (!result.failed) {
        executedTools.add(result.tool);

        // Extract sources and images from tool result using shared processor
        final extractionStartTime = DateTime.now();
        final extractionResult = ToolResultProcessor.extractSourcesAndImages(result.output, result.tool);
        final extractionTime = DateTime.now().difference(extractionStartTime).inMilliseconds;

        print('⏱️ [TIMING] Source/image extraction for ${result.tool} took ${extractionTime}ms');

        if (extractionResult['sources'].isNotEmpty) {
          allSources.addAll(extractionResult['sources']);
        }
        if (extractionResult['images'].isNotEmpty) {
          allImages.addAll(extractionResult['images']);
          print('Found ${extractionResult['images'].length} images from ${result.tool} - added to separate images array');
        }
      }
    }

    final processingEndTime = DateTime.now();
    final processingTime = processingEndTime.difference(processingStartTime).inMilliseconds;
    print('⏱️ [TIMING] Result processing completed in ${processingTime}ms at ${processingEndTime.toIso8601String()}');

    // Sort results by original order to maintain consistency
    final sortingStartTime = DateTime.now();
    allResults.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    final sortingTime = DateTime.now().difference(sortingStartTime).inMilliseconds;

    // Remove duplicate sources by URL and ensure each URL is processed only once
    final deduplicationStartTime = DateTime.now();
    final uniqueSources = ToolResultProcessor.deduplicateSources(allSources);
    final deduplicationTime = DateTime.now().difference(deduplicationStartTime).inMilliseconds;

    // Remove any images that might have been accidentally added to sources
    final cleaningStartTime = DateTime.now();
    final cleanSources = ToolResultProcessor.cleanSources(uniqueSources);
    final cleaningTime = DateTime.now().difference(cleaningStartTime).inMilliseconds;

    final totalExecutionTime = DateTime.now().difference(planStartTime).inMilliseconds;

    print('⏱️ [TIMING] Final processing times - Sorting: ${sortingTime}ms, Deduplication: ${deduplicationTime}ms, Cleaning: ${cleaningTime}ms');
    print('⚡ Two-phase execution complete in ${totalExecutionTime}ms: ${allResults.length} tools executed, ${cleanSources.length} sources found, ${allImages.length} images found');
    print('⏱️ [TIMING] Plan execution completed at ${DateTime.now().toIso8601String()}');

    // Store extracted sources and images in the results for the writer to use
    // Only add to the first result to avoid duplication
    if (allResults.isNotEmpty && !allResults.first.failed) {
      allResults.first.output['extractedSources'] = cleanSources.map((s) => s.toJson()).toList();
      allResults.first.output['extractedImages'] = allImages;
    }

    return allResults;
  }

  /// Execute tools in parallel (for independent tools)
  Future<List<ToolResult>> executeToolsParallel(
    List<ToolSpec> toolSpecs, {
    ToolProgressCallback? onProgress,
    ToolResultCallback? onResult,
  }) async {
    final futures = toolSpecs.map((toolSpec) => executeTool(
      toolSpec,
      onProgress: onProgress,
      onResult: onResult,
    ));

    return await Future.wait(futures);
  }

  Future<void> initialize() async {
    try {
      print('⚡ Initializing Executor Engine (tool execution engine with isolate pool)');

      // Create tool map for quick lookup
      _toolsManager = ToolsManager();
      for (final tool in _toolsManager.allTools) {
        _toolMap[tool.name] = tool;
      }

      _initialized = true;
      print('✅ Executor Engine initialized with ${_toolsManager.allTools.length} tools and isolate pool');
    } catch (error) {
      print('❌ Executor Engine initialization failed: $error');
      rethrow;
    }
  }

  /// Cache tool result
  void _cacheResult(String toolName, Map<String, dynamic> input, ToolResult result) {
    final cacheKey = _generateCacheKey(toolName, input);
    
    // Implement LRU cache eviction
    if (_resultCache.length >= _maxCacheSize) {
      final oldestKey = _resultCache.keys.first;
      _resultCache.remove(oldestKey);
    }
    
    _resultCache[cacheKey] = result;
    print('⚡ Cached result for $toolName');
  }

  /// Execute tool in isolate (separate thread)
  Future<ToolExecutionResult> _executeToolInIsolate(ToolExecutionMessage message) async {
    print('🔧 Main: Starting isolate execution for ${message.toolName}');
    final receivePort = ReceivePort();
    Isolate? isolate;

    try {
      print('🔧 Main: Creating isolate for ${message.toolName}');
      // Create isolate for tool execution
      isolate = await Isolate.spawn(
        _toolExecutionIsolate,
        IsolateData(
          message: message,
          sendPort: receivePort.sendPort,
        ),
      );
      print('🔧 Main: Isolate created successfully for ${message.toolName}');

      // Track active isolate
      _activeIsolates.add(isolate);

      print('🔧 Main: Waiting for result from isolate for ${message.toolName}');
      // Wait for result from isolate
      final result = await receivePort.first as ToolExecutionResult;
      print('🔧 Main: Received result from isolate for ${message.toolName}: ${result.failed ? 'FAILED' : 'SUCCESS'}');

      return result;
    } catch (error) {
      print('🔧 Main: Error in isolate execution for ${message.toolName}: $error');
      return ToolExecutionResult(
        toolName: message.toolName,
        input: message.input,
        output: {'error': error.toString()},
        executionTime: 0,
        timestamp: DateTime.now().toIso8601String(),
        order: message.order,
        failed: true,
        error: error.toString(),
      );
    } finally {
      // Clean up isolate
      if (isolate != null) {
        print('🔧 Main: Cleaning up isolate for ${message.toolName}');
        isolate.kill();
        _activeIsolates.remove(isolate);
      }
    }
  }

  /// Execute tool in main isolate (avoid isolate issues)
  Future<ToolExecutionResult> _executeToolInMainIsolate(ToolExecutionMessage message) async {
    try {
      print('🔧 Main Thread: Starting execution for ${message.toolName}');
      final startTime = DateTime.now();

      // Get tool from tools manager in main isolate
      final tool = _toolsManager.getToolByName(message.toolName);
      print('🔧 Main Thread: Tool lookup for ${message.toolName}: ${tool != null ? 'found' : 'not found'}');

      if (tool == null) {
        throw Exception('Tool ${message.toolName} not found in main thread. Available tools: ${_toolsManager.allTools.map((t) => t.name).join(', ')}');
      }

      print('🔧 Main Thread: Executing tool ${message.toolName} with input: ${message.input}');
      // Execute tool (await the async operation)
      final toolResult = await tool.invoke(message.input);
      print('🔧 Main Thread: Tool execution completed, result keys: ${toolResult.keys.join(', ')}');

      final executionTime = DateTime.now().difference(startTime).inMilliseconds;
      print('🔧 Main Thread: Execution time: ${executionTime}ms');

      final result = ToolExecutionResult(
        toolName: message.toolName,
        input: message.input,
        output: toolResult,
        executionTime: executionTime,
        timestamp: DateTime.now().toIso8601String(),
        order: message.order,
        failed: false,
      );

      print('🔧 Main Thread: Returning successful result for ${message.toolName}');
      return result;
    } catch (error) {
      print('🔧 Main Thread: Error executing tool ${message.toolName}: $error');
      final result = ToolExecutionResult(
        toolName: message.toolName,
        input: message.input,
        output: {'error': error.toString()},
        executionTime: 0,
        timestamp: DateTime.now().toIso8601String(),
        order: message.order,
        failed: true,
        error: error.toString(),
      );

      print('🔧 Main Thread: Returning error result for ${message.toolName}');
      return result;
    }
  }

  /// Execute tool with fallback from isolate to main thread
  Future<ToolExecutionResult> _executeToolWithFallback(ToolExecutionMessage message) async {
    try {
      // First try isolate execution
      print('🔧 Attempting isolate execution for ${message.toolName}');
      final result = await _executeToolInIsolate(message);

      // Check if the result indicates a successful execution
      if (!result.failed && result.executionTime > 0) {
        print('🔧 Isolate execution successful for ${message.toolName}');
        return result;
      } else {
        print('🔧 Isolate execution failed or returned empty result for ${message.toolName}, falling back to main thread');
        return await _executeToolInMainIsolate(message);
      }
    } catch (error) {
      print('🔧 Isolate execution error for ${message.toolName}: $error, falling back to main thread');
      return await _executeToolInMainIsolate(message);
    }
  }

  /// Execute tool with thread pool management
  Future<ToolExecutionResult> _executeToolWithPool(ToolExecutionMessage message) async {
    // Wait if we have too many active isolates
    while (_activeIsolates.length >= _maxConcurrentIsolates) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    final result = await _executeToolInIsolate(message);

    return result;
  }

  /// Extract URLs from search results for content fetching
  Future<Set<String>> _extractUrlsFromSearchResults(
    List<ToolResult> searchResults,
  ) async {
    final urlsToFetch = <String>{};
    
    for (final result in searchResults) {
      if (result.failed) continue;
      
      final output = result.output;
      final urls = _extractUrlsFromToolOutput(output);
      
      // Add URLs that need content extraction
      for (final url in urls) {
        if (url.isNotEmpty && !urlsToFetch.contains(url)) {
          urlsToFetch.add(url);
          print('🔗 Found URL for content extraction: $url');
        }
      }
    }
    
    print('📋 Total unique URLs to fetch: ${urlsToFetch.length}');
    return urlsToFetch;
  }

  /// Extract URLs from tool output
  List<String> _extractUrlsFromToolOutput(Map<String, dynamic> output) {
    final urls = <String>[];
    
    // Handle different tool output structures
    if (output['results'] != null && output['results'] is List) {
      final results = output['results'] as List<dynamic>;
      for (final result in results) {
        if (result is Map<String, dynamic>) {
          final url = result['url'] as String?;
          if (url != null && url.isNotEmpty) {
            urls.add(url);
          }
        }
      }
    }
    
    // Also check for direct URL fields
    final url = output['url'] as String?;
    if (url != null && url.isNotEmpty) {
      urls.add(url);
    }
    
    return urls;
  }
  
  /// Generate cache key for tool execution
  String _generateCacheKey(String toolName, Map<String, dynamic> input) {
    final inputJson = jsonEncode(input);
    return '${toolName}_${inputJson.hashCode}';
  }
  
  /// Get cached result if available
  ToolResult? _getCachedResult(String toolName, Map<String, dynamic> input) {
    final cacheKey = _generateCacheKey(toolName, input);
    final cached = _resultCache[cacheKey];
    
    if (cached != null) {
      print('⚡ Using cached result for $toolName');
      return cached;
    }
    
    return null;
  }
  
  /// Check if URL is a Wikipedia URL (kept for backward compatibility)
  bool _isWikipediaUrl(String url) {
    return url.toLowerCase().contains('wikipedia.org') || 
           url.toLowerCase().contains('wikipedia.com');
  }
} 