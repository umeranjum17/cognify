import 'dart:convert';
import 'dart:math' as math;

import '../../models/tool_spec.dart';
import '../../services/premium_feature_gate.dart';
import '../../utils/json_utils.dart';
import '../openrouter_client.dart';
import '../tools.dart';

/// Search Agent - Analyzes queries and creates tool execution plans
class SearchAgent {
  // Static caches for performance optimization
  static String? _toolDescriptionsCache;
  static final Map<String, dynamic> _modelCapabilitiesCache = {};
  final String modelName;
  
  final String mode;
  late OpenRouterClient _openRouterClient;

  SearchAgent({
    required this.modelName,
    this.mode = 'chat',
  }) {
    _openRouterClient = OpenRouterClient();
  }

  /// Create execution plan with sequential thinking
  Future<Map<String, dynamic>> createExecutionPlan({
    required String query,
    required List<String> enabledTools,
    required String mode,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? options,
    bool isEntitled = false,
  }) async {
    try {
      // Check if forceBasicPlan option is set - if so, return basic plan
      if (options != null && options['forceBasicPlan'] == true) {
        return _createBasicPlan(query, enabledTools, mode);
      }
      
      // Check if search agents are enabled - if not, return basic plan
      if (!FeatureAccess.isEnabled(isEntitled, 'search_agents')) {
        return _createBasicPlan(query, enabledTools, mode);
      }

      // Step 1: Perform sequential thinking analysis (only for DeepSearch mode)
      Map<String, dynamic>? thinkingResult;
      if (mode.toLowerCase() == 'deepsearch') {
        
        thinkingResult = await _performSequentialThinking(query, mode);
        
      } else {
        
      }

      final fileAttachments = processFileAttachments(attachments ?? []);
      final planningPrompt = createPlanningPrompt(query, fileAttachments, mode, enabledTools, thinkingResult);

      final response = await _openRouterClient.createChatCompletion(
        model: modelName,
        messages: [
          {'role': 'user', 'content': planningPrompt}
        ],
        temperature: 0.3,
        maxTokens: 2000,
      );

      // Handle the correct response structure from OpenRouter client
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

      // Extract generation ID and usage for cost tracking
      final generationId = response['generationId'] as String?;
      final usage = response['usage'] as Map<String, dynamic>?;
      
      if (generationId != null) {
        
      }
      if (usage != null) {
        
      }

      
      
      // Clean the response by removing markdown code blocks
      String cleanedContent = content.trim();
      if (cleanedContent.startsWith('```json')) {
        cleanedContent = cleanedContent.substring(7); // Remove ```json
      } else if (cleanedContent.startsWith('```')) {
        cleanedContent = cleanedContent.substring(3); // Remove ```
      }
      if (cleanedContent.endsWith('```')) {
        cleanedContent = cleanedContent.substring(0, cleanedContent.length - 3);
      }
      cleanedContent = cleanedContent.trim();
      
      
      
      // Parse the JSON response
      final jsonResponse = jsonDecode(cleanedContent);
      final tools = jsonResponse['tools'] as List<dynamic>?;
      
      if (tools != null) {
        
        for (final tool in tools) {
          
        }
      } else {
        
      }

      // Parse the response - handle both pure JSON and JSON wrapped in markdown
      String jsonContent = content.trim();

      // Remove markdown code blocks if present
      if (jsonContent.startsWith('```json')) {
        jsonContent = jsonContent.substring(7);
      }
      if (jsonContent.startsWith('```')) {
        jsonContent = jsonContent.substring(3);
      }
      if (jsonContent.endsWith('```')) {
        jsonContent = jsonContent.substring(0, jsonContent.length - 3);
      }

      jsonContent = jsonContent.trim();

      try {
        final rawPlan = jsonDecode(jsonContent);
        final plan = JsonUtils.safeStringKeyMap(rawPlan) ?? {};
        
        final toolSpecs = _parseExecutionPlan(plan);

        // Enhance tool specs with thinking results if available
        final enhancedToolSpecs = _enhanceToolSpecsWithThinking(toolSpecs, thinkingResult);

        // Return both tool specs and generation information
        return {
          'toolSpecs': enhancedToolSpecs,
          'generationId': generationId,
          'usage': usage,
          'model': modelName,
          'stage': 'planning',
          'thinkingResult': thinkingResult,
        };
      } catch (e) {
        print('Failed to parse planner response: $e');
        print('Attempting to extract JSON from response...');
        
        // Try to extract JSON from the response
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonContent);
        if (jsonMatch != null) {
          try {
            final extractedJson = jsonMatch.group(0)!;
            
            final plan = jsonDecode(extractedJson) as Map<String, dynamic>;
            final toolSpecs = _parseExecutionPlan(plan);

            // Enhance tool specs with thinking results if available
            final enhancedToolSpecs = _enhanceToolSpecsWithThinking(toolSpecs, thinkingResult);

            return {
              'toolSpecs': enhancedToolSpecs,
              'generationId': generationId,
              'usage': usage,
              'model': modelName,
              'stage': 'planning',
              'thinkingResult': thinkingResult,
            };
          } catch (e2) {
            print('Failed to extract JSON: $e2');
            throw Exception('Could not parse planner response: $e');
          }
        }
        
        throw Exception('Could not parse planner response: $e');
      }

    } catch (error) {
      print('❌ Failed to create execution plan: $error');
      final fallbackSpecs = _createFallbackPlan(query, enabledTools, mode);
      return {
        'toolSpecs': fallbackSpecs,
        'generationId': null,
        'usage': null,
        'model': modelName,
        'stage': 'planning',
      };
    }
  }

  /// Create planning prompt with sequential thinking integration
  String createPlanningPrompt(
    String query,
    Map<String, dynamic>? fileAttachments,
    String mode,
    List<String> enabledTools,
    Map<String, dynamic>? thinkingResult,
  ) {
    final toolDescriptions = generateToolDescriptions();
    final enabledToolsList = enabledTools.join(', ');
    final searchLimits = _getModeSearchLimits(mode);

    String fileContext = '';
    if (fileAttachments != null) {
      fileContext = '''
File Attachments:
${fileAttachments['summary']}
${fileAttachments['files'].map((f) => '- ${f['description']}').join('\n')}

''';
    }

    // Add sequential thinking context if available (DeepSearch mode only)
    String thinkingContext = '';
    if (thinkingResult != null && mode.toLowerCase() == 'deepsearch') {
      final searchStrategies = thinkingResult['search_strategies'] as List<dynamic>? ?? [];
      final keyConceptsList = (thinkingResult['key_concepts'] as List<dynamic>? ?? []).join(', ');

      thinkingContext = '''
**SEQUENTIAL THINKING ANALYSIS (DeepSearch Mode):**
Understanding: ${thinkingResult['understanding'] ?? 'Not provided'}
Key Concepts: $keyConceptsList
Complexity: ${thinkingResult['complexity'] ?? 'medium'}

**RECOMMENDED SEARCH STRATEGIES:**
${searchStrategies.map((strategy) => '- ${strategy['angle']}: ${strategy['description']} (Query: "${strategy['query']}", Priority: ${strategy['priority']})').join('\n')}

**STRATEGIC GUIDANCE:**
Use the above search strategies to create multiple targeted search calls instead of one broad search.
Each search should focus on a specific angle to provide comprehensive coverage.

''';
    }

    // Create mode-specific planning instructions
    final String planningInstructions = mode.toLowerCase() == 'deepsearch'
        ? '''Create a strategic execution plan that leverages the sequential thinking analysis above. Consider:
1. Use the recommended search strategies to create multiple focused search calls
2. Each search should target a specific aspect identified in the thinking analysis
3. Prioritize tools based on the complexity and information needs identified
4. Optimize search queries using the suggested terms from the thinking analysis'''
        : '''Create an efficient execution plan for fast response. Consider:
1. What information does the user need?
2. Which tools are most relevant?
3. What order should tools be executed in?
4. What parameters should be passed to each tool?''';

    return '''
You are a planning agent that creates ${mode.toLowerCase() == 'deepsearch' ? 'strategic' : 'efficient'} tool execution plans.

Available Tools:
$toolDescriptions

Enabled Tools: $enabledToolsList
Mode: $mode

User Query: $query
$fileContext$thinkingContext

$planningInstructions

**${mode.toLowerCase() == 'deepsearch' ? 'ENHANCED SEARCH STRATEGY GUIDELINES (DeepSearch Mode)' : 'SEARCH GUIDELINES (Chat Mode)'}:**
${mode.toLowerCase() == 'deepsearch'
  ? '''- Use the search strategies from the thinking analysis to create multiple targeted searches
- Instead of one broad search, create 2-3 focused searches with different angles
- Each search should use optimized query terms from the thinking analysis
- Prioritize high-priority search strategies first, then medium and low priority
- For people/celebrities: combine web search, image search, and specific biographical searches
- For complex topics: use brave_search_enhanced with different query angles
- For keyword analysis: use keyword_extraction after getting diverse search results'''
  : '''- For queries about people, celebrities, politicians, or public figures, consider using both web search AND image search
- For visual content needs, always include image_search tool
- For complex topics, use brave_search_enhanced for better search results
- For keyword analysis, use keyword_extraction after getting search results
- Keep the plan focused and efficient for fast responses'''}
- **ALWAYS use web_fetch for Wikipedia URLs (wikipedia.org) to get detailed content**
- **ALWAYS use web_fetch for any URLs found in search results to extract full content**

**MODE-SPECIFIC SEARCH LIMITS:**
- Chat mode: Use count=${searchLimits['maxResults']} for search tools (fast responses)
- DeepSearch mode: Use count=${searchLimits['maxResults']} for search tools (${searchLimits['maxResults']! ~/ 5}x more comprehensive)

${mode.toLowerCase() == 'deepsearch'
  ? '''**STRATEGIC SEARCH IMPLEMENTATION (DeepSearch Mode):**
When creating search tools, use the recommended search strategies above:
- Create separate search tool calls for each high/medium priority strategy
- Use the optimized query terms provided in each strategy
- Vary the search approaches (general web, enhanced search, image search, etc.)
- Maintain the same total number of tool calls but make them more strategic'''
  : '''**EFFICIENT SEARCH IMPLEMENTATION (Chat Mode):**
When creating search tools for fast responses:
- Use direct, focused search queries
- Prioritize the most relevant tools for the query
- Keep tool calls minimal but effective
- Focus on getting quick, accurate results'''}

Return your response as a JSON object with this exact structure:
{
  "analysis": "${mode.toLowerCase() == 'deepsearch' ? 'Brief analysis incorporating the sequential thinking insights' : 'Brief analysis of what the user wants'}",
  "tools": [
    {
      "name": "tool_name",
      "input": {
        "query": "${mode.toLowerCase() == 'deepsearch' ? 'optimized search terms from thinking analysis' : 'search query'}",
        "count": ${searchLimits['maxResults']} // REQUIRED for search tools
      },
      "order": 1,
      "reasoning": "${mode.toLowerCase() == 'deepsearch' ? 'Why this specific search angle is needed (reference thinking analysis)' : 'Why this tool is needed'}"
    }
  ],
  "estimatedSteps": 3,
  "complexity": "low|medium|high"${mode.toLowerCase() == 'deepsearch' ? ',\n  "thinking_integration": "How the plan leverages the sequential thinking analysis"' : ''}
}

**CRITICAL**:
${mode.toLowerCase() == 'deepsearch'
  ? '''- For search tools, use the optimized queries from the thinking analysis
- Create multiple focused searches instead of one broad search
- ALWAYS include "count": ${searchLimits['maxResults']} in search tool parameters
- Reference the thinking analysis in your reasoning for each tool'''
  : '''- For search tools (brave_search, brave_search_enhanced), ALWAYS include "count": ${searchLimits['maxResults']} in the input parameters
- Only use tools that are enabled
- Keep the plan focused and efficient for fast responses'''}
''';
  }

  /// Generate tool descriptions with caching
  String generateToolDescriptions() {
    if (_toolDescriptionsCache != null) {
      return _toolDescriptionsCache!;
    }

    try {
      final toolsManager = ToolsManager();
      final toolDescriptions = toolsManager.allTools.map((tool) {
        final name = tool.name;
        final description = tool.description;

        // Get schema information if available
        String schemaInfo = '';
        if (tool.schema != null && tool.schema!['properties'] != null) {
          final properties = (tool.schema!['properties'] as Map<String, dynamic>).keys.toList();
          if (properties.isNotEmpty) {
            schemaInfo = ' (Input: ${properties.join(', ')})';
          }
        }

        return '- $name: $description$schemaInfo';
      }).join('\n');

      _toolDescriptionsCache = toolDescriptions;
      
      return toolDescriptions;
    } catch (error) {
      
      // Fallback to basic tool list
      final toolsManager = ToolsManager();
      return toolsManager.allTools.map((tool) => '- ${tool.name}: ${tool.description}').join('\n');
    }
  }

  /// Process file attachments
  Map<String, dynamic>? processFileAttachments(List<Map<String, dynamic>> attachments) {
    if (attachments.isEmpty) {
      return null;
    }

    try {
      final processedFiles = attachments.map((attachment) {
        final id = attachment['id'] as String;
        final name = attachment['name'] as String;
        final type = attachment['type'] as String; // 'image', 'file', 'pdf', 'text'
        final base64Data = attachment['base64Data'] as String;
        final size = attachment['size'] as int;
        final mimeType = attachment['mimeType'] as String;

        // Process different file types
        Map<String, dynamic> fileContext = {
          'id': id,
          'name': name,
          'type': type,
          'mimeType': mimeType,
          'size': '${(size / 1024).round()}KB' // Convert to KB for readability
        };

        // Handle different file types appropriately
        switch (type) {
          case 'image':
            fileContext['description'] = 'Image file: $name';
            fileContext['content'] = '[Image: $name ($mimeType)]';
            fileContext['base64'] = base64Data;
            break;

          case 'text':
            try {
              // For text files, decode base64 to get actual text content
              final textContent = utf8.decode(base64.decode(base64Data));
              fileContext['description'] = 'Text file: $name';
              fileContext['content'] = textContent;
              fileContext['textLength'] = textContent.length;
            } catch (e) {
              fileContext['description'] = 'Text file: $name (failed to decode)';
              fileContext['content'] = '[Text file content could not be decoded]';
            }
            break;

          case 'pdf':
            fileContext['description'] = 'PDF file: $name';
            fileContext['content'] = '[PDF: $name ($mimeType)]';
            break;

          default:
            fileContext['description'] = 'File: $name';
            fileContext['content'] = '[File: $name ($mimeType)]';
        }

        return fileContext;
      }).toList();

      return {
        'type': 'file_attachments',
        'count': processedFiles.length,
        'files': processedFiles,
        'summary': '${processedFiles.length} file(s) attached to query'
      };
    } catch (error) {
      
      return null;
    }
  }

  /// Create basic plan when search agents are disabled
  Map<String, dynamic> _createBasicPlan(String query, List<String> enabledTools, String mode) {
    // When feature flag is disabled, return a basic plan with only non-search tools
    final basicSpecs = <ToolSpec>[];
    
    // Filter out search-related tools
    final allowedTools = enabledTools.where((tool) => !_isSearchTool(tool)).toList();
    
    return {
      'toolSpecs': basicSpecs,
      'generationId': null,
      'usage': null,
      'model': modelName,
      'stage': 'planning',
      'basicMode': true, // Flag to indicate this is a basic plan
    };
  }

  /// Check if a tool is search-related (to be filtered out when feature flag is disabled)
  bool _isSearchTool(String toolName) {
    const searchTools = {
      'brave_search',
      'brave_search_enhanced', 
      'web_fetch',
      'image_search',
      'youtube_processor',
      'sequential_thinking', // Also disable advanced thinking
    };
    return searchTools.contains(toolName);
  }

  /// Create fallback plan when planning fails
  List<ToolSpec> _createFallbackPlan(String query, List<String> enabledTools, [String mode = 'chat']) {
    

    final searchLimits = _getModeSearchLimits(mode);

    // Enhanced fallback: try to use thinking-based approach even in fallback (DeepSearch mode only)
    final fallbackSpecs = <ToolSpec>[];

    // Add sequential thinking if available and in DeepSearch mode
    if (enabledTools.contains('sequential_thinking') && mode.toLowerCase() == 'deepsearch') {
      fallbackSpecs.add(ToolSpec(
        name: 'sequential_thinking',
        input: {'problem': query, 'steps': 3},
        order: 1,
        reasoning: 'Fallback analysis of the query (DeepSearch mode)',
      ));
    }

    // Add search with enhanced query if available
    if (enabledTools.contains('brave_search_enhanced')) {
      fallbackSpecs.add(ToolSpec(
        name: 'brave_search_enhanced',
        input: {'query': query, 'count': searchLimits['maxResults']},
        order: 2,
        reasoning: 'Fallback enhanced search for query',
      ));
    } else if (enabledTools.contains('brave_search')) {
      fallbackSpecs.add(ToolSpec(
        name: 'brave_search',
        input: {'query': query, 'count': searchLimits['maxResults']},
        order: 2,
        reasoning: 'Fallback search for query',
      ));
    }

    return fallbackSpecs;
  }

  /// Create fallback thinking result when analysis fails
  Map<String, dynamic> _createFallbackThinking(String query, String mode) {
    return {
      'understanding': 'Search for information about: $query',
      'key_concepts': [query],
      'information_needs': ['general information', 'recent updates', 'detailed content'],
      'search_strategies': [
        {
          'angle': 'primary_focus',
          'description': 'Main search for the query',
          'query': query,
          'priority': 'high'
        }
      ],
      'recommended_tools': ['brave_search_enhanced'],
      'complexity': 'medium'
    };
  }

  /// Enhance tool specs with thinking results
  List<ToolSpec> _enhanceToolSpecsWithThinking(List<ToolSpec> toolSpecs, Map<String, dynamic>? thinkingResult) {
    if (thinkingResult == null) return toolSpecs;

    final searchStrategies = thinkingResult['search_strategies'] as List<dynamic>? ?? [];
    if (searchStrategies.isEmpty) return toolSpecs;

    // Create enhanced tool specs with optimized search queries
    final enhancedSpecs = <ToolSpec>[];
    int searchStrategyIndex = 0;

    for (final spec in toolSpecs) {
      if ((spec.name == 'brave_search' || spec.name == 'brave_search_enhanced') &&
          searchStrategyIndex < searchStrategies.length) {

        final strategy = searchStrategies[searchStrategyIndex] as Map<String, dynamic>;
        final optimizedQuery = strategy['query'] as String? ?? spec.input['query'] as String;
        final angle = strategy['angle'] as String? ?? 'search';

        // Create enhanced tool spec with optimized query
        enhancedSpecs.add(ToolSpec(
          name: spec.name,
          input: {
            ...spec.input,
            'query': optimizedQuery,
          },
          order: spec.order,
          reasoning: '${spec.reasoning} ($angle: ${strategy['description'] ?? 'optimized search'})',
        ));

        searchStrategyIndex++;
      } else {
        // Keep non-search tools as-is
        enhancedSpecs.add(spec);
      }
    }

    return enhancedSpecs;
  }

  /// Get mode-specific search limits
  Map<String, int> _getModeSearchLimits(String mode) {
    switch (mode.toLowerCase()) {
      case 'deepsearch':
        // With pagination we can safely target up to 40 combined results
        return {'maxResults': 50, 'maxScrape': 50};
      case 'chat':
      default:
        return {'maxResults': 10, 'maxScrape': 10};
    }
  }

  /// Helper to parse the execution plan from the JSON response
  List<ToolSpec> _parseExecutionPlan(Map<String, dynamic> plan) {
    final tools = plan['tools'] as List<dynamic>? ?? [];
    return tools.map((tool) {
      return ToolSpec(
        name: tool['name'] as String,
        input: tool['input'] as Map<String, dynamic>,
        order: tool['order'] as int,
        reasoning: tool['reasoning'] as String? ?? 'No reasoning provided',
      );
    }).toList();
  }

  /// Perform sequential thinking analysis on the query
  Future<Map<String, dynamic>> _performSequentialThinking(String query, String mode) async {
    try {
      final thinkingPrompt = '''
Analyze the following query using sequential thinking to create a comprehensive search strategy:

Query: "$query"
Mode: $mode

Break down your analysis into these steps:

1. **Understanding**: What is the user really asking for? What are the key concepts and entities?

2. **Information Needs**: What specific types of information would best answer this query?

3. **Search Angles**: What are 2-3 different search approaches that would provide complementary information?

4. **Query Optimization**: For each search angle, what would be the most effective search terms?

5. **Strategy**: What tools and sequence would be most effective?

Return your analysis as JSON with this structure:
{
  "understanding": "What the user wants",
  "key_concepts": ["concept1", "concept2", "concept3"],
  "information_needs": ["need1", "need2", "need3"],
  "search_strategies": [
    {
      "angle": "primary_focus",
      "description": "Main search approach",
      "query": "optimized search terms",
      "priority": "high"
    },
    {
      "angle": "complementary_info",
      "description": "Additional perspective",
      "query": "alternative search terms",
      "priority": "medium"
    },
    {
      "angle": "context_background",
      "description": "Background/context search",
      "query": "contextual search terms",
      "priority": "low"
    }
  ],
  "recommended_tools": ["tool1", "tool2"],
  "complexity": "low|medium|high"
}
''';

      final response = await _openRouterClient.createChatCompletion(
        model: modelName,
        messages: [
          {'role': 'user', 'content': thinkingPrompt}
        ],
        temperature: 0.4,
        maxTokens: 1500,
      );

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

      // Clean and parse the JSON response
      String cleanedContent = content.trim();
      if (cleanedContent.startsWith('```json')) {
        cleanedContent = cleanedContent.substring(7);
      } else if (cleanedContent.startsWith('```')) {
        cleanedContent = cleanedContent.substring(3);
      }
      if (cleanedContent.endsWith('```')) {
        cleanedContent = cleanedContent.substring(0, cleanedContent.length - 3);
      }
      cleanedContent = cleanedContent.trim();

      try {
        final thinkingResult = jsonDecode(cleanedContent) as Map<String, dynamic>;
        print('🧠 Sequential thinking analysis completed successfully');
        return thinkingResult;
      } catch (e) {
        print('Failed to parse thinking response: $e');
        // Return fallback thinking result
        return _createFallbackThinking(query, mode);
      }

    } catch (error) {
      print('❌ Sequential thinking failed: $error');
      return _createFallbackThinking(query, mode);
    }
  }
}