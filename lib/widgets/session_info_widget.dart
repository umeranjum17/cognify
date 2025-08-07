import 'package:flutter/material.dart';

import '../models/mode_config.dart';
import '../theme/app_theme.dart';
import '../services/session_cost_service.dart';
import '../services/unified_api_service.dart';
import 'session_cost_bottom_sheet.dart';

class SessionInfoWidget extends StatefulWidget {
  final String? llmUsed;
  final String? modelName;
  final double cost;
  final double sessionCost;
  final Map<String, dynamic>? toolResults;
  final Map<String, dynamic>? costBreakdown;
  final int messageCount;
  final dynamic modelCapabilities; // ModelCapabilities? - using dynamic to avoid import issues
  final ChatMode? mode; // NEW: Pass current mode for quick switcher
  final Function(String)? onModelSwitched; // NEW: Callback for model switch
  final Map<String, dynamic>? openRouterCredits; // NEW: OpenRouter credits data

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
    if (widget.openRouterCredits != null) {
      _creditsData = widget.openRouterCredits;
      return;
    }

    setState(() {
      _isLoadingCredits = true;
      _creditsError = null;
    });

    try {
      final data = await UnifiedApiService().getCredits();
      setState(() {
        _creditsData = data;
        _isLoadingCredits = false;
      });
    } catch (e) {
      setState(() {
        _creditsError = e.toString();
        _isLoadingCredits = false;
      });
    }
  }

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
                  Expanded(
                    child: _buildCreditsDisplay(theme),
                  ),
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
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 12,
                    color: widget.llmUsed == 'local-ollama' ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCostDisplayText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: widget.llmUsed == 'local-ollama' ? Colors.green : null,
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

    if (_creditsError != null || _creditsData == null || _creditsData!['success'] != true) {
      return Text(
        'Credits unavailable',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final credits = _creditsData!['credits'] as Map<String, dynamic>;
    final remainingCredits = (credits['remaining_credits'] as num?)?.toDouble() ?? 0.0;
    
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

  String _getCostDisplayText() {
    if (widget.llmUsed == 'local-ollama') {
      return 'Free (Local)';
    }

    String sessionText = widget.sessionCost == 0.0 ? '\$0' : '\$${widget.sessionCost.toStringAsFixed(3)}';
    String lastText = widget.cost == 0.0 ? '\$0' : '\$${widget.cost.toStringAsFixed(3)}';

    return 'Session: $sessionText • Last: $lastText';
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