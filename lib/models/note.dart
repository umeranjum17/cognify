class Note {
  final String id;
  final String title;
  final String content;
  final String htmlContent;
  final String createdAt;
  final String updatedAt;
  final double? totalCost;
  final List<String>? tags;
  final List<dynamic>? messages;
  final String? messageId;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.htmlContent,
    required this.createdAt,
    required this.updatedAt,
    this.totalCost,
    this.tags,
    this.messages,
    this.messageId,
  });

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        htmlContent: json['htmlContent'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        totalCost: (json['totalCost'] as num?)?.toDouble(),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
        messages: json['messages'] as List?,
        messageId: json['messageId'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'htmlContent': htmlContent,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'totalCost': totalCost,
        'tags': tags,
        'messages': messages,
        'messageId': messageId,
      };
}
