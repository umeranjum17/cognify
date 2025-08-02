import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mobile_roadmaps.dart';
import '../models/enhanced_roadmap_models.dart' as enhanced;
import '../models/roadmap_models.dart';
import '../models/roadmap_role.dart';
import 'enhanced_roadmap_service.dart';
import 'unified_api_service.dart';

class RoadmapService {
  // Cache duration: 30 days for roadmap data (doesn't change frequently)
  static const Duration _cacheDuration = Duration(days: 30);
  // Storage keys for persistent caching
  static const String _cacheKeyPrefix = 'roadmap_cache_';

  static const String _timestampKeyPrefix = 'roadmap_timestamp_';

  final UnifiedApiService _apiService = UnifiedApiService();
  final EnhancedRoadmapService _enhancedService = EnhancedRoadmapService();

  /// Clear all cached roadmaps
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix) || key.startsWith(_timestampKeyPrefix)) {
          await prefs.remove(key);
        }
      }

      print('📊 [ROADMAP] Cleared all persistent cache');
    } catch (e) {
      print('Error clearing all roadmap cache: $e');
    }
  }

  /// Clear enhanced roadmap cache
  Future<void> clearEnhancedCache() async {
    try {
      await _enhancedService.clearCache();
    } catch (e) {
      print('❌ [ROADMAP] Error clearing enhanced cache: $e');
    }
  }

  /// Fetch enhanced roadmap data (NEW METHOD - RECOMMENDED)
  Future<enhanced.EnhancedRoadmap> fetchEnhancedRoadmap(enhanced.LearningRole role) async {
    try {
      print('📊 [ROADMAP] Fetching enhanced roadmap for ${role.displayName}');
      return await _enhancedService.getRoadmap(role);
    } catch (e) {
      print('❌ [ROADMAP] Error fetching enhanced roadmap for ${role.displayName}: $e');
      rethrow;
    }
  }

  /// Fetch roadmap data with persistent caching
  Future<MobileRoadmap> fetchRoadmap(LearningRole role) async {
    final roleKey = role.name;

    // Check persistent cache first
    final cachedRoadmap = await _getCachedRoadmap(roleKey);
    if (cachedRoadmap != null) {
      final cacheTime = await _getCacheTimestamp(roleKey);
      if (cacheTime != null) {
        final now = DateTime.now();
        if (now.difference(cacheTime) < _cacheDuration) {
          print('📊 [ROADMAP] Using persistent cached data for $roleKey (${now.difference(cacheTime).inDays} days old)');
          return cachedRoadmap;
        } else {
          print('📊 [ROADMAP] Persistent cache expired for $roleKey (${now.difference(cacheTime).inDays} days old), refreshing...');
          await _clearCachedRoadmap(roleKey);
        }
      }
    }

    try {
      // Use smart defaults for fast loading - users can analyze gaps via chat
      final roadmapData = await _buildSmartRoadmap(role);

      // Cache persistently
      await _cacheRoadmap(roleKey, roadmapData);
      print('📊 [ROADMAP] Persistently cached roadmap for $roleKey (valid for ${_cacheDuration.inDays} days)');
      return roadmapData;
    } catch (e) {
      print('Error building roadmap for $roleKey: $e');
      // Don't return fallback data - let UI handle loading state
      rethrow;
    }
  }

  /// Force refresh roles by clearing cache and fetching fresh data
  Future<List<RoadmapRole>> forceRefreshRoles() async {
    try {
      // Clear any cached roles data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_roadmap_roles');
      await prefs.remove('cached_roadmap_roles_timestamp');

      print('📊 [ROADMAP] Force refreshing roles from backend');

      // Fetch fresh data from backend
      return await getAllRoadmapRoles();
    } catch (e) {
      print('Error force refreshing roles: $e');
      return _getFallbackRoles();
    }
  }

  /// Get all enhanced roadmaps
  Future<List<enhanced.EnhancedRoadmap>> getAllEnhancedRoadmaps() async {
    try {
      return await _enhancedService.getAllRoadmaps();
    } catch (e) {
      print('❌ [ROADMAP] Error fetching all enhanced roadmaps: $e');
      rethrow;
    }
  }

  /// Get all available roadmap roles from the backend
  Future<List<RoadmapRole>> getAllRoadmapRoles() async {
    try {
      final response = await _apiService.getRoadmapRoles();

      if (response['success'] == true && response['data'] != null) {
        final rolesResponse = RoadmapRolesResponse.fromJson(response);
        return rolesResponse.data?.roles ?? [];
      }

      print('Failed to fetch roadmap roles: ${response['error']}');
      return _getFallbackRoles();
    } catch (e) {
      print('Error fetching roadmap roles: $e');
      return _getFallbackRoles();
    }
  }

  /// Get roadmap role by ID
  Future<RoadmapRole?> getRoadmapRoleById(String roleId) async {
    try {
      final response = await _apiService.getRoadmapRoleById(roleId);

      if (response['success'] == true && response['data'] != null) {
        return RoadmapRole.fromJson(response['data']);
      }

      print('Failed to fetch roadmap role $roleId: ${response['error']}');
      return null;
    } catch (e) {
      print('Error fetching roadmap role $roleId: $e');
      return null;
    }
  }

  /// Get roadmap statistics
  Future<Map<String, dynamic>> getRoadmapStats(String roadmapId) async {
    try {
      return await _enhancedService.getRoadmapStats(roadmapId);
    } catch (e) {
      print('❌ [ROADMAP] Error getting roadmap stats: $e');
      return {};
    }
  }

  /// Convert RoadmapRole to LearningRole enum
  LearningRole? roadmapRoleToLearningRole(RoadmapRole role) {
    // Map roadmap role IDs to LearningRole enum values
    switch (role.id.toLowerCase()) {
      case 'frontend':
        return LearningRole.frontend;
      case 'backend':
        return LearningRole.backend;
      case 'fullstack':
        return LearningRole.fullstack;
      case 'devops':
        return LearningRole.devops;
      case 'android':
        return LearningRole.android;
      case 'flutter':
        return LearningRole.flutter;
      case 'reactnative':
        return LearningRole.reactNative;
      case 'aidatascientist':
      case 'dataanalyst':
        return LearningRole.dataScience;
      case 'aiengineer':
        return LearningRole.aiEngineer;
      case 'mlops':
        return LearningRole.mlops;
      case 'javascript':
        return LearningRole.javascript;
      case 'typescript':
        return LearningRole.typescript;
      case 'python':
        return LearningRole.python;
      case 'java':
        return LearningRole.java;
      case 'golang':
        return LearningRole.golang;
      case 'rust':
        return LearningRole.rust;
      case 'cpp':
        return LearningRole.cpp;
      case 'react':
        return LearningRole.react;
      case 'vue':
        return LearningRole.vue;
      case 'nodejs':
        return LearningRole.nodejs;
      case 'springboot':
        return LearningRole.springBoot;
      case 'mongodb':
        return LearningRole.mongodb;
      case 'postgresql':
        return LearningRole.postgresql;
      case 'redis':
        return LearningRole.redis;
      case 'systemdesign':
        return LearningRole.systemDesign;
      case 'softwarearchitect':
        return LearningRole.softwareArchitect;
      case 'designsystem':
        return LearningRole.designSystem;
      case 'uxdesign':
        return LearningRole.uxDesign;
      case 'productmanager':
        return LearningRole.productManager;
      case 'engineeringmanager':
        return LearningRole.engineeringManager;
      case 'gamedeveloper':
        return LearningRole.gamedev;
      case 'blockchain':
        return LearningRole.blockchain;
      case 'cybersecurity':
        return LearningRole.cyberSecurity;
      case 'technicalwriter':
        return LearningRole.technicalWriter;
      case 'devrel':
        return LearningRole.devrel;
      case 'promptengineering':
        return LearningRole.promptEngineering;
      case 'codereview':
        return LearningRole.codeReview;
      case 'computerscience':
        return LearningRole.computerScience;
      case 'datastructuresandalgorithms':
        return LearningRole.dataStructuresAlgorithms;
      case 'linux':
        return LearningRole.linux;
      case 'graphql':
        return LearningRole.graphql;
      case 'docker':
        return LearningRole.docker;
      case 'kubernetes':
        return LearningRole.kubernetes;
      case 'terraform':
        return LearningRole.terraform;
      default:
        print('Unknown roadmap role ID: ${role.id}');
        return null;
    }
  }

  /// Search roadmap roles
  Future<List<RoadmapRole>> searchRoadmapRoles(String query) async {
    try {
      final response = await _apiService.searchRoadmapRoles(query);

      if (response['success'] == true && response['data'] != null) {
        final searchResponse = RoadmapRoleSearchResponse.fromJson(response);
        return searchResponse.data?.roles ?? [];
      }

      print('Failed to search roadmap roles: ${response['error']}');
      return [];
    } catch (e) {
      print('Error searching roadmap roles: $e');
      return [];
    }
  }

  /// Update topic completion status
  Future<void> updateTopicCompletion(String roadmapId, String topicId, bool isCompleted) async {
    try {
      await _enhancedService.updateTopicCompletion(roadmapId, topicId, isCompleted);
    } catch (e) {
      print('❌ [ROADMAP] Error updating topic completion: $e');
    }
  }

  /// Build backend roadmap with common backend topics
  MobileRoadmap _buildExtractedBackendRoadmap() {
    final backendTopics = [
      'Internet',
      'Basic Frontend Knowledge',
      'OS and General Knowledge',
      'Learn a Language',
      'Python',
      'JavaScript',
      'Java',
      'Go',
      'Rust',
      'C#',
      'PHP',
      'Version Control Systems',
      'Git',
      'Relational Databases',
      'PostgreSQL',
      'MySQL',
      'MariaDB',
      'MS SQL',
      'Oracle',
      'NoSQL databases',
      'MongoDB',
      'RethinkDB',
      'CouchDB',
      'DynamoDB',
      'More about Databases',
      'ORMs',
      'ACID',
      'Transactions',
      'N+1 Problem',
      'Database Normalization',
      'Indexes',
      'Data Replication',
      'Sharding Strategies',
      'APIs',
      'REST',
      'JSON APIs',
      'SOAP',
      'gRPC',
      'GraphQL',
      'Authentication',
      'Cookie Based',
      'OAuth',
      'Basic Authentication',
      'Token Authentication',
      'JWT',
      'OpenID',
      'SAML',
      'Caching',
      'CDN',
      'Server Side',
      'Client Side',
      'Redis',
      'Memcached',
      'Web Security',
      'HTTPS',
      'CORS',
      'SSL/TLS',
      'OWASP Security Risks',
      'Hashing Algorithms',
      'Testing',
      'Integration Testing',
      'Unit Testing',
      'Functional Testing',
      'CI/CD',
      'Design and Development Principles',
      'SOLID',
      'KISS',
      'YAGNI',
      'DRY',
      'Architectural Patterns',
      'Monolithic Apps',
      'Microservices',
      'SOA',
      'CQRS and Event Sourcing',
      'Serverless',
      'Search Engines',
      'Elasticsearch',
      'Solr',
      'Message Brokers',
      'RabbitMQ',
      'Apache Kafka',
      'Containerization vs Virtualization',
      'Docker',
      'rkt',
      'LXC',
      'GraphQL',
      'Apollo',
      'Relay Modern',
      'Graph Databases',
      'Neo4j',
      'WebSockets',
      'Web Servers',
      'Nginx',
      'Apache',
      'Caddy',
      'MS IIS',
      'Building for Scale',
      'Mitigation Strategies',
      'Migration Strategies',
      'Horizontal vs Vertical Scaling',
      'Building with Observability in mind'
    ];

    final categories = [
      RoadmapCategory(
        id: 'fundamentals',
        title: 'Fundamentals',
        description: 'Core backend development concepts',
        icon: Icons.foundation,
        topics: backendTopics.sublist(0, 20).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key)
        ).toList(),
        order: 0,
      ),
      RoadmapCategory(
        id: 'databases',
        title: 'Databases',
        description: 'Database design and management',
        icon: Icons.storage,
        topics: backendTopics.sublist(20, 40).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 20)
        ).toList(),
        order: 1,
      ),
      RoadmapCategory(
        id: 'apis-auth',
        title: 'APIs & Authentication',
        description: 'API design and security',
        icon: Icons.security,
        topics: backendTopics.sublist(40, 60).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 40)
        ).toList(),
        order: 2,
      ),
      RoadmapCategory(
        id: 'advanced-backend',
        title: 'Advanced Backend',
        description: 'Scalability, architecture, and DevOps',
        icon: Icons.architecture,
        topics: backendTopics.sublist(60).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 60)
        ).toList(),
        order: 3,
      ),
    ];

    return MobileRoadmap(
      id: 'backend-extracted',
      title: 'Backend Developer Roadmap',
      description: 'Complete backend development roadmap with ${backendTopics.length} topics',
      role: LearningRole.backend,
      categories: categories,
    );
  }

  /// Build extracted DevOps roadmap
  MobileRoadmap _buildExtractedDevOpsRoadmap() {
    final devopsTopics = [
      // Fundamentals
      'How the Internet Works',
      'Operating Systems',
      'Linux Basics',
      'Terminal Usage',
      'Networking Concepts',
      'DNS',
      'HTTP/HTTPS',
      'SSH',

      // Programming
      'Python',
      'Go',
      'Bash Scripting',
      'PowerShell',

      // Version Control
      'Git',
      'GitHub/GitLab',

      // Containerization
      'Docker',
      'Docker Compose',
      'Container Orchestration',
      'Kubernetes',

      // CI/CD
      'Jenkins',
      'GitHub Actions',
      'GitLab CI',
      'Azure DevOps',

      // Infrastructure as Code
      'Terraform',
      'Ansible',
      'CloudFormation',
      'Pulumi',

      // Monitoring & Logging
      'Prometheus',
      'Grafana',
      'ELK Stack',
      'Datadog',

      // Cloud Providers
      'AWS',
      'Azure',
      'Google Cloud',
      'Digital Ocean',

      // Security
      'Security Best Practices',
      'SSL/TLS',
      'Firewalls',
      'VPN'
    ];

    final categories = [
      RoadmapCategory(
        id: 'fundamentals',
        title: 'DevOps Fundamentals',
        description: 'Core concepts and foundational knowledge',
        icon: Icons.foundation,
        topics: devopsTopics.sublist(0, 8).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key)
        ).toList(),
        order: 0,
      ),
      RoadmapCategory(
        id: 'programming',
        title: 'Programming & Scripting',
        description: 'Essential programming skills for DevOps',
        icon: Icons.code,
        topics: devopsTopics.sublist(8, 12).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 8)
        ).toList(),
        order: 1,
      ),
      RoadmapCategory(
        id: 'containers',
        title: 'Containerization',
        description: 'Docker and container orchestration',
        icon: Icons.inventory_2,
        topics: devopsTopics.sublist(14, 18).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 14)
        ).toList(),
        order: 2,
      ),
      RoadmapCategory(
        id: 'cicd',
        title: 'CI/CD',
        description: 'Continuous integration and deployment',
        icon: Icons.sync,
        topics: devopsTopics.sublist(18, 22).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 18)
        ).toList(),
        order: 3,
      ),
      RoadmapCategory(
        id: 'infrastructure',
        title: 'Infrastructure as Code',
        description: 'Automate infrastructure provisioning',
        icon: Icons.architecture,
        topics: devopsTopics.sublist(22, 26).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 22)
        ).toList(),
        order: 4,
      ),
      RoadmapCategory(
        id: 'monitoring',
        title: 'Monitoring & Logging',
        description: 'Observability and system monitoring',
        icon: Icons.monitor,
        topics: devopsTopics.sublist(26, 30).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 26)
        ).toList(),
        order: 5,
      ),
      RoadmapCategory(
        id: 'cloud',
        title: 'Cloud Platforms',
        description: 'Major cloud service providers',
        icon: Icons.cloud,
        topics: devopsTopics.sublist(30, 34).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 30)
        ).toList(),
        order: 6,
      ),
    ];

    return MobileRoadmap(
      id: 'devops-extracted',
      title: 'DevOps Engineer Roadmap',
      description: 'Complete DevOps roadmap with ${devopsTopics.length} topics',
      role: LearningRole.devops,
      categories: categories,
    );
  }

  /// Build extracted Engineering Manager roadmap
  MobileRoadmap _buildExtractedEngineeringManagerRoadmap() {
    final managerTopics = [
      // Leadership Fundamentals
      'Leadership Principles',
      'Team Building',
      'Communication Skills',
      'Conflict Resolution',
      'Decision Making',
      'Delegation',
      'Motivation',
      'Coaching and Mentoring',

      // People Management
      'Hiring and Recruiting',
      'Performance Management',
      'Career Development',
      'One-on-Ones',
      'Feedback and Reviews',
      'Team Dynamics',
      'Remote Team Management',

      // Technical Leadership
      'Technical Strategy',
      'Architecture Decisions',
      'Code Reviews',
      'Technical Debt Management',
      'Technology Evaluation',
      'Engineering Standards',

      // Project Management
      'Agile Methodologies',
      'Scrum',
      'Kanban',
      'Sprint Planning',
      'Retrospectives',
      'Risk Management',
      'Resource Planning',
      'Timeline Management',

      // Business & Strategy
      'Business Acumen',
      'Product Strategy',
      'Stakeholder Management',
      'Budget Management',
      'ROI Analysis',
      'Cross-functional Collaboration',

      // Process & Quality
      'Engineering Processes',
      'Quality Assurance',
      'Testing Strategies',
      'DevOps Practices',
      'Incident Management',
      'Post-mortems',

      // Culture & Growth
      'Engineering Culture',
      'Diversity and Inclusion',
      'Team Scaling',
      'Organizational Design',
      'Change Management',
      'Innovation Management'
    ];

    final categories = [
      RoadmapCategory(
        id: 'leadership',
        title: 'Leadership Fundamentals',
        description: 'Core leadership and management skills',
        icon: Icons.people,
        topics: managerTopics.sublist(0, 8).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key)
        ).toList(),
        order: 0,
      ),
      RoadmapCategory(
        id: 'people',
        title: 'People Management',
        description: 'Managing and developing team members',
        icon: Icons.person,
        topics: managerTopics.sublist(8, 15).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 8)
        ).toList(),
        order: 1,
      ),
      RoadmapCategory(
        id: 'technical',
        title: 'Technical Leadership',
        description: 'Leading technical decisions and architecture',
        icon: Icons.engineering,
        topics: managerTopics.sublist(15, 21).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 15)
        ).toList(),
        order: 2,
      ),
      RoadmapCategory(
        id: 'project',
        title: 'Project Management',
        description: 'Managing projects and delivery',
        icon: Icons.assignment,
        topics: managerTopics.sublist(21, 29).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 21)
        ).toList(),
        order: 3,
      ),
      RoadmapCategory(
        id: 'business',
        title: 'Business & Strategy',
        description: 'Business acumen and strategic thinking',
        icon: Icons.business,
        topics: managerTopics.sublist(29, 35).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 29)
        ).toList(),
        order: 4,
      ),
      RoadmapCategory(
        id: 'process',
        title: 'Process & Quality',
        description: 'Engineering processes and quality management',
        icon: Icons.settings,
        topics: managerTopics.sublist(35, 41).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 35)
        ).toList(),
        order: 5,
      ),
      RoadmapCategory(
        id: 'culture',
        title: 'Culture & Growth',
        description: 'Building culture and scaling teams',
        icon: Icons.groups,
        topics: managerTopics.sublist(41).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 41)
        ).toList(),
        order: 6,
      ),
    ];

    return MobileRoadmap(
      id: 'engineering-manager-extracted',
      title: 'Engineering Manager Roadmap',
      description: 'Complete engineering management roadmap with ${managerTopics.length} topics',
      role: LearningRole.engineeringManager,
      categories: categories,
    );
  }

  /// Build frontend roadmap with extracted data from roadmap.sh
  MobileRoadmap _buildExtractedFrontendRoadmap() {
    final frontendTopics = [
      // Internet & Basics
      'Internet',
      'How does the internet work?',
      'What is HTTP?',
      'What is Domain Name?',
      'What is hosting?',
      'DNS and how it works?',
      'Browsers and how they work?',

      // HTML
      'HTML',
      'Learn the basics',
      'Writing Semantic HTML',
      'Forms and Validations',
      'Accessibility',
      'SEO Basics',

      // CSS
      'CSS',
      'Learn the basics',
      'Making Layouts',
      'Responsive Design',
      'Writing CSS',
      'Tailwind',
      'CSS Architecture',
      'CSS Preprocessors',
      'BEM',
      'Sass',
      'PostCSS',

      // JavaScript
      'JavaScript',
      'Learn the Basics',
      'Learn DOM Manipulation',
      'Fetch API / Ajax (XHR)',
      'TypeScript',

      // Version Control
      'Version Control Systems',
      'Git',
      'VCS Hosting',
      'GitHub',
      'GitLab',
      'Bitbucket',

      // Package Managers
      'Package Managers',
      'npm',
      'yarn',
      'pnpm',

      // Frameworks
      'Pick a Framework',
      'React',
      'Vue.js',
      'Angular',
      'Svelte',
      'Solid JS',
      'Qwik',

      // Build Tools
      'Build Tools',
      'Module Bundlers',
      'Webpack',
      'Vite',
      'Parcel',
      'Rollup',
      'esbuild',
      'SWC',

      // Linting & Formatting
      'Linters and Formatters',
      'ESLint',
      'Prettier',

      // Testing
      'Testing',
      'Jest',
      'Vitest',
      'Playwright',
      'Cypress',

      // Security
      'Web Security Basics',
      'Authentication Strategies',
      'CORS',
      'HTTPS',
      'Content Security Policy',
      'OWASP Security Risks',

      // Advanced Topics
      'Web Components',
      'Custom Elements',
      'HTML Templates',
      'Shadow DOM',
      'Type Checkers',

      // SSR & Frameworks
      'SSR',
      'Next.js',
      'Nuxt.js',
      'Svelte Kit',
      'react-router',

      // GraphQL
      'GraphQL',
      'Apollo',
      'Relay Modern',

      // Static Site Generators
      'Static Site Generators',
      'Astro',
      'Eleventy',
      'Vuepress',

      // Mobile & Desktop
      'Mobile Apps',
      'React Native',
      'Flutter',
      'Ionic',
      'Desktop Apps',
      'Electron',
      'Tauri',
      'Nodejs',

      // Performance
      'Performance Best Practices',
      'PRPL Pattern',
      'RAIL Model',
      'Performance Metrics',
      'Using Lighthouse',
      'Using DevTools',

      // Browser APIs
      'Browser APIs',
      'Storage',
      'Web Sockets',
      'Server Sent Events',
      'Service Workers',
      'Location',
      'Notifications',
      'Device Orientation',
      'Payments',
      'Credentials',

      // PWAs
      'PWAs'
    ];

    print('📊 [ROADMAP] Building extracted frontend roadmap with ${frontendTopics.length} topics');

    final categories = [
      RoadmapCategory(
        id: 'basics',
        title: 'Internet & Basics',
        description: 'Fundamental concepts of web development',
        icon: Icons.language,
        topics: frontendTopics.sublist(0, 7).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key)
        ).toList(),
        order: 0,
      ),
      RoadmapCategory(
        id: 'html-css',
        title: 'HTML & CSS',
        description: 'Markup and styling fundamentals',
        icon: Icons.web,
        topics: frontendTopics.sublist(7, 27).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 7)
        ).toList(),
        order: 1,
      ),
      RoadmapCategory(
        id: 'javascript',
        title: 'JavaScript & TypeScript',
        description: 'Programming language fundamentals',
        icon: Icons.code,
        topics: frontendTopics.sublist(27, 32).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 27)
        ).toList(),
        order: 2,
      ),
      RoadmapCategory(
        id: 'tools',
        title: 'Development Tools',
        description: 'Version control, package managers, and build tools',
        icon: Icons.build,
        topics: frontendTopics.sublist(32, 75).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 32)
        ).toList(),
        order: 3,
      ),
      RoadmapCategory(
        id: 'advanced',
        title: 'Advanced Topics',
        description: 'Security, performance, and modern web APIs',
        icon: Icons.rocket_launch,
        topics: frontendTopics.sublist(75).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 75)
        ).toList(),
        order: 4,
      ),
    ];

    return MobileRoadmap(
      id: 'frontend-extracted',
      title: 'Frontend Developer Roadmap',
      description: 'Complete roadmap extracted from roadmap.sh with ${frontendTopics.length} topics',
      role: LearningRole.frontend,
      categories: categories,
    );
  }

  /// Build extracted Full Stack roadmap
  MobileRoadmap _buildExtractedFullStackRoadmap() {
    final fullStackTopics = [
      // Frontend Fundamentals
      'HTML',
      'CSS',
      'JavaScript',
      'TypeScript',
      'React',
      'Vue.js',
      'Angular',
      'Responsive Design',

      // Backend Fundamentals
      'Node.js',
      'Express.js',
      'Python',
      'Django/Flask',
      'Java',
      'Spring Boot',
      'C#',
      'ASP.NET Core',

      // Databases
      'SQL',
      'PostgreSQL',
      'MySQL',
      'MongoDB',
      'Redis',
      'Database Design',

      // DevOps & Deployment
      'Git',
      'Docker',
      'CI/CD',
      'AWS/Azure/GCP',
      'Linux',
      'Nginx',

      // Full Stack Skills
      'API Design',
      'Authentication',
      'Security',
      'Testing',
      'Performance',
      'System Design'
    ];

    final categories = [
      RoadmapCategory(
        id: 'frontend',
        title: 'Frontend Development',
        description: 'Client-side technologies and frameworks',
        icon: Icons.web,
        topics: fullStackTopics.sublist(0, 8).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key)
        ).toList(),
        order: 0,
      ),
      RoadmapCategory(
        id: 'backend',
        title: 'Backend Development',
        description: 'Server-side technologies and frameworks',
        icon: Icons.dns,
        topics: fullStackTopics.sublist(8, 16).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 8)
        ).toList(),
        order: 1,
      ),
      RoadmapCategory(
        id: 'databases',
        title: 'Databases',
        description: 'Data storage and management',
        icon: Icons.storage,
        topics: fullStackTopics.sublist(16, 22).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 16)
        ).toList(),
        order: 2,
      ),
      RoadmapCategory(
        id: 'devops',
        title: 'DevOps & Deployment',
        description: 'Deployment and infrastructure',
        icon: Icons.cloud_upload,
        topics: fullStackTopics.sublist(22, 28).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 22)
        ).toList(),
        order: 3,
      ),
      RoadmapCategory(
        id: 'advanced',
        title: 'Advanced Full Stack',
        description: 'Advanced concepts and best practices',
        icon: Icons.rocket_launch,
        topics: fullStackTopics.sublist(28).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 28)
        ).toList(),
        order: 4,
      ),
    ];

    return MobileRoadmap(
      id: 'fullstack-extracted',
      title: 'Full Stack Developer Roadmap',
      description: 'Complete full stack development roadmap with ${fullStackTopics.length} topics',
      role: LearningRole.fullstack,
      categories: categories,
    );
  }

  /// Build roadmap using extracted data from roadmap.sh
  MobileRoadmap? _buildExtractedRoadmap(LearningRole role) {
    switch (role) {
      case LearningRole.backend:
        return _buildExtractedBackendRoadmap();
      case LearningRole.frontend:
        return _buildExtractedFrontendRoadmap();
      case LearningRole.devops:
        return _buildExtractedDevOpsRoadmap();
      case LearningRole.softwareArchitect:
        return _buildExtractedSoftwareArchitectRoadmap();
      case LearningRole.engineeringManager:
        return _buildExtractedEngineeringManagerRoadmap();
      case LearningRole.fullstack:
        return _buildExtractedFullStackRoadmap();
      default:
        return null;
    }
  }

  /// Build extracted Software Architect roadmap
  MobileRoadmap _buildExtractedSoftwareArchitectRoadmap() {
    final architectTopics = [
      // Architecture Fundamentals
      'Software Architecture Principles',
      'Design Patterns',
      'SOLID Principles',
      'Clean Architecture',
      'Domain-Driven Design',
      'Event-Driven Architecture',
      'Microservices Architecture',
      'Monolithic Architecture',

      // System Design
      'System Design Principles',
      'Scalability',
      'Performance',
      'Reliability',
      'Availability',
      'Consistency',
      'CAP Theorem',
      'Load Balancing',

      // Data Architecture
      'Database Design',
      'Data Modeling',
      'ACID Properties',
      'NoSQL vs SQL',
      'Data Warehousing',
      'Data Lakes',

      // Security Architecture
      'Security Principles',
      'Authentication',
      'Authorization',
      'Encryption',
      'Security Patterns',

      // Technology Leadership
      'Technical Decision Making',
      'Technology Evaluation',
      'Architecture Documentation',
      'Code Reviews',
      'Mentoring'
    ];

    final categories = [
      RoadmapCategory(
        id: 'fundamentals',
        title: 'Architecture Fundamentals',
        description: 'Core architectural principles and patterns',
        icon: Icons.architecture,
        topics: architectTopics.sublist(0, 8).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key)
        ).toList(),
        order: 0,
      ),
      RoadmapCategory(
        id: 'system-design',
        title: 'System Design',
        description: 'Designing scalable and reliable systems',
        icon: Icons.account_tree,
        topics: architectTopics.sublist(8, 16).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 8)
        ).toList(),
        order: 1,
      ),
      RoadmapCategory(
        id: 'data',
        title: 'Data Architecture',
        description: 'Data design and management strategies',
        icon: Icons.storage,
        topics: architectTopics.sublist(16, 22).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 16)
        ).toList(),
        order: 2,
      ),
      RoadmapCategory(
        id: 'security',
        title: 'Security Architecture',
        description: 'Security design and implementation',
        icon: Icons.security,
        topics: architectTopics.sublist(22, 27).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 22)
        ).toList(),
        order: 3,
      ),
      RoadmapCategory(
        id: 'leadership',
        title: 'Technology Leadership',
        description: 'Leading technical teams and decisions',
        icon: Icons.people,
        topics: architectTopics.sublist(27).asMap().entries.map((entry) =>
          _createSmartTopic(entry.value, entry.key + 27)
        ).toList(),
        order: 4,
      ),
    ];

    return MobileRoadmap(
      id: 'software-architect-extracted',
      title: 'Software Architect Roadmap',
      description: 'Complete software architecture roadmap with ${architectTopics.length} topics',
      role: LearningRole.softwareArchitect,
      categories: categories,
    );
  }

  /// Build fallback roadmap when roadmap.sh fails
  MobileRoadmap _buildFallbackRoadmap(LearningRole role) {
    switch (role) {
      case LearningRole.frontend:
        return _buildSmartFrontendRoadmap();
      case LearningRole.backend:
        return _buildSmartBackendRoadmap();
      default:
        return MobileRoadmaps.getRoadmap(role);
    }
  }

  /// Build smart backend roadmap with predefined data
  MobileRoadmap _buildSmartBackendRoadmap() {
    // Define the topics with smart defaults
    final topicNames = [
      'How the Internet Works',
      'JavaScript',
      'Python',
    ];

    // Use smart defaults for all backend topics - users can get AI analysis via chat
    final List<RoadmapTopic> topics = topicNames.asMap().entries.map((entry) {
      return _createSmartBackendTopic(entry.value, entry.key);
    }).toList();

    return MobileRoadmap(
      id: 'backend',
      title: 'Backend Developer Roadmap',
      description: 'Step by step guide to becoming a backend developer (powered by roadmap.sh)',
      role: LearningRole.backend,
      categories: [
        RoadmapCategory(
          id: 'fundamentals',
          title: 'Backend Fundamentals',
          description: 'Core concepts every backend developer should know',
          icon: Icons.dns,
          order: 1,
          topics: topics,
        ),
      ],
    );
  }

  /// Build smart frontend roadmap with predefined data
  MobileRoadmap _buildSmartFrontendRoadmap() {
    // Define the topics with smart defaults
    final topicNames = [
      'How the Internet Works',
      'HTML',
      'CSS',
      'JavaScript',
    ];

    // Use smart defaults for all topics - users can get AI analysis via chat
    final List<RoadmapTopic> topics = topicNames.asMap().entries.map((entry) {
      return _createSmartTopic(entry.value, entry.key);
    }).toList();

    return MobileRoadmap(
      id: 'frontend',
      title: 'Frontend Developer Roadmap',
      description: 'Step by step guide to becoming a frontend developer (powered by roadmap.sh)',
      role: LearningRole.frontend,
      categories: [
        RoadmapCategory(
          id: 'fundamentals',
          title: 'Web Fundamentals',
          description: 'Core concepts every frontend developer should know',
          icon: Icons.web,
          order: 1,
          topics: topics,
        ),
      ],
    );
  }

  /// Build roadmap from roadmap.sh data (AI analysis available via chat)
  Future<MobileRoadmap> _buildSmartRoadmap(LearningRole role) async {
    try {
      // First try to get real roadmap.sh data for comprehensive content
      print('📊 [ROADMAP] Fetching real roadmap data from roadmap.sh for ${role.name}');
      final fetchedData = await _fetchFromRoadmapSh(role);
      if (fetchedData != null) {
        print('📊 [ROADMAP] Successfully fetched real roadmap for ${role.name} with ${fetchedData.categories.length} categories');
        return fetchedData;
      }

      // Try extracted roadmap data as backup
      final extractedData = _buildExtractedRoadmap(role);
      if (extractedData != null) {
        print('📊 [ROADMAP] Using extracted roadmap data for ${role.name} with ${extractedData.categories.length} categories');
        return extractedData;
      }

      // No fallback - throw error to show loading state
      throw Exception('Unable to fetch roadmap data from roadmap.sh. Please check your internet connection and try again.');
    } catch (e) {
      print('Error building smart roadmap for ${role.name}: $e');
      // Don't return fallback - let UI handle loading state
      rethrow;
    }
  }

  /// Cache roadmap to persistent storage
  Future<void> _cacheRoadmap(String roleKey, MobileRoadmap roadmap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = roadmap.toJson();
      await prefs.setString('$_cacheKeyPrefix$roleKey', jsonEncode(json));
      await prefs.setString('$_timestampKeyPrefix$roleKey', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching roadmap for $roleKey: $e');
    }
  }

  /// Clear cached roadmap from persistent storage
  Future<void> _clearCachedRoadmap(String roleKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cacheKeyPrefix$roleKey');
      await prefs.remove('$_timestampKeyPrefix$roleKey');
    } catch (e) {
      print('Error clearing cached roadmap for $roleKey: $e');
    }
  }

  /// Create smart backend topic with predefined data
  RoadmapTopic _createSmartBackendTopic(String topicName, int index) {
    final smartData = _getSmartBackendTopicData(topicName);
    return RoadmapTopic(
      id: topicName.toLowerCase().replaceAll(' ', '-'),
      name: topicName,
      description: smartData['description'],
      difficulty: smartData['difficulty'],
      estimatedHours: smartData['hours'],
      prerequisites: [],
      keyConcepts: smartData['concepts'],
      resources: [],
    );
  }

  /// Create smart topic with predefined data to avoid API calls
  RoadmapTopic _createSmartTopic(String topicName, int index) {
    final smartData = _getSmartTopicData(topicName);
    return RoadmapTopic(
      id: topicName.toLowerCase().replaceAll(' ', '-'),
      name: topicName,
      description: smartData['description'],
      difficulty: smartData['difficulty'],
      estimatedHours: smartData['hours'],
      prerequisites: [],
      keyConcepts: smartData['concepts'],
      resources: [],
    );
  }

  /// Extract roadmap data from HTML content (roadmap.sh uses dynamic loading)
  List<String> _extractRoadmapTopics(String htmlContent, LearningRole role) {
    final List<String> topics = [];

    try {
      print('📊 [ROADMAP] Extracting topics from ${htmlContent.length} chars of HTML');

      // Method 1: Look for frontend terms in the content (since roadmap.sh loads dynamically)
      final roleBasedTopics = _getRoleBasedTopics(role);
      for (final topic in roleBasedTopics) {
        if (htmlContent.toLowerCase().contains(topic.toLowerCase())) {
          topics.add(topic);
        }
      }

      // Method 2: Extract from script tags that might contain roadmap data
      final scriptMatches = RegExp(r'<script[^>]*>(.*?)</script>', multiLine: true, dotAll: true).allMatches(htmlContent);
      for (final match in scriptMatches) {
        final scriptContent = match.group(1) ?? '';
        if (scriptContent.contains('roadmap') || scriptContent.contains('frontend')) {
          // Try to extract quoted strings that might be topic names
          final quotedMatches = RegExp(r'"([A-Za-z][A-Za-z\s\-\.]{2,25})"').allMatches(scriptContent);
          for (final quotedMatch in quotedMatches) {
            final quoted = quotedMatch.group(1)?.trim();
            if (quoted != null && _isValidTopicName(quoted)) {
              topics.add(quoted);
            }
          }
        }
      }

      // Method 3: Look for meta descriptions and structured data
      final metaMatches = RegExp(r'<meta[^>]*content="([^"]*)"[^>]*>', multiLine: true).allMatches(htmlContent);
      for (final match in metaMatches) {
        final content = match.group(1) ?? '';
        if (content.toLowerCase().contains('frontend') || content.toLowerCase().contains('developer')) {
          final words = content.split(RegExp(r'[,\s]+'));
          for (final word in words) {
            if (_isValidTopicName(word.trim())) {
              topics.add(word.trim());
            }
          }
        }
      }

      print('📊 [ROADMAP] Extracted ${topics.length} topics from HTML analysis');
    } catch (e) {
      print('📊 [ROADMAP] Error extracting topics: $e');
    }

    return topics;
  }

  /// Fetch roadmap data from roadmap.sh
  Future<MobileRoadmap?> _fetchFromRoadmapSh(LearningRole role) async {
    final roleUrl = _getRoadmapShUrl(role);
    if (roleUrl == null) return null;

    try {
      final response = await _apiService.fetchRoadmapFromUrl(roleUrl);
      if (response['success'] == true && response['data'] != null) {
        return _parseRoadmapShData(response['data'], role);
      }
    } catch (e) {
      print('Error fetching roadmap.sh data: $e');
    }

    return null;
  }

  /// Get cached roadmap from persistent storage
  Future<MobileRoadmap?> _getCachedRoadmap(String roleKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('$_cacheKeyPrefix$roleKey');
      if (cachedJson != null) {
        final Map<String, dynamic> json = jsonDecode(cachedJson);
        return MobileRoadmap.fromJson(json);
      }
    } catch (e) {
      print('Error loading cached roadmap for $roleKey: $e');
    }
    return null;
  }

  /// Get cache timestamp from persistent storage
  Future<DateTime?> _getCacheTimestamp(String roleKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString('$_timestampKeyPrefix$roleKey');
      if (timestampStr != null) {
        return DateTime.parse(timestampStr);
      }
    } catch (e) {
      print('Error loading cache timestamp for $roleKey: $e');
    }
    return null;
  }

  /// Get fallback roles when API fails (only verified roadmaps)
  List<RoadmapRole> _getFallbackRoles() {
    return [
      const RoadmapRole(
        id: 'backend',
        name: 'Backend',
        path: '/backend',
        url: 'https://roadmap.sh/backend',
      ),
      const RoadmapRole(
        id: 'frontend',
        name: 'Frontend',
        path: '/frontend',
        url: 'https://roadmap.sh/frontend',
      ),
      const RoadmapRole(
        id: 'devops',
        name: 'DevOps',
        path: '/devops',
        url: 'https://roadmap.sh/devops',
      ),
      const RoadmapRole(
        id: 'software-architect',
        name: 'Software Architect',
        path: '/software-architect',
        url: 'https://roadmap.sh/software-architect',
      ),
      const RoadmapRole(
        id: 'engineering-manager',
        name: 'Engineering Manager',
        path: '/engineering-manager',
        url: 'https://roadmap.sh/engineering-manager',
      ),
      const RoadmapRole(
        id: 'fullstack',
        name: 'Full Stack',
        path: '/full-stack',
        url: 'https://roadmap.sh/full-stack',
      ),
      const RoadmapRole(
        id: 'android',
        name: 'Android',
        path: '/android',
        url: 'https://roadmap.sh/android',
      ),
      const RoadmapRole(
        id: 'gamedeveloper',
        name: 'Game Developer',
        path: '/game-developer',
        url: 'https://roadmap.sh/game-developer',
      ),
    ];
  }

  /// Get roadmap.sh URL for role (verified URLs only)
  String? _getRoadmapShUrl(LearningRole role) {
    switch (role) {
      case LearningRole.backend:
        return 'https://roadmap.sh/backend';
      case LearningRole.frontend:
        return 'https://roadmap.sh/frontend';
      case LearningRole.devops:
        return 'https://roadmap.sh/devops';
      case LearningRole.softwareArchitect:
        return 'https://roadmap.sh/software-architect';
      case LearningRole.engineeringManager:
        return 'https://roadmap.sh/engineering-manager';
      case LearningRole.fullstack:
        return 'https://roadmap.sh/full-stack';
      default:
        // Only return URLs for verified roadmaps
        // Other roles will use extracted/fallback data
        return null;
    }
  }

  /// Get role-based topics that we expect to find
  List<String> _getRoleBasedTopics(LearningRole role) {
    switch (role) {
      case LearningRole.frontend:
        return [
          'HTML', 'CSS', 'JavaScript', 'TypeScript', 'React', 'Vue', 'Angular',
          'Webpack', 'Vite', 'Sass', 'Tailwind', 'Bootstrap', 'jQuery',
          'Node.js', 'npm', 'Git', 'GitHub', 'VS Code', 'Chrome DevTools',
          'Responsive Design', 'Web APIs', 'DOM', 'AJAX', 'Fetch API',
          'ES6+', 'Babel', 'ESLint', 'Prettier', 'Testing', 'Jest'
        ];
      case LearningRole.backend:
        return [
          'Node.js', 'Python', 'Java', 'Go', 'Rust', 'PHP', 'C#',
          'Express', 'Django', 'Spring', 'FastAPI', 'Laravel',
          'Database', 'SQL', 'PostgreSQL', 'MongoDB', 'Redis',
          'API', 'REST', 'GraphQL', 'Authentication', 'JWT',
          'Docker', 'Kubernetes', 'AWS', 'Azure', 'GCP'
        ];
      default:
        return [
          'Programming', 'Web Development', 'Software Engineering',
          'Computer Science', 'Algorithms', 'Data Structures'
        ];
    }
  }

  /// Get display name for role
  String _getRoleDisplayName(LearningRole role) {
    switch (role) {
      case LearningRole.frontend:
        return 'Frontend Developer';
      case LearningRole.backend:
        return 'Backend Developer';
      case LearningRole.fullstack:
        return 'Full Stack Developer';
      case LearningRole.devops:
        return 'DevOps Engineer';
      case LearningRole.dataScience:
        return 'Data Scientist';
      case LearningRole.android:
        return 'Android Developer';
      default:
        return 'Developer';
    }
  }

  /// Get smart predefined data for backend topics
  Map<String, dynamic> _getSmartBackendTopicData(String topicName) {
    switch (topicName.toLowerCase()) {
      case 'how the internet works':
        return {
          'description': 'Understand internet protocols, HTTP/HTTPS, DNS, and how data flows across networks.',
          'difficulty': DifficultyLevel.fundamentals,
          'hours': 8,
          'concepts': ['HTTP/HTTPS', 'DNS', 'TCP/IP', 'Network Protocols'],
        };
      case 'javascript':
        return {
          'description': 'Learn JavaScript for backend development with Node.js, async programming, and server-side concepts.',
          'difficulty': DifficultyLevel.intermediate,
          'hours': 25,
          'concepts': ['Node.js', 'Async/Await', 'Express.js', 'NPM'],
        };
      case 'python':
        return {
          'description': 'Master Python for backend development including frameworks like Django/Flask and database integration.',
          'difficulty': DifficultyLevel.intermediate,
          'hours': 30,
          'concepts': ['Django/Flask', 'Database ORM', 'REST APIs', 'Virtual Environments'],
        };
      default:
        return {
          'description': 'Learn about $topicName fundamentals for backend development.',
          'difficulty': DifficultyLevel.fundamentals,
          'hours': 12,
          'concepts': ['Core Concepts', 'Best Practices'],
        };
    }
  }

  /// Get smart description for topics
  String _getSmartDescription(String topicName) {
    return _getSmartTopicData(topicName)['description'];
  }

  /// Get smart key concepts for topics
  List<String> _getSmartKeyConcepts(String topicName) {
    return _getSmartTopicData(topicName)['concepts'];
  }

  /// Get smart predefined data for common topics
  Map<String, dynamic> _getSmartTopicData(String topicName) {
    switch (topicName.toLowerCase()) {
      case 'html':
        return {
          'description': 'Learn HTML fundamentals including semantic markup, forms, and accessibility best practices.',
          'difficulty': DifficultyLevel.fundamentals,
          'hours': 6,
          'concepts': ['Semantic HTML', 'Forms', 'Accessibility', 'Document Structure'],
        };
      case 'css':
        return {
          'description': 'Master CSS styling, layouts, responsive design, and modern CSS features like Grid and Flexbox.',
          'difficulty': DifficultyLevel.fundamentals,
          'hours': 12,
          'concepts': ['Flexbox', 'Grid', 'Responsive Design', 'CSS Variables'],
        };
      case 'javascript':
        return {
          'description': 'Learn JavaScript fundamentals, DOM manipulation, async programming, and ES6+ features.',
          'difficulty': DifficultyLevel.intermediate,
          'hours': 20,
          'concepts': ['DOM Manipulation', 'Async/Await', 'ES6+', 'Event Handling'],
        };
      default:
        return {
          'description': 'Learn about $topicName fundamentals and core concepts.',
          'difficulty': DifficultyLevel.fundamentals,
          'hours': 8,
          'concepts': ['Core Concepts', 'Best Practices'],
        };
    }
  }

  /// Check if a string is a valid topic name
  bool _isValidTopicName(String name) {
    if (name.length < 2 || name.length > 30) return false;
    if (name.contains('http') || name.contains('.com')) return false;
    if (name.contains('@') || name.contains('#')) return false;
    if (RegExp(r'^\d+$').hasMatch(name)) return false; // Only numbers
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9\s\-\.\+#]*$').hasMatch(name)) return false;

    // Filter out common non-topic words
    final excludeWords = ['the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'];
    if (excludeWords.contains(name.toLowerCase())) return false;

    return true;
  }

  /// Parse difficulty level from backend response
  DifficultyLevel _parseDifficulty(String? difficulty) {
    if (difficulty == null) return DifficultyLevel.fundamentals;

    final lower = difficulty.toLowerCase();
    if (lower.contains('beginner') || lower.contains('fundamental')) {
      return DifficultyLevel.fundamentals;
    } else if (lower.contains('intermediate')) {
      return DifficultyLevel.intermediate;
    } else if (lower.contains('advanced')) {
      return DifficultyLevel.advanced;
    } else if (lower.contains('expert')) {
      return DifficultyLevel.expert;
    }

    return DifficultyLevel.fundamentals;
  }

  /// Parse estimated hours from backend response
  int _parseEstimatedHours(String? estimatedTime) {
    if (estimatedTime == null) return 8;

    // Try to extract numbers from strings like "2-4 hours", "8 hours", etc.
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(estimatedTime);

    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 8;
    }

    return 8;
  }

  /// Parse roadmap.sh HTML/JSON data into our MobileRoadmap format
  MobileRoadmap _parseRoadmapShData(dynamic data, LearningRole role) {
    try {
      // Extract topics from roadmap.sh content
      final List<RoadmapTopic> topics = [];

      // Parse the content based on roadmap.sh structure
      if (data is Map && data['content'] != null) {
        final content = data['content'] as String;
        print('📊 [ROADMAP] Parsing content length: ${content.length}');

        // Try multiple patterns to extract roadmap topics
        List<String> topicNames = [];

        // Extract topics from HTML content (roadmap.sh uses dynamic loading)
        final extractedTopics = _extractRoadmapTopics(content, role);
        topicNames.addAll(extractedTopics);

        // Pattern 2: Look for data attributes in SVG elements that might contain topic info
        final dataMatches = RegExp(r'data-[^=]*="([^"]*)"', multiLine: true).allMatches(content);
        final dataValues = dataMatches
            .map((match) => match.group(1)?.trim())
            .where((name) => name != null && name.isNotEmpty && name.length > 2 && !name.contains('http'))
            .cast<String>()
            .toList();

        print('📊 [ROADMAP] Found ${dataValues.length} data attribute values');
        topicNames.addAll(dataValues);

        // Pattern 3: Look for astro-island components which might contain roadmap data
        final astroMatches = RegExp(r'<astro-island[^>]*props="([^"]*)"', multiLine: true).allMatches(content);
        for (final match in astroMatches) {
          final propsJson = match.group(1);
          if (propsJson != null) {
            try {
              // Try to extract topic names from JSON props
              final decoded = Uri.decodeComponent(propsJson);
              final topicMatches = RegExp(r'"([^"]{3,})"').allMatches(decoded);
              final extractedTopics = topicMatches
                  .map((m) => m.group(1)?.trim())
                  .where((name) => name != null && name.isNotEmpty && !name.contains('http') && !name.contains('.'))
                  .cast<String>()
                  .toList();
              topicNames.addAll(extractedTopics);
              print('📊 [ROADMAP] Extracted ${extractedTopics.length} topics from astro-island props');
            } catch (e) {
              print('📊 [ROADMAP] Error parsing astro-island props: $e');
            }
          }
        }

        // Clean and filter topic names
        topicNames = topicNames
            .where((name) => name.length >= 3 && name.length <= 50) // Reasonable length
            .where((name) => !name.contains('http')) // Remove URLs
            .where((name) => !name.contains('.js') && !name.contains('.css')) // Remove file extensions
            .where((name) => RegExp(r'^[a-zA-Z0-9\s\-\+\#\.]+$').hasMatch(name)) // Only valid characters
            .map((name) => name.trim())
            .toSet() // Remove duplicates
            .toList();

        print('📊 [ROADMAP] Filtered to ${topicNames.length} valid topics');

        // Sort by relevance (shorter, more common terms first)
        topicNames.sort((a, b) {
          // Prioritize common frontend/backend terms
          final commonTerms = ['HTML', 'CSS', 'JavaScript', 'React', 'Node.js', 'Python', 'API', 'Database'];
          final aIsCommon = commonTerms.any((term) => a.toLowerCase().contains(term.toLowerCase()));
          final bIsCommon = commonTerms.any((term) => b.toLowerCase().contains(term.toLowerCase()));

          if (aIsCommon && !bIsCommon) return -1;
          if (!aIsCommon && bIsCommon) return 1;

          // Then by length (shorter first)
          return a.length.compareTo(b.length);
        });

        // Take the best topics (limit to prevent overwhelming UI)
        topicNames = topicNames.take(12).toList();

        for (int i = 0; i < topicNames.length; i++) {
          final topicName = topicNames[i];
          topics.add(_createSmartTopic(topicName, i));
        }

        print('📊 [ROADMAP] Created ${topics.length} roadmap topics');
      }

      // If no topics found, use fallback
      if (topics.isEmpty) {
        return _buildFallbackRoadmap(role);
      }

      return MobileRoadmap(
        id: role.name,
        title: '${_getRoleDisplayName(role)} Roadmap',
        description: 'Comprehensive learning path from roadmap.sh',
        role: role,
        categories: [
          RoadmapCategory(
            id: 'main',
            title: 'Learning Path',
            description: 'Step-by-step progression from roadmap.sh',
            icon: Icons.route,
            topics: topics,
            order: 0,
          ),
        ],
      );
    } catch (e) {
      print('Error parsing roadmap.sh data: $e');
      return _buildFallbackRoadmap(role);
    }
  }
}


