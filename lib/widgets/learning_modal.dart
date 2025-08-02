import 'package:flutter/material.dart';

import '../models/roadmap_models.dart';
import '../services/unified_api_service.dart';
import '../theme/app_theme.dart';

class LearningModal extends StatefulWidget {
  final RoadmapTopic topic;
  final String role;

  const LearningModal({
    super.key,
    required this.topic,
    this.role = 'frontend',
  });

  @override
  State<LearningModal> createState() => _LearningModalState();
}

class _LearningModalState extends State<LearningModal> {
  final UnifiedApiService _apiService = UnifiedApiService();
  Map<String, dynamic>? _topicData;
  bool _isLoading = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          _buildHeader(theme, isDark),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState(theme)
                : _error != null
                    ? _buildErrorState(theme)
                    : _buildContent(theme, isDark),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTopicData();
  }

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(
                '/editor',
                arguments: {
                  'prompt': 'Help me get more insights or help me learn about ${widget.topic.name}.'
                },
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Start Learning Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          _buildSection(
            title: 'Overview',
            content: _buildDescription(theme, isDark),
            theme: theme,
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // Key Points
          if (_topicData?['keyPoints'] != null)
            _buildSection(
              title: 'Key Learning Points',
              content: _buildKeyPoints(theme, isDark),
              theme: theme,
              isDark: isDark,
            ),

          const SizedBox(height: 24),

          // Resources
          if (_topicData?['resources'] != null && (_topicData!['resources'] as List).isNotEmpty)
            _buildSection(
              title: 'Resources',
              content: _buildResources(theme, isDark),
              theme: theme,
              isDark: isDark,
            ),

          const SizedBox(height: 32),

          // Action buttons
          _buildActionButtons(theme, isDark),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDescription(ThemeData theme, bool isDark) {
    final description = _topicData?['description'] ?? widget.topic.description;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        description,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.darkText : AppColors.lightText,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTopicData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Topic icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getDifficultyColor(widget.topic.difficulty).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDifficultyIcon(widget.topic.difficulty),
              color: _getDifficultyColor(widget.topic.difficulty),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Topic info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.topic.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(widget.topic.difficulty).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.topic.difficulty.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getDifficultyColor(widget.topic.difficulty),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.topic.estimatedHours}h',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPoints(ThemeData theme, bool isDark) {
    final keyPoints = _topicData?['keyPoints'] as List? ?? widget.topic.keyConcepts;
    
    return Column(
      children: keyPoints.map<Widget>((point) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  point.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading topic data...'),
        ],
      ),
    );
  }

  Widget _buildResources(ThemeData theme, bool isDark) {
    final resources = _topicData?['resources'] as List? ?? [];
    
    return Column(
      children: resources.map<Widget>((resource) {
        final title = resource['title'] ?? 'Resource';
        final url = resource['url'] ?? '#';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: url != '#' ? () {
              // TODO: Open URL in browser
            } : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 16,
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  if (url != '#')
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget content,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
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

  IconData _getDifficultyIcon(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.fundamentals:
        return Icons.foundation;
      case DifficultyLevel.intermediate:
        return Icons.trending_up;
      case DifficultyLevel.advanced:
        return Icons.rocket_launch;
      case DifficultyLevel.expert:
        return Icons.emoji_events;
    }
  }

  Future<void> _loadTopicData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use smart defaults for topic data - users can get AI analysis via chat
      setState(() {
        _topicData = {
          'topic': widget.topic.name,
          'description': widget.topic.description,
          'keyPoints': widget.topic.keyConcepts,
          'difficulty': widget.topic.difficulty.toString().split('.').last,
          'estimatedTime': '${widget.topic.estimatedHours} hours',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading topic data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}
