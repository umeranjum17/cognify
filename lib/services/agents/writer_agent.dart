import 'dart:convert';
import 'dart:math' as math;

import '../../models/chat_stream_event.dart';
import '../../models/message.dart';
import '../../models/tool_result.dart';
import '../../utils/json_utils.dart';
import '../../utils/logger.dart';
import '../openrouter_client.dart';

/// Writer Agent - Creates final responses from tool results
class WriterAgent {
  final String modelName;
  final String mode;
  late OpenRouterClient _openRouterClient;

  WriterAgent({
    required this.modelName,
    this.mode = 'chat',
  }) {
    _openRouterClient = OpenRouterClient();
  }

  /// Create message input for vision models
  Future<Map<String, dynamic>> createMessageInput(
    String prompt,
    List<Map<String, dynamic>> attachments,
  ) async {
    print('🔍 DEBUG: createMessageInput called with ${attachments.length} attachments');
    if (attachments.isNotEmpty) {
      for (int i = 0; i < attachments.length; i++) {
        final att = attachments[i];
        print('🔍 DEBUG: Attachment $i:');
        print('  - type: ${att['type']}');
        print('  - name: ${att['name']}');
        print('  - mimeType: ${att['mimeType']}');
        print('  - has base64Data: ${att['base64Data'] != null}');
        if (att['base64Data'] != null) {
          final base64 = att['base64Data'] as String;
          print('  - base64 length: ${base64.length}');
        }
      }
    }
    
    if (attachments.isEmpty) {
      print('🔍 DEBUG: No attachments, returning simple text message');
      return {'role': 'user', 'content': prompt};
    }

    // For vision models, include image data
    final content = <Map<String, dynamic>>[];
    
    // Add text content
    content.add({'type': 'text', 'text': prompt});
    
    // Add image and file content
    for (final attachment in attachments) {
      if (attachment['type'] == 'image' && attachment['base64Data'] != null) {
        content.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:${attachment['mimeType']};base64,${attachment['base64Data']}'
          }
        });
      } else if (attachment['type'] == 'pdf' && attachment['base64Data'] != null) {
        // Attach PDF using OpenRouter-compatible 'file' part
        final mime = (attachment['mimeType'] as String?) ?? 'application/pdf';
        content.add({
          'type': 'file',
          'file': {
            'filename': attachment['name'] ?? 'document.pdf',
            'file_data': 'data:$mime;base64,${attachment['base64Data']}',
          }
        });
        print('🔍 DEBUG: Added PDF attachment (file part): ${attachment['name']}');
      } else if ((attachment['type'] == 'file' || attachment['type'] == 'document') && attachment['base64Data'] != null) {
        // Attach generic documents (doc, docx, etc.) using 'file' part
        final mime = (attachment['mimeType'] as String?) ?? 'application/octet-stream';
        content.add({
          'type': 'file',
          'file': {
            'filename': attachment['name'] ?? 'document',
            'file_data': 'data:$mime;base64,${attachment['base64Data']}',
          }
        });
        print('🔍 DEBUG: Added file attachment (file part): ${attachment['name']}');
      } else if (attachment['type'] == 'text' && attachment['base64Data'] != null) {
        // Add text file content directly
        try {
          final bytes = base64Decode(attachment['base64Data']);
          final textContent = utf8.decode(bytes);
          content.add({
            'type': 'text',
            'text': '--- Content of ${attachment['name']} ---\n$textContent\n--- End of ${attachment['name']} ---'
          });
          print('🔍 DEBUG: Added text attachment: ${attachment['name']}');
        } catch (e) {
          print('⚠️ DEBUG: Failed to decode text attachment: $e');
        }
      }
    }

    return {'role': 'user', 'content': content};
  }

  /// Create writing prompt
  String createWritingPrompt(
    String originalQuery,
    List<ToolResult> toolResults,
    String mode,
    bool isIncognitoMode,
    String personality,
    String language,
    List<Message> conversationHistory,
    List<Map<String, dynamic>> attachments,
  ) {
    // Get pre-extracted images from executor agent
    final images = _getPreExtractedImages(toolResults);
    
    // Create rich tool summary using executor data (aligned with server-side)
    final toolSummary = _createRichToolSummary(toolResults);
    
    // Create sources section from web_fetch tool results
    final sourcesSection = _createSourcesSectionFromWebFetch(toolResults);

    // Create images section for markdown inclusion (aligned with server-side)
    String imagesSection = '';
    if (images.isNotEmpty) {
      
      for (final image in images) {
        
      }
      
      imagesSection = '''

**AVAILABLE IMAGES FOR MARKDOWN INCLUSION:**

''';
      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final imageUrl = image['url'] ?? '';
        final imageTitle = image['title'] ?? 'Image';
        
        
        
        // Include all images with valid URLs (no CORS filtering in disabled security mode)
        if (imageUrl.isNotEmpty) {
          imagesSection += '''
${i + 1}. **$imageTitle**
   MARKDOWN: ![$imageTitle]($imageUrl)
   DESCRIPTION: ${image['description'] ?? 'No description'}
   CONTEXT: ${image['source'] ?? 'Unknown source'}

''';
        } else {
          
        }
      }
    }

    // Enhanced prompt for DeepSearch mode with chain-of-thought reasoning (aligned with server-side)
    final isDeepSearchMode = mode == 'deepsearch';
    String reasoningSection = '';
    if (isDeepSearchMode) {
      reasoningSection = '''

**🧠 DEEPSEARCH MODE - ADVANCED REASONING REQUIRED:**

Before writing your response, engage in systematic chain-of-thought reasoning:

1. **ANALYSIS PHASE**:
   - What are the key aspects of this query?
   - What patterns emerge from the tool results?
   - What are the most important insights to highlight?

2. **SYNTHESIS PHASE**:
   - How do the different sources complement each other?
   - What contradictions or gaps exist in the information?
   - What deeper insights can be drawn from the combined data?

3. **VALIDATION PHASE**:
   - Are the conclusions well-supported by evidence?
   - What assumptions am I making?
   - How confident am I in different aspects of the response?

4. **REFLECTION PHASE**:
   - Does this response fully address the user's needs?
   - What additional context would be valuable?
   - How can I make this response more comprehensive and actionable?

5. **VISUALIZATION PHASE**:
   - Would a Mermaid diagram help explain complex concepts?
   - Are there system architectures, flows, or processes that need visual representation?
   - Can I create diagrams for: workflows, data flows, system designs, user journeys, or technical processes?

**DEEPSEARCH QUALITY STANDARDS:**
- Provide 4x more depth than standard responses with comprehensive analysis
- Include multiple perspectives and nuanced analysis with detailed explanations
- Cross-reference information across sources for validation and synthesis
- Offer strategic insights beyond basic facts with actionable recommendations
- Address potential follow-up questions proactively with thorough coverage
- Leverage enhanced visual content and images to enrich explanations
- **CREATE MERMAID DIAGRAMS** for technical concepts, architectures, and complex processes
- Provide extensive detail, examples, and comprehensive coverage of all aspects
''';
    }

    // Get personality and language instructions
    final personalityInstruction = _getPersonalityInstructions(personality);
    final languageInstruction = _getLanguageInstructions(language);

    // Process user attachments (images, files)
    String attachmentContext = '';
    if (attachments.isNotEmpty) {
      attachmentContext = '''\n\n**USER ATTACHMENTS:**\n''';
      
      int imageCount = 0;
      int fileCount = 0;
      
      for (final attachment in attachments) {
        final type = attachment['type'] as String?;
        final name = attachment['name'] as String?;
        final mimeType = attachment['mimeType'] as String?;
        
        if (type == 'image') {
          imageCount++;
          attachmentContext += '''\n🖼️ **Image ${imageCount}: $name**
   - Type: $mimeType
   - Description: User has provided an image for analysis
   - IMPORTANT: This image is directly visible to you. Analyze and describe what you see in detail.
''';
        } else if (type == 'text' || type == 'file') {
          fileCount++;
          attachmentContext += '''\n📄 **File ${fileCount}: $name**
   - Type: $mimeType
   - Description: User has provided a file attachment
''';
        }
      }
      
      if (imageCount > 0) {
        attachmentContext += '''\n\n⚠️ **IMPORTANT INSTRUCTIONS FOR ATTACHED IMAGES:**
1. You can see the user's attached images directly in this conversation
2. Analyze each image thoroughly and describe what you observe
3. Reference specific details, colors, text, objects, people, or any visual elements you see
4. If the user asks about the image(s), provide detailed analysis based on what you can see
5. Do NOT say you cannot see images - you have vision capabilities
6. Integrate your image analysis naturally into your response
''';
      }
    }

    // Create conversation context section (aligned with server-side)
    String conversationContext = '';
    if (conversationHistory.isNotEmpty) {
      conversationContext = '''

**CONVERSATION CONTEXT:**
${conversationHistory.map((msg) {
  final content = msg.content is String ? msg.content : msg.content.toString();
  return '${msg.role.toUpperCase()}: $content';
}).join('\n')}

**CONTEXT ANALYSIS:**
- Consider the conversation flow and previous topics discussed
- If the current query is related to previous messages, build upon that context
- If the query is completely off-topic, treat it as a new conversation thread
- Use context to better understand vague or ambiguous queries
- Provide responses that acknowledge and connect to the conversation history when relevant
''';
    }

    // Define response guidelines section
    const responseGuidelines = '''**RESPONSE EXCELLENCE GUIDELINES:**

🎯 **CONTENT QUALITY:**
1. **PRIORITIZE SCRAPED CONTENT**: Use the "SCRAPED CONTENT" from sources above - this contains the most current, detailed information
2. **EXTRACT SPECIFIC DETAILS**: For version queries, extract COMPLETE version numbers. For comparisons, provide specific metrics. For tutorials, give concrete steps.
3. **NO GENERIC ADVICE**: Never say "check the source" or "visit the website" - extract and present the actual information
4. **BE COMPREHENSIVE**: Provide thorough answers that fully address the query

📝 **FORMATTING & STRUCTURE:**
5. **USE RICH FORMATTING**: Use **bold**, *italics*, bullet points, numbered lists, and code blocks appropriately
6. **ADD ENGAGING EMOJIS**: Use relevant emojis to make the response more engaging (🎉, 🚀, ⚡, 🔧, 📊, etc.)
7. **STRUCTURE CLEARLY**: Use headers, sections, and logical flow. Break up long text into digestible chunks
8. **HIGHLIGHT KEY INFO**: Make important information stand out with formatting

🖼️ **IMAGE INTEGRATION:**
9. **SMART IMAGE INCLUSION**: Include images from the "AVAILABLE IMAGES" section when they:
   - Directly illustrate concepts being explained (diagrams, architectures, interfaces)
   - Show the person/product/place being discussed (portraits, screenshots, landmarks)
   - Provide visual examples that enhance understanding (tutorials, comparisons)
   - Are central to the topic (when discussing visual design, UI/UX, etc.)
10. **IMAGE PLACEMENT**: Place images strategically within your response where they add most value
11. **IMAGE CONTEXT**: Briefly introduce images with context (e.g., "Here's the current Next.js architecture:")
12. **AVOID DECORATIVE IMAGES**: Don't include images that are purely decorative or don't add meaningful value
13. **USE DIRECT URLS**: Use the provided markdown format with direct image URLs (no proxy needed)

🎨 **RESPONSE STYLE:**
14. **CONVERSATIONAL TONE**: Write in a friendly, approachable manner while being professional
15. **ACTIONABLE INSIGHTS**: Provide practical, actionable information the user can immediately use
16. **CONTEXT AWARENESS**: Tailor the response style to the query type (technical for dev questions, explanatory for concepts)
17. **COMPLETE ANSWERS**: Ensure the response fully satisfies the user's information need

📊 **MERMAID DIAGRAMS (DeepSearch Mode Only):**
18. **SMART USAGE**: Only create Mermaid diagrams for technical concepts like DDD, Hexagonal architecture, SQS/SNS/PUBSUB, event-driven systems, microservices, system flows, etc. Do NOT create diagrams for people ("who is John Cena"), places, entertainment, or general topics - use images for those instead.
19. **STYLING**: Use classy colors like dark greys, blacks, and subtle professional accents. Keep the design clean and modern.
20. **SYNTAX**: Always wrap in ```mermaid code blocks with proper Mermaid syntax.

📊 **QUERY-SPECIFIC GUIDELINES:**
- **Version Queries**: Extract exact version numbers, release dates, and key features
- **Comparisons**: Provide structured comparisons with pros/cons, use cases, and recommendations
- **How-to Guides**: Give step-by-step instructions with code examples where relevant
- **Best Practices**: List specific, actionable recommendations with explanations
- **Troubleshooting**: Provide clear solutions with explanations of why they work
- **News/Updates**: Focus on latest information with dates and specific details

**RESPONSE FORMAT:**
- Start with a direct answer to the query
- Provide detailed information based on tool results
- Include relevant examples or specifics when available
- Use markdown formatting for better readability

🚫 **CRITICAL: DO NOT INCLUDE SOURCES IN YOUR RESPONSE**
- DO NOT add a "Sources:" section at the end of your response
- DO NOT list source URLs, titles, or links in your response text
- Sources are displayed separately in the UI cards below your response
- Focus ONLY on the content and information, not the sources themselves

Write your response now:''';

    // Log prompt length breakdown
    _logPromptLengthBreakdown(
      personalityInstruction: personalityInstruction,
      originalQuery: originalQuery,
      mode: mode,
      isIncognitoMode: isIncognitoMode,
      personality: personality,
      language: language,
      languageInstruction: languageInstruction,
      attachmentContext: attachmentContext,
      conversationContext: conversationContext,
      toolSummary: toolSummary,
      sourcesSection: sourcesSection,
      imagesSection: imagesSection,
      reasoningSection: reasoningSection,
      responseGuidelines: responseGuidelines,
    );

    return '''$personalityInstruction

**USER QUERY:** "$originalQuery"
**MODE:** $mode${isDeepSearchMode ? ' (ULTRA-COMPREHENSIVE ANALYSIS)' : ''}
**INCOGNITO:** ${isIncognitoMode ? 'ON' : 'OFF'}
${personality != 'Default' ? '**PERSONALITY:** $personality' : ''}
${language != 'English' ? '**LANGUAGE:** $language - $languageInstruction' : ''}$attachmentContext$conversationContext

**TOOL RESULTS:**
$toolSummary

$sourcesSection

$imagesSection
$reasoningSection

$responseGuidelines''';
  }

  Future<void> initialize() async {
    try {
      

      // Calculate max tokens based on mode - use conservative limits
      int maxTokens;
      if (mode == 'deepsearch') {
        maxTokens = 50000;
      } else {
        // Use conservative limits for chat mode
        maxTokens = 3000; // Increased from 2500 for better responses
      }

      // Log streaming configuration
      
      

      
    } catch (error) {
      print('❌ Writer Agent initialization failed: $error');
      rethrow;
    }
  }

  /// Write response without streaming
  Future<Map<String, dynamic>> writeResponse({
    required String originalQuery,
    required List<ToolResult> toolResults,
    required String mode,
    bool isIncognitoMode = false,
    List<String> selectedSourceIds = const [],
    String personality = 'Default',
    String language = 'English',
    List<Message> conversationHistory = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      

      // Debug: Log image information
      final images = _getPreExtractedImages(toolResults);
      
      if (images.isNotEmpty) {
        
      }

      final writingPrompt = createWritingPrompt(
        originalQuery,
        toolResults,
        mode,
        isIncognitoMode,
        personality,
        language,
        conversationHistory,
        attachments,
      );

      final estimatedTokens = (writingPrompt.length / 4).round();
      
      

      final messageInput = await createMessageInput(writingPrompt, attachments);
      
      // Debug: Log the message structure being sent
      print('🐛 DEBUG: Message being sent to API:');
      print('🐛 DEBUG: Message role: ${messageInput['role']}');
      if (messageInput['content'] is String) {
        print('🐛 DEBUG: Content is String, length: ${(messageInput['content'] as String).length}');
      } else if (messageInput['content'] is List) {
        final contentList = messageInput['content'] as List;
        print('🐛 DEBUG: Content is List with ${contentList.length} items:');
        for (int i = 0; i < contentList.length; i++) {
          final item = contentList[i] as Map<String, dynamic>;
          print('🐛 DEBUG:   Item $i type: ${item['type']}');
          if (item['type'] == 'text') {
            final text = item['text'] as String?;
            print('🐛 DEBUG:     Text length: ${text?.length ?? 0}');
          } else if (item['type'] == 'image_url') {
            final imageUrl = item['image_url'] as Map<String, dynamic>?;
            final url = imageUrl?['url'] as String?;
            if (url != null && url.startsWith('data:')) {
              final mimeType = url.substring(5, url.indexOf(';'));
              print('🐛 DEBUG:     Image MIME type: $mimeType');
              print('🐛 DEBUG:     Base64 data present: YES');
            }
          }
        }
      }

      
      
      // Calculate max tokens based on mode (aligned with server-side)
      int maxTokens;
      if (mode == 'deepsearch') {
        maxTokens = 50000; // 20x for deepsearch - 4x more powerful (server-side: 50000)
      } else {
        maxTokens = 2500; // Aligned with server-side default
      }
      
      
      final response = await _openRouterClient.createChatCompletion(
        model: modelName,
        messages: [messageInput],
        temperature: 0.8,
        maxTokens: maxTokens,
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
        print('🔗 Writer generation ID: $generationId');
      }
      if (usage != null) {
        
      }

      // Log actual token usage comparison
      _logActualTokenUsage(usage, estimatedTokens);

      // Debug: Check if response includes images when they should
      if (images.isNotEmpty) {
        final hasImagesInResponse = content.contains('![') && content.contains('](');
        
        if (hasImagesInResponse) {
          // Find all image markdown in the response
          final imageMatches = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').allMatches(content);
          
          for (final match in imageMatches) {
            print('🖼️ Writer Agent: Image markdown: ![${match.group(1)}](${match.group(2)})');
          }
        } else {
          
          
          for (final image in images) {
            print('🖼️ Writer Agent: - ${image['title']}: ${image['url']}');
          }
        }
      }

      
      

      return {
        'content': content,
        'generationId': generationId,
        'usage': usage,
        'model': modelName,
        'stage': 'writing',
      };

    } catch (error) {
      print('❌ Writer Agent failed: $error');
      return {
        'content': 'I apologize, but I encountered an error while generating the response. Please try again.',
        'generationId': null,
        'usage': null,
        'model': modelName,
        'stage': 'writing',
      };
    }
  }

  /// Write response and return data (no streaming - for orchestration)
  Future<Map<String, dynamic>> writeResponseData({
    required String originalQuery,
    required List<ToolResult> toolResults,
    required String mode,
    bool isIncognitoMode = false,
    List<String> selectedSourceIds = const [],
    String personality = 'Default',
    String language = 'English',
    List<Message> conversationHistory = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      

      // Debug: Log image information
      final images = _getPreExtractedImages(toolResults);
      
      if (images.isNotEmpty) {
        
      }

      final writingPrompt = createWritingPrompt(
        originalQuery,
        toolResults,
        mode,
        isIncognitoMode,
        personality,
        language,
        conversationHistory,
        attachments,
      );

      final estimatedTokens = (writingPrompt.length / 4).round();
      
      

      final messageInput = await createMessageInput(writingPrompt, attachments);
      
      // Debug: Log the message structure being sent
      print('🐛 DEBUG: Message being sent to API:');
      print('🐛 DEBUG: Message role: ${messageInput['role']}');
      if (messageInput['content'] is String) {
        print('🐛 DEBUG: Content is String, length: ${(messageInput['content'] as String).length}');
      } else if (messageInput['content'] is List) {
        final contentList = messageInput['content'] as List;
        print('🐛 DEBUG: Content is List with ${contentList.length} items:');
        for (int i = 0; i < contentList.length; i++) {
          final item = contentList[i] as Map<String, dynamic>;
          print('🐛 DEBUG:   Item $i type: ${item['type']}');
          if (item['type'] == 'text') {
            final text = item['text'] as String?;
            print('🐛 DEBUG:     Text length: ${text?.length ?? 0}');
          } else if (item['type'] == 'image_url') {
            final imageUrl = item['image_url'] as Map<String, dynamic>?;
            final url = imageUrl?['url'] as String?;
            if (url != null && url.startsWith('data:')) {
              final mimeType = url.substring(5, url.indexOf(';'));
              print('🐛 DEBUG:     Image MIME type: $mimeType');
              print('🐛 DEBUG:     Base64 data present: YES');
            }
          }
        }
      }

      // Calculate max tokens based on mode
      int maxTokens;
      if (mode == 'deepsearch') {
        maxTokens = 50000;
      } else {
        maxTokens = 2500;
      }
      
      
      
      
      
      // Get response without streaming
      final response = await _openRouterClient.createChatCompletion(
        model: modelName,
        messages: [messageInput],
        temperature: 0.8,
        maxTokens: maxTokens,
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
        print('🔗 Writer generation ID: $generationId');
      }
      if (usage != null) {
        
      }

      // Log actual token usage comparison
      _logActualTokenUsage(usage, estimatedTokens);

      // Debug: Check if response includes images when they should
      if (images.isNotEmpty) {
        final hasImagesInResponse = content.contains('![') && content.contains('](');
        
        if (hasImagesInResponse) {
          // Find all image markdown in the response
          final imageMatches = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').allMatches(content);
          
          for (final match in imageMatches) {
            print('🖼️ Writer Agent: Image markdown: ![${match.group(1)}](${match.group(2)})');
          }
        } else {
          
          
          for (final image in images) {
            print('🖼️ Writer Agent: - ${image['title']}: ${image['url']}');
          }
        }
      }

      
      

      return {
        'content': content,
        'generationId': generationId,
        'usage': usage,
        'model': modelName,
        'stage': 'writing',
        'images': images,
      };

    } catch (error) {
      print('❌ Writer Agent failed: $error');
      return {
        'content': 'I apologize, but I encountered an error while generating the response. Please try again.',
        'generationId': null,
        'usage': null,
        'model': modelName,
        'stage': 'writing',
        'error': error.toString(),
      };
    }
  }

  /// Write response using streaming with unified events
  Stream<ChatStreamEvent> writeResponseStream({
    required String originalQuery,
    required List<ToolResult> toolResults,
    required String mode,
    bool isIncognitoMode = false,
    List<String> selectedSourceIds = const [],
    String personality = 'Default',
    String language = 'English',
    List<Message> conversationHistory = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async* {
    print('🐛 DEBUG: WriterAgent.writeResponseStream starting');
    print('🔍 DEBUG: Received ${attachments.length} attachments in writeResponseStream');
    for (int i = 0; i < attachments.length; i++) {
      final att = attachments[i];
      print('🔍 DEBUG: writeResponseStream Attachment $i: type=${att['type']}, name=${att['name']}');
    }
    try {
      

      // Debug: Log image information
      final images = _getPreExtractedImages(toolResults);
      
      if (images.isNotEmpty) {
        
      }

      final writingPrompt = createWritingPrompt(
        originalQuery,
        toolResults,
        mode,
        isIncognitoMode,
        personality,
        language,
        conversationHistory,
        attachments,
      );

      final estimatedTokens = (writingPrompt.length / 4).round();
      
      

      final messageInput = await createMessageInput(writingPrompt, attachments);
      
      // Debug: Log the message structure being sent
      print('🐛 DEBUG: Message being sent to API:');
      print('🐛 DEBUG: Message role: ${messageInput['role']}');
      if (messageInput['content'] is String) {
        print('🐛 DEBUG: Content is String, length: ${(messageInput['content'] as String).length}');
      } else if (messageInput['content'] is List) {
        final contentList = messageInput['content'] as List;
        print('🐛 DEBUG: Content is List with ${contentList.length} items:');
        for (int i = 0; i < contentList.length; i++) {
          final item = contentList[i] as Map<String, dynamic>;
          print('🐛 DEBUG:   Item $i type: ${item['type']}');
          if (item['type'] == 'text') {
            final text = item['text'] as String?;
            print('🐛 DEBUG:     Text length: ${text?.length ?? 0}');
          } else if (item['type'] == 'image_url') {
            final imageUrl = item['image_url'] as Map<String, dynamic>?;
            final url = imageUrl?['url'] as String?;
            if (url != null && url.startsWith('data:')) {
              final mimeType = url.substring(5, url.indexOf(';'));
              print('🐛 DEBUG:     Image MIME type: $mimeType');
              print('🐛 DEBUG:     Base64 data present: YES');
            }
          }
        }
      }

      // Stream the response
      String fullResponse = '';
      
      
      // Calculate max tokens based on mode (aligned with server-side)
      int maxTokens;
      if (mode == 'deepsearch') {
        maxTokens = 50000; // 20x for deepsearch - 4x more powerful (server-side: 50000)
      } else {
        maxTokens = 2500; // Aligned with server-side default
      }
      
      
      
      
      
      // Track generation ID and usage from streaming response (aligned with server-side)
      String? generationId;
      Map<String, dynamic>? usage;
      bool foundChunkUsage = false;
      int chunkCount = 0;
      
      print('🐛 DEBUG: WriterAgent about to start streaming from OpenRouter with model: $modelName');
      await for (final chunk in _openRouterClient.createChatCompletionStream(
        model: modelName,
        messages: [messageInput],
        temperature: 0.8,
        maxTokens: maxTokens,
      )) {
        chunkCount++;
        
        // Extract generation ID and usage from streaming response (aligned with server-side)
        if (!foundChunkUsage && chunk.containsKey('generationId')) {
          generationId = chunk['generationId'] as String?;
          usage = chunk['usage'] as Map<String, dynamic>?;
          foundChunkUsage = true;
        }
        
        // Check for errors FIRST before checking done status
        if (chunk.containsKey('error')) {
          print('❌ Streaming error: ${chunk['error']}');
          print('🐛 DEBUG: WriterAgent detected error chunk, about to yield ChatStreamEvent.error');
          yield ChatStreamEvent.error(
            error: chunk['error'] as String? ?? 'Unknown streaming error',
            model: modelName,
            llmUsed: 'writer-agent',
          );
          break;
        }
        // Handle content chunks
        else if (chunk.containsKey('content') && chunk['content'].isNotEmpty) {
          final content = chunk['content'] as String;
          fullResponse += content;
          
          yield ChatStreamEvent.content(
            content: content,
            model: modelName,
            llmUsed: 'writer-agent',
          );
        } else if (chunk.containsKey('done') && chunk['done'] == true) {
          // Log actual token usage comparison for streaming
          _logActualTokenUsage(usage, estimatedTokens);
          
          
          
          
          // Emit final metadata if not already emitted
          if (generationId != null || usage != null) {
            
            yield ChatStreamEvent.complete(
              message: fullResponse,
              costData: usage,
              generationIds: generationId != null ? [{'id': generationId, 'stage': 'writing', 'model': modelName}] : null,
              model: modelName,
              llmUsed: 'writer-agent',
            );
          } else {
            
            yield ChatStreamEvent.complete(
              message: fullResponse,
              costData: null,
              generationIds: null,
              model: modelName,
              llmUsed: 'writer-agent',
            );
          }
          break;
        }
      }

      // Debug: Check if response includes images when they should
      if (images.isNotEmpty) {
        final hasImagesInResponse = fullResponse.contains('![') && fullResponse.contains('](');
        if (!hasImagesInResponse) {
          
        }
      }

    } catch (error) {
      print('❌ Writer Agent failed: $error');
      print('🐛 DEBUG: WriterAgent catch block, about to yield ChatStreamEvent.error');
      yield ChatStreamEvent.error(
        error: 'I apologize, but I encountered an error while generating the response. Please try again.',
        model: modelName,
        llmUsed: 'writer-agent',
      );
    }
  }

  /// Create conversation context (legacy method - kept for compatibility)
  String _createConversationContext(List<Message> conversationHistory) {
    if (conversationHistory.isEmpty) {
      return '';
    }

    final recentMessages = conversationHistory.take(5).toList();
    final context = recentMessages.map((msg) {
      final role = msg.role == 'user' ? 'User' : 'Assistant';
      return '$role: ${msg.content}';
    }).join('\n');

    return '''
Recent Conversation Context:
$context

''';
  }

  /// Create results summary with enhanced content extraction (legacy method - kept for compatibility)
  String _createResultsSummary(List<ToolResult> toolResults) {
    return _createRichToolSummary(toolResults);
  }

  /// Create rich tool summary using executor data (aligned with server-side)
  String _createRichToolSummary(List<ToolResult> toolResults) {
    if (toolResults.isEmpty) {
      return 'No tool results available';
    }

    final successfulResults = toolResults.where((r) => !r.failed).toList();
    final failedResults = toolResults.where((r) => r.failed).toList();
    
    // Create rich tool summary using executor data and plan context (aligned with server-side)
    String toolSummary = '';
    if (successfulResults.isNotEmpty) {
      toolSummary = successfulResults.map((result) {
        // Get execution time if available
        final executionTime = result.executionTime ?? 0;
        
        String summary = '**${result.tool}** (${executionTime}ms): No reason provided\n';

        // Create tool-specific rich summaries based on executor data (aligned with server-side)
        if (result.tool == 'brave_search_enhanced' || result.tool == 'brave_search') {
          final output = result.output as Map<String, dynamic>?;
          if (output != null) {
            final results = output['results'] as List<dynamic>? ?? [];
            final resultsCount = results.length;
            summary += '   📊 Found $resultsCount search results\n';
            
            final searchQuery = output['searchTerms'] as String?;
            if (searchQuery != null) {
              summary += '   🔍 Query: "$searchQuery"\n';
            }
            
            if (resultsCount > 0) {
              final topResult = results[0] as Map<String, dynamic>?;
              if (topResult != null) {
                final title = topResult['title'] as String? ?? 'No title';
                final url = topResult['url'] as String? ?? '';
                summary += '   🎯 Top result: "$title" ($url)\n';
              }
            }
          }
        } else if (result.tool == 'image_search') {
          final output = result.output as Map<String, dynamic>?;
          if (output != null) {
            final images = output['images'] as List<dynamic>? ?? [];
            final imageCount = images.length;
            summary += '   🖼️ Found $imageCount images\n';
            
            final searchQuery = output['searchQuery'] as String?;
            if (searchQuery != null) {
              summary += '   🔍 Query: "$searchQuery"\n';
            }
            
            if (imageCount > 0) {
              final firstImage = images[0] as Map<String, dynamic>?;
              if (firstImage != null) {
                final title = firstImage['title'] as String? ?? 'Untitled image';
                summary += '   📸 Sample: $title\n';
              }
            }
          }
        } else if (result.tool == 'source_content' || result.tool == 'source_query') {
          final output = result.output as Map<String, dynamic>?;
          if (output != null) {
            final results = output['results'] as List<dynamic>? ?? [];
            final resultsCount = results.length;
            summary += '   📚 Found $resultsCount source results\n';
            
            if (resultsCount > 0) {
              int totalContent = 0;
              for (final r in results) {
                if (r is Map<String, dynamic>) {
                  final content = r['content'] as String?;
                  if (content != null) {
                    totalContent += content.length;
                  }
                }
              }
              summary += '   📄 Total content: $totalContent characters\n';
            }
          }
        } else if (result.tool == 'current_time') {
          final output = result.output as Map<String, dynamic>?;
          if (output != null) {
            final currentTime = output['currentTime'] as String? ?? (output['content'] as String?) ?? 'Time retrieved';
            summary += '   🕐 Current time: $currentTime\n';
          }
        } else if (result.tool == 'web_fetch') {
          final output = result.output as Map<String, dynamic>?;
          if (output != null) {
            final results = output['results'] as List<dynamic>? ?? [];
            final resultsCount = results.length;
            summary += '   🌐 Fetched $resultsCount web pages\n';
            
            if (resultsCount > 0) {
              int totalContent = 0;
              for (final r in results) {
                if (r is Map<String, dynamic>) {
                  final content = r['content'] as String?;
                  if (content != null) {
                    totalContent += content.length;
                  }
                }
              }
              summary += '   📄 Total content: $totalContent characters\n';
              
              // Show first result title if available
              final firstResult = results[0] as Map<String, dynamic>?;
              if (firstResult != null) {
                final title = firstResult['title'] as String? ?? 'Untitled';
                summary += '   📰 Sample: $title\n';
              }
            }
          }
        } else {
          // Fallback for other tools - show structured content if available (aligned with server-side)
          final output = result.output;
          
          // Debug: Log tool that's causing massive output
          if (output['content'] != null) {
            final content = output['content'] as String?;
            if (content != null && content.length > 1000) {
              print('⚠️ WARNING: Tool "${result.tool}" has massive content: ${content.length} chars');
              print('⚠️ First 200 chars: ${content.substring(0, 200)}...');
            }
          }
          
          if (output['content'] != null) {
            final content = output['content'] as String?;
            if (content != null) {
              // Limit content to prevent massive tool summaries
              final limitedContent = content.length > 500 ? '${content.substring(0, 500)}... (truncated ${content.length - 500} chars)' : content;
              summary += '   📄 $limitedContent\n';
            }
          } else if (output is String) {
            final content = output as String;
            // Limit content to prevent massive tool summaries
            final limitedContent = content.length > 500 ? '${content.substring(0, 500)}... (truncated ${content.length - 500} chars)' : content;
            summary += '   📄 $limitedContent\n';
          } else {
            final outputStr = output.toString();
            // Limit content to prevent massive tool summaries
            final limitedContent = outputStr.length > 500 ? '${outputStr.substring(0, 500)}... (truncated ${outputStr.length - 500} chars)' : outputStr;
            summary += '   📄 $limitedContent\n';
          }
        }

        return summary;
      }).join('\n');
    }

    // Add execution summary (aligned with server-side)
    if (toolResults.isNotEmpty) {
      final totalTools = toolResults.length;
      final successCount = successfulResults.length;
      final failedCount = failedResults.length;
      
      toolSummary += '\n**EXECUTION SUMMARY:**\n';
      toolSummary += '✅ $successCount/$totalTools tools succeeded';
      if (failedCount > 0) {
        toolSummary += ', ❌ $failedCount failed';
      }
      toolSummary += '\n';
    }
    
    // Debug: Log tool summary length
    if (toolSummary.length > 10000) {
      print('⚠️ WARNING: Tool summary is very large: ${toolSummary.length} chars');
      print('⚠️ This may indicate a tool is dumping massive content');
    }
    
    return toolSummary;
  }

  /// Create sources section from web_fetch tool results with randomized content extraction
  String _createSourcesSectionFromWebFetch(List<ToolResult> toolResults) {
    // Extract all web_fetch results
    final webFetchResults = toolResults.where((result) => 
      result.tool == 'web_fetch' && !result.failed
    ).toList();
    
    if (webFetchResults.isEmpty) {
      return '';
    }
    
    
    
    String sourcesSection = '''

**SOURCES WITH SCRAPED CONTENT:**

''';
    
    for (int i = 0; i < webFetchResults.length; i++) {
      final result = webFetchResults[i];
      final output = result.output as Map<String, dynamic>?;
      
      if (output == null) continue;
      
      
      
      // Handle both single page and multiple page results
      List<Map<String, dynamic>> pages = [];
      
      if (output.containsKey('results')) {
        // Multiple pages structure
        final results = output['results'] as List<dynamic>? ?? [];
        
        
        for (final page in results) {
          if (page is Map<String, dynamic>) {
            pages.add(page);
          }
        }
      } else {
        // Single page structure (direct content)
        
        pages.add(output);
      }
      
      for (int j = 0; j < pages.length; j++) {
        final page = pages[j];
        
        final title = page['title'] as String? ?? 'Untitled';
        final url = page['url'] as String? ?? '';
        final content = page['content'] as String? ?? '';
        
        if (content.isEmpty) continue;
        
        Logger.debugOnly('Processing page $j: "$title" ($url) - ${content.length} chars');
        
        sourcesSection += '''
${i + 1}.${j + 1}. **$title**
   URL: $url
''';
        
        // Randomly select a preview length between 5000 and 15000, but not exceeding content length
        final contentLength = content.length;
        final random = DateTime.now().microsecondsSinceEpoch % 10000 + 5000; // pseudo-random, deterministic per run
        final previewLength = (random > contentLength) ? contentLength : random;
        
        
        
        // Add assertions to catch issues
        assert(previewLength > 0, 'Preview length must be positive');
        assert(previewLength <= contentLength, 'Preview length cannot exceed content length');
        
        final preview = content.substring(0, previewLength);
        final hasMore = previewLength < contentLength;
        
        sourcesSection += '''   📄 SCRAPED CONTENT: $contentLength characters available
   📖 PREVIEW: $preview${hasMore ? '...' : ''}
''';
        
        sourcesSection += '''
''';
      }
    }
    
    return sourcesSection;
  }

  /// Get language instructions
  String _getLanguageInstructions(String language) {
    if (language == 'English') {
      return '';
    }

    final languageInstructions = {
      'Urdu': 'IMPORTANT: Respond in Urdu language. Use proper Urdu grammar, vocabulary, and sentence structure.',
      'Arabic': 'IMPORTANT: Respond in Arabic language. Use proper Arabic grammar, vocabulary, and sentence structure.',
      'French': 'IMPORTANT: Respond in French language. Use proper French grammar, vocabulary, and sentence structure.'
    };

    return languageInstructions[language] ?? '';
  }





  /// Get personality instructions
  String _getPersonalityInstructions(String personality) {
    final personalities = {
      'Default': 'You are a helpful, professional AI assistant. Provide clear, accurate, and well-structured responses.',
      'Comedian': 'You are a witty, humorous AI assistant. Use jokes, funny analogies, and light-hearted commentary while still providing accurate information. Keep it clever and entertaining, but never at the expense of accuracy.',
      'Macho Cool': 'You are a confident, direct AI assistant with a cool, no-nonsense attitude. Use confident language, be straight to the point, and maintain a "been there, done that" vibe. Keep it professional but with swagger.',
      'Friendly Helper': 'You are a warm, encouraging, and supportive AI assistant. Use friendly language, offer encouragement, and maintain an upbeat, positive tone. Make the user feel supported and valued.',
      'Professional Expert': 'You are a formal, highly knowledgeable AI assistant. Use precise, business-like language, provide detailed analysis, and maintain a professional, authoritative tone throughout your responses.'
    };

    return personalities[personality] ?? personalities['Default']!;
  }

  /// Get pre-extracted images from executor agent (no fallback processing)
  List<Map<String, dynamic>> _getPreExtractedImages(List<ToolResult> toolResults) {
    final images = <Map<String, dynamic>>[];

    // Only use pre-extracted images from executor agent
    for (final result in toolResults) {
      if (result.failed) continue;

      final rawOutput = result.output;
      final output = JsonUtils.safeStringKeyMap(rawOutput);
      if (output == null) continue;

      // Use pre-extracted images from executor agent
      if (output['extractedImages'] != null && output['extractedImages'] is List) {
        final extractedImages = output['extractedImages'] as List<dynamic>;
        Logger.debugOnly('Writer Agent: Using ${extractedImages.length} pre-extracted images from executor');

        for (final item in extractedImages) {
          if (item is Map<String, dynamic>) {
            images.add(item);
          }
        }
        break; // Only process the first result with extracted images
      }
    }

            Logger.debugOnly('Writer Agent: Total images available: ${images.length}');
    return images;
  }

  /// Log actual token usage and compare with estimates
  void _logActualTokenUsage(Map<String, dynamic>? usage, int estimatedTokens) {
    if (usage == null) {
      
      return;
    }

    final promptTokens = usage['prompt_tokens'] as int? ?? 0;
    final completionTokens = usage['completion_tokens'] as int? ?? 0;
    final totalTokens = usage['total_tokens'] as int? ?? 0;
    
    final accuracy = estimatedTokens > 0 ? ((promptTokens - estimatedTokens).abs() / estimatedTokens * 100) : 0.0;
    final accuracyEmoji = accuracy < 10 ? '🎯' : accuracy < 25 ? '📊' : '⚠️';
    
    print('\n${'=' * 60}');
    
    print('=' * 60);
    
    
    
    
    print('$accuracyEmoji Estimation accuracy: ${accuracy.toStringAsFixed(1)}% ${accuracy < 10 ? '(Excellent)' : accuracy < 25 ? '(Good)' : '(Needs improvement)'}');
    
    if (accuracy > 25) {
      print('\n💡 ESTIMATION IMPROVEMENT SUGGESTIONS:');
      print('   • Review prompt length calculation method');
      print('   • Consider tokenization differences between models');
      print('   • Check for special characters or formatting that affect token count');
    }
    print('=' * 60);
  }

  /// Analyze and log prompt length breakdown in a fancy table format
  void _logPromptLengthBreakdown({
    required String personalityInstruction,
    required String originalQuery,
    required String mode,
    required bool isIncognitoMode,
    required String personality,
    required String language,
    required String languageInstruction,
    required String attachmentContext,
    required String conversationContext,
    required String toolSummary,
    required String sourcesSection,
    required String imagesSection,
    required String reasoningSection,
    required String responseGuidelines,
  }) {
    final sections = [
      {'name': 'Personality Instruction', 'content': personalityInstruction},
      {'name': 'User Query', 'content': originalQuery},
      {'name': 'Mode & Settings', 'content': 'MODE: $mode, INCOGNITO: ${isIncognitoMode ? 'ON' : 'OFF'}, PERSONALITY: $personality'},
      {'name': 'Language Instruction', 'content': languageInstruction},
      {'name': 'Attachment Context', 'content': attachmentContext},
      {'name': 'Conversation Context', 'content': conversationContext},
      {'name': 'Tool Summary', 'content': toolSummary},
      {'name': 'Sources Section', 'content': sourcesSection}, // From web_fetch tool results
      {'name': 'Images Section', 'content': imagesSection},
      {'name': 'Reasoning Section', 'content': reasoningSection},
      {'name': 'Response Guidelines', 'content': responseGuidelines},
    ];

    // Calculate lengths and percentages
    final totalLength = sections.fold<int>(0, (sum, section) => sum + section['content']!.length);
    final breakdown = sections.map((section) {
      final length = section['content']!.length;
      final percentage = totalLength > 0 ? (length / totalLength * 100) : 0.0;
      return {
        'name': section['name']!,
        'length': length,
        'percentage': percentage,
        'tokens': (length / 4).round(),
      };
    }).toList();

    // Sort by length descending
    breakdown.sort((a, b) => (b['length'] as int).compareTo(a['length'] as int));

          // Log debug information only in verbose mode
      Logger.debugOnly('Prompt breakdown analysis completed');
      Logger.debugOnly('Total prompt length: $totalLength chars (${(totalLength / 4).round()} estimated tokens)');
      
      if (Logger.shouldShowDebug) {
        // Only show detailed breakdown in verbose debug mode
        print('\n${'=' * 80}');
        print('=' * 80);
        print('${'Section'.padRight(25)} ${'Chars'.padRight(8)} ${'Tokens'.padRight(8)} ${'%'.padRight(6)} ${'Bar'}');
        print('-' * 80);

        for (final section in breakdown) {
          final name = section['name'] as String;
          final length = section['length'] as int;
          final tokens = section['tokens'] as int;
          final percentage = section['percentage'] as double;
          
          // Create visual bar (max 30 characters)
          final barLength = (percentage / 100 * 30).round();
          final bar = '█' * barLength + '░' * (30 - barLength);
          
          print('${name.padRight(25)} ${length.toString().padRight(8)} ${tokens.toString().padRight(8)} ${(percentage).toStringAsFixed(1).padRight(6)} $bar');
        }

        print('-' * 80);
        print('${'TOTAL'.padRight(25)} ${totalLength.toString().padRight(8)} ${(totalLength / 4).round().toString().padRight(8)} ${'100.0'.padRight(6)} ${'█' * 30}');
        print('=' * 80);

        // Highlight top consumers
        final topConsumers = breakdown.take(3).toList();
        print('\n🔥 TOP PROMPT CONSUMERS:');
        for (int i = 0; i < topConsumers.length; i++) {
          final consumer = topConsumers[i];
          final emoji = i == 0 ? '🥇' : i == 1 ? '🥈' : '🥉';
          print('$emoji ${consumer['name']}: ${consumer['length']} chars (${(consumer['percentage'] as double).toStringAsFixed(1)}%)');
        }

        // Token estimation
        final estimatedTokens = (totalLength / 4).round();
        print('\n💡 TOKEN ESTIMATION:');
        print('   📝 Estimated tokens: $estimatedTokens');
        print('   📊 Actual tokens (if available): Will be logged after API call');
        
        // Recommendations
        print('\n💭 OPTIMIZATION RECOMMENDATIONS:');
        if (estimatedTokens > 8000) {
          print('   ⚠️  High token usage detected! Consider:');
          print('      • Reducing conversation history length');
          print('      • Limiting number of sources processed');
          print('      • Shortening tool summaries');
        } else if (estimatedTokens > 4000) {
          print('   ⚡ Moderate token usage. Monitor for optimization opportunities.');
        } else {
          print('   ✅ Token usage is within reasonable limits.');
        }
        print('=' * 80 + '\n');
      }
  }

  /// Randomize content length between 7000-20000 characters and normalize text
  String _randomizeContent(String content) {
    if (content.length <= 7000) {
      return content; // Keep original if too short
    }
    
    final random = math.Random();
    final targetLength = random.nextInt(13001) + 7000; // 7000 to 20000
    
    if (content.length <= targetLength) {
      return content; // Keep original if target is longer than content
    }
    
    // Randomly choose to take from beginning or end
    final takeFromEnd = random.nextBool();
    
    String randomized;
    if (takeFromEnd) {
      // Take from the end
      randomized = content.substring(content.length - targetLength);
      
    } else {
      // Take from the beginning
      randomized = content.substring(0, targetLength);
      
    }
    
    // Remove punctuation and convert to lowercase
    final normalized = randomized
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove punctuation, keep words and spaces
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize multiple spaces to single space
        .trim();
    
    
    
    return normalized;
  }
} 