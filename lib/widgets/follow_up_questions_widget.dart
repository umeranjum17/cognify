import 'package:flutter/material.dart';

import '../services/session_cost_service.dart';
import '../services/unified_api_service.dart';
import 'modern_card.dart';

class FollowUpQuestionsWidget extends StatefulWidget {
  final String aiAnswer;
  final String? model;
  final List<dynamic>? sources;
  final List<dynamic>? messages;
  final void Function(List<String>)? onQuestionsRefreshed;
  final bool shouldFetch; // New parameter to control when to fetch

  final void Function({
    required String question,
    required String previousAnswer,
    required List<dynamic>? sources,
  })? onQuestionTap;

  const FollowUpQuestionsWidget({
    super.key,
    required this.aiAnswer,
    this.model,
    this.sources,
    this.messages,
    this.onQuestionsRefreshed,
    this.onQuestionTap,
    this.shouldFetch = true, // Default to true for backward compatibility
  });

  @override
  State<FollowUpQuestionsWidget> createState() => _FollowUpQuestionsWidgetState();
}

class _FollowUpQuestionsWidgetState extends State<FollowUpQuestionsWidget> {
  Future<List<String>>? _futureQuestions; // Changed to nullable
  String? _lastAnswer;
  bool _hasStartedFetching = false;

  @override
  Widget build(BuildContext context) {
    // Only start fetching if shouldFetch is true, we haven't started yet, and we have content
    if (widget.shouldFetch && !_hasStartedFetching && widget.aiAnswer.trim().isNotEmpty) {
      _hasStartedFetching = true;
      _futureQuestions = _fetchFollowUpQuestions();
    }

    // If we shouldn't fetch or haven't started, show a placeholder
    if (!widget.shouldFetch || _futureQuestions == null) {
      return const SizedBox.shrink();
    }

    // If we should fetch but don't have content yet, show a loading state
    if (widget.shouldFetch && widget.aiAnswer.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Waiting for message content...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<String>>(
      future: _futureQuestions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading skeleton while waiting
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(3, (index) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 20,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              )),
            ),
          );
        } else if (snapshot.hasError) {
          return ModernCard(
            variant: CardVariant.accent,
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(height: 8),
                Text('Failed to load follow-up questions',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _refreshQuestions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return ModernCard(
            variant: CardVariant.minimal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('No follow-up questions available.',
                    style: Theme.of(context).textTheme.bodyMedium),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _refreshQuestions,
                ),
              ],
            ),
          );
        } else {
          final questions = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...questions.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.onQuestionTap != null) {
                          widget.onQuestionTap!(
                            question: q,
                            previousAnswer: widget.aiAnswer,
                            sources: widget.sources,
                          );
                        }
                      },
                      child: ModernCard(
                        variant: CardVariant.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        borderRadius: 10,
                        showShadow: false,
                        child: Text(
                          q,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    if (idx != questions.length - 1)
                      const SizedBox(height: 8),
                  ],
                );
              }),
            ],
          );
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant FollowUpQuestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch if aiAnswer changes and we should fetch
    if (widget.aiAnswer != _lastAnswer && widget.shouldFetch) {
      _lastAnswer = widget.aiAnswer;
      _hasStartedFetching = true;
      setState(() {
        _futureQuestions = _fetchFollowUpQuestions();
      });
    }
    // Reset fetching state if shouldFetch changes from true to false
    if (oldWidget.shouldFetch && !widget.shouldFetch) {
      _hasStartedFetching = false;
      _futureQuestions = null;
    }
    // Reset fetching state if shouldFetch changes from false to true
    if (!oldWidget.shouldFetch && widget.shouldFetch) {
      _hasStartedFetching = false;
      _futureQuestions = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _lastAnswer = widget.aiAnswer;
    // Don't start fetching in initState - wait for shouldFetch to be true
  }

  Future<List<String>> _fetchFollowUpQuestions() async {
    // Use the updated UnifiedApiService method for /api/followup-questions
    final response = await UnifiedApiService().generateFollowUpQuestions(
      widget.aiAnswer,
      model: widget.model,
      sources: widget.sources,
      messages: widget.messages,
      stream: false,
    );

    // Track generation ID for cost calculation if available
    if (response['generationId'] != null) {
      try {
        final sessionCostService = SessionCostService();
        await sessionCostService.addGenerationIds([
          {
            'id': response['generationId'],
            'stage': 'followup-questions',
            'model': widget.model ?? 'google/gemini-2.0-flash-exp:free',
            'inputTokens': response['usage']?['prompt_tokens'] ?? 0,
            'outputTokens': response['usage']?['completion_tokens'] ?? 0,
            'totalTokens': response['usage']?['total_tokens'] ?? 0,
          }
        ]);
        print('💰 Added follow-up questions generation ID for cost tracking: ${response['generationId']}');
      } catch (e) {
        print('Error tracking follow-up questions cost: $e');
      }
    }

    return List<String>.from(response['questions'] ?? []);
  }

  void _refreshQuestions() {
    setState(() {
      _futureQuestions = _fetchFollowUpQuestions();
    });
  }
}