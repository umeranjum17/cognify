import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../api/api.dart';
import '../models/mode_config.dart';
import '../theme/app_theme.dart';
import '../services/session_cost_service.dart';
import '../services/request_usage_estimator.dart';
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
  RequestUsageEstimate? _modelEstimate;

  @override
  void initState() {
    super.initState();
    _loadCreditsIfNeeded();
    _estimateCurrentModelIfNeeded();
  }

  Future<void> _loadCreditsIfNeeded() async {
    if (widget.openRouterCredits != null) {
      _creditsData = widget.openRouterCredits;
      return;
    }

    setState(() {
      _isLoadingCredits = true;
      _creditsError = null;
    });
    try {
      final balance = await API.instance.getCreditsBalance();
      // Map server shape to local expected shape
      _creditsData = {
        'success': true,
        'credits': {
          'remaining_credits': balance,
          // Optional fields used by other widgets
          'total_credits': balance,
          'total_usage': 0.0,
          'fetched_at': DateTime.now().toUtc().toIso8601String(),
        },
      };
    } catch (e) {
      _creditsError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCredits = false;
        });
      }
    }
  }

  Future<void> _estimateCurrentModelIfNeeded() async {
    final modelId = widget.modelName;
    if (modelId == null || modelId.isEmpty) return;
    try {
      final estimate = await RequestUsageEstimator.estimate(
        modelId: modelId,
        mode: widget.mode,
      );
      if (mounted) {
        setState(() {
          _modelEstimate = estimate;
        });
      }
    } catch (_) {
      // Ignore and keep null → UI falls back gracefully
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
            _buildQuotaAndPriceLabel(quotaText),
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

  String _buildQuotaAndPriceLabel(String quotaText) {
    // If we have an estimate, show the price per request
    if (_modelEstimate != null && !_modelEstimate!.isFree) {
      final units = _modelEstimate!.requestUnits;
      final price = _modelEstimate!.dollarCost;
      final priceStr = price < 0.01
          ? '<\$0.01'
          : '\$${price.toStringAsFixed(2)}';

      // Extract just the number from quotaText for cleaner display
      final remaining = widget.remainingRequests;
      if (remaining != null) {
        final count = _formatCount(remaining);
        return '$count left · $priceStr/req · ${units}u';
      }
      return '$quotaText · $priceStr/req · ${units}u';
    }
    if (_modelEstimate != null && _modelEstimate!.isFree) {
      final remaining = widget.remainingRequests;
      if (remaining != null) {
        return '${_formatCount(remaining)} left · Free';
      }
      return '$quotaText · Free';
    }
    return quotaText;
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
      // Show request count instead when credits are unavailable
      final remaining = widget.remainingRequests;
      if (remaining != null && remaining > 0) {
        return Text(
          '${_formatCount(remaining)} request${remaining == 1 ? '' : 's'} left',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        );
      }
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
