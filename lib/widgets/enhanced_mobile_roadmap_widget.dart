import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../models/enhanced_roadmap_models.dart';
import '../services/enhanced_roadmap_service.dart';
import '../theme/app_theme.dart';

class EnhancedMobileRoadmapWidget extends StatefulWidget {
  final LearningRole role;
  final Function(String topic)? onTopicSelected;

  const EnhancedMobileRoadmapWidget({
    super.key,
    this.role = LearningRole.frontend,
    this.onTopicSelected,
  });

  @override
  State<EnhancedMobileRoadmapWidget> createState() => _EnhancedMobileRoadmapWidgetState();
}

class _EnhancedMobileRoadmapWidgetState extends State<EnhancedMobileRoadmapWidget>
    with AutomaticKeepAliveClientMixin {
  final EnhancedRoadmapService _roadmapService = EnhancedRoadmapService();

  EnhancedRoadmap? _roadmap;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  final Set<String> _expandedCategories = {};
  final Set<String> _expandedTopics = {};

  // Performance optimizations
  List<EnhancedRoadmapCategory>? _cachedFilteredCategories;
  String? _lastSearchQuery;
  String? _lastSelectedDifficulty;
  Timer? _searchDebounceTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true; // Keep widget state alive

  @override
  void initState() {
    super.initState();
    _loadRoadmap();
  }

  @override
  void didUpdateWidget(EnhancedMobileRoadmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      print('🔄 [ROADMAP] Role changed from ${oldWidget.role.displayName} to ${widget.role.displayName}');
      _invalidateCache(); // Clear cache when role changes
      _loadRoadmap();
    }
  }

  Future<void> _loadRoadmap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roadmap = await _roadmapService.getRoadmap(widget.role);
      setState(() {
        _roadmap = roadmap;
        _isLoading = false;
        // Expand first category by default
        if (roadmap.categories.isNotEmpty) {
          _expandedCategories.add(roadmap.categories.first.id);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<EnhancedRoadmapCategory> get _filteredCategories {
    if (_roadmap == null) return [];

    // Use cached results if filters haven't changed
    if (_cachedFilteredCategories != null &&
        _lastSearchQuery == _searchQuery &&
        _lastSelectedDifficulty == _selectedDifficulty) {
      return _cachedFilteredCategories!;
    }

    // Perform filtering
    final filtered = _roadmap!.categories.where((category) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final categoryMatch = category.title.toLowerCase().contains(query) ||
                             category.description.toLowerCase().contains(query);
        final topicMatch = category.topics.any((topic) =>
          topic.title.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query) ||
          topic.tags.any((tag) => tag.toLowerCase().contains(query))
        );
        if (!categoryMatch && !topicMatch) return false;
      }

      // Filter by difficulty
      if (_selectedDifficulty != 'All') {
        final hasMatchingTopics = category.topics.any((topic) =>
          topic.difficulty.toLowerCase() == _selectedDifficulty.toLowerCase()
        );
        if (!hasMatchingTopics) return false;
      }

      return true;
    }).toList();

    // Cache the results
    _cachedFilteredCategories = filtered;
    _lastSearchQuery = _searchQuery;
    _lastSelectedDifficulty = _selectedDifficulty;

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

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
        // Search and filters
        _buildSearchAndFilters(theme),

        // Roadmap stats
        if (_roadmap != null) _buildRoadmapStats(theme),

        // Roadmap content
        Expanded(
          child: _filteredCategories.isEmpty
              ? _buildEmptyState(theme)
              : _buildOptimizedCategoriesView(theme),
        ),
      ],
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

  Widget _buildErrorState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load roadmap',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRoadmap,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar with debouncing
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search topics...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.grey[800]
                  : Colors.grey[100],
            ),
            onChanged: _onSearchChanged,
          ),
          
          const SizedBox(height: 12),
          
          // Difficulty filter
          Row(
            children: [
              Text(
                'Difficulty:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Beginner', 'Intermediate', 'Advanced']
                        .map((difficulty) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(difficulty),
                                selected: _selectedDifficulty == difficulty,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedDifficulty = difficulty;
                                    _invalidateCache(); // Clear cache when filter changes
                                  });
                                },
                                selectedColor: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.2),
                                checkmarkColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapStats(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final roadmap = _roadmap!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Topics',
              '${roadmap.completedTopicsCount}/${roadmap.metadata.totalTopics}',
              Icons.article_outlined,
              theme,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Categories',
              '${roadmap.metadata.totalCategories}',
              Icons.category_outlined,
              theme,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Progress',
              '${(roadmap.totalCompletionPercentage * 100).toInt()}%',
              Icons.trending_up,
              theme,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Hours',
              '${roadmap.metadata.estimatedHours}h',
              Icons.schedule,
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No topics found',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedCategoriesView(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _filteredCategories.length,
      // Performance optimizations
      cacheExtent: 1000, // Cache more items for smoother scrolling
      addAutomaticKeepAlives: true, // Keep built items alive
      addRepaintBoundaries: true, // Optimize repainting
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        return _buildOptimizedCategoryCard(category, theme, index);
      },
    );
  }

  Widget _buildCategoriesView(ThemeData theme) {
    return _buildOptimizedCategoriesView(theme);
  }

  Widget _buildCategoryCard(EnhancedRoadmapCategory category, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isExpanded = _expandedCategories.contains(category.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Category header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(category.id);
                } else {
                  _expandedCategories.add(category.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.iconData,
                      color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Category info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats and expand icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${category.completedTopicsCount}/${category.topics.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Progress bar
          if (category.topics.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: category.completionPercentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

          // Topics list
          if (isExpanded) ...[
            const SizedBox(height: 8),
            ...category.topics.map((topic) => _buildTopicTile(topic, theme)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTopicTile(EnhancedRoadmapTopic topic, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => _handleTopicTap(topic),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: topic.isCompleted
                ? Colors.green.withValues(alpha: 0.3)
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
                  ? Colors.green
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              size: 20,
            ),

            const SizedBox(width: 12),

            // Topic info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: topic.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (topic.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      topic.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (topic.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: topic.tags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: topic.difficultyColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: topic.difficultyColor,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Difficulty and time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      topic.difficultyIcon,
                      color: topic.difficultyColor,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      topic.difficulty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: topic.difficultyColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${topic.estimatedHours}h',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  String _generateLearningPrompt(EnhancedRoadmapTopic topic) {
    final roadmapTitle = _roadmap?.title ?? widget.role.displayName;

    return '''I want to learn about "${topic.title}" in the context of ${roadmapTitle} development.

Please provide:
1. Key concepts and fundamentals
2. Learning resources (books, documentation, tutorials)
3. Practical examples and exercises
4. Best practices and common patterns
5. How this relates to other ${roadmapTitle} topics

Topic difficulty: ${topic.difficulty}
Estimated time: ${topic.estimatedTime}

${topic.description.isNotEmpty ? 'Context: ${topic.description}' : ''}''';
  }

  /// Performance optimization: Optimized category card with lazy loading
  Widget _buildOptimizedCategoryCard(EnhancedRoadmapCategory category, ThemeData theme, int index) {
    // Use RepaintBoundary to optimize repainting
    return RepaintBoundary(
      key: ValueKey('category_${category.id}'),
      child: _buildCategoryCard(category, theme),
    );
  }

  /// Clear cached filtered results
  void _invalidateCache() {
    _cachedFilteredCategories = null;
    _lastSearchQuery = null;
    _lastSelectedDifficulty = null;
  }

  /// Debounced search to improve performance
  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
          _invalidateCache(); // Clear cache when search changes
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _invalidateCache();
    super.dispose();
  }
}
