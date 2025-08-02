import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/roadmap_models.dart';
import '../theme/app_theme.dart';

class RoadmapTopicCard extends StatelessWidget {
  final RoadmapTopic topic;
  final VoidCallback? onTap;
  final bool showProgress;
  final LearningRole? currentRole;

  const RoadmapTopicCard({
    super.key,
    required this.topic,
    this.onTap,
    this.showProgress = true,
    this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getDifficultyColor(topic.difficulty).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with difficulty dots and completion status
              Row(
                children: [
                  _buildDifficultyDots(topic.difficulty, _getDifficultyColor(topic.difficulty)),
                  const Spacer(),
                  if (showProgress)
                    Icon(
                      topic.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: topic.isCompleted 
                          ? Colors.green 
                          : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      size: 20,
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Topic title
              Text(
                topic.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: topic.isCompleted 
                      ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)
                      : null,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Description
              Text(
                topic.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Key concepts chips
              if (topic.keyConcepts.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: topic.keyConcepts.take(3).map((concept) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? AppColors.darkSurface.withValues(alpha: 0.8)
                            : AppColors.lightSurface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        concept,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (topic.keyConcepts.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${topic.keyConcepts.length - 3} more',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              
              // Footer with time estimate and action buttons
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${topic.estimatedHours}h',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  if (topic.prerequisites.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.link,
                      size: 14,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${topic.prerequisites.length} prereq${topic.prerequisites.length != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _exploreWithAI(context),
                      icon: const Icon(Icons.psychology, size: 16),
                      label: const Text('Explore'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        foregroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isFilled ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Future<void> _exploreWithAI(BuildContext context) async {
    final prompt = _generateTopicPrompt();

    try {
      // Save topic context to SharedPreferences for editor screen
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
            'difficulty': topic.difficulty.name,
            'role': currentRole?.name ?? 'backend',
            'keyConcepts': topic.keyConcepts,
            'estimatedHours': topic.estimatedHours,
            'prerequisites': topic.prerequisites,
          }
        }),
      );

      // Navigate to editor
      context.push('/editor');
    } catch (e) {
      // Fallback: navigate with basic prompt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _generateTopicPrompt() {
    final roleContext = currentRole?.displayName ?? 'Backend Developer';
    final difficultyLevel = topic.difficulty.displayName.toLowerCase();

    // Generate contextual prompt based on difficulty and topic
    String prompt;

    final keyConcepts = topic.keyConcepts.isNotEmpty
        ? topic.keyConcepts.take(3).join(', ')
        : 'core concepts';

    prompt = "I want to learn ${topic.name} for $roleContext development. "
             "Please provide:\n\n"
             "• **Key Points**: What is ${topic.name} and why it matters\n"
             "• **Learning Resources**: Books, tutorials, documentation, courses, and websites\n\n"
             "Focus on $keyConcepts. Keep it concise and practical.";

    return prompt;
  }
  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.fundamentals:
        return Colors.green;
      case DifficultyLevel.intermediate:
        return Colors.blue;
      case DifficultyLevel.advanced:
        return Colors.orange;
      case DifficultyLevel.expert:
        return Colors.red;
    }
  }
}

class TopicDetailModal extends StatelessWidget {
  final RoadmapTopic topic;

  const TopicDetailModal({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(topic.difficulty).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDifficultyIcon(topic.difficulty),
                  color: _getDifficultyColor(topic.difficulty),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      topic.difficulty.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _getDifficultyColor(topic.difficulty),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Description
          Text(
            'Description',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            topic.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          
          const SizedBox(height: 20),
          
          // Key Concepts
          if (topic.keyConcepts.isNotEmpty) ...[
            Text(
              'Key Concepts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topic.keyConcepts.map((concept) {
                return Chip(
                  label: Text(concept),
                  backgroundColor: theme.cardColor,
                  side: BorderSide(color: theme.dividerColor),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
          
          // Prerequisites
          if (topic.prerequisites.isNotEmpty) ...[
            Text(
              'Prerequisites',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...topic.prerequisites.map((prereq) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_right,
                      size: 16,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      prereq,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
          
          // Time estimate
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 20,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 8),
              Text(
                'Estimated time: ${topic.estimatedHours} hours',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.fundamentals:
        return Colors.green;
      case DifficultyLevel.intermediate:
        return Colors.blue;
      case DifficultyLevel.advanced:
        return Colors.orange;
      case DifficultyLevel.expert:
        return Colors.red;
    }
  }

  IconData _getDifficultyIcon(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.fundamentals:
        return Icons.school;
      case DifficultyLevel.intermediate:
        return Icons.trending_up;
      case DifficultyLevel.advanced:
        return Icons.rocket_launch;
      case DifficultyLevel.expert:
        return Icons.star;
    }
  }


}
