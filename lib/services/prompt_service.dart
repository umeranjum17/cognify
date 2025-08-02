import '../database/database_service.dart';


/// Template-based prompt management and optimization service
class PromptService {
  static final PromptService _instance = PromptService._internal();
  // Built-in prompt templates
  static const Map<String, Map<String, dynamic>> _builtInTemplates = {
    'chat': {
      'name': 'General Chat',
      'template': '''You are a helpful AI assistant. Respond to the user's question or request in a clear, informative, and friendly manner.

User: {user_input}''',
      'variables': ['user_input'],
      'category': 'general',
    },
    'summarize': {
      'name': 'Content Summarization',
      'template': '''Please provide a comprehensive summary of the following content. Include:

1. Main points and key takeaways
2. Important details and supporting information
3. Any conclusions or recommendations

Content to summarize:
{content}

Summary:''',
      'variables': ['content'],
      'category': 'analysis',
    },
    'analyze': {
      'name': 'Content Analysis',
      'template': '''Analyze the following content and provide insights on:

1. Key themes and topics
2. Important entities (people, organizations, technologies)
3. Relationships and connections
4. Potential implications or significance

Content to analyze:
{content}

Analysis:''',
      'variables': ['content'],
      'category': 'analysis',
    },
  };
  final DatabaseService _db = DatabaseService();

  bool _initialized = false;
  factory PromptService() => _instance;
  
  PromptService._internal();

  /// Build a prompt from a template with variables
  String buildPrompt(String templateId, Map<String, String> variables) {
    final template = getTemplate(templateId);
    if (template == null) {
      throw ArgumentError('Template not found: $templateId');
    }

    String prompt = template['template'] as String;
    
    // Replace variables in the template
    for (final entry in variables.entries) {
      prompt = prompt.replaceAll('{${entry.key}}', entry.value);
    }
    
    return prompt;
  }

  /// Create a chat message structure for LLM
  List<Map<String, dynamic>> createChatMessages({
    String? systemPrompt,
    required String userMessage,
    List<Map<String, dynamic>>? conversationHistory,
  }) {
    final messages = <Map<String, dynamic>>[];
    
    // Add system prompt if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }
    
    // Add conversation history if provided
    if (conversationHistory != null) {
      messages.addAll(conversationHistory);
    }
    
    // Add current user message
    messages.add({
      'role': 'user',
      'content': userMessage,
    });
    
    return messages;
  }

  /// Get all available templates
  Map<String, Map<String, dynamic>> getAllTemplates() {
    return Map.from(_builtInTemplates);
  }

  /// Get a prompt template by ID
  Map<String, dynamic>? getTemplate(String templateId) {
    return _builtInTemplates[templateId];
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _db.initialize();
    _initialized = true;
    
    print('📝 PromptService initialized');
  }

}
