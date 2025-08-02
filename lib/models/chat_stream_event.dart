import 'chat_source.dart';

/// Unified stream event model for consistent processing across all services
class ChatStreamEvent {
  final StreamEventType type;
  final String? message;
  final String? content;
  final List<ChatSource>? sources;
  final List<Map<String, dynamic>>? images;
  final Map<String, dynamic>? metadata;
  final String? conversationId;
  final String? model;
  final String? llmUsed;
  final bool done;
  final String? error;

  const ChatStreamEvent({
    required this.type,
    this.message,
    this.content,
    this.sources,
    this.images,
    this.metadata,
    this.conversationId,
    this.model,
    this.llmUsed,
    this.done = false,
    this.error,
  });

  /// Create a complete event
  factory ChatStreamEvent.complete({
    required String message,
    List<ChatSource>? sources,
    List<Map<String, dynamic>>? images,
    Map<String, dynamic>? costData,
    List<Map<String, dynamic>>? generationIds,
    String? conversationId,
    String? model,
    String? llmUsed,
  }) {
    return ChatStreamEvent(
      type: StreamEventType.complete,
      message: message,
      sources: sources,
      images: images,
      conversationId: conversationId,
      model: model,
      llmUsed: llmUsed,
      metadata: {
        'cost': costData,
        'generationIds': generationIds,
      },
      done: true,
    );
  }

  /// Create a content event
  factory ChatStreamEvent.content({
    required String content,
    List<ChatSource>? sources,
    List<Map<String, dynamic>>? images,
    String? conversationId,
    String? model,
    String? llmUsed,
  }) {
    return ChatStreamEvent(
      type: StreamEventType.content,
      content: content,
      sources: sources,
      images: images,
      conversationId: conversationId,
      model: model,
      llmUsed: llmUsed,
    );
  }

  /// Create an error event
  factory ChatStreamEvent.error({
    required String error,
    String? conversationId,
    String? model,
    String? llmUsed,
  }) {
    return ChatStreamEvent(
      type: StreamEventType.error,
      error: error,
      conversationId: conversationId,
      model: model,
      llmUsed: llmUsed,
      done: true,
    );
  }

  /// Create from Map format (for backward compatibility)
  factory ChatStreamEvent.fromMap(Map<String, dynamic> map) {
    final type = StreamEventType.values.firstWhere(
      (t) => t.name == map['type'] || t.name == map['event'],
      orElse: () => StreamEventType.content,
    );

    return ChatStreamEvent(
      type: type,
      message: map['message'],
      content: map['content'],
      sources: map['sources'] != null 
        ? (map['sources'] as List).map((s) => ChatSource.fromJson(s)).toList()
        : null,
      images: map['images'] != null 
        ? List<Map<String, dynamic>>.from(map['images'])
        : null,
      metadata: map['metadata'] != null 
        ? Map<String, dynamic>.from(map['metadata'])
        : null,
      conversationId: map['conversationId'],
      model: map['model'],
      llmUsed: map['llmUsed'],
      done: map['done'] ?? false,
      error: map['error'],
    );
  }

  /// Create a milestone event
  factory ChatStreamEvent.milestone({
    required String message,
    required String phase,
    double? progress,
    String? conversationId,
    String? model,
    String? llmUsed,
  }) {
    return ChatStreamEvent(
      type: StreamEventType.milestone,
      message: message,
      conversationId: conversationId,
      model: model,
      llmUsed: llmUsed,
      metadata: {
        'phase': phase,
        'progress': progress,
      },
    );
  }

  /// Create a sources ready event
  factory ChatStreamEvent.sourcesReady({
    required List<ChatSource> sources,
    List<Map<String, dynamic>>? images,
    String? conversationId,
    String? model,
    String? llmUsed,
  }) {
    return ChatStreamEvent(
      type: StreamEventType.sourcesReady,
      sources: sources,
      images: images,
      conversationId: conversationId,
      model: model,
      llmUsed: llmUsed,
      metadata: {
        'sourceCount': sources.length,
        'imageCount': images?.length ?? 0,
      },
    );
  }

  /// Create a status event
  factory ChatStreamEvent.status({
    required String message,
    String? conversationId,
    String? model,
    String? llmUsed,
    Map<String, dynamic>? metadata,
  }) {
    return ChatStreamEvent(
      type: StreamEventType.status,
      message: message,
      conversationId: conversationId,
      model: model,
      llmUsed: llmUsed,
      metadata: metadata,
    );
  }

  /// Convert to Map format for compatibility with existing code
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type.name,
      'done': done,
    };

    if (message != null) map['message'] = message;
    if (content != null) map['content'] = content;
    if (sources != null) map['sources'] = sources!.map((s) => s.toJson()).toList();
    if (images != null) map['images'] = images;
    if (metadata != null) map.addAll(metadata!);
    if (conversationId != null) map['conversationId'] = conversationId;
    if (model != null) map['model'] = model;
    if (llmUsed != null) map['llmUsed'] = llmUsed;
    if (error != null) map['error'] = error;

    // Add legacy event field for compatibility
    map['event'] = type.name;

    return map;
  }

  @override
  String toString() {
    return 'ChatStreamEvent(type: $type, message: $message, content: ${content?.substring(0, content!.length.clamp(0, 50))}..., done: $done)';
  }
}

/// Unified stream event types for consistent processing across all services
enum StreamEventType {
  // Status events
  status,
  milestone,
  progress,
  
  // Content events
  content,
  sourcesReady,
  imagesReady,
  
  // Completion events
  complete,
  error,
  
  // Tool events
  toolProgress,
  toolResult,
  
  // Cost tracking
  costUpdate,
} 