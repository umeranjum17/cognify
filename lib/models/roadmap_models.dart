import 'package:flutter/material.dart';

enum DifficultyLevel {
  fundamentals,
  intermediate,
  advanced,
  expert,
}

enum NodeType {
  core,        // Main technology nodes (yellow in roadmap.sh)
  topic,       // Learning topics (beige in roadmap.sh)
  skill,       // Specific skills
  tool,        // Tools and frameworks
  concept,     // Concepts and theory
}

class NodePosition {
  final double x;
  final double y;

  const NodePosition(this.x, this.y);
}

class RoadmapConnection {
  final String fromNodeId;
  final String toNodeId;
  final bool isDotted;
  final bool isCurved;

  const RoadmapConnection({
    required this.fromNodeId,
    required this.toNodeId,
    this.isDotted = false,
    this.isCurved = true,
  });
}

class RoadmapGraphNode {
  final String id;
  final String title;
  final String? subtitle;
  final NodeType type;
  final NodePosition position;
  final bool isCompleted;
  final bool isOptional;
  final List<String> prerequisites;
  final String? description;

  const RoadmapGraphNode({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    required this.position,
    this.isCompleted = false,
    this.isOptional = false,
    this.prerequisites = const [],
    this.description,
  });
}

enum LearningRole {
  // Core Development Roles
  backend,
  frontend,
  fullstack,

  // Mobile Development
  android,
  flutter,
  reactNative,

  // DevOps & Infrastructure
  devops,
  docker,
  kubernetes,
  terraform,

  // Data & AI
  dataScience,
  aiDataScientist,
  aiEngineer,
  dataAnalyst,
  mlops,

  // Programming Languages
  javascript,
  typescript,
  python,
  java,
  golang,
  rust,
  cpp,

  // Frameworks & Technologies
  react,
  angular,
  vue,
  nodejs,
  springBoot,
  aspnetCore,

  // Databases
  mongodb,
  postgresql,
  redis,

  // Design & Architecture
  systemDesign,
  softwareArchitect,
  apiDesign,
  designSystem,
  uxDesign,

  // Management & Leadership
  productManager,
  engineeringManager,

  // Specialized Roles
  gamedev,
  blockchain,
  cyberSecurity,
  technicalWriter,
  devrel,
  promptEngineering,

  // Skills & Practices
  codeReview,
  computerScience,
  dataStructuresAlgorithms,
  linux,
  graphql,
}

class RoadmapTopic {
  final String id;
  final String name;
  final String description;
  final DifficultyLevel difficulty;
  final int estimatedHours;
  final List<String> prerequisites;
  final List<String> keyConcepts;
  final List<String> resources;
  final bool isCompleted;
  final String? iconName;

  const RoadmapTopic({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.estimatedHours,
    required this.prerequisites,
    required this.keyConcepts,
    required this.resources,
    this.isCompleted = false,
    this.iconName,
  });

  RoadmapTopic copyWith({
    String? id,
    String? name,
    String? description,
    DifficultyLevel? difficulty,
    int? estimatedHours,
    List<String>? prerequisites,
    List<String>? keyConcepts,
    List<String>? resources,
    bool? isCompleted,
    String? iconName,
  }) {
    return RoadmapTopic(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      prerequisites: prerequisites ?? this.prerequisites,
      keyConcepts: keyConcepts ?? this.keyConcepts,
      resources: resources ?? this.resources,
      isCompleted: isCompleted ?? this.isCompleted,
      iconName: iconName ?? this.iconName,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'difficulty': difficulty.name,
      'estimatedHours': estimatedHours,
      'prerequisites': prerequisites,
      'keyConcepts': keyConcepts,
      'resources': resources,
      'isCompleted': isCompleted,
      'iconName': iconName,
    };
  }

  /// Create from JSON for caching
  factory RoadmapTopic.fromJson(Map<String, dynamic> json) {
    return RoadmapTopic(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      difficulty: DifficultyLevel.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => DifficultyLevel.fundamentals,
      ),
      estimatedHours: json['estimatedHours'] ?? 8,
      prerequisites: List<String>.from(json['prerequisites'] ?? []),
      keyConcepts: List<String>.from(json['keyConcepts'] ?? []),
      resources: List<String>.from(json['resources'] ?? []),
      isCompleted: json['isCompleted'] ?? false,
      iconName: json['iconName'],
    );
  }
}

class LearningPath {
  final LearningRole role;
  final String title;
  final String description;
  final List<RoadmapTopic> fundamentals;
  final List<RoadmapTopic> intermediate;
  final List<RoadmapTopic> advanced;
  final List<RoadmapTopic> expert;

  const LearningPath({
    required this.role,
    required this.title,
    required this.description,
    required this.fundamentals,
    required this.intermediate,
    required this.advanced,
    required this.expert,
  });

