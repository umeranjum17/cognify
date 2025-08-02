import 'dart:async';
import 'dart:convert';

import 'brave_search_service.dart';
import 'content_extractor.dart';
import 'openrouter_client.dart';

/// Enhanced Brave Search Tool
class BraveSearchEnhancedTool extends Tool {
  final BraveSearchService _braveSearchService = BraveSearchService();

  BraveSearchEnhancedTool() : super(
    name: 'brave_search_enhanced',
    description: 'Enhanced web search with intelligent result ranking',
    schema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Search query'},
        'count': {'type': 'number', 'description': 'Number of results (default: 5)'}
      },
      'required': ['query']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final query = input['query'] as String;
      final count = input['count'] as int? ?? 5;
      
      print('🔍 Brave search enhanced tool: Searching for "$query" with count $count');
      final results = await _braveSearchService.search(query, count: count);
      print('🔍 Brave search enhanced tool: Got ${results.length} results');
      
      // Return results without content extraction - content will be extracted separately
      final response = {
        'searchTerms': query,
        'results': results,
        'sources': ['web', 'wikipedia', 'news'],
        'totalResults': results.length,
        'enhancedSearch': true,
        'timestamp': DateTime.now().toIso8601String()
      };
      
      print('🔍 Brave search enhanced tool: Returning ${results.length} results (no content extraction)');
      print('🔍 Brave search enhanced tool: Response structure: ${response.keys.toList()}');
      
      return response;
    } catch (e) {
      print('Enhanced brave search tool failed: $e');
      return {
        'error': "Enhanced search failed",
        'message': e.toString(),
        'searchTerms': input['query'],
        'timestamp': DateTime.now().toIso8601String()
      };
    }
  }
}

/// Brave Search Tool
class BraveSearchTool extends Tool {
  final BraveSearchService _braveSearchService = BraveSearchService();

  BraveSearchTool() : super(
    name: 'brave_search',
    description: 'Search the web using Brave Search API',
    schema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Search query'},
        'count': {'type': 'number', 'description': 'Number of results (default: 5)'}
      },
      'required': ['query']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final query = input['query'] as String;
      final count = input['count'] as int? ?? 5;
      
      print('🔍 Brave search tool: Searching for "$query" with count $count');
      final results = await _braveSearchService.search(query, count: count);
      print('🔍 Brave search tool: Got ${results.length} results');
      
      final response = {
        'searchTerms': query,
        'results': results,
        'totalResults': results.length,
        'timestamp': DateTime.now().toIso8601String()
      };
      
      print('🔍 Brave search tool: Returning ${results.length} results');
      print('🔍 Brave search tool: Response structure: ${response.keys.toList()}');
      
      return response;
    } catch (e) {
      print('Brave search tool failed: $e');
      return {
        'error': "Search failed",
        'message': e.toString(),
        'searchTerms': input['query'],
        'timestamp': DateTime.now().toIso8601String()
      };
    }
  }
}

/// Browser Roadmap Tool
class BrowserRoadmapTool extends Tool {
  BrowserRoadmapTool() : super(
    name: 'browser_roadmap',
    description: 'Access and process learning roadmaps',
    schema: {
      'type': 'object',
      'properties': {
        'roadmapType': {'type': 'string', 'description': 'Type of roadmap to fetch'},
        'action': {'type': 'string', 'description': 'Action to perform (fetch, search, etc.)'}
      },
      'required': ['roadmapType']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final roadmapType = input['roadmapType'] as String;
      final action = input['action'] as String? ?? 'fetch';
      
      // Mock roadmap data - in real implementation, load from assets
      final roadmaps = {
        'ai-engineer': {
          'title': 'AI Engineer Roadmap',
          'description': 'Comprehensive path to becoming an AI Engineer',
          'topics': ['Machine Learning', 'Deep Learning', 'NLP', 'Computer Vision']
        },
        'backend': {
          'title': 'Backend Developer Roadmap',
          'description': 'Complete backend development learning path',
          'topics': ['APIs', 'Databases', 'Cloud Computing', 'DevOps']
        }
      };
      
      final roadmap = roadmaps[roadmapType];
      
      if (roadmap == null) {
        throw Exception('Roadmap type not found: $roadmapType');
      }
      
      return {
        'type': 'roadmap_data',
        'roadmapType': roadmapType,
        'action': action,
        'data': roadmap
      };
    } catch (e) {
      print('Browser roadmap tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'roadmapType': input['roadmapType']
      };
    }
  }
}

/// Image Search Tool
class ImageSearchTool extends Tool {
  final BraveSearchService _braveSearchService = BraveSearchService();

