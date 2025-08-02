import 'package:flutter/material.dart';

import '../services/session_cost_service.dart';
import '../theme/app_theme.dart';
import 'model_capabilities_bottom_sheet.dart';
import 'session_cost_bottom_sheet.dart';

class SessionInfoWidget extends StatelessWidget {
  final String? llmUsed;
  final String? modelName;
  final double cost;
  final double sessionCost;
  final Map<String, dynamic>? toolResults;
  final Map<String, dynamic>? costBreakdown;
  final int messageCount;
  final dynamic modelCapabilities; // ModelCapabilities? - using dynamic to avoid import issues

  const SessionInfoWidget({
    super.key,
    this.llmUsed,
    this.modelName,
    required this.cost,
    required this.sessionCost,
    this.toolResults,
    this.costBreakdown,
    this.messageCount = 0,
    this.modelCapabilities,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.spacingMd,
        vertical: AppColors.spacingSm,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Main info row
          Row(
            children: [
              Icon(
                Icons.memory,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showModelCapabilitiesBottomSheet(context),
                  child: Text(
                    _getModelDisplayText(),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showSessionCostPopup(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 14,
                        color: llmUsed == 'local-ollama' ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getCostDisplayText(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: llmUsed == 'local-ollama' ? Colors.green : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Tool execution info
          if (toolResults != null && toolResults!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.build,
                  size: 12,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tools:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: toolResults!.entries.map((entry) {
                      final hasError = entry.value is Map &&
                          (entry.value as Map).containsKey('error');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: hasError ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            color: hasError ? Colors.red : Colors.green,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }





  String _getCostDisplayText() {
    if (llmUsed == 'local-ollama') {
      return 'Free (Local)';
    }

    String sessionText = sessionCost == 0.0 ? '\$0' : '\$${sessionCost.toStringAsFixed(3)}';
    String lastText = cost == 0.0 ? '\$0' : '\$${cost.toStringAsFixed(3)}';

    return 'Session: $sessionText • Last: $lastText';
  }

  String _getModelDisplayText() {
    // Get the actual model name, not the default fallback
    final actualModelName = modelName ?? llmUsed ?? 'Unknown';

    final displayName = actualModelName.contains('/')
      ? actualModelName.split('/').last.replaceAll(':free', '')
      : actualModelName;
    return 'Model: $displayName';
  }

  void _showModelCapabilitiesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModelCapabilitiesBottomSheet(
        modelCapabilities: modelCapabilities,
        modelName: modelName,
      ),
    );
  }

  void _showSessionCostPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SessionCostBottomSheet(
          sessionCostService: SessionCostService(),
          scrollController: scrollController,
          additionalCostData: {
            'costBreakdown': costBreakdown,
            'sessionCost': sessionCost,
            'messageCost': cost,
            'messageCount': messageCount,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      ),
    );
  }
}