import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trending_topic.dart';

class TrendingTopicCard extends StatelessWidget {
  final TrendingTopic topic;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onSourceTap;

  const TrendingTopicCard({
    super.key,
    required this.topic,
    required this.index,
    required this.onTap,
    this.onSourceTap,
  });

  Color _getSourceColor(String sourceType, BuildContext context) {
    switch (sourceType) {
      case 'reddit':
        return const Color(0xFFFF4500);
      case 'hackernews':
        return const Color(0xFFFF6600);
      case 'github':
        return const Color(0xFF333333);
      case 'medium':
        return const Color(0xFF00AB6C);
      case 'devto':
        return const Color(0xFF0A0A0A);
      default:
        return Theme.of(context).primaryColor;
    }
  }

  IconData _getSourceIcon(String sourceType) {
    switch (sourceType) {
      case 'reddit':
        return Icons.forum;
      case 'hackernews':
        return Icons.article;
      case 'github':
        return Icons.code;
      case 'medium':
        return Icons.article;
      case 'devto':
        return Icons.developer_mode;
      default:
        return Icons.search;
    }
  }

  String _formatTimeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return difference.inMinutes <= 0 ? 'Just now' : '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  String _formatScore(TrendingTopicMetadata metadata) {
    if (metadata.stars != null && metadata.stars! > 0) return '${metadata.stars} ⭐';
    if (metadata.score != null && metadata.score! > 0) return '${metadata.score} ↑';
    if (metadata.reactions != null && metadata.reactions! > 0) return '${metadata.reactions} ❤️';
    if (metadata.comments != null && metadata.comments! > 0) return '${metadata.comments} 💬';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceColor = _getSourceColor(topic.source.type, context);

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: sourceColor,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Source Badge and Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getSourceIcon(topic.source.type),
                              size: 14,
                              color: sourceColor,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                topic.source.name,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: sourceColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimeAgo(topic.metadata.publishedAt),
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  topic.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Description
                if (topic.description.isNotEmpty)
                  Text(
                    topic.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 10),

                // Tags
                if (topic.metadata.tags.isNotEmpty)
                  Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: topic.metadata.tags.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 8,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const Spacer(),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.chat, size: 14),
                        label: const Text(
                          'Discuss',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (onSourceTap != null)
                      OutlinedButton.icon(
                        onPressed: onSourceTap,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text(
                          'Source',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Footer with score
                Center(
                  child: Text(
                    _formatScore(topic.metadata),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Relevance indicator
                if (topic.relevanceScore != null && topic.relevanceScore! > 0.8)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// List widget for trending topics (one per row)
class TrendingTopicsGrid extends StatelessWidget {
  final List<TrendingTopic> topics;
  final Function(TrendingTopic) onTopicPress;
  final Function(TrendingTopic)? onSourcePress;
  final bool loading;

  const TrendingTopicsGrid({
    super.key,
    required this.topics,
    required this.onTopicPress,
    this.onSourcePress,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(3, (index) =>
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
          ),
        ),
      );
    }

    if (topics.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up,
                size: 48,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(height: 16),
              Text(
                'No trending topics available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: topics.map((topic) =>
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: TrendingTopicListCard(
            topic: topic,
            onTopicPress: () => onTopicPress(topic),
            onSourcePress: onSourcePress != null ? () => onSourcePress!(topic) : null,
          ),
        ),
      ).toList(),
    );
  }
}

// New list-style card for trending topics
class TrendingTopicListCard extends StatelessWidget {
  final TrendingTopic topic;
  final VoidCallback onTopicPress;
  final VoidCallback? onSourcePress;

  const TrendingTopicListCard({
    super.key,
    required this.topic,
    required this.onTopicPress,
    this.onSourcePress,
  });

  Color _getSourceColor(String sourceType, BuildContext context) {
    switch (sourceType) {
      case 'reddit':
        return const Color(0xFFFF4500);
      case 'hackernews':
        return const Color(0xFFFF6600);
      case 'github':
        return const Color(0xFF333333);
      case 'medium':
        return const Color(0xFF00AB6C);
      case 'devto':
        return const Color(0xFF0A0A0A);
      default:
        return Theme.of(context).primaryColor;
    }
  }

  IconData _getSourceIcon(String sourceType) {
    switch (sourceType) {
      case 'reddit':
        return Icons.forum;
      case 'hackernews':
        return Icons.article;
      case 'github':
        return Icons.code;
      case 'medium':
        return Icons.article;
      case 'devto':
        return Icons.developer_mode;
      default:
        return Icons.search;
    }
  }

  String _formatTimeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return difference.inMinutes <= 0 ? 'Just now' : '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  String _formatScore(TrendingTopicMetadata metadata) {
    if (metadata.stars != null && metadata.stars! > 0) return '${metadata.stars} ⭐';
    if (metadata.score != null && metadata.score! > 0) return '${metadata.score} ↑';
    if (metadata.reactions != null && metadata.reactions! > 0) return '${metadata.reactions} ❤️';
    if (metadata.comments != null && metadata.comments! > 0) return '${metadata.comments} 💬';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceColor = _getSourceColor(topic.source.type, context);

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: sourceColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with source and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSourceIcon(topic.source.type),
                        size: 16,
                        color: sourceColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        topic.source.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sourceColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimeAgo(topic.metadata.publishedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              topic.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Description
            if (topic.description.isNotEmpty)
              Text(
                topic.description,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 12),

            // Tags and Score
            Row(
              children: [
                // Tags
                if (topic.metadata.tags.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: topic.metadata.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // Score
                if (_formatScore(topic.metadata).isNotEmpty)
                  Text(
                    _formatScore(topic.metadata),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onTopicPress,
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text(
                      'Discuss',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (onSourcePress != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSourcePress,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        'Source',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sourceColor,
                        side: BorderSide(color: sourceColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
