import 'package:flutter/material.dart';

import '../services/cost_service.dart';
import '../services/session_cost_service.dart';
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
                    await _loadSessionData();
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
    _loadSessionData();
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
    final hasAccurateCosts = sessionSummary!['hasAccurateCosts'] as bool? ?? false;
    final accuracy = sessionSummary!['accuracy'] as double? ?? 0.0;
    final successfulFetches = sessionSummary!['successfulFetches'] as int? ?? 0;
    final failedFetches = sessionSummary!['failedFetches'] as int? ?? 0;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
          // Session Overview
          _buildSectionCard(
            theme,
            'Session Overview',
            Icons.assessment,
            [
              _buildInfoRow(
                'Total Cost',
                sessionCost == 0.0 ? '\$0' : CostService.formatCost(sessionCost),
                sessionCost == 0.0 ? Colors.green : Colors.orange
              ),
              _buildInfoRow('Messages', messageCount.toString(), Colors.blue),
              _buildInfoRow('Generations', totalGenerations.toString(), Colors.orange),
              _buildInfoRow('Accuracy', '${(accuracy * 100).toStringAsFixed(1)}%', 
                hasAccurateCosts ? Colors.green : Colors.orange),
            ],
          ),

          const SizedBox(height: 16),

          // Generation Details
          _buildSectionCard(
            theme,
            'Generation Details',
            Icons.data_usage,
            [
              _buildInfoRow('Successful Fetches', successfulFetches.toString(), Colors.green),
              _buildInfoRow('Failed Fetches', failedFetches.toString(), 
                failedFetches > 0 ? Colors.red : Colors.grey),
              _buildInfoRow('Total Requests', (successfulFetches + failedFetches).toString(), Colors.blue),
            ],
          ),

          const SizedBox(height: 16),

          // Individual Generation IDs
          if (sessionSummary!['enhancedGenerations'] != null && 
              (sessionSummary!['enhancedGenerations'] as List).isNotEmpty) ...[
            _buildGenerationsList(theme, sessionSummary!['enhancedGenerations'] as List<Map<String, dynamic>>),
            const SizedBox(height: 16),
          ],

          // Session ID Info
          if (widget.additionalCostData != null || widget.sessionCostService.currentSessionId != null) ...[
            _buildSectionCard(
              theme,
              'Session Information',
              Icons.fingerprint,
              [
                if (widget.sessionCostService.currentSessionId != null)
                  _buildInfoRow('Session ID', 
                    widget.sessionCostService.currentSessionId!.length > 12 
                        ? '${widget.sessionCostService.currentSessionId!.substring(0, 12)}...'
                        : widget.sessionCostService.currentSessionId!, 
                    Colors.grey),
                if (widget.additionalCostData?['timestamp'] != null)
                  _buildInfoRow('Last Updated', 
                    DateTime.tryParse(widget.additionalCostData!['timestamp'].toString())
                        ?.toLocal().toString().substring(0, 19) ?? 'Unknown',
                    Colors.grey),
              ],
            ),
          ],
      ],
    );
  }

  Widget _buildGenerationItem(ThemeData theme, Map<String, dynamic> generation, int index) {
    final stage = generation['stage']?.toString() ?? 'Unknown';
    final model = generation['model']?.toString() ?? 'Unknown';
    final totalTokens = generation['totalTokens'] as int? ?? 0;
    final cost = generation['cost'] as double? ?? 0.0;
    final inputTokens = generation['inputTokens'] as int? ?? 0;
    final outputTokens = generation['outputTokens'] as int? ?? 0;
    final success = generation['success'] as bool? ?? false;
    
    // Extract additional data from costData if available
    final costData = generation['costData'] as Map<String, dynamic>?;
    final latency = costData?['latency'] as int?;
    final generationTime = costData?['generation_time'] as int?;
    final providerName = costData?['provider_name'] as String?;
    final finishReason = costData?['finish_reason'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with generation number and status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$index',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$stage - ${model.split('/').last.replaceAll(':free', '')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (providerName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getProviderColor(providerName).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    providerName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getProviderColor(providerName),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Tokens and cost row
          Row(
            children: [
              if (totalTokens > 0) ...[
                Icon(
                  Icons.token,
                  size: 10,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 3),
                Text(
                  '$totalTokens',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    fontSize: 9,
                  ),
                ),
                if (inputTokens > 0 && outputTokens > 0) ...[
                  Text(
                    ' ($inputTokens+$outputTokens)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                      fontSize: 8,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
              ],
              
              // Cost display
              Icon(
                Icons.monetization_on,
                size: 10,
                color: success ? Colors.green.withValues(alpha: 0.7) : Colors.orange.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 3),
              if (success && cost > 0) ...[
                Text(
                  '\$${cost.toStringAsFixed(6)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else if (success && cost == 0.0) ...[
                Text(
                  '\$0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Text(
                  'Cost not yet available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          
          // Performance metrics row (if available)
          if (latency != null || generationTime != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (latency != null) ...[
                  Icon(
                    Icons.network_check,
                    size: 9,
                    color: _getLatencyColor(latency),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${latency}ms',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getLatencyColor(latency),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (generationTime != null) ...[
                    const SizedBox(width: 8),
                  ],
                ],
                if (generationTime != null) ...[
                  Icon(
                    Icons.timer,
                    size: 9,
                    color: _getGenerationTimeColor(generationTime),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${generationTime}ms gen',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getGenerationTimeColor(generationTime),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (finishReason != null && finishReason != 'stop') ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.info_outline,
                    size: 9,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    finishReason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber,
                      fontSize: 8,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerationsList(ThemeData theme, List<Map<String, dynamic>> generations) {
    return _buildSectionCard(
      theme,
      'Generation History (${generations.length})',
      Icons.history,
      [
        Container(
          height: 160, // Increased height to accommodate more info
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(4),
            itemCount: generations.length,
            itemBuilder: (context, index) {
              final generation = generations[index];
              return _buildGenerationItem(theme, generation, index + 1);
            },
          ),
        ),
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

  /// Get color based on generation time performance
  Color _getGenerationTimeColor(int generationTime) {
    if (generationTime < 500) return Colors.green; // Fast
    if (generationTime < 1500) return Colors.orange; // Moderate
    return Colors.red; // Slow
  }

  /// Get color based on latency performance
  Color _getLatencyColor(int latency) {
    if (latency < 1000) return Colors.green; // Good
    if (latency < 3000) return Colors.orange; // Fair
    return Colors.red; // Poor
  }

  /// Get color for provider badges
  Color _getProviderColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return Colors.blue;
      case 'openai':
        return Colors.green;
      case 'anthropic':
        return Colors.purple;
      case 'deepseek':
        return Colors.teal;
      case 'mistral':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadSessionData() async {
    try {
      final summary = await widget.sessionCostService.getSessionSummary();
      setState(() {
        sessionSummary = summary;
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
