import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/enhanced_roadmap_models.dart';
import '../services/enhanced_roadmap_service.dart';
import '../theme/app_theme.dart';

class FlatEnhancedRoadmapWidget extends StatefulWidget {
  final LearningRole role;
  final Function(String topic)? onTopicSelected;

  const FlatEnhancedRoadmapWidget({
    super.key,
    this.role = LearningRole.frontend,
    this.onTopicSelected,
  });

  @override
  State<FlatEnhancedRoadmapWidget> createState() => _FlatEnhancedRoadmapWidgetState();
}

class _FlatEnhancedRoadmapWidgetState extends State<FlatEnhancedRoadmapWidget> {
  final EnhancedRoadmapService _roadmapService = EnhancedRoadmapService();
  
  EnhancedRoadmap? _roadmap;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final Set<String> _expandedCategories = {};
  Timer? _searchDebounceTimer;
  final TextEditingController _searchController = TextEditingController();

  List<EnhancedRoadmapCategory> get _filteredCategories {
    if (_roadmap == null) return [];
    
    if (_searchQuery.isEmpty) {
      return _roadmap!.categories;
    }
    
    return _roadmap!.categories.map((category) {
      final filteredTopics = category.topics.where((topic) {
        final query = _searchQuery.toLowerCase();
        return topic.title.toLowerCase().contains(query) ||
               topic.description.toLowerCase().contains(query) ||
               topic.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
      
      // Return category with filtered topics
      return EnhancedRoadmapCategory(
        id: category.id,
        title: category.title,
        description: category.description,
        icon: category.icon,
        topics: filteredTopics,
        order: category.order,
        estimatedHours: category.estimatedHours,
        topicCount: filteredTopics.length,
      );
    }).where((category) => 
      category.topics.isNotEmpty || 
      category.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      category.description.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return _buildLoadingState(theme, isDark);
    }

    if (_error != null) {
      return _buildErrorState(theme, isDark);
    }

    return Column(
      children: [
        // Clean search bar
        _buildSearchBar(theme, isDark),
        
        // Flat tree view
        Expanded(
          child: _filteredCategories.isEmpty
              ? _buildEmptyState(theme, isDark)
              : _buildFlatTreeView(theme, isDark),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(FlatEnhancedRoadmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      print('🔄 [FLAT_ROADMAP] Role changed from ${oldWidget.role.displayName} to ${widget.role.displayName}');
      _loadRoadmap();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRoadmap();
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : AppColors.lightBorder.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No learning topics found',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : AppColors.lightBorder.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to load roadmap',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkCard : AppColors.lightCard).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder.withValues(alpha: 0.2) : AppColors.lightBorder.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Unable to load asset: "assets/roadmaps/${widget.role.id}-enhanced.json"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The asset does not exist or has empty data.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadRoadmap,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatCategoryNode(EnhancedRoadmapCategory category, ThemeData theme, bool isDark) {
    final isExpanded = _expandedCategories.contains(category.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Category header - flat design
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(category.id);
                } else {
                  _expandedCategories.add(category.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder.withValues(alpha: 0.2) : AppColors.lightBorder.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.03 : 0.015),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Category icon
                  Icon(
                    category.iconData,
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),

                  // Category info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (category.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            category.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Topic count and expand icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${category.topics.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Topics list - flat design
          if (isExpanded && category.topics.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...category.topics.map((topic) => _buildFlatTopicNode(topic, category, theme, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildFlatTopicNode(EnhancedRoadmapTopic topic, EnhancedRoadmapCategory category, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 32, bottom: 4),
      child: InkWell(
        onTap: () => _handleTopicTapWithPath(topic, category),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: topic.isCompleted
                ? (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: topic.isCompleted
                  ? (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Completion status
              Icon(
                topic.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: topic.isCompleted
                    ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                size: 16,
              ),
      
              const SizedBox(width: 8),
      
              // Topic info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        fontWeight: FontWeight.w500,
                        decoration: topic.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (topic.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        topic.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
      
              // Difficulty indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: topic.difficultyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  topic.difficulty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: topic.difficultyColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlatTreeView(ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        return _buildFlatCategoryNode(category, theme, isDark);
      },
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading ${widget.role.displayName} roadmap...',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.3)
              : AppColors.lightBorder.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search topics...',
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        style: TextStyle(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }

  String _generateLearningPrompt(EnhancedRoadmapTopic topic) {
    final roadmapTitle = _roadmap?.title ?? widget.role.displayName;

    return '''I want to learn about "${topic.title}" in the context of $roadmapTitle development.

Please provide:
1. Key concepts and fundamentals
2. Learning resources (books, documentation, tutorials)
3. Practical examples and exercises
4. Best practices and common patterns
5. How this relates to other $roadmapTitle topics

Topic difficulty: ${topic.difficulty}
Estimated time: ${topic.estimatedTime}

${topic.description.isNotEmpty ? 'Context: ${topic.description}' : ''}''';
  }

  void _handleTopicTap(EnhancedRoadmapTopic topic) {
    // Navigate to learning with topic context
    final context = this.context;
    if (context.mounted) {
      context.push('/editor', extra: {
        'initialPrompt': _generateLearningPrompt(topic),
        'mode': 'deepsearch',
      });
    }

    // Call callback if provided
    widget.onTopicSelected?.call(topic.title);
  }

  void _handleTopicTapWithPath(EnhancedRoadmapTopic topic, EnhancedRoadmapCategory category) {
    // Build the full path: Role > Category > Topic
    final roleName = widget.role.displayName;
    final categoryName = category.title;
    final topicName = topic.title;
    final fullPath = '$roleName > $categoryName > $topicName';

    final contextInfo = Uri.encodeComponent('{"role":"$roleName","category":"$categoryName","topic":"$topicName"}');
    final prompt = Uri.encodeComponent('Help me get more insights or help me learn about $fullPath.');

    // Use go_router navigation with full context
    context.push('/editor?prompt=$prompt&role=${widget.role.id}&context=$contextInfo');

    // Call callback if provided
    widget.onTopicSelected?.call(fullPath);
  }

  Future<void> _loadRoadmap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('📊 [FLAT_ROADMAP] Loading roadmap for ${widget.role.displayName} (ID: ${widget.role.id})');
      final roadmap = await _roadmapService.getRoadmap(widget.role);

      setState(() {
        _roadmap = roadmap;
        _isLoading = false;
        // Expand first category by default
        _expandedCategories.clear();
        if (roadmap.categories.isNotEmpty) {
          _expandedCategories.add(roadmap.categories.first.id);
        }
      });

      print('✅ [FLAT_ROADMAP] Successfully loaded ${roadmap.title} (ID: ${roadmap.id}) with ${roadmap.categories.length} categories');
      if (roadmap.categories.isNotEmpty) {
        print('📂 [FLAT_ROADMAP] First category: ${roadmap.categories.first.title}');
      }
    } catch (e) {
      print('❌ [FLAT_ROADMAP] Error loading roadmap: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
        });
      }
    });
  }
}
