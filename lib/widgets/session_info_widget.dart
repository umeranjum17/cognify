import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/mode_config.dart';
import '../theme/app_theme.dart';
import '../services/session_cost_service.dart';
import '../services/user_service.dart';
import 'session_cost_bottom_sheet.dart';

class SessionInfoWidget extends StatefulWidget {
  final String? llmUsed;
  final String? modelName;
  final double cost;
  final double sessionCost;
  final Map<String, dynamic>? toolResults;
  final Map<String, dynamic>? costBreakdown;
  final int messageCount;
  final dynamic
  modelCapabilities; // ModelCapabilities? - using dynamic to avoid import issues
  final ChatMode? mode; // NEW: Pass current mode for quick switcher
  final Function(String)? onModelSwitched; // NEW: Callback for model switch
  final Map<String, dynamic>? openRouterCredits; // NEW: OpenRouter credits data
  final int? remainingRequests;
  final bool isQuotaLoading;

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
    this.mode,
    this.onModelSwitched,
    this.openRouterCredits,
    this.remainingRequests,
    this.isQuotaLoading = false,
  });

  @override
  State<SessionInfoWidget> createState() => _SessionInfoWidgetState();
}

class _SessionInfoWidgetState extends State<SessionInfoWidget> {
  Map<String, dynamic>? _creditsData;
  bool _isLoadingCredits = false;
  String? _creditsError;

  @override
  void initState() {
    super.initState();
    _loadCreditsIfNeeded();
  }

  Future<void> _loadCreditsIfNeeded() async {
    // Credits fetching is no longer needed
    if (widget.openRouterCredits != null) {
      _creditsData = widget.openRouterCredits;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quotaText = _getQuotaDisplayText();
    final quotaColor = _resolveQuotaDisplayColor(theme);
    final iconColor =
        quotaColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.spacingMd,
        vertical: AppColors.spacingSm,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // OpenRouter credits info (replacing model info)
          Expanded(
            child: GestureDetector(
              onTap: () => _showSessionCostPopup(context),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: _buildCreditsDisplay(theme)),
                ],
              ),
            ),
          ),

          // Cost info (simplified)
          GestureDetector(
            onTap: () => _showSessionCostPopup(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message_outlined, size: 12, color: iconColor),
                  const SizedBox(width: 4),
                  Text(
                    quotaText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: quotaColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsDisplay(ThemeData theme) {
    if (_isLoadingCredits) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Loading credits...',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      );
    }

    if (_creditsError != null ||
        _creditsData == null ||
        _creditsData!['success'] != true) {
      return Text(
        'Credits unavailable',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final credits = _creditsData!['credits'] as Map<String, dynamic>;
    final remainingCredits =
        (credits['remaining_credits'] as num?)?.toDouble() ?? 0.0;

    final color = remainingCredits > 0
        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
        : Colors.red;

    return Text(
      'Balance: \$${remainingCredits.toStringAsFixed(2)}',
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getQuotaDisplayText() {
    if (widget.llmUsed == 'local-ollama') {
      return 'Free (Local)';
    }

    if (widget.isQuotaLoading) {
      return 'Messages: loading...';
    }

    final remaining = widget.remainingRequests;

    final fallback = AppSecrets.initialRequestAllocation;
    final effectiveRemaining = ((remaining ?? fallback).clamp(
      0,
      1 << 30,
    )).toInt();

    if (remaining == null) {
      // Still highlight that this is a default estimate until real quota loads.
      return 'Messages available: ${_formatCount(effectiveRemaining)}';
    }

    if (effectiveRemaining <= 0) {
      return 'No messages remaining';
    }

    if (effectiveRemaining == 1) {
      return '1 message remaining';
    }

    return 'Messages remaining: ${_formatCount(effectiveRemaining)}';
  }

  Color? _resolveQuotaDisplayColor(ThemeData theme) {
    if (widget.llmUsed == 'local-ollama') {
      return Colors.green;
    }

    if (widget.isQuotaLoading) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    final remaining = widget.remainingRequests;
    if (remaining == null) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.7);
    }

    if (remaining <= 0) {
      return Colors.redAccent;
    }

    return theme.colorScheme.onSurface.withValues(alpha: 0.75);
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final formatted = (value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      );
      return '${formatted}M';
    }
    if (value >= 1000) {
      final formatted = (value / 1000).toStringAsFixed(
        value % 1000 == 0 ? 0 : 1,
      );
      return '${formatted}K';
    }
    return value.toString();
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
            'costBreakdown': widget.costBreakdown,
            'sessionCost': widget.sessionCost,
            'messageCost': widget.cost,
            'messageCount': widget.messageCount,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      ),
    );
  }
}
