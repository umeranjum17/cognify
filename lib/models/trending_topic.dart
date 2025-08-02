class TrendingTopicSource {
  final String name;
  final String logo;
  final String url;
  final String type; // 'reddit' | 'hackernews' | 'github' | 'medium' | 'devto' | 'search'

  TrendingTopicSource({
    required this.name,
    required this.logo,
    required this.url,
    required this.type,
  });

  factory TrendingTopicSource.fromJson(Map<String, dynamic> json) => TrendingTopicSource(
        name: json['name'] ?? '',
        logo: json['logo'] ?? '',
        url: json['url'] ?? '',
        type: json['type'] ?? 'search',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'logo': logo,
        'url': url,
        'type': type,
      };
}

class TrendingTopicMetadata {
  final int? score;
  final int? comments;
  final int? stars;
  final int? reactions;
  final int? readingTime;
  final String publishedAt;
  final List<String> tags;

  TrendingTopicMetadata({
    this.score,
    this.comments,
    this.stars,
    this.reactions,
    this.readingTime,
    required this.publishedAt,
    required this.tags,
  });

  factory TrendingTopicMetadata.fromJson(Map<String, dynamic> json) => TrendingTopicMetadata(
        score: json['score'],
        comments: json['comments'],
        stars: json['stars'],
        reactions: json['reactions'],
        readingTime: json['readingTime'],
        publishedAt: json['publishedAt'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'score': score,
        'comments': comments,
        'stars': stars,
        'reactions': reactions,
        'readingTime': readingTime,
        'publishedAt': publishedAt,
        'tags': tags,
      };
}

class TrendingTopic {
  final String id;
  final String title;
  final String description;
  final String url;
  final TrendingTopicSource source;
  final TrendingTopicMetadata metadata;
  final double? relevanceScore;

  TrendingTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.source,
    required this.metadata,
    this.relevanceScore,
  });

  factory TrendingTopic.fromJson(Map<String, dynamic> json) => TrendingTopic(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        url: json['url'] ?? '',
        source: TrendingTopicSource.fromJson(json['source'] ?? {}),
        metadata: TrendingTopicMetadata.fromJson(json['metadata'] ?? {}),
        relevanceScore: json['relevanceScore']?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'url': url,
        'source': source.toJson(),
        'metadata': metadata.toJson(),
        'relevanceScore': relevanceScore,
      };
}

class TrendingTopicsResponse {
  final List<TrendingTopic> topics;

  TrendingTopicsResponse({required this.topics});

  factory TrendingTopicsResponse.fromJson(Map<String, dynamic> json) => TrendingTopicsResponse(
        topics: (json['topics'] as List)
            .map((e) => TrendingTopic.fromJson(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'topics': topics.map((e) => e.toJson()).toList(),
      };
}