  List<RoadmapTopic> getTopicsByDifficulty(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.fundamentals:
        return fundamentals;
      case DifficultyLevel.intermediate:
        return intermediate;
      case DifficultyLevel.advanced:
        return advanced;
      case DifficultyLevel.expert:
        return expert;
    }
  }

  List<RoadmapTopic> get allTopics => [
        ...fundamentals,
        ...intermediate,
        ...advanced,
        ...expert,
      ];

  int get totalTopics => allTopics.length;
  int get completedTopics => allTopics.where((topic) => topic.isCompleted).length;
  double get progressPercentage => totalTopics > 0 ? completedTopics / totalTopics : 0.0;
}

extension DifficultyLevelExtension on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.fundamentals:
        return 'Fundamentals';
      case DifficultyLevel.intermediate:
        return 'Intermediate';
      case DifficultyLevel.advanced:
        return 'Advanced';
      case DifficultyLevel.expert:
        return 'Expert';
    }
  }

  String get description {
    switch (this) {
      case DifficultyLevel.fundamentals:
        return 'Core concepts and basics';
      case DifficultyLevel.intermediate:
        return 'Building on the fundamentals';
      case DifficultyLevel.advanced:
        return 'Complex topics and patterns';
      case DifficultyLevel.expert:
        return 'Cutting-edge and specialized';
    }
  }
}

extension LearningRoleExtension on LearningRole {
  String get displayName {
    switch (this) {
      case LearningRole.backend:
        return 'Backend Developer';
      case LearningRole.frontend:
        return 'Frontend Developer';
      case LearningRole.fullstack:
        return 'Full Stack Developer';
      case LearningRole.android:
        return 'Android Developer';
      case LearningRole.flutter:
        return 'Flutter Developer';
      case LearningRole.reactNative:
        return 'React Native Developer';
      case LearningRole.devops:
        return 'DevOps Engineer';
      case LearningRole.docker:
        return 'Docker Specialist';
      case LearningRole.kubernetes:
        return 'Kubernetes Engineer';
      case LearningRole.terraform:
        return 'Terraform Engineer';
      case LearningRole.dataScience:
        return 'Data Scientist';
      case LearningRole.aiDataScientist:
        return 'AI Data Scientist';
      case LearningRole.aiEngineer:
        return 'AI Engineer';
      case LearningRole.dataAnalyst:
        return 'Data Analyst';
      case LearningRole.mlops:
        return 'MLOps Engineer';
      case LearningRole.javascript:
        return 'JavaScript Developer';
      case LearningRole.typescript:
        return 'TypeScript Developer';
      case LearningRole.python:
        return 'Python Developer';
      case LearningRole.java:
        return 'Java Developer';
      case LearningRole.golang:
        return 'Go Developer';
      case LearningRole.rust:
        return 'Rust Developer';
      case LearningRole.cpp:
        return 'C++ Developer';
      case LearningRole.react:
        return 'React Developer';
      case LearningRole.angular:
        return 'Angular Developer';
      case LearningRole.vue:
        return 'Vue.js Developer';
      case LearningRole.nodejs:
        return 'Node.js Developer';
      case LearningRole.springBoot:
        return 'Spring Boot Developer';
      case LearningRole.aspnetCore:
        return 'ASP.NET Core Developer';
      case LearningRole.mongodb:
        return 'MongoDB Specialist';
      case LearningRole.postgresql:
        return 'PostgreSQL Specialist';
      case LearningRole.redis:
        return 'Redis Specialist';
      case LearningRole.systemDesign:
        return 'System Design Expert';
      case LearningRole.softwareArchitect:
        return 'Software Architect';
      case LearningRole.apiDesign:
        return 'API Design Specialist';
      case LearningRole.designSystem:
        return 'Design System Expert';
      case LearningRole.uxDesign:
        return 'UX Designer';
      case LearningRole.productManager:
        return 'Product Manager';
      case LearningRole.engineeringManager:
        return 'Engineering Manager';
      case LearningRole.gamedev:
        return 'Game Developer';
      case LearningRole.blockchain:
        return 'Blockchain Developer';
      case LearningRole.cyberSecurity:
        return 'Cybersecurity Specialist';
      case LearningRole.technicalWriter:
        return 'Technical Writer';
      case LearningRole.devrel:
        return 'Developer Relations';
      case LearningRole.promptEngineering:
        return 'Prompt Engineer';
      case LearningRole.codeReview:
        return 'Code Review Expert';
      case LearningRole.computerScience:
        return 'Computer Science';
      case LearningRole.dataStructuresAlgorithms:
        return 'Data Structures & Algorithms';
      case LearningRole.linux:
        return 'Linux Administrator';
      case LearningRole.graphql:
        return 'GraphQL Specialist';
    }
  }