  ImageSearchTool() : super(
    name: 'image_search',
    description: 'Search for images using Brave Search',
    schema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Image search query'},
        'count': {'type': 'number', 'description': 'Number of images to return'}
      },
      'required': ['query']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final query = input['query'] as String;
      final count = input['count'] as int? ?? 5;
      
      print('🖼️ Image search tool: Searching for "$query" with count $count');
      final results = await _braveSearchService.searchImages(query, count: count);
      print('🖼️ Image search tool: Got ${results['images']?.length ?? 0} image results');
      
      final response = {
        'searchTerms': query,
        'images': results['images'] ?? [],
        'totalImages': results['images']?.length ?? 0,
        'timestamp': DateTime.now().toIso8601String()
      };
      
      print('🖼️ Image search tool: Returning ${response['totalImages']} images');
      print('🖼️ Image search tool: Response structure: ${response.keys.toList()}');
      
      return response;
    } catch (e) {
      print('Image search tool failed: $e');
      return {
        'error': "Image search failed",
        'message': e.toString(),
        'searchTerms': input['query'],
        'timestamp': DateTime.now().toIso8601String()
      };
    }
  }
}

/// Keyword Extraction Tool
class KeywordExtractionTool extends Tool {
  final OpenRouterClient _openRouterClient = OpenRouterClient();

  KeywordExtractionTool() : super(
    name: 'keyword_extraction',
    description: 'Extract keywords and key phrases from text',
    schema: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': 'Text to extract keywords from'},
        'maxKeywords': {'type': 'number', 'description': 'Maximum number of keywords to extract'}
      },
      'required': ['text']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final text = input['text'] as String;
      final maxKeywords = input['maxKeywords'] as int? ?? 10;
      
      final prompt = '''
Extract the most important keywords and key phrases from the following text. 
Return only the keywords separated by commas, no explanations.

Text: $text

Maximum keywords: $maxKeywords
''';

      final response = await _openRouterClient.createChatCompletion(
        model: 'google/gemini-2.0-flash-exp:free',
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        temperature: 0.1,
        maxTokens: 500,
      );

      // Handle the response structure correctly
      final responseData = response['response'] as Map<String, dynamic>?;
      if (responseData == null) {
        throw Exception('Invalid response structure from OpenRouter');
      }
      final choices = responseData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('No choices in response');
      }
      final content = choices[0]['message']['content'] as String?;
      if (content == null) {
        throw Exception('No content in response');
      }

      final keywords = content
          .split(',')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .take(maxKeywords)
          .toList();

      return {
        'type': 'keyword_extraction',
        'text': text,
        'keywords': keywords,
        'count': keywords.length
      };
    } catch (e) {
      print('Keyword extraction tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'text': input['text']
      };
    }
  }
}

/// Memory Tool
class MemoryTool extends Tool {
  MemoryTool() : super(
    name: 'memory_manager',
    description: 'Manage conversation memory and context',
    schema: {
      'type': 'object',
      'properties': {
        'action': {'type': 'string', 'description': 'Memory action (store, retrieve, clear)'},
        'key': {'type': 'string', 'description': 'Memory key'},
        'value': {'type': 'string', 'description': 'Value to store'}
      },
      'required': ['action']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final action = input['action'] as String;
      final key = input['key'] as String?;
      final value = input['value'] as String?;
      
      // Mock memory implementation
      // In real app, this would use local storage or database
      switch (action) {
        case 'store':
          if (key == null || value == null) {
            throw Exception('Key and value required for store action');
          }
          return {
            'type': 'memory_store',
            'action': action,
            'key': key,
            'stored': true
          };
          
        case 'retrieve':
          if (key == null) {
            throw Exception('Key required for retrieve action');
          }
          return {
            'type': 'memory_retrieve',
            'action': action,
            'key': key,
            'value': 'Mock retrieved value for $key'
          };
          
        case 'clear':
          return {
            'type': 'memory_clear',
            'action': action,
            'cleared': true
          };
          
        default:
          throw Exception('Unknown memory action: $action');
      }
    } catch (e) {
      print('Memory tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'action': input['action']
      };
    }
  }
}

/// Sequential Thinking Tool
class SequentialThinkingTool extends Tool {
  final OpenRouterClient _openRouterClient = OpenRouterClient();

