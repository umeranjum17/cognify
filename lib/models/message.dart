import 'chat_source.dart';

class Attachment {
  final String id;
  final String type; // 'pdf' | 'image' | 'text'
  final String name;
  final String? uri;
  final String? content;
  final int? size;
  final String? processedContent;
  final Map<String, dynamic>? metadata;

  Attachment({
    required this.id,
    required this.type,
    required this.name,
    this.uri,
    this.content,
    this.size,
    this.processedContent,
    this.metadata,
  });


  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] ?? '',
        type: json['type'] ?? 'text',
        name: json['name'] ?? '',
        uri: json['uri'],
        content: json['content'],
        size: json['size'],
        processedContent: json['processedContent'],
        metadata: json['metadata'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (uri != null) 'uri': uri,
        if (content != null) 'content': content,
        if (size != null) 'size': size,
        if (processedContent != null) 'processedContent': processedContent,
        if (metadata != null) 'metadata': metadata,
      };
}

class FileUrl {
  final String url;
  final String mediaType;

  FileUrl({required this.url, required this.mediaType});

  factory FileUrl.fromJson(Map<String, dynamic> json) => FileUrl(
        url: json['url'] ?? '',
        mediaType: json['media_type'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'media_type': mediaType,
      };
}

class ImageUrl {
  final String url;

  ImageUrl({required this.url});

  factory ImageUrl.fromJson(Map<String, dynamic> json) => ImageUrl(
        url: json['url'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'url': url,
      };
}

class Message {
  final String id;
  final String type; // 'user' | 'assistant' | 'system'
  final dynamic content; // String or List<MessageContent>
  final String timestamp;
  final bool? isProcessing;
  final List<Attachment>? attachments;
  final List<ChatSource>? sources;
  final List<String>? followUpQuestions;
  final List<String>? additionalFollowUpQuestions;
  final List<Map<String, dynamic>>? images;

  // Cost tracking fields
  final double? messageCost;
  final double? sessionCost;
  final Map<String, dynamic>? costBreakdown;

  Message({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.isProcessing,
    this.attachments,
    this.sources,
    this.followUpQuestions,
    this.additionalFollowUpQuestions,
    this.images,
    this.messageCost,
    this.sessionCost,
    this.costBreakdown,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] ?? '',
        type: json['type'] ?? json['role'] ?? 'user', // Support both 'type' and 'role'
        content: json['content'],
        timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
        isProcessing: json['isProcessing'],
        attachments: json['attachments'] != null
            ? (json['attachments'] as List)
                .map((a) => Attachment.fromJson(a))
                .toList()
            : null,
        sources: json['sources'] != null
            ? (json['sources'] as List)
                .map((s) => ChatSource.fromJson(s))
                .toList()
            : null,
        followUpQuestions: json['followUpQuestions'] != null
            ? List<String>.from(json['followUpQuestions'])
            : null,
        additionalFollowUpQuestions: json['additionalFollowUpQuestions'] != null
            ? List<String>.from(json['additionalFollowUpQuestions'])
            : null,
        images: json['images'] != null
            ? List<Map<String, dynamic>>.from(json['images'].map((img) => Map<String, dynamic>.from(img)))
            : null,
        messageCost: json['messageCost']?.toDouble(),
        sessionCost: json['sessionCost']?.toDouble(),
        costBreakdown: json['costBreakdown'] as Map<String, dynamic>?,
      );

  /// Check if message has any file attachments
  bool get hasFileAttachments =>
      (attachments != null && attachments!.isNotEmpty);

  // Legacy support for simple string content
  String get role => type == 'user' ? 'user' : 'assistant';

  String get textContent {
    if (content is String) {
      return content as String;
    } else if (content is List) {
      final List<String> textParts = [];
      for (final part in (content as List)) {
        if (part is Map && part['type'] == 'text') {
          final dynamic textVal = part['text'];
          if (textVal is String) {
            textParts.add(textVal);
          } else if (textVal is List) {
            // Handle nested text structures like lists of segments
            for (final seg in textVal) {
              if (seg is Map && seg['text'] is String) {
                textParts.add(seg['text'] as String);
              } else if (seg is String) {
                textParts.add(seg);
              }
            }
          } else if (textVal != null) {
            textParts.add(textVal.toString());
          }
        }
      }
      return textParts.join('\n');
    }
    return '';
  }


  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'role': role, // Include for API compatibility
        'content': content,
        'timestamp': timestamp,
        if (isProcessing != null) 'isProcessing': isProcessing,
        if (attachments != null)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
        if (sources != null)
          'sources': sources!.map((s) => s.toJson()).toList(),
        if (followUpQuestions != null) 'followUpQuestions': followUpQuestions,
        if (additionalFollowUpQuestions != null) 'additionalFollowUpQuestions': additionalFollowUpQuestions,
        if (images != null) 'images': images,
        if (messageCost != null) 'messageCost': messageCost,
        if (sessionCost != null) 'sessionCost': sessionCost,
        if (costBreakdown != null) 'costBreakdown': costBreakdown,
      };
}

/// Helper class to build multimodal messages
class MessageBuilder {
  final String id;
  final String type;
  final String timestamp;
  final List<MessageContent> _contents = [];

  MessageBuilder({
    required this.id,
    required this.type,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  /// Add file URL
  MessageBuilder addFileUrl(String url, String mediaType) {
    _contents.add(MessageContent.fileUrl(url, mediaType));
    return this;
  }

  /// Add image URL
  MessageBuilder addImageUrl(String url) {
    _contents.add(MessageContent.imageUrl(url));
    return this;
  }

  /// Add text content
  MessageBuilder addText(String text) {
    _contents.add(MessageContent.text(text));
    return this;
  }

  /// Build the message
  Message build() {
    // If only one text content, use string format for simplicity
    dynamic content;
    if (_contents.length == 1 && _contents.first.type == 'text') {
      content = _contents.first.text;
    } else {
      content = _contents.map((c) => c.toJson()).toList();
    }

    return Message(
      id: id,
      type: type,
      content: content,
      timestamp: timestamp,
    );
  }
}

class MessageContent {
  final String type; // 'text' | 'image_url' | 'file'
  final String? text;
  final ImageUrl? imageUrl;
  final FileUrl? fileUrl;

  MessageContent({
    required this.type,
    this.text,
    this.imageUrl,
    this.fileUrl,
  });

  factory MessageContent.fileUrl(String url, String mediaType) => MessageContent(
        type: 'file',
        fileUrl: FileUrl(url: url, mediaType: mediaType),
      );

  factory MessageContent.fromJson(Map<String, dynamic> json) => MessageContent(
        type: json['type'] ?? 'text',
        text: json['text'],
        imageUrl: json['image_url'] != null
            ? ImageUrl.fromJson(json['image_url'])
            : (json['image'] != null
                ? (json['image'] is String
                    ? ImageUrl(url: json['image'] as String)
                    : (json['image'] is Map<String, dynamic> && (json['image'] as Map<String, dynamic>)['url'] is String
                        ? ImageUrl(url: (json['image'] as Map<String, dynamic>)['url'] as String)
                        : null))
                : null),
        fileUrl: json['file_url'] != null ? FileUrl.fromJson(json['file_url']) : null,
      );

  factory MessageContent.imageUrl(String url) => MessageContent(
        type: 'image_url',
        imageUrl: ImageUrl(url: url),
      );

  factory MessageContent.text(String text) => MessageContent(
        type: 'text',
        text: text,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        if (text != null) 'text': text,
        if (imageUrl != null) 'image_url': imageUrl!.toJson(),
        if (fileUrl != null) 'file_url': fileUrl!.toJson(),
      };
}
