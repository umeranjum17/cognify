import 'package:flutter/material.dart';

/// Enhanced roadmap models that match the new JSON structure

enum LearningRole {
  frontend('frontend', 'Frontend Developer'),
  backend('backend', 'Backend Developer'),
  fullstack('fullstack', 'Full Stack Developer'),
  devops('devops', 'DevOps Engineer'),
  dataScience('data-science', 'Data Scientist'),
  mobile('mobile', 'Mobile Developer'),
  android('android', 'Android Developer'),
  ios('ios', 'iOS Developer'),
  gamedev('gamedev', 'Game Developer'),
  aiEngineer('ai-engineer', 'AI Engineer'),
  softwareArchitect('software-architect', 'Software Architect'),
  engineeringManager('engineering-manager', 'Engineering Manager');

  const LearningRole(this.id, this.displayName);
  final String id;
  final String displayName;

  static LearningRole fromId(String id) {
    return LearningRole.values.firstWhere(
      (role) => role.id == id,
      orElse: () => LearningRole.frontend,
    );
  }
}

/// Enhanced topic model matching the new JSON structure
class EnhancedRoadmapTopic {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final String estimatedTime;
  final List<String> prerequisites;
  final List<String> resources;
  final bool isCompleted;
  final int estimatedHours;
  final List<String> tags;
  final List<String> learningObjectives;
  final List<String> practicalExercises;

  const EnhancedRoadmapTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedTime,
    required this.prerequisites,
    required this.resources,
    required this.isCompleted,
    required this.estimatedHours,
    required this.tags,
    required this.learningObjectives,
    required this.practicalExercises,
  });

  /// Create from JSON
  factory EnhancedRoadmapTopic.fromJson(Map<String, dynamic> json) {
    return EnhancedRoadmapTopic(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      difficulty: json['difficulty'] ?? 'intermediate',
      estimatedTime: json['estimatedTime'] ?? '2-4 hours',
      prerequisites: List<String>.from(json['prerequisites'] ?? []),
      resources: List<String>.from(json['resources'] ?? []),
      isCompleted: json['isCompleted'] ?? false,
      estimatedHours: json['estimatedHours'] ?? 3,
      tags: List<String>.from(json['tags'] ?? []),
      learningObjectives: List<String>.from(json['learningObjectives'] ?? []),
      practicalExercises: List<String>.from(json['practicalExercises'] ?? []),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'estimatedTime': estimatedTime,
      'prerequisites': prerequisites,
      'resources': resources,
      'isCompleted': isCompleted,
      'estimatedHours': estimatedHours,
      'tags': tags,
      'learningObjectives': learningObjectives,
      'practicalExercises': practicalExercises,
    };
  }

  /// Copy with changes
  EnhancedRoadmapTopic copyWith({
    String? id,
    String? title,
    String? description,
    String? difficulty,
    String? estimatedTime,
    List<String>? prerequisites,
    List<String>? resources,
    bool? isCompleted,
    int? estimatedHours,
    List<String>? tags,
    List<String>? learningObjectives,
    List<String>? practicalExercises,
  }) {
    return EnhancedRoadmapTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      prerequisites: prerequisites ?? this.prerequisites,
      resources: resources ?? this.resources,
      isCompleted: isCompleted ?? this.isCompleted,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      tags: tags ?? this.tags,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      practicalExercises: practicalExercises ?? this.practicalExercises,
    );
  }

  /// Get difficulty color
  Color get difficultyColor {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  /// Get difficulty icon
  IconData get difficultyIcon {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Icons.circle;
      case 'intermediate':
        return Icons.circle_outlined;
      case 'advanced':
        return Icons.circle_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

/// Enhanced category model matching the new JSON structure
class EnhancedRoadmapCategory {
  final String id;
  final String title;
  final String description;
  final String icon;
  final List<EnhancedRoadmapTopic> topics;
  final int order;
  final int estimatedHours;
  final int topicCount;

  const EnhancedRoadmapCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.topics,
    required this.order,
    required this.estimatedHours,
    required this.topicCount,
  });

  /// Create from JSON
  factory EnhancedRoadmapCategory.fromJson(Map<String, dynamic> json) {
    final topicsList = (json['topics'] as List<dynamic>?)
        ?.map((t) => EnhancedRoadmapTopic.fromJson(t as Map<String, dynamic>))
        .toList() ?? [];

    return EnhancedRoadmapCategory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'category',
      topics: topicsList,
      order: json['order'] ?? 0,
      estimatedHours: json['estimatedHours'] ?? 0,
      topicCount: json['topicCount'] ?? topicsList.length,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'topics': topics.map((t) => t.toJson()).toList(),
      'order': order,
      'estimatedHours': estimatedHours,
      'topicCount': topicCount,
    };
  }

  /// Get icon data from string
  IconData get iconData {
    switch (icon.toLowerCase()) {
      case 'foundation':
        return Icons.foundation;
      case 'code':
        return Icons.code;
      case 'storage':
        return Icons.storage;
      case 'api':
        return Icons.api;
      case 'bug_report':
        return Icons.bug_report;
      case 'security':
        return Icons.security;
      case 'cloud':
        return Icons.cloud;
      case 'architecture':
        return Icons.architecture;
      case 'speed':
        return Icons.speed;
      case 'groups':
        return Icons.groups;
      case 'people':
        return Icons.people;
      case 'psychology':
        return Icons.psychology;
      default:
        return Icons.category;
    }
  }

  /// Get completed topics count
  int get completedTopicsCount {
    return topics.where((topic) => topic.isCompleted).length;
  }

  /// Get completion percentage
  double get completionPercentage {
    if (topics.isEmpty) return 0.0;
    return completedTopicsCount / topics.length;
  }
}