  SequentialThinkingTool() : super(
    name: 'sequential_thinking',
    description: 'Break down complex problems into sequential steps',
    schema: {
      'type': 'object',
      'properties': {
        'problem': {'type': 'string', 'description': 'Problem to analyze'},
        'steps': {'type': 'number', 'description': 'Number of steps to break down into'}
      },
      'required': ['problem']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final problem = input['problem'] as String;
      final steps = input['steps'] as int? ?? 5;
      
      final prompt = '''
Analyze the following problem and break it down into $steps sequential steps:

Problem: $problem

Provide a structured analysis with:
1. Problem understanding
2. Step-by-step breakdown
3. Key considerations for each step
4. Expected outcomes

Format your response as JSON with the following structure:
{
  "problem": "original problem",
  "understanding": "problem analysis",
  "steps": [
    {
      "step": 1,
      "title": "Step title",
      "description": "Step description",
      "considerations": ["consideration1", "consideration2"],
      "expectedOutcome": "What this step should achieve"
    }
  ],
  "summary": "Overall approach summary"
}
''';

      final response = await _openRouterClient.createChatCompletion(
        model: 'google/gemini-2.0-flash-exp:free',
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        temperature: 0.3,
        maxTokens: 2000,
      );

      Map<String, dynamic> result;
      try {
        result = json.decode(response['choices'][0]['message']['content']);
      } catch (e) {
        result = {
          'problem': problem,
          'understanding': 'Analysis failed to parse',
          'steps': [],
          'summary': response['choices'][0]['message']['content']
        };
      }

      return {
        'type': 'sequential_analysis',
        'problem': problem,
        'analysis': result
      };
    } catch (e) {
      print('Sequential thinking tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'problem': input['problem']
      };
    }
  }
}

/// Source Content Tool
class SourceContentTool extends Tool {
  SourceContentTool() : super(
    name: 'source_content',
    description: 'Extract content from specific sources',
    schema: {
      'type': 'object',
      'properties': {
        'sourceId': {'type': 'string', 'description': 'Source ID to extract from'},
        'extractType': {'type': 'string', 'description': 'Type of content to extract'}
      },
      'required': ['sourceId']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final sourceId = input['sourceId'] as String;
      final extractType = input['extractType'] as String? ?? 'full';
      
      // Mock source content extraction
      return {
        'type': 'source_content',
        'sourceId': sourceId,
        'extractType': extractType,
        'content': 'Mock extracted content from source $sourceId',
        'length': 150,
        'hasContent': true
      };
    } catch (e) {
      print('Source content tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'sourceId': input['sourceId']
      };
    }
  }
}

/// Source Query Tool
class SourceQueryTool extends Tool {
  SourceQueryTool() : super(
    name: 'source_query',
    description: 'Query and search through stored sources',
    schema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Search query'},
        'sourceIds': {'type': 'array', 'description': 'Specific source IDs to search'}
      },
      'required': ['query']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final query = input['query'] as String;
      final sourceIds = input['sourceIds'] as List<String>?;
      
      // Mock source query implementation
      return {
        'type': 'source_query_results',
        'query': query,
        'results': [
          {
            'id': 'mock-source-1',
            'title': 'Mock Source 1',
            'url': 'https://example.com/1',
            'relevance': 0.85
          }
        ],
        'count': 1
      };
    } catch (e) {
      print('Source query tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'query': input['query']
      };
    }
  }
}

/// Time Tool
class TimeTool extends Tool {
  TimeTool() : super(
    name: 'time_tool',
    description: 'Get current time and date information',
    schema: {
      'type': 'object',
      'properties': {
        'format': {'type': 'string', 'description': 'Time format (iso, readable, timestamp)'}
      }
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final format = input['format'] as String? ?? 'iso';
      final now = DateTime.now();
      
      String formattedTime;
      switch (format) {
        case 'iso':
          formattedTime = now.toIso8601String();
          break;
        case 'readable':
          formattedTime = now.toString();
          break;
        case 'timestamp':
          formattedTime = now.millisecondsSinceEpoch.toString();
          break;
        default:
          formattedTime = now.toIso8601String();
      }
      
      return {
        'type': 'time_info',
        'format': format,
        'time': formattedTime,
        'timestamp': now.millisecondsSinceEpoch,
        'timezone': now.timeZoneName
      };
    } catch (e) {
      print('Time tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString()
      };
    }
  }
}

/// Tool interface for Flutter implementation
abstract class Tool {
  final String name;
  final String description;
  final Map<String, dynamic>? schema;

  const Tool({
    required this.name,
    required this.description,
    this.schema,
  });

  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input);
}

