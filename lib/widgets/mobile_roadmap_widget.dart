import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/roadmap_models.dart';
import '../services/roadmap_service.dart';
import '../theme/app_theme.dart';

class MobileRoadmapWidget extends StatefulWidget {
  final LearningRole role;
  final Function(String topic)? onTopicSelected;

  const MobileRoadmapWidget({
    super.key,
    this.role = LearningRole.frontend,
    this.onTopicSelected,
  });

  @override
  State<MobileRoadmapWidget> createState() => _MobileRoadmapWidgetState();
}

class _MobileRoadmapWidgetState extends State<MobileRoadmapWidget> {
  final RoadmapService _roadmapService = RoadmapService();
  MobileRoadmap? _roadmap;
  bool _isLoading = true;
  String? _error;
  String? _selectedTopicId;
  String _searchQuery = '';
  final Set<String> _expandedCategories = {};
  final Set<String> _expandedTopics = {};

  List<RoadmapCategory> get _filteredCategories {
    if (_roadmap == null || _searchQuery.isEmpty) {
      return _roadmap?.categories ?? [];
    }

    return _roadmap!.categories.map((category) {
      final filteredTopics = category.topics.where((topic) {
        final matchesSearch = _searchQuery.isEmpty ||
            topic.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            topic.description.toLowerCase().contains(_searchQuery.toLowerCase());
        
        return matchesSearch;
      }).toList();

      return RoadmapCategory(
        id: category.id,
        title: category.title,
        description: category.description,
        icon: category.icon,
        order: category.order,
        topics: filteredTopics,
      );
    }).where((category) => category.topics.isNotEmpty).toList();
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
        // Search and filters
        _buildSearchAndFilters(theme),

        // Roadmap content
        Expanded(
          child: _filteredCategories.isEmpty
              ? _buildEmptyState(theme)
              : _buildTreeView(theme),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(MobileRoadmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _loadRoadmap();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRoadmap();
  }

  Widget _buildConceptTreeNode(String concept, RoadmapTopic parentTopic, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return _buildTreeNode(
      icon: Icons.lightbulb_outline,
      title: concept,
      subtitle: null,
      isExpanded: false,
      hasChildren: false,
      onTap: () => _learnAboutConceptWithContext(concept, parentTopic), // Navigate to editor for concept learning
      level: 2,
      theme: theme,
    );
  }

  Widget _buildDifficultyDots(DifficultyLevel difficulty, Color color) {
    int filledDots = 0;
    switch (difficulty) {
      case DifficultyLevel.fundamentals:
        filledDots = 1;
        break;
      case DifficultyLevel.intermediate:
        filledDots = 2;
        break;
      case DifficultyLevel.advanced:
      case DifficultyLevel.expert:
        filledDots = 3;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isFilled = index < filledDots;
        return Container(
          margin: EdgeInsets.only(right: index < 2 ? 3 : 0),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isFilled ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }



  Widget _buildEmptyState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search terms or difficulty filters to discover new learning opportunities',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Roadmap Not Available',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'We\'re having trouble loading the latest roadmap data. Please check your connection and try again in a few minutes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadRoadmap,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    side: BorderSide(
                      color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),

                const SizedBox(width: 12),

                TextButton.icon(
                  onPressed: () => context.push('/chat'),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Ask AI Instead'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Tip: You can still get personalized learning advice through chat!',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder.withValues(alpha: 0.2) : AppColors.lightBorder.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnButton(RoadmapTopic topic, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? AppColors.darkAccent : AppColors.lightAccent,
            isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToLearning(topic),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  'Learn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Cognify logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.psychology_rounded,
                size: 40,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
            ),

            const SizedBox(height: 24),

            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Curating Your Learning Path',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _getWisdomText(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'This usually takes 2-5 minutes',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          // Search bar with modern styling
          Container(
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
              decoration: InputDecoration(
                hintText: 'Search learning topics...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 16,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Hint about AI analysis via chat
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkCard : AppColors.lightCard).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Need personalized learning advice? Ask the chat for AI-powered gap analysis and recommendations!',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText.withValues(alpha: 0.8) : AppColors.lightText.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopicTreeNode(RoadmapTopic topic, RoadmapCategory category, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isExpanded = _expandedTopics.contains(topic.id);
    final isSelected = _selectedTopicId == topic.id;
    final difficultyColor = _getDifficultyColor(topic.difficulty);

    return Column(
      children: [
        // Topic node
        _buildTreeNode(
          icon: Icons.article_outlined,
          title: topic.name,
          subtitle: topic.description,
          isExpanded: isExpanded,
          hasChildren: topic.keyConcepts.isNotEmpty,
          onTap: () {
            if (topic.keyConcepts.isEmpty) {
              // Leaf node - navigate to editor for learning
              _navigateToLearning(topic);
            } else {
              // Parent node - expand/collapse
              _selectTopic(topic);
              _toggleTopicExpansion(topic.id);
            }
          },
          level: 1,
          theme: theme,
          isSelected: isSelected,
          trailingWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDifficultyDots(topic.difficulty, difficultyColor),
              const SizedBox(width: 12),
              Text(
                '${topic.estimatedHours}h',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Key concepts (leaf nodes)
        if (isExpanded)
          ...topic.keyConcepts.map((concept) => _buildConceptTreeNode(concept, topic, theme)),
      ],
    );
  }

  Widget _buildTreeCategoryNode(RoadmapCategory category, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isExpanded = _expandedCategories.contains(category.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Root category node - same design as children
          _buildTreeNode(
            icon: category.icon,
            title: category.title,
            subtitle: category.description,
            isExpanded: isExpanded,
            hasChildren: category.topics.isNotEmpty,
            onTap: () => _toggleCategoryExpansion(category.id),
            level: 0,
            theme: theme,
            trailingWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${category.topics.length} topics',
                style: TextStyle(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Child topic nodes
          if (isExpanded)
            ...category.topics.map((topic) => _buildTopicTreeNode(topic, category, theme)),
        ],
      ),
    );
  }

  Widget _buildTreeNode({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isExpanded,
    required bool hasChildren,
    required VoidCallback onTap,
    required int level,
    required ThemeData theme,
    bool isSelected = false,
    Widget? trailingWidget,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final indentWidth = level * 24.0;

    return Container(
      margin: EdgeInsets.only(
        left: indentWidth,
        bottom: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1)
                  : (isDark ? AppColors.darkCard : AppColors.lightCard),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                    : (isDark ? AppColors.darkBorder.withValues(alpha: 0.2) : AppColors.lightBorder.withValues(alpha: 0.15)),
                width: isSelected ? 2 : 1,
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
                // Tree connector and expand/collapse icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tree branch lines
                    if (level > 0) ...[
                      Container(
                        width: 20,
                        height: 1,
                        color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Expand/collapse icon or node indicator
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: hasChildren
                          ? Icon(
                              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                              size: 16,
                              color: (isDark ? AppColors.darkText : AppColors.lightText),
                            )
                          : Icon(
                              icon,
                              size: 14,
                              color: (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: level == 0 ? FontWeight.w700 : FontWeight.w600,
                          fontSize: level == 0 ? 18 : (level == 1 ? 16 : 14),
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            height: 1.3,
                            fontSize: level == 0 ? 13 : 12,
                          ),
                          maxLines: level == 0 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing widget
                if (trailingWidget != null) ...[
                  const SizedBox(width: 8),
                  trailingWidget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreeView(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        return _buildTreeCategoryNode(category, theme);
      },
    );
  }

  String _createLearningPrompt(RoadmapTopic topic) {
    final roleContext = widget.role.displayName;
    final keyConcepts = topic.keyConcepts.isNotEmpty
        ? topic.keyConcepts.take(3).join(', ')
        : 'core concepts';

    return "I want to learn ${topic.name} for $roleContext development. "
           "Please provide:\n\n"
           "• **Key Points**: What is ${topic.name} and why it matters\n"
           "• **Learning Resources**: Latest and most acclaimed books, tutorials, documentation, courses, and websites\n\n"
           "Focus on $keyConcepts. Prioritize recent, high-quality sources from 2023-2024.";
  }

  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.fundamentals:
        return Colors.green;
      case DifficultyLevel.intermediate:
        return Colors.orange;
      case DifficultyLevel.advanced:
        return Colors.red;
      case DifficultyLevel.expert:
        return Colors.purple;
    }
  }

  String _getDifficultyLabel(DifficultyLevel difficulty) {
    switch (difficulty) {
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

  String _getWisdomText() {
    final wisdomTexts = [
      "\"The expert in anything was once a beginner.\" - Helen Hayes",
      "\"Learning never exhausts the mind.\" - Leonardo da Vinci",
      "\"The more you learn, the more you realize you don't know.\" - Aristotle",
      "\"Education is the most powerful weapon to change the world.\" - Nelson Mandela",
      "\"Live as if you were to die tomorrow. Learn as if you were to live forever.\" - Gandhi",
      "\"The beautiful thing about learning is that no one can take it away from you.\" - B.B. King",
      "\"An investment in knowledge pays the best interest.\" - Benjamin Franklin",
      "\"The capacity to learn is a gift; the ability to learn is a skill; the willingness to learn is a choice.\" - Brian Herbert",
      "\"Tell me and I forget, teach me and I may remember, involve me and I learn.\" - Benjamin Franklin",
      "\"The only source of knowledge is experience.\" - Albert Einstein",
    ];

    final now = DateTime.now();
    final index = now.millisecond % wisdomTexts.length;
    return wisdomTexts[index];
  }

  void _learnAboutConceptWithContext(String concept, RoadmapTopic parentTopic) async {
    // Create learning prompt for the concept with parent context
    final prompt = "I want to learn about $concept in ${parentTopic.name} for ${widget.role.displayName} development. "
                  "Please provide:\n\n"
                  "• **Key Points**: What is $concept and why it's important in ${parentTopic.name}\n"
                  "• **Learning Resources**: Latest and most acclaimed books, tutorials, documentation, and courses\n\n"
                  "Prioritize recent, high-quality sources from 2023-2024.";

    // Navigate to editor with concept context
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'editorInitialData',
      jsonEncode({
        'content': prompt,
        'title': 'Learning: ${parentTopic.name} - $concept',
        'isNewConversation': true,
        'topicContext': {
          'topicId': '${parentTopic.id}_${concept.toLowerCase().replaceAll(' ', '_')}',
          'topicName': concept,
          'parentTopic': parentTopic.name,
          'role': widget.role.name,
          'difficulty': parentTopic.difficulty.displayName,
          'estimatedHours': 2,
        },
      }),
    );

    if (mounted) {
      context.push('/editor');
    }
  }

  void _loadRoadmap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fast loading with optimized roadmap service
      final roadmap = await _roadmapService.fetchRoadmap(widget.role);
      if (mounted) {
        setState(() {
          _roadmap = roadmap;
          _isLoading = false;
          // Expand the first category by default
          _expandedCategories.clear();
          if (_roadmap!.categories.isNotEmpty) {
            _expandedCategories.add(_roadmap!.categories.first.id);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToLearning(RoadmapTopic topic) async {
    // Create learning prompt for the topic
    final prompt = _createLearningPrompt(topic);

    // Navigate to editor with topic context
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'editorInitialData',
      jsonEncode({
        'content': prompt,
        'title': 'Learning: ${topic.name}',
        'isNewConversation': true,
        'topicContext': {
          'topicId': topic.id,
          'topicName': topic.name,
          'role': widget.role.name,
          'difficulty': topic.difficulty.displayName,
          'estimatedHours': topic.estimatedHours,
        },
      }),
    );

    if (mounted) {
      context.push('/editor');
    }
  }

  void _selectTopic(RoadmapTopic topic) {
    setState(() {
      _selectedTopicId = _selectedTopicId == topic.id ? null : topic.id;
    });
  }

  void _toggleCategoryExpansion(String categoryId) {
    setState(() {
      if (_expandedCategories.contains(categoryId)) {
        _expandedCategories.remove(categoryId);
      } else {
        _expandedCategories.add(categoryId);
      }
    });
  }

  void _toggleTopicExpansion(String topicId) {
    setState(() {
      if (_expandedTopics.contains(topicId)) {
        _expandedTopics.remove(topicId);
      } else {
        _expandedTopics.add(topicId);
      }
    });
  }
}
