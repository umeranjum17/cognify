import 'package:flutter/material.dart';
import '../services/cost_service.dart';

class CostDisplayWidget extends StatelessWidget {
  final double? messageCost;
  final double? sessionCost;
  final Map<String, dynamic>? costBreakdown;
  final bool showSessionCost;
  final bool compact;

  const CostDisplayWidget({
    super.key,
    this.messageCost,
    this.sessionCost,
    this.costBreakdown,
    this.showSessionCost = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Don't show anything if no cost data
    if (messageCost == null && sessionCost == null && costBreakdown == null) {
      return const SizedBox.shrink();
    }

    // For free models, show "Free" badge
    if ((messageCost ?? 0) == 0 && (sessionCost ?? 0) == 0) {
      return _buildFreeBadge(theme);
    }

    if (compact) {
      return _buildCompactDisplay(theme);
    } else {
      return _buildDetailedDisplay(theme);
    }
  }

  Widget _buildFreeBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Free',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCompactDisplay(ThemeData theme) {
    final cost = showSessionCost ? sessionCost : messageCost;
    if (cost == null || cost == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        CostService.formatCost(cost),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildDetailedDisplay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (messageCost != null && messageCost! > 0) ...[
            _buildCostRow(
              theme,
              'Message Cost',
              CostService.formatCost(messageCost!),
              Icons.chat_bubble_outline,
            ),
          ],
          if (sessionCost != null && sessionCost! > 0) ...[
            if (messageCost != null && messageCost! > 0) const SizedBox(height: 4),
            _buildCostRow(
              theme,
              'Session Total',
              CostService.formatCost(sessionCost!),
              Icons.receipt_long,
            ),
          ],
          if (costBreakdown != null) ...[
            const SizedBox(height: 4),
            _buildTokenInfo(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildCostRow(ThemeData theme, String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenInfo(ThemeData theme) {
    final inputTokens = costBreakdown?['inputTokens'] ?? 0;
    final outputTokens = costBreakdown?['outputTokens'] ?? 0;
    final totalTokens = costBreakdown?['totalTokens'] ?? (inputTokens + outputTokens);

    if (totalTokens == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.token,
          size: 12,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          '${totalTokens} tokens',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        if (inputTokens > 0 && outputTokens > 0) ...[
          Text(
            ' (${inputTokens}↑ ${outputTokens}↓)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

class MessageCostBadge extends StatelessWidget {
  final double? cost;
  final Map<String, dynamic>? costBreakdown;

  const MessageCostBadge({
    super.key,
    this.cost,
    this.costBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    return CostDisplayWidget(
      messageCost: cost,
      costBreakdown: costBreakdown,
      compact: true,
    );
  }
}

class SessionCostSummary extends StatelessWidget {
  final double? sessionCost;
  final int messageCount;
  final Map<String, dynamic>? costBreakdown;

  const SessionCostSummary({
    super.key,
    this.sessionCost,
    this.messageCount = 0,
    this.costBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (sessionCost == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 16,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CostService.getSessionCostSummary(
                  sessionCost: sessionCost!,
                  messageCount: messageCount,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (costBreakdown != null) ...[
                const SizedBox(height: 2),
                Text(
                  CostService.getCostBreakdownText(costBreakdown),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
