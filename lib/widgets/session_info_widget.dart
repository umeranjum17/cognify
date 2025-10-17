import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../api/api.dart';
import '../models/mode_config.dart';
import '../theme/app_theme.dart';
import '../services/session_cost_service.dart';
import '../services/request_usage_estimator.dart';
import '../services/user_service.dart';
import 'session_cost_bottom_sheet.dart';
import 'quick_credit_purchase_sheet.dart';
import 'wallet_topup_sheet.dart';
import '../config/purchases_config.dart';
import 'package:provider/provider.dart';
import '../providers/credits_purchase_provider.dart';
import '../providers/firebase_auth_provider.dart';
import '../providers/usage_quota_provider.dart';
import '../models/usage_quota.dart';

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
  final VoidCallback? onBuyCreditsTapped; // Optional override for buy credits action

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
    this.onBuyCreditsTapped,
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


  void _updateCreditsFromProvider(UsageQuota quota) {
    if (mounted) {
      print('🔄 [SessionInfoWidget] Updating credits from provider: ${quota.remaining} remaining');
      setState(() {
        _creditsData = {
          'success': true,
          'credits': {
            'remaining_credits': quota.remaining.toDouble(),
            'total_credits': quota.limit.toDouble(),
            'total_usage': quota.requestsConsumed.toDouble(),
            'fetched_at': DateTime.now().toUtc().toIso8601String(),
          },
        };
        _isLoadingCredits = false;
        _creditsError = null;
      });
      print('✅ [SessionInfoWidget] Credits updated in UI: ${quota.remaining} credits');
    }
  }

  void _updateCreditsFromProviderWithoutSetState(UsageQuota quota) {
    print('🔄 [SessionInfoWidget] Updating credits from provider (no setState): ${quota.remaining} remaining');
    _creditsData = {
      'success': true,
      'credits': {
        'remaining_credits': quota.remaining.toDouble(),
        'total_credits': quota.limit.toDouble(),
        'total_usage': quota.requestsConsumed.toDouble(),
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
      },
    };
    _isLoadingCredits = false;
    _creditsError = null;
    print('✅ [SessionInfoWidget] Credits updated in UI (no setState): ${quota.remaining} credits');
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
      print('📊 Model estimate for $modelId: ${estimate.requestUnits} units, \$${estimate.dollarCost}, isFree: ${estimate.isFree}');
      if (mounted) {
        setState(() {
          _modelEstimate = estimate;
        });
      }
    } catch (e) {
      print('❌ Failed to estimate model $modelId: $e');
      // Ignore and keep null → UI falls back gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsageQuotaProvider>(
      builder: (context, quotaProvider, child) {
        return _buildContent(context, quotaProvider);
      },
    );
  }

  Widget _buildContent(BuildContext context, UsageQuotaProvider quotaProvider) {
    final theme = Theme.of(context);
    final quotaText = _getQuotaDisplayText();
    final quotaColor = _resolveQuotaDisplayColor(theme);
    final iconColor =
        quotaColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.6);

    // Get remaining credits for display - use provider data if available, fallback to local data
    int remainingUnits = 0;
    if (quotaProvider.quota != null) {
      remainingUnits = quotaProvider.quota!.remaining;
      print('🔄 [SessionInfoWidget] Using provider data: ${remainingUnits} credits');
    } else if (_creditsData != null && _creditsData!['success'] == true) {
      remainingUnits = ((_creditsData!['credits'] as Map<String, dynamic>)['remaining_credits'] as num?)?.toInt() ?? 0;
      print('🔄 [SessionInfoWidget] Using local data: ${remainingUnits} credits');
    }

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
            child: Row(
              children: [
                Icon(
                  Icons.account_balance,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Expanded(child: _buildCreditsAndModelDisplay(theme, quotaText, quotaProvider: quotaProvider)),
              ],
            ),
          ),

          // (Cost info merged into left label)

          // Buy Credits chip (classy, subtle – primary action as rightmost)
          if (!_isLoadingCredits) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Purchase more credits',
              child: GestureDetector(
                onTap: () {
                  if (widget.onBuyCreditsTapped != null) {
                    widget.onBuyCreditsTapped!();
                  } else {
                    _showQuickCreditPurchase(context, remainingUnits);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Buy credits',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildQuotaAndPriceLabel(String quotaText) {
    // Show only the cost per message for current model
    if (_modelEstimate == null) {
      return 'Loading...';
    }
    
    // Always show fractional request units; never label as Free
    final units = _modelEstimate!.requestUnits;
    if (units <= 0) return 'x0.3 per msg';
    return '${units.toStringAsFixed(1)} per msg';
  }

  Widget _buildCreditsDisplay(ThemeData theme, {UsageQuotaProvider? quotaProvider}) {
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

    // Use provider data if available, otherwise fallback to local data
    int remainingUnits = 0;
    if (quotaProvider?.quota != null) {
      remainingUnits = quotaProvider!.quota!.remaining;
    } else if (_creditsData != null && _creditsData!['success'] == true) {
      final credits = _creditsData!['credits'] as Map<String, dynamic>;
      remainingUnits = (credits['remaining_credits'] as num?)?.toInt() ?? 0;
    } else if (widget.remainingRequests != null && widget.remainingRequests! > 0) {
      // Show request count instead when credits are unavailable
      final remaining = widget.remainingRequests!;
      return Text(
        '${_formatCount(remaining)} request${remaining == 1 ? '' : 's'} left',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      return Text(
        'Credits unavailable',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final color = remainingUnits > 0
        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
        : Colors.red;

    return Text(
      '${_formatCount(remainingUnits)} credits',
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCreditsAndModelDisplay(ThemeData theme, String quotaText, {UsageQuotaProvider? quotaProvider}) {
    final left = _buildCreditsDisplay(theme, quotaProvider: quotaProvider);
    return Row(
      children: [
        Flexible(child: left),
        const SizedBox(width: 8),
        Text(
          '·',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 8),
      ],
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

    const fallback = 0;
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

  void _showQuickCreditPurchase(BuildContext context, int currentCredits) {
    if (!PurchasesConfig.purchasesEnabled) {
      _showWalletTopUp(context, currentCredits);
      return;
    }
    // Legacy path (kept for compatibility when enabled)
    final subs = Provider.of<CreditsPurchaseProvider>(context, listen: false);
    final auth = Provider.of<FirebaseAuthProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CreditsPurchaseProvider>.value(value: subs),
          ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
        ],
        child: QuickCreditPurchaseSheet(currentCredits: currentCredits),
      ),
    ).then((purchased) {
      if (purchased == true) {
        _loadCreditsIfNeeded();
      }
    });
  }

  void _showWalletTopUp(BuildContext context, int currentCredits) {
    // Capture providers from the current scope BEFORE opening the sheet
    final subs = Provider.of<CreditsPurchaseProvider>(context, listen: false);
    final auth = Provider.of<FirebaseAuthProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CreditsPurchaseProvider>.value(value: subs),
          ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
        ],
        child: WalletTopUpSheet(currentCredits: currentCredits),
      ),
    ).then((purchased) {
      if (purchased == true) {
        _loadCreditsIfNeeded();
      }
    });
  }
}
