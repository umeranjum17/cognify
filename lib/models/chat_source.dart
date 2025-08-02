/// Chat source model for agent system
class ChatSource {
  final String title;
  final String url;
  final String? description;
  final String type;
  final String? content;
  final bool hasScrapedContent;

  ChatSource({
    required this.title,
    required this.url,
    this.description,
    required this.type,
    this.content,
    required this.hasScrapedContent,
  });

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'web',
      content: json['content'],
      hasScrapedContent: json['hasScrapedContent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'description': description,
      'type': type,
      'content': content,
      'hasScrapedContent': hasScrapedContent,
    };
  }

  @override
  String toString() {
    return 'ChatSource(title: $title, url: $url, type: $type, hasContent: ${content != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatSource &&
        other.title == title &&
        other.url == url &&
        other.type == type;
  }

  @override
  int get hashCode {
    return title.hashCode ^ url.hashCode ^ type.hashCode;
  }
}
