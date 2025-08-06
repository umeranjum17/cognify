import 'package:flutter/material.dart';

import '../services/cost_service.dart';
import '../services/session_cost_service.dart';
import '../services/openrouter_client.dart';
import '../services/cost_calculation_service.dart';
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
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
          Expanded(
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildContent(theme, isDark),
          ),
        ],
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
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Loading session data...',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final sessionCost = sessionSummary!['sessionCost'] as double? ?? 0.0;
    final messageCount = sessionSummary!['messageCount'] as int? ?? 0;
    final totalGenerations = sessionSummary!['totalGenerations'] as int? ?? 0;
    
    // Platform credits data (OpenRouter account) - Fix type casting
    final totalCreditsRaw = platformCredits?['total_credits'];
    final totalUsageRaw = platformCredits?['total_usage'];
    final remainingCreditsRaw = platformCredits?['remaining_credits'];
    
    // Safe type conversion
    final totalCredits = _safeToDouble(totalCreditsRaw);
    final totalUsage = _safeToDouble(totalUsageRaw);
    final remainingCredits = _safeToDouble(remainingCreditsRaw);
    final creditsFetchedAt = platformCredits?['fetched_at'] as String?;
    
    // Platform stats data (local tracking)
    final platformTotalCost = platformStats?['totalCost'] as double? ?? 0.0;
    final platformTotalRequests = platformStats?['modelCount'] as int? ?? 0;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // Current Session
        _buildSectionCard(
          theme,
          'Current Session',
          Icons.assessment,
          [
            _buildInfoRow(
              'Session Cost',
              sessionCost == 0.0 ? '\$0' : CostService.formatCost(sessionCost),
              sessionCost == 0.0 ? Colors.green : Colors.orange
            ),
            _buildInfoRow('Requests', totalGenerations.toString(), Colors.blue),
            _buildInfoRow('Messages', messageCount.toString(), Colors.grey),
          ],
        ),

        const SizedBox(height: 16),

        // Platform Usage (OpenRouter Account)
        _buildSectionCard(
          theme,
          'OpenRouter Account',
          Icons.account_balance,
          [
            _buildInfoRow('Total Spent', '\$${totalUsage.toStringAsFixed(2)}', Colors.red),
            _buildInfoRow('Remaining', '\$${remainingCredits.toStringAsFixed(2)}', Colors.green),
            _buildInfoRow('Total Credits', '\$${totalCredits.toStringAsFixed(2)}', Colors.blue),
          ],
        ),

        const SizedBox(height: 16),

        // Platform Stats (Local Tracking)
        _buildSectionCard(
          theme,
          'Platform Stats',
          Icons.analytics,
          [
            _buildInfoRow('Total Tracked Cost', '\$${platformTotalCost.toStringAsFixed(6)}', Colors.orange),
            _buildInfoRow('Total Requests', platformTotalRequests.toString(), Colors.purple),
          ],
        ),

        const SizedBox(height: 16),

        // Last Updated
        if (creditsFetchedAt != null || widget.additionalCostData?['timestamp'] != null) ...[
          _buildSectionCard(
            theme,
            'Last Updated',
            Icons.access_time,
            [
              if (creditsFetchedAt != null)
                _buildInfoRow('OpenRouter Data', 
                  _formatTimestamp(creditsFetchedAt),
                  Colors.grey),
              if (widget.additionalCostData?['timestamp'] != null)
                _buildInfoRow('Session Data', 
                  _formatTimestamp(widget.additionalCostData!['timestamp'].toString()),
                  Colors.grey),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color? valueColor) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(ThemeData theme, String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
             '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
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
      
      setState(() {
        sessionSummary = summary;
        platformCredits = credits;
        platformStats = stats;
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
