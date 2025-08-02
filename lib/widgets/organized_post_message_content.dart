import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/app_theme.dart';
import 'follow_up_questions_widget.dart';
import 'modern_card.dart';

class OrganizedPostMessageContent extends StatefulWidget {
  final Message message;
  final String Function() getModelForCurrentMode;
  final List<Message> messages;
  final Function(String) sendMessage;
  final List<String> selectedSourceIds;
  final List<dynamic> selectedSources;

  const OrganizedPostMessageContent({
    super.key,
    required this.message,
    required this.getModelForCurrentMode,
    required this.messages,
    required this.sendMessage,
    required this.selectedSourceIds,
    required this.selectedSources,
  });

  @override
  State<OrganizedPostMessageContent> createState() => _OrganizedPostMessageContentState();
}

class _OrganizedPostMessageContentState extends State<OrganizedPostMessageContent> {
  bool _showFollowUp = false; // Changed to false - accordion closed by default

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Follow-up Questions Section
          _followUpSection(theme, isDark),

          // Additional Follow-up Questions
          if (widget.message.additionalFollowUpQuestions != null &&
              widget.message.additionalFollowUpQuestions!.isNotEmpty)
            _additionalQuestionsSection(theme, isDark),
        ],
      ),
    );
  }

  Widget _additionalQuestionsSection(ThemeData theme, bool isDark) {
    return ModernCard(
      variant: CardVariant.minimal,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 16,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
              const SizedBox(width: 6),
              Text(
                'AI Suggestions',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Additional follow-up questions
          ...widget.message.additionalFollowUpQuestions!.map((question) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.sendMessage(question),
                    borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _followUpSection(ThemeData theme, bool isDark) {
    // Only show follow-up questions if message is complete (not processing)
    final bool isMessageComplete = widget.message.isProcessing != true;
    
    // Don't show the entire section if message is still processing
    if (!isMessageComplete) {
      return const SizedBox.shrink();
    }
    
    return ModernCard(
      variant: CardVariant.minimal,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 16,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
              const SizedBox(width: 6),
              Text(
                'Follow-up Questions',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
              const Spacer(),
              // Show expand/collapse button since message is complete
              IconButton(
                icon: Icon(
                  _showFollowUp ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                onPressed: () => setState(() => _showFollowUp = !_showFollowUp),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          // Follow-up questions content - only show when accordion is opened
          if (_showFollowUp) ...[
            const SizedBox(height: 8),
            FollowUpQuestionsWidget(
              aiAnswer: widget.message.textContent,
              model: widget.getModelForCurrentMode(),
              sources: widget.message.sources,
              messages: widget.messages.map((m) => m.toJson()).toList(),
              onQuestionsRefreshed: (questions) {},
              onQuestionTap: ({
                required String question,
                required String previousAnswer,
                required List<dynamic>? sources,
              }) {
                widget.sendMessage(question);
              },
              shouldFetch: _showFollowUp, // Only fetch when accordion is open
            ),
          ],
        ],
      ),
    );
  }


}
