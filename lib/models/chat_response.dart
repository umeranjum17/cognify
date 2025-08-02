import 'chat_source.dart';

class ChatResponse {
  final String? id;
  final String? message;
  final List<dynamic>? choices;
  final double? cost;
  final String? conversationId;
  final List<ChatSource>? sources;
  final List<String>? followUpQuestions;
  // NEW FIELDS:
  final String? llmUsed;           // "local-ollama" or "openrouter"
  final String? model;             // actual model name (e.g., "phi3:mini")
  final Map<String, dynamic>? toolResults; // tool execution results

  // Enhanced cost tracking
  final double? messageCost;       // Cost for this specific message
  final double? sessionCost;       // Cumulative session cost
  final Map<String, dynamic>? costBreakdown; // Detailed cost breakdown

  // Generation tracking for accurate cost calculation
  final String? sessionId;         // Session ID for cost tracking
  final List<Map<String, dynamic>>? generationIds; // OpenRouter generation IDs for accurate cost calculation

  // Agent system fields
  final String? type;              // 'status', 'content', 'complete', 'error'
  final String? content;           // Response content
  final Map<String, dynamic>? metadata; // Additional metadata

  ChatResponse({
    this.id,
    this.message,
    this.choices,
    this.cost,
    this.conversationId,
    this.sources,
    this.followUpQuestions,
    this.llmUsed,
    this.model,
    this.toolResults,
    this.messageCost,
    this.sessionCost,
    this.costBreakdown,
    this.sessionId,
    this.generationIds,
    this.type,
    this.content,
    this.metadata,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
        id: json['id'],
        message: json['message'],
        choices: json['choices'],
        cost: json['cost']?.toDouble(),
        conversationId: json['conversationId'],
        sources: json['sources'] != null
            ? (json['sources'] as List)
                .map((source) => ChatSource.fromJson(source))
                .toList()
            : null,
        followUpQuestions: json['followUpQuestions'] != null
            ? List<String>.from(json['followUpQuestions'])
            : null,
        llmUsed: json['llmUsed'],
        model: json['model'],
        toolResults: json['toolResults'] as Map<String, dynamic>?,
        messageCost: json['messageCost']?.toDouble(),
        sessionCost: json['sessionCost']?.toDouble(),
        costBreakdown: json['costBreakdown'] as Map<String, dynamic>?,
        sessionId: json['sessionId'],
        generationIds: json['generationIds'] != null
            ? List<Map<String, dynamic>>.from(json['generationIds'])
            : null,
        type: json['type'],
        content: json['content'],
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (message != null) 'message': message,
        if (choices != null) 'choices': choices,
        if (cost != null) 'cost': cost,
        if (conversationId != null) 'conversationId': conversationId,
        if (sources != null) 'sources': sources!.map((s) => s.toJson()).toList(),
        if (followUpQuestions != null) 'followUpQuestions': followUpQuestions,
        if (llmUsed != null) 'llmUsed': llmUsed,
        if (model != null) 'model': model,
        if (toolResults != null) 'toolResults': toolResults,
        if (messageCost != null) 'messageCost': messageCost,
        if (sessionCost != null) 'sessionCost': sessionCost,
        if (costBreakdown != null) 'costBreakdown': costBreakdown,
        if (sessionId != null) 'sessionId': sessionId,
        if (generationIds != null) 'generationIds': generationIds,
        if (type != null) 'type': type,
        if (content != null) 'content': content,
        if (metadata != null) 'metadata': metadata,
      };
}