/// Learning path step
class LearningPathStep {
  final int step;
  final String category;
  final String description;
  final int estimatedHours;

  const LearningPathStep({
    required this.step,
    required this.category,
    required this.description,
    required this.estimatedHours,
  });

  factory LearningPathStep.fromJson(Map<String, dynamic> json) {
    return LearningPathStep(
      step: json['step'] ?? 0,
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      estimatedHours: json['estimatedHours'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'category': category,
      'description': description,
      'estimatedHours': estimatedHours,
    };
  }
}

/// Roadmap metadata
class RoadmapMetadata {
  final int totalTopics;
  final int totalCategories;
  final int estimatedHours;
  final String difficulty;
  final double completionRate;
  final List<String> tags;
  final List<String> prerequisites;
  final List<LearningPathStep> learningPath;

  const RoadmapMetadata({
    required this.totalTopics,
    required this.totalCategories,
    required this.estimatedHours,
    required this.difficulty,
    required this.completionRate,
    required this.tags,
    required this.prerequisites,
    required this.learningPath,
  });

  factory RoadmapMetadata.fromJson(Map<String, dynamic> json) {
    return RoadmapMetadata(
      totalTopics: json['totalTopics'] ?? 0,
      totalCategories: json['totalCategories'] ?? 0,
      estimatedHours: json['estimatedHours'] ?? 0,
      difficulty: json['difficulty'] ?? 'intermediate',
      completionRate: (json['completionRate'] ?? 0.0).toDouble(),
      tags: List<String>.from(json['tags'] ?? []),
      prerequisites: List<String>.from(json['prerequisites'] ?? []),
      learningPath: (json['learningPath'] as List<dynamic>?)
          ?.map((step) => LearningPathStep.fromJson(step as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTopics': totalTopics,
      'totalCategories': totalCategories,
      'estimatedHours': estimatedHours,
      'difficulty': difficulty,
      'completionRate': completionRate,
      'tags': tags,
      'prerequisites': prerequisites,
      'learningPath': learningPath.map((step) => step.toJson()).toList(),
    };
  }
}

/// Enhanced roadmap model matching the new JSON structure
class EnhancedRoadmap {
  final String id;
  final String title;
  final String description;
  final String version;
  final String lastUpdated;
  final String source;
  final List<EnhancedRoadmapCategory> categories;
  final RoadmapMetadata metadata;

  const EnhancedRoadmap({
    required this.id,
    required this.title,
    required this.description,
    required this.version,
    required this.lastUpdated,
    required this.source,
    required this.categories,
    required this.metadata,
  });

  /// Create from JSON
  factory EnhancedRoadmap.fromJson(Map<String, dynamic> json) {
    return EnhancedRoadmap(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      version: json['version'] ?? '1.0.0',
      lastUpdated: json['lastUpdated'] ?? '',
      source: json['source'] ?? '',
      categories: (json['categories'] as List<dynamic>?)
          ?.map((c) => EnhancedRoadmapCategory.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
      metadata: RoadmapMetadata.fromJson(json['metadata'] ?? {}),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'version': version,
      'lastUpdated': lastUpdated,
      'source': source,
      'categories': categories.map((c) => c.toJson()).toList(),
      'metadata': metadata.toJson(),
    };
  }

  /// Get all topics across categories
  List<EnhancedRoadmapTopic> getAllTopics() {
    return categories.expand((category) => category.topics).toList();
  }

  /// Get topic by ID
  EnhancedRoadmapTopic? getTopicById(String id) {
    try {
      return getAllTopics().firstWhere((topic) => topic.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get category by ID
  EnhancedRoadmapCategory? getCategoryById(String id) {
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get learning role from ID
  LearningRole get learningRole {
    return LearningRole.fromId(id);
  }

  /// Get total completion percentage
  double get totalCompletionPercentage {
    final allTopics = getAllTopics();
    if (allTopics.isEmpty) return 0.0;

    final completedTopics = allTopics.where((topic) => topic.isCompleted).length;
    return completedTopics / allTopics.length;
  }

  /// Get completed topics count
  int get completedTopicsCount {
    return getAllTopics().where((topic) => topic.isCompleted).length;
  }

  /// Get next recommended topic
  EnhancedRoadmapTopic? getNextRecommendedTopic() {
    // Find first incomplete topic in order of categories
    for (final category in categories) {
      for (final topic in category.topics) {
        if (!topic.isCompleted) {
          return topic;
        }
      }
    }
    return null;
  }

  /// Get topics by difficulty
  List<EnhancedRoadmapTopic> getTopicsByDifficulty(String difficulty) {
    return getAllTopics()
        .where((topic) => topic.difficulty.toLowerCase() == difficulty.toLowerCase())
        .toList();
  }

  /// Get topics by tag
  List<EnhancedRoadmapTopic> getTopicsByTag(String tag) {
    return getAllTopics()
        .where((topic) => topic.tags.contains(tag))
        .toList();
  }
}
