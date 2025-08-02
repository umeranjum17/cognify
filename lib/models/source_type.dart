class SourceType {
  final String id;
  final String name;
  final String icon;
  final String placeholder;
  final RegExp? pattern;
  final String color;

  const SourceType({
    required this.id,
    required this.name,
    required this.icon,
    required this.placeholder,
    this.pattern,
    required this.color,
  });

  static const List<SourceType> sourceTypes = [
    SourceType(
      id: 'youtube',
      name: 'YouTube',
      icon: 'play_circle_filled',
      placeholder: 'https://youtube.com/watch?v=...',
      color: '#FF0000',
    ),
    SourceType(
      id: 'medium',
      name: 'Medium',
      icon: 'article',
      placeholder: 'https://medium.com/@author/article-title',
      color: '#00AB6C',
    ),
    SourceType(
      id: 'substack',
      name: 'Substack',
      icon: 'email',
      placeholder: 'https://newsletter.substack.com/p/...',
      color: '#FF6719',
    ),
    SourceType(
      id: 'reddit',
      name: 'Reddit',
      icon: 'forum',
      placeholder: 'https://reddit.com/r/programming/...',
      color: '#FF4500',
    ),
    SourceType(
      id: 'github',
      name: 'GitHub',
      icon: 'code',
      placeholder: 'https://github.com/user/repo',
      color: '#181717',
    ),
    SourceType(
      id: 'blink',
      name: 'Blinkist',
      icon: 'menu_book',
      placeholder: 'https://www.blinkist.com/books/...',
      color: '#00D4AA',
    ),
    SourceType(
      id: 'website',
      name: 'Website',
      icon: 'language',
      placeholder: 'https://example.com/article',
      color: '#2196F3',
    ),
  ];

  static SourceType? findById(String id) {
    try {
      return sourceTypes.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }

  static String detectSourceType(String url) {
    // Normalize URL for better detection
    final normalizedUrl = url.toLowerCase().trim();

    // Define patterns for detection in order of specificity
    final patterns = {
      'youtube': RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/shorts\/|m\.youtube\.com)', caseSensitive: false),
      'substack': RegExp(r'\.substack\.com', caseSensitive: false),
      'medium': RegExp(r'(?:^https?:\/\/)?(?:www\.)?medium\.com', caseSensitive: false),
      'reddit': RegExp(r'(?:^https?:\/\/)?(?:www\.)?reddit\.com', caseSensitive: false),
      'github': RegExp(r'(?:^https?:\/\/)?(?:www\.)?github\.com', caseSensitive: false),
      'blink': RegExp(r'(?:^https?:\/\/)?(?:www\.)?blinkist\.com', caseSensitive: false),
    };

    // Check each pattern in order of specificity
    for (final entry in patterns.entries) {
      if (entry.value.hasMatch(normalizedUrl)) {
        return entry.key;
      }
    }

    // Fallback to website if no pattern matches
    return 'website';
  }

  static String getSourceIcon(String sourceType) {
    final type = findById(sourceType);
    if (type != null) return type.icon;

    switch (sourceType) {
      case 'file': return 'insert_drive_file';
      case 'url': return 'link';
      case 'youtube': return 'play_circle_filled';
      case 'medium': return 'article';
      case 'substack': return 'email';
      case 'reddit': return 'forum';
      case 'github': return 'code';
      case 'blink': return 'menu_book';
      case 'website': return 'language';
      default: return 'insert_drive_file';
    }
  }

  static String getSourceColor(String sourceType) {
    final type = findById(sourceType);
    if (type != null) return type.color;

    switch (sourceType) {
      case 'youtube': return '#FF0000';
      case 'medium': return '#00AB6C';
      case 'substack': return '#FF6719';
      case 'reddit': return '#FF4500';
      case 'github': return '#181717';
      case 'blink': return '#00D4AA';
      case 'website': return '#2196F3';
      default: return '#6366F1';
    }
  }
}
