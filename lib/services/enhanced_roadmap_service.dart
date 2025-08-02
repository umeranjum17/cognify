import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enhanced_roadmap_models.dart';

/// Enhanced roadmap service that loads from local JSON assets
class EnhancedRoadmapService {
  static const String _cachePrefix = 'enhanced_roadmap_';
  static const Duration _cacheDuration = Duration(days: 30); // 1 month cache
  
  // Singleton pattern
  static final EnhancedRoadmapService _instance = EnhancedRoadmapService._internal();
  factory EnhancedRoadmapService() => _instance;
  EnhancedRoadmapService._internal();

  // In-memory cache for faster access
  final Map<String, EnhancedRoadmap> _memoryCache = {};
  
  /// Available roadmap IDs
  static const List<String> availableRoadmaps = [
    'ai-engineer',
    'backend',
    'engineering-manager',
    'frontend',
    'software-architect',
  ];

  /// Get roadmap by learning role
  Future<EnhancedRoadmap> getRoadmap(LearningRole role) async {
    return await getRoadmapById(role.id);
  }

  /// Get roadmap by ID
  Future<EnhancedRoadmap> getRoadmapById(String roadmapId) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(roadmapId)) {
        print('📊 [ENHANCED_ROADMAP] Using memory cache for $roadmapId');
        return _memoryCache[roadmapId]!;
      }

      // Check persistent cache
      final cachedRoadmap = await _getCachedRoadmap(roadmapId);
      if (cachedRoadmap != null) {
        final cacheTime = await _getCacheTimestamp(roadmapId);
        if (cacheTime != null) {
          final now = DateTime.now();
          if (now.difference(cacheTime) < _cacheDuration) {
            print('📊 [ENHANCED_ROADMAP] Using persistent cache for $roadmapId (${now.difference(cacheTime).inDays} days old)');
            _memoryCache[roadmapId] = cachedRoadmap;
            return cachedRoadmap;
          } else {
            print('📊 [ENHANCED_ROADMAP] Cache expired for $roadmapId, loading fresh data');
            await _clearCachedRoadmap(roadmapId);
          }
        }
      }

      // Load from assets
      final roadmap = await _loadRoadmapFromAssets(roadmapId);
      
      // Cache the result
      await _cacheRoadmap(roadmapId, roadmap);
      _memoryCache[roadmapId] = roadmap;
      
      print('📊 [ENHANCED_ROADMAP] Loaded and cached roadmap for $roadmapId');
      return roadmap;
      
    } catch (e) {
      print('❌ [ENHANCED_ROADMAP] Error loading roadmap $roadmapId: $e');
      rethrow;
    }
  }

  /// Load roadmap from assets
  Future<EnhancedRoadmap> _loadRoadmapFromAssets(String roadmapId) async {
    // Simple direct asset path - should work since files are in assets/roadmaps/
    final assetPath = 'assets/roadmaps/$roadmapId-enhanced.json';
    print('📄 [ENHANCED_ROADMAP] Loading from asset: $assetPath');
    
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      final roadmap = EnhancedRoadmap.fromJson(jsonData);
      print('✅ [ENHANCED_ROADMAP] Successfully loaded ${roadmap.title} with ${roadmap.categories.length} categories and ${roadmap.metadata.totalTopics} topics');
      
      return roadmap;
    } catch (e) {
      print('❌ [ENHANCED_ROADMAP] Failed to load roadmap from $assetPath: $e');
      throw Exception('Failed to load roadmap $roadmapId: Unable to load asset "$assetPath". The asset does not exist or has empty data.');
    }
  }

  /// Get all available roadmaps
  Future<List<EnhancedRoadmap>> getAllRoadmaps() async {
    final roadmaps = <EnhancedRoadmap>[];
    
    for (final roadmapId in availableRoadmaps) {
      try {
        final roadmap = await getRoadmapById(roadmapId);
        roadmaps.add(roadmap);
      } catch (e) {
        print('⚠️ [ENHANCED_ROADMAP] Failed to load roadmap $roadmapId: $e');
        // Continue loading other roadmaps
      }
    }
    
    return roadmaps;
  }

  /// Get roadmap index (metadata for all roadmaps)
  Future<Map<String, dynamic>> getRoadmapIndex() async {
    try {
      const assetPath = 'assets/roadmaps/roadmap-index-enhanced.json';
      final jsonString = await rootBundle.loadString(assetPath);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('❌ [ENHANCED_ROADMAP] Failed to load roadmap index: $e');
      return {};
    }
  }

  /// Update topic completion status
  Future<void> updateTopicCompletion(String roadmapId, String topicId, bool isCompleted) async {
    try {
      // Update memory cache
      if (_memoryCache.containsKey(roadmapId)) {
        final roadmap = _memoryCache[roadmapId]!;
        final topic = roadmap.getTopicById(topicId);
        if (topic != null) {
          final updatedTopic = topic.copyWith(isCompleted: isCompleted);
          
          // Find and update the topic in the category
          for (int i = 0; i < roadmap.categories.length; i++) {
            final category = roadmap.categories[i];
            for (int j = 0; j < category.topics.length; j++) {
              if (category.topics[j].id == topicId) {
                final updatedTopics = List<EnhancedRoadmapTopic>.from(category.topics);
                updatedTopics[j] = updatedTopic;
                
                final updatedCategory = EnhancedRoadmapCategory(
                  id: category.id,
                  title: category.title,
                  description: category.description,
                  icon: category.icon,
                  topics: updatedTopics,
                  order: category.order,
                  estimatedHours: category.estimatedHours,
                  topicCount: category.topicCount,
                );
                
                final updatedCategories = List<EnhancedRoadmapCategory>.from(roadmap.categories);
                updatedCategories[i] = updatedCategory;
                
                final updatedRoadmap = EnhancedRoadmap(
                  id: roadmap.id,
                  title: roadmap.title,
                  description: roadmap.description,
                  version: roadmap.version,
                  lastUpdated: roadmap.lastUpdated,
                  source: roadmap.source,
                  categories: updatedCategories,
                  metadata: roadmap.metadata,
                );
                
                _memoryCache[roadmapId] = updatedRoadmap;
                await _cacheRoadmap(roadmapId, updatedRoadmap);
                
                print('✅ [ENHANCED_ROADMAP] Updated topic $topicId completion: $isCompleted');
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ [ENHANCED_ROADMAP] Failed to update topic completion: $e');
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _memoryCache.clear();
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
    
    for (final key in keys) {
      await prefs.remove(key);
    }
    
    print('🧹 [ENHANCED_ROADMAP] Cleared all caches');
  }

  /// Cache roadmap to persistent storage
  Future<void> _cacheRoadmap(String roadmapId, EnhancedRoadmap roadmap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$roadmapId';
      final timestampKey = '${cacheKey}_timestamp';
      
      await prefs.setString(cacheKey, json.encode(roadmap.toJson()));
      await prefs.setString(timestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('⚠️ [ENHANCED_ROADMAP] Failed to cache roadmap $roadmapId: $e');
    }
  }

  /// Get cached roadmap from persistent storage
  Future<EnhancedRoadmap?> _getCachedRoadmap(String roadmapId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$roadmapId';
      final jsonString = prefs.getString(cacheKey);
      
      if (jsonString != null) {
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        return EnhancedRoadmap.fromJson(jsonData);
      }
    } catch (e) {
      print('⚠️ [ENHANCED_ROADMAP] Failed to get cached roadmap $roadmapId: $e');
    }
    return null;
  }

  /// Get cache timestamp
  Future<DateTime?> _getCacheTimestamp(String roadmapId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '${_cachePrefix}${roadmapId}_timestamp';
      final timestampString = prefs.getString(timestampKey);
      
      if (timestampString != null) {
        return DateTime.parse(timestampString);
      }
    } catch (e) {
      print('⚠️ [ENHANCED_ROADMAP] Failed to get cache timestamp for $roadmapId: $e');
    }
    return null;
  }

  /// Clear cached roadmap
  Future<void> _clearCachedRoadmap(String roadmapId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$roadmapId';
      final timestampKey = '${cacheKey}_timestamp';
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
    } catch (e) {
      print('⚠️ [ENHANCED_ROADMAP] Failed to clear cached roadmap $roadmapId: $e');
    }
  }

  /// Get roadmap statistics
  Future<Map<String, dynamic>> getRoadmapStats(String roadmapId) async {
    try {
      final roadmap = await getRoadmapById(roadmapId);
      
      return {
        'totalTopics': roadmap.metadata.totalTopics,
        'completedTopics': roadmap.completedTopicsCount,
        'completionPercentage': roadmap.totalCompletionPercentage,
        'totalCategories': roadmap.metadata.totalCategories,
        'estimatedHours': roadmap.metadata.estimatedHours,
        'difficulty': roadmap.metadata.difficulty,
        'tags': roadmap.metadata.tags,
        'prerequisites': roadmap.metadata.prerequisites,
      };
    } catch (e) {
      print('❌ [ENHANCED_ROADMAP] Failed to get roadmap stats: $e');
      return {};
    }
  }

}
