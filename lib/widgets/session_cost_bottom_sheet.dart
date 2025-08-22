import 'package:flutter/material.dart';

import '../services/cost_service.dart';
import '../services/session_cost_service.dart';
import '../services/openrouter_client.dart';
import '../services/cost_calculation_service.dart';
import '../services/user_spending_service.dart';
import '../utils/logger.dart';

class SessionCostBottomSheet extends StatefulWidget {
  final SessionCostService sessionCostService;
  final Map<String, dynamic>? additionalCostData;
  final ScrollController? scrollController;

  const SessionCostBottomSheet({
    super.key,
    required this.sessionCostService,
    this.additionalCostData,
    this.scrollController,
  });

  @override
  State<SessionCostBottomSheet> createState() => _SessionCostBottomSheetState();
}

class _SessionCostBottomSheetState extends State<SessionCostBottomSheet> {
  Map<String, dynamic>? sessionSummary;
  Map<String, dynamic>? platformCredits;
  Map<String, dynamic>? platformStats;
  double? totalUserSpending;
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Session Cost Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Refresh button
                IconButton(
                  onPressed: () async {
                    setState(() {
                      isLoading = true;
                    });
                    await widget.sessionCostService.recalculateSessionCosts();
                    await _loadData();
                  },
                  icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
                  tooltip: 'Refresh costs',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),

          // Content
          isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _buildContent(theme, isDark),
        ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    if (sessionSummary == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final sessionCost = sessionSummary!['sessionCost'] as double? ?? 0.0;
    final messageCount = sessionSummary!['messageCount'] as int? ?? 0;
    final totalGenerations = sessionSummary!['totalGenerations'] as int? ?? 0;
    
    final remainingCreditsRaw = platformCredits?['remaining_credits'];
    final remainingCredits = _safeToDouble(remainingCreditsRaw);
    final userTotalSpending = totalUserSpending ?? 0.0;
    final platformTotalCost = platformStats?['totalCost'] as double? ?? 0.0;
    final allTimeCost = userTotalSpending > 0 ? userTotalSpending : platformTotalCost;
    final platformTotalRequests = platformStats?['modelCount'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary cost metrics - prominent display
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildPrimaryCard(
                  theme,
                  'Session Cost',
                  sessionCost == 0.0 ? '\$0.00' : CostService.formatCost(sessionCost),
                  sessionCost == 0.0 ? Colors.green : theme.colorScheme.primary,
                  Icons.timeline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildPrimaryCard(
                  theme,
                  'OR Credit',
                  '\$${remainingCredits.toStringAsFixed(2)}',
                  remainingCredits > 10 ? Colors.green : remainingCredits > 5 ? Colors.orange : Colors.red,
                  Icons.account_balance_wallet,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // All-time cost in its own row for better visibility
          _buildSecondaryCard(
            theme,
            'All Time Cost',
            allTimeCost == 0.0 ? '\$0.00' : (userTotalSpending > 0 ? '\$${allTimeCost.toStringAsFixed(2)}' : '\$${allTimeCost.toStringAsFixed(6)}'),
            allTimeCost == 0.0 ? Colors.green : Colors.red,
            Icons.trending_up,
          ),
          
          const SizedBox(height: 16),
          
          // Usage statistics - compact row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Session Msgs',
                  messageCount.toString(),
                  Colors.blue,
                  Icons.message,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Total Requests',
                  platformTotalRequests.toString(),
                  Colors.purple,
                  Icons.api,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Session Calls',
                  totalGenerations.toString(),
                  Colors.orange,
                  Icons.refresh,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCard(ThemeData theme, String title, String value, Color valueColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: valueColor, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryCard(ThemeData theme, String title, String value, Color valueColor, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: valueColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String title, String value, Color valueColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: valueColor, size: 16),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }




  /// Safe conversion from dynamic to double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  Future<void> _loadData() async {
    try {
      // Load session data
      final summary = await widget.sessionCostService.getSessionSummary();
      
      // Load platform credits data (OpenRouter account)
      final openRouterClient = OpenRouterClient();
      final credits = await openRouterClient.getCredits();
      
      // Load platform stats data (local tracking)
      final costCalculationService = CostCalculationService();
      await costCalculationService.initialize();
      final stats = costCalculationService.getTotalStats();
      
      // Load user spending data
      final userSpendingService = UserSpendingService();
      final userTotal = await userSpendingService.getTotalSpending();
      
      setState(() {
        sessionSummary = summary;
        platformCredits = credits;
        platformStats = stats;
        totalUserSpending = userTotal;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Logger.error('Error loading session data: $e', tag: 'SessionCost');
    }
  }
}