  String get description {
    switch (this) {
      case LearningRole.backend:
        return 'Server-side development and APIs';
      case LearningRole.frontend:
        return 'User interfaces and client-side';
      case LearningRole.fullstack:
        return 'End-to-end web development';
      case LearningRole.android:
        return 'Native Android app development';
      case LearningRole.flutter:
        return 'Cross-platform mobile development';
      case LearningRole.reactNative:
        return 'React-based mobile development';
      case LearningRole.devops:
        return 'Infrastructure and deployment';
      case LearningRole.docker:
        return 'Containerization with Docker';
      case LearningRole.kubernetes:
        return 'Container orchestration';
      case LearningRole.terraform:
        return 'Infrastructure as code';
      case LearningRole.dataScience:
        return 'Data analysis and machine learning';
      case LearningRole.aiDataScientist:
        return 'AI and machine learning specialist';
      case LearningRole.aiEngineer:
        return 'AI systems engineering and deployment';
      case LearningRole.dataAnalyst:
        return 'Data analysis and visualization';
      case LearningRole.mlops:
        return 'ML operations and deployment';
      case LearningRole.javascript:
        return 'JavaScript programming';
      case LearningRole.typescript:
        return 'TypeScript development';
      case LearningRole.python:
        return 'Python programming';
      case LearningRole.java:
        return 'Java development';
      case LearningRole.golang:
        return 'Go programming';
      case LearningRole.rust:
        return 'Rust systems programming';
      case LearningRole.cpp:
        return 'C++ programming';
      case LearningRole.react:
        return 'React frontend development';
      case LearningRole.angular:
        return 'Angular framework';
      case LearningRole.vue:
        return 'Vue.js framework';
      case LearningRole.nodejs:
        return 'Node.js backend development';
      case LearningRole.springBoot:
        return 'Spring Boot Java framework';
      case LearningRole.aspnetCore:
        return 'ASP.NET Core development';
      case LearningRole.mongodb:
        return 'MongoDB database';
      case LearningRole.postgresql:
        return 'PostgreSQL database';
      case LearningRole.redis:
        return 'Redis caching and data store';
      case LearningRole.systemDesign:
        return 'Large-scale system architecture';
      case LearningRole.softwareArchitect:
        return 'Software architecture and design';
      case LearningRole.apiDesign:
        return 'API design and development';
      case LearningRole.designSystem:
        return 'Design systems and components';
      case LearningRole.uxDesign:
        return 'User experience design';
      case LearningRole.productManager:
        return 'Product management and strategy';
      case LearningRole.engineeringManager:
        return 'Engineering team leadership';
      case LearningRole.gamedev:
        return 'Game engines and interactive media';
      case LearningRole.blockchain:
        return 'Blockchain and Web3 development';
      case LearningRole.cyberSecurity:
        return 'Security and penetration testing';
      case LearningRole.technicalWriter:
        return 'Technical documentation';
      case LearningRole.devrel:
        return 'Developer advocacy and relations';
      case LearningRole.promptEngineering:
        return 'AI prompt design and optimization';
      case LearningRole.codeReview:
        return 'Code review best practices';
      case LearningRole.computerScience:
        return 'Computer science fundamentals';
      case LearningRole.dataStructuresAlgorithms:
        return 'Data structures and algorithms';
      case LearningRole.linux:
        return 'Linux system administration';
      case LearningRole.graphql:
        return 'GraphQL API development';
    }
  }
}

class RoadmapGraph {
  final String id;
  final String title;
  final String description;
  final LearningRole role;
  final List<RoadmapGraphNode> nodes;
  final List<RoadmapConnection> connections;
  final double width;
  final double height;

  const RoadmapGraph({
    required this.id,
    required this.title,
    required this.description,
    required this.role,
    required this.nodes,
    required this.connections,
    this.width = 1200,
    this.height = 800,
  });

  RoadmapGraphNode? getNodeById(String id) {
    try {
      return nodes.firstWhere((node) => node.id == id);
    } catch (e) {
      return null;
    }
  }

  List<RoadmapConnection> getConnectionsForNode(String nodeId) {
    return connections.where((conn) =>
      conn.fromNodeId == nodeId || conn.toNodeId == nodeId
    ).toList();
  }
}

// New mobile-friendly roadmap structure
class RoadmapCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<RoadmapTopic> topics;
  final int order;

  const RoadmapCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.topics,
    required this.order,
  });

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon.codePoint,
      'topics': topics.map((t) => t.toJson()).toList(),
      'order': order,
    };
  }

  /// Create from JSON for caching
  factory RoadmapCategory.fromJson(Map<String, dynamic> json) {
    return RoadmapCategory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: IconData(json['icon'] ?? Icons.category.codePoint, fontFamily: 'MaterialIcons'),
      topics: (json['topics'] as List<dynamic>?)
          ?.map((t) => RoadmapTopic.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
      order: json['order'] ?? 0,
    );
  }
}

class MobileRoadmap {
  final String id;
  final String title;
  final String description;
  final LearningRole role;
  final List<RoadmapCategory> categories;

  const MobileRoadmap({
    required this.id,
    required this.title,
    required this.description,
    required this.role,
    required this.categories,
  });

  List<RoadmapTopic> getAllTopics() {
    return categories.expand((category) => category.topics).toList();
  }

  RoadmapTopic? getTopicById(String id) {
    try {
      return getAllTopics().firstWhere((topic) => topic.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'role': role.name,
      'categories': categories.map((c) => c.toJson()).toList(),
    };
  }

  /// Create from JSON for caching
  factory MobileRoadmap.fromJson(Map<String, dynamic> json) {
    return MobileRoadmap(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      role: LearningRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => LearningRole.frontend,
      ),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((c) => RoadmapCategory.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