/// Tools collection and management
class ToolsManager {
  static final ToolsManager _instance = ToolsManager._internal();
  // All available tools
  final List<Tool> allTools = [
    BraveSearchTool(),
    BraveSearchEnhancedTool(),
    SequentialThinkingTool(),
    WebFetchTool(),
    YouTubeTool(),
    BrowserRoadmapTool(),
    ImageSearchTool(),
    KeywordExtractionTool(),
    MemoryTool(),
    SourceQueryTool(),
    SourceContentTool(),
    TimeTool(),
  ];
  // Core tools for basic functionality
  final List<Tool> coreTools = [
    BraveSearchTool(),
    BraveSearchEnhancedTool(),
    SequentialThinkingTool(),
    WebFetchTool(),
    YouTubeTool(),
    BrowserRoadmapTool(),
    ImageSearchTool(),
    KeywordExtractionTool(),
    MemoryTool(),
    SourceQueryTool(),
    SourceContentTool(),
    TimeTool(),
  ];

  factory ToolsManager() => _instance;

  ToolsManager._internal();

  /// Get all available tool names
  List<String> getAvailableToolNames() {
    return allTools.map((tool) => tool.name).toList();
  }

  /// Get core tool names
  List<String> getCoreToolNames() {
    return coreTools.map((tool) => tool.name).toList();
  }

  /// Get tool by name
  Tool? getToolByName(String name) {
    try {
      return allTools.firstWhere((tool) => tool.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get tools by name
  List<Tool> getToolsByName(List<String> toolNames) {
    final toolMap = <String, Tool>{};
    for (final tool in allTools) {
      toolMap[tool.name] = tool;
    }

    return toolNames
        .where((name) => toolMap.containsKey(name))
        .map((name) => toolMap[name]!)
        .toList();
  }

  /// Validate tools
  List<Map<String, dynamic>> validateTools() {
    final results = <Map<String, dynamic>>[];
    
    for (final tool in allTools) {
      try {
        if (tool.name.isEmpty || tool.description.isEmpty) {
          throw Exception('Tool missing required properties');
        }
        results.add({
          'name': tool.name,
          'status': 'valid'
        });
      } catch (e) {
        print('Tool validation failed: ${tool.name} - $e');
        results.add({
          'name': tool.name,
          'status': 'invalid',
          'error': e.toString()
        });
      }
    }

    final validCount = results.where((r) => r['status'] == 'valid').length;
    print('Tool validation complete. Valid tools: $validCount/${results.length}');
    
    return results;
  }
}

/// Web Fetch Tool
class WebFetchTool extends Tool {
  final ContentExtractor _contentExtractor = ContentExtractor();

  WebFetchTool() : super(
    name: 'web_fetch',
    description: 'Fetch and extract content from web URLs',
    schema: {
      'type': 'object',
      'properties': {
        'url': {'type': 'string', 'description': 'URL to fetch'},
        'extractText': {'type': 'boolean', 'description': 'Extract text content'}
      },
      'required': ['url']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final url = input['url'] as String;
      final extractText = input['extractText'] as bool? ?? true;
      
      final content = await _contentExtractor.extractContent(url);
      
      return {
        'type': 'web_content',
        'url': url,
        'content': extractText ? content : null,
        'contentLength': content.length,
        'hasContent': content.isNotEmpty
      };
    } catch (e) {
      print('Web fetch tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'url': input['url']
      };
    }
  }
}

/// YouTube Tool
class YouTubeTool extends Tool {
  YouTubeTool() : super(
    name: 'youtube_processor',
    description: 'Process YouTube URLs and extract video information',
    schema: {
      'type': 'object',
      'properties': {
        'url': {'type': 'string', 'description': 'YouTube URL'},
        'extractTranscript': {'type': 'boolean', 'description': 'Extract video transcript'}
      },
      'required': ['url']
    }
  );

  @override
  Future<Map<String, dynamic>> invoke(Map<String, dynamic> input) async {
    try {
      final url = input['url'] as String;
      final extractTranscript = input['extractTranscript'] as bool? ?? false;
      
      // Basic YouTube URL processing
      final videoId = _extractVideoId(url);
      
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }
      
      return {
        'type': 'youtube_video',
        'url': url,
        'videoId': videoId,
        'thumbnail': 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
        'embedUrl': 'https://www.youtube.com/embed/$videoId',
        'extractTranscript': extractTranscript,
        'note': 'Transcript extraction not implemented in Flutter version'
      };
    } catch (e) {
      print('YouTube tool failed: $e');
      return {
        'type': 'error',
        'error': e.toString(),
        'url': input['url']
      };
    }
  }

  String? _extractVideoId(String url) {
    final regex = RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}

// Export tools for easy access 