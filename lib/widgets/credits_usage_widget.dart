import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'quick_credit_purchase_sheet.dart';

class CreditsUsageWidget extends StatefulWidget {
  const CreditsUsageWidget({super.key});

  @override
  State<CreditsUsageWidget> createState() => _CreditsUsageWidgetState();
}

class _CreditsUsageWidgetState extends State<CreditsUsageWidget> {
  Map<String, dynamic>? _creditsData;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppColors.spacingMd),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: AppColors.spacingSm),
              Text(
                'OpenRouter Credits',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: _loadCredits,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppColors.spacingSm),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(AppColors.spacingSm),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: AppColors.spacingXs),
                  Expanded(
                    child: Text(
                      'Unable to load credits information',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_creditsData != null && _creditsData!['success'] == true)
            _buildCreditsInfo(theme, isDark)
          else if (!_isLoading)
            Container(
              padding: const EdgeInsets.all(AppColors.spacingSm),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: AppColors.spacingXs),
                  Expanded(
                    child: Text(
                      'Credits information not available',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Widget _buildCreditRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: AppColors.spacingXs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditsInfo(ThemeData theme, bool isDark) {
    final credits = _creditsData!['credits'] as Map<String, dynamic>;
    final totalUnits = (credits['total_credits'] as num?)?.toInt() ?? 0;
    final usedUnits = (credits['total_usage'] as num?)?.toInt() ?? 0;
    final remainingUnits = (credits['remaining_credits'] as num?)?.toInt() ?? 0;
    final fetchedAt = credits['fetched_at'] as String?;

    return Column(
      children: [
        // Total Credits
        _buildCreditRow(
          theme,
          'Total Credits',
          '${totalUnits}x',
          Icons.account_balance,
          Colors.blue,
        ),
        const SizedBox(height: AppColors.spacingXs),
        
        // Used Credits
        _buildCreditRow(
          theme,
          'Used',
          '${usedUnits}x',
          Icons.trending_up,
          Colors.orange,
        ),
        const SizedBox(height: AppColors.spacingXs),
        
        // Remaining Credits
        _buildCreditRow(
          theme,
          'Remaining',
          '${remainingUnits}x',
          Icons.account_balance_wallet,
          remainingUnits > 0 ? Colors.green : Colors.red,
        ),
        
        // Buy Credits button
        const SizedBox(height: AppColors.spacingMd),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showQuickCreditPurchase(remainingUnits),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add_card, size: 20),
            label: const Text(
              'Buy More Credits',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        if (fetchedAt != null) ...[
          const SizedBox(height: AppColors.spacingSm),
          Text(
            'Last updated: ${_formatTimestamp(fetchedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _loadCredits() async {
    // Credits fetching is no longer needed
    setState(() {
      _isLoading = false;
      _creditsData = null;
    });
  }

  void _showQuickCreditPurchase(int currentCredits) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickCreditPurchaseSheet(
        currentCredits: currentCredits,
      ),
    ).then((purchased) {
      // Reload credits if purchase was successful
      if (purchased == true) {
        _loadCredits();
      }
    });
  }
}
