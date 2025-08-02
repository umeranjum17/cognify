import 'chat_source.dart';
import 'file_attachment.dart';

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

  factory Attachment.fromFileAttachment(FileAttachment fileAttachment) => Attachment(
        id: fileAttachment.id,
        type: fileAttachment.type,
        name: fileAttachment.name,
        content: fileAttachment.base64Data,
        size: fileAttachment.size,
        metadata: {
          'mimeType': fileAttachment.mimeType,
          'createdAt': fileAttachment.createdAt.toIso8601String(),
        },
      );

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
  final List<FileAttachment>? fileAttachments; // New: Enhanced file attachments
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
    this.fileAttachments,
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
        fileAttachments: json['fileAttachments'] != null
            ? (json['fileAttachments'] as List)
                .map((f) => FileAttachment.fromJson(f))
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

  /// Get all file attachments (both old and new format)
  List<FileAttachment> get allFileAttachments {
    List<FileAttachment> allAttachments = [];
    
    // Add new format file attachments
    if (fileAttachments != null) {
      allAttachments.addAll(fileAttachments!);
    }
    
    // Convert old format attachments to new format
    if (attachments != null) {
      for (final attachment in attachments!) {
        if (attachment.content != null) {
          try {
            allAttachments.add(FileAttachment(
              id: attachment.id,
              name: attachment.name,
              type: attachment.type,
              base64Data: attachment.content!,
              size: attachment.size ?? 0,
              mimeType: attachment.metadata?['mimeType'] ?? 'application/octet-stream',
              createdAt: attachment.metadata?['createdAt'] != null
                  ? DateTime.parse(attachment.metadata!['createdAt'])
                  : DateTime.now(),
            ));
          } catch (e) {
            print('Error converting attachment to FileAttachment: $e');
          }
        }
      }
    }
    
    return allAttachments;
  }

  /// Check if message has any file attachments
  bool get hasFileAttachments => 
      (fileAttachments != null && fileAttachments!.isNotEmpty) ||
      (attachments != null && attachments!.isNotEmpty);

  // Legacy support for simple string content
  String get role => type == 'user' ? 'user' : 'assistant';

  String get textContent {
    if (content is String) {
      return content as String;
    } else if (content is List) {
      final textParts = (content as List)
          .where((part) => part is Map && part['type'] == 'text')
          .map((part) => part['text'] as String)
          .toList();
      return textParts.join('\n');
    }
    return '';
  }

  /// Create a copy of the message with new file attachments
  Message copyWithFileAttachments(List<FileAttachment> newFileAttachments) {
    return Message(
      id: id,
      type: type,
      content: content,
      timestamp: timestamp,
      isProcessing: isProcessing,
      attachments: attachments,
      fileAttachments: newFileAttachments,
      sources: sources,
      followUpQuestions: followUpQuestions,
      additionalFollowUpQuestions: additionalFollowUpQuestions,
      images: images,
      messageCost: messageCost,
      sessionCost: sessionCost,
      costBreakdown: costBreakdown,
    );
  }

  /// Convert message to API format for sending to server
  Map<String, dynamic> toApiJson() {
    final json = toJson();
    
    // Include file attachments in API format
    if (fileAttachments != null && fileAttachments!.isNotEmpty) {
      json['attachments'] = fileAttachments!.map((f) => f.toJson()).toList();
    }
    
    return json;
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
        if (fileAttachments != null)
          'fileAttachments': fileAttachments!.map((f) => f.toJson()).toList(),
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
  final List<FileAttachment> _fileAttachments = [];

  MessageBuilder({
    required this.id,
    required this.type,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  /// Add file attachment
  MessageBuilder addFileAttachment(FileAttachment attachment) {
    _fileAttachments.add(attachment);
    _contents.add(MessageContent.fromFileAttachment(attachment));
    return this;
  }

  /// Add multiple file attachments
  MessageBuilder addFileAttachments(List<FileAttachment> attachments) {
    for (final attachment in attachments) {
      addFileAttachment(attachment);
    }
    return this;
  }

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
      fileAttachments: _fileAttachments.isNotEmpty ? _fileAttachments : null,
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

  /// Create MessageContent from FileAttachment
  factory MessageContent.fromFileAttachment(FileAttachment attachment) {
    if (attachment.isImage) {
      // Create data URL for images
      final dataUrl = 'data:${attachment.mimeType};base64,${attachment.base64Data}';
      return MessageContent.imageUrl(dataUrl);
    } else {
      // Create file URL for other files
      final dataUrl = 'data:${attachment.mimeType};base64,${attachment.base64Data}';
      return MessageContent.fileUrl(dataUrl, attachment.mimeType);
    }
  }

  factory MessageContent.fromJson(Map<String, dynamic> json) => MessageContent(
        type: json['type'] ?? 'text',
        text: json['text'],
        imageUrl: json['image_url'] != null ? ImageUrl.fromJson(json['image_url']) : null,
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
