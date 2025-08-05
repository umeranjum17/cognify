import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../../models/chat_source.dart';
import '../../models/tool_result.dart';
import '../../models/tool_spec.dart';
import '../../utils/logger.dart';
import '../../utils/concurrency_pool.dart';
import '../../utils/json_utils.dart';
import '../tool_result_processor.dart';
import '../tools.dart';
import '../../config/app_config.dart';

/// Progress callback for tool execution
typedef ToolProgressCallback = void Function(Map<String, dynamic> progress);

/// Result callback for tool execution
typedef ToolResultCallback = void Function(ToolResult result);

/// Optimized Executor Engine - Fast tool execution without isolate overhead
class ExecutorEngine {
  static const int _maxCacheSize = 50;
  static const int _ioConcurrencyLimit = 4; // Concurrent IO operations
  
  final ScopedLogger _logger = Logger.scope('ExecutorEngine');
  final Map<String, Tool> _toolMap = {};
  late ToolsManager _toolsManager;
  bool _initialized = false;
  
  // Simple cache for tool results
  final Map<String, ToolResult> _resultCache = {};
  
  // Concurrency control pools
  final ConcurrencyPool _ioPool = ConcurrencyPool(_ioConcurrencyLimit);
  
  // Tool execution policy - determines if tool should run on main thread vs isolate
  static const Set<String> _ioToolTypes = {
    'brave_search',
    'brave_search_enhanced', 
    'image_search',
    'web_fetch',
    'youtube_processor',
    'source_query',
    'source_content',
    'time_tool',
  };

  /// Execute a single tool
  Future<ToolResult> executeTool(
    ToolSpec toolSpec, {
    ToolProgressCallback? onProgress,
    ToolResultCallback? onResult,
  }) async {
    final timer = Stopwatch2('Tool ${toolSpec.name}', _logger);
    
    try {
      // Check cache first
      final cachedResult = _getCachedResult(toolSpec.name, toolSpec.input);
      if (cachedResult != null) {
        
        onProgress?.call({
          'tool': toolSpec.name,
          'message': '⚡ Using cached result',
          'stage': 'cached'
        });
        return cachedResult;
      }

      
      onProgress?.call({
        'tool': toolSpec.name,
        'message': '🔧 Starting ${toolSpec.name}...',
        'stage': 'starting'
      });

      final tool = _toolsManager.getToolByName(toolSpec.name);
      if (tool == null) {
        throw Exception('Tool ${toolSpec.name} not found');
      }

      // Execute tool with concurrency control
      final startTime = DateTime.now();
      final dynamic rawToolResult;
      
      if (_ioToolTypes.contains(toolSpec.name)) {
        // IO-bound tool: use concurrency pool on main isolate
        rawToolResult = await _ioPool.withResource(() => tool.invoke(toolSpec.input));
      } else {
        // Light tool: execute directly
        rawToolResult = await tool.invoke(toolSpec.input);
      }
      
      // Normalize the tool result to ensure type safety
      final Map<String, dynamic> toolResult = JsonUtils.safeStringKeyMap(rawToolResult) ?? {};
      
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

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

      onProgress?.call({
        'tool': toolSpec.name,
        'message': '✅ ${toolSpec.name} completed',
        'stage': 'completed',
        'result': result.toJson()
      });

      onResult?.call(result);
      timer.stop();
      return result;

    } catch (toolError) {
      _logger.error('Tool ${toolSpec.name} failed', toolError);

      final result = ToolResult(
        tool: toolSpec.name,
        input: toolSpec.input,
        output: {'error': toolError.toString()},
        executionTime: 0,
        timestamp: DateTime.now().toIso8601String(),
        order: toolSpec.order,
        failed: true,
      );

      onProgress?.call({
        'tool': toolSpec.name,
        'message': '❌ ${toolSpec.name} failed',
        'stage': 'failed',
        'result': result.toJson()
      });

      onResult?.call(result);
      timer.stop();
      return result;
    }
  }

  /// Execute tools in optimized two-phase approach
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

    final planTimer = Stopwatch2('Plan execution', _logger);
    

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

    

    // Execute search tools in parallel
    final searchResults = <ToolResult>[];
    if (searchTools.isNotEmpty) {
      final searchTimer = Stopwatch2('Search phase', _logger);
      
      // Get Brave API key once
      final braveApiKey = await AppConfig().braveSearchApiKey ?? 'BSA6Crcr3bFuvfEOIgHdL-y7IO_YPqr';

      final searchFutures = searchTools.map((spec) async {
        onProgress?.call({
          'tool': spec.name,
          'message': '🔍 Starting search: ${spec.name}...',
          'stage': 'search_starting'
        });

        // Add API key to input for Brave search tools
        final input = spec.name.contains('brave') || spec.name == 'image_search'
            ? {...spec.input, 'braveApiKey': braveApiKey}
            : spec.input;

        final result = await executeTool(
          ToolSpec(
            name: spec.name,
            input: input,
            order: spec.order,
            reasoning: spec.reasoning,
          ),
          onProgress: onProgress,
          onResult: onResult,
        );

        onProgress?.call({
          'tool': spec.name,
          'message': result.failed ? '❌ Search failed' : '✅ Search completed',
          'stage': result.failed ? 'search_failed' : 'search_completed',
        });

        return result;
      });

      searchResults.addAll(await Future.wait(searchFutures));
      
      
      // Extract URLs for content fetching
      final urlsToFetch = await _extractUrlsFromSearchResults(searchResults);
      for (final url in urlsToFetch) {
        
        fetchTools.add(ToolSpec(
          name: 'web_fetch',
          input: {'url': url, 'extractText': true},
          order: 100,
          reasoning: 'Content extraction for URL from search results',
        ));
      }
    }

    // Phase 2: Execute fetch tools in parallel
    final fetchResults = <ToolResult>[];
    if (fetchTools.isNotEmpty) {
      final fetchTimer = Stopwatch2('Fetch phase', _logger);

      final fetchFutures = fetchTools.map((spec) async {
        onProgress?.call({
          'tool': spec.name,
          'message': '📄 Starting fetch: ${spec.name}...',
          'stage': 'fetch_starting'
        });

        final result = await executeTool(spec, onProgress: onProgress, onResult: onResult);

        onProgress?.call({
          'tool': spec.name,
          'message': result.failed ? '❌ Fetch failed' : '✅ Fetch completed',
          'stage': result.failed ? 'fetch_failed' : 'fetch_completed',
        });

        return result;
      });

      fetchResults.addAll(await Future.wait(fetchFutures));
      
    }

    // Execute other tools in parallel
    final otherResults = <ToolResult>[];
    if (otherTools.isNotEmpty) {
      final otherTimer = Stopwatch2('Other tools phase', _logger);

      final otherFutures = otherTools.map((spec) async {
        onProgress?.call({
          'tool': spec.name,
          'message': '🔧 Starting tool: ${spec.name}...',
          'stage': 'other_starting'
        });

        final result = await executeTool(spec, onProgress: onProgress, onResult: onResult);

        onProgress?.call({
          'tool': spec.name,
          'message': result.failed ? '❌ Tool failed' : '✅ Tool completed',
          'stage': result.failed ? 'other_failed' : 'other_completed',
        });

        return result;
      });

      otherResults.addAll(await Future.wait(otherFutures));
      
    }

    // Combine all results
    final allResults = <ToolResult>[];
    allResults.addAll(searchResults);
    allResults.addAll(fetchResults);
    allResults.addAll(otherResults);

    // Process results and extract sources/images
    final processingTimer = Stopwatch2('Result processing', _logger);

    final allSources = <ChatSource>[];
    final allImages = <Map<String, dynamic>>[];

    for (final result in allResults) {
      if (!result.failed) {
        final extractionResult = ToolResultProcessor.extractSourcesAndImages(result.output, result.tool);
        if (extractionResult['sources'].isNotEmpty) {
          allSources.addAll(extractionResult['sources']);
        }
        if (extractionResult['images'].isNotEmpty) {
          allImages.addAll(extractionResult['images']);
        }
      }
    }

    // Sort results by original order
    allResults.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    // Deduplicate sources and clean
    final uniqueSources = ToolResultProcessor.deduplicateSources(allSources);
    final cleanSources = ToolResultProcessor.cleanSources(uniqueSources);

    
    
    
    

    // Store extracted sources and images in the results
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
      

      // Create tool map for quick lookup
      _toolsManager = ToolsManager();
      for (final tool in _toolsManager.allTools) {
        _toolMap[tool.name] = tool;
      }

      _initialized = true;
      
    } catch (error) {
      _logger.error('Executor Engine initialization failed', error);
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
    
  }

  /// Extract URLs from search results for content fetching
  Future<Set<String>> _extractUrlsFromSearchResults(List<ToolResult> searchResults) async {
    final urlsToFetch = <String>{};
    
    for (final result in searchResults) {
      if (result.failed) continue;
      
      final output = result.output;
      final urls = _extractUrlsFromToolOutput(output);
      
      for (final url in urls) {
        if (url.isNotEmpty && !urlsToFetch.contains(url)) {
          urlsToFetch.add(url);
        }
      }
    }
    
    
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
    return _resultCache[cacheKey];
  }
}