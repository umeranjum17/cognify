import 'package:flutter/material.dart';

import '../models/file_attachment.dart';
import '../theme/app_theme.dart';
import '../config/model_registry.dart';
import '../services/request_usage_estimator.dart';
import '../services/model_service.dart';
// Estimation handled by backend

class ModelCapabilitiesBottomSheet extends StatefulWidget {
  final ModelCapabilities? modelCapabilities;
  final String? modelName;
  final Map<String, dynamic>? pricing;
  final Map<String, dynamic>? modelData;

  const ModelCapabilitiesBottomSheet({
    super.key,
    this.modelCapabilities,
    this.modelName,
    this.pricing,
    this.modelData,
  });

  @override
  State<ModelCapabilitiesBottomSheet> createState() => _ModelCapabilitiesBottomSheetState();
}

class _ModelCapabilitiesBottomSheetState extends State<ModelCapabilitiesBottomSheet> {
  bool _isDescriptionExpanded = false;

  Map<String, dynamic>? _resolvePricing() {
    final dynamic raw =
        widget.pricing ?? widget.modelCapabilities?.pricing ?? widget.modelData?['pricing'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return null;
  }

  String _getUsageEstimateLabel({bool compact = false}) {
    final pricing = _resolvePricing();
    if (pricing == null || pricing.isEmpty) return compact ? '~1 req' : '≈1 request';
    return compact ? '~1 req' : '≈1 request';
  }

  String _getRequestLabel({bool compact = false}) {
    return _getUsageEstimateLabel(compact: compact);
  }

  String _getEstimatedDollarCost() {
    final pricing = _resolvePricing();
    if (pricing == null || pricing.isEmpty) return 'Est. cost shown after request';
    return 'Est. cost shown after request';
  }

  bool _isFree() {
    // Check model data first (same logic as ModelQuickSwitcher)
    if (widget.modelData != null) {
      if (widget.modelData!['isFree'] == true) return true;
      final modelId = widget.modelData!['id'] as String? ?? '';
      if (ModelRegistry.isModelFree(modelId)) return true;
    }

    // If backend or model data indicates free
    // Otherwise fall back to pricing presence

    final p = _resolvePricing();
    if (p == null || p.isEmpty) return false; // Unknown => treat as paid
    final input = (p['input'] ?? 0.0) as double;
    final output = (p['output'] ?? 0.0) as double;
    return input == 0.0 && output == 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.modelCapabilities == null) {
      return Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(theme),
            const SizedBox(height: 24),
            Text(
              'Model capabilities not available',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit to 60% of screen height
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16), // Reduced padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(theme),
              const SizedBox(height: 16), // Reduced spacing

              // Title
              Text(
                'Model Capabilities',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18, // Smaller title
                ),
              ),
              const SizedBox(height: 4), // Reduced spacing

              // Model name
              Text(
                _getModelDisplayText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16), // Reduced spacing

              // Capabilities content (scrollable)
              Flexible(child: _buildCapabilitiesGrid(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(ThemeData theme) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCapabilitiesGrid(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Model Overview
          _buildModelOverview(theme, isDark),
          const SizedBox(height: 12),

          // Context Length (moved up for better visibility)
          _buildContextLengthSection(theme, isDark),
          const SizedBox(height: 12),

          // Units per request (moved up for better visibility)
          _buildUnitsPerRequestSection(theme, isDark),
          const SizedBox(height: 12),

          // Input Modalities
          _buildInputModalitiesSection(theme, isDark),
          const SizedBox(height: 12),

          // Output Modalities
          _buildOutputModalitiesSection(theme, isDark),
          const SizedBox(height: 12),

          // Description (moved down, now with show more functionality)
          _buildDescriptionSection(theme, isDark),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCapabilitySection(
    String title,
    List<Widget> items,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8), // Reduced spacing
        ...items,
      ],
    );
  }

  Widget _buildCapabilityItem(
    String title,
    bool supported,
    IconData icon,
    ThemeData theme, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: supported
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: supported
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            supported ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: supported
                ? Colors.green
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingItem(
    String title,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    final isFreeValue = value == 'Free';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isFreeValue ? Colors.green : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isFreeValue
                        ? Colors.green
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: isFreeValue
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isFreeValue ? Icons.check_circle : Icons.monetization_on,
            size: 16,
            color: isFreeValue
                ? Colors.green
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  String _formatContextLength(int length) {
    if (length >= 1000000) {
      return '${(length / 1000000).toStringAsFixed(1)}M';
    } else if (length >= 1000) {
      return '${(length / 1000).toStringAsFixed(0)}K';
    } else {
      return '$length';
    }
  }

  String _getModelDisplayText() {
    if (widget.modelName == null) return 'Unknown Model';

    final displayName = widget.modelName!.contains('/')
        ? widget.modelName!.split('/').last.replaceAll(':free', '')
        : widget.modelName!;
    return 'Model: $displayName';
  }

  String _resolveModelId() {
    final idFromData = widget.modelData != null ? widget.modelData!['id'] as String? : null;
    if (idFromData != null && idFromData.isNotEmpty) return idFromData;
    return widget.modelName ?? 'unknown';
  }

  // Minimal sections
  Widget _buildModelOverview(ThemeData theme, bool isDark) {
    final modelName = widget.modelData?['name']?.toString() ?? _getModelDisplayText();
    
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.darkBackground.withValues(alpha: 0.3)
            : AppColors.lightBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8), // Smaller radius
        border: Border.all(
          color: isDark 
              ? AppColors.darkAccent.withValues(alpha: 0.2)
              : AppColors.lightAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy,
            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
            size: 20, // Smaller icon
          ),
          const SizedBox(width: 10), // Reduced spacing
          Expanded(
            child: Text(
              modelName,
              style: theme.textTheme.titleSmall?.copyWith( // Smaller text
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(ThemeData theme, bool isDark) {
    final description = widget.modelData?['description']?.toString();
    
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Check if description is long enough to need truncation
    const int maxLines = 3;
    final bool needsTruncation = description.split('\n').length > maxLines || 
                                description.length > 200;
    
    return _buildCapabilitySection('Description', [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark 
              ? AppColors.darkBackground.withValues(alpha: 0.2)
              : AppColors.lightBackground.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark 
                    ? AppColors.darkTextSecondary 
                    : AppColors.lightTextSecondary,
                height: 1.4,
              ),
              maxLines: _isDescriptionExpanded ? null : maxLines,
              overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
            ),
            if (needsTruncation) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDescriptionExpanded = !_isDescriptionExpanded;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isDescriptionExpanded ? 'Show Less' : 'Show More',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark 
                            ? AppColors.darkAccent 
                            : AppColors.lightAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isDescriptionExpanded 
                          ? Icons.keyboard_arrow_up 
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark 
                          ? AppColors.darkAccent 
                          : AppColors.lightAccent,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ], theme);
  }

  Widget _buildInputModalitiesSection(ThemeData theme, bool isDark) {
    final modalities = _getInputModalities();
    
    return _buildCapabilitySection('Input Modalities', [
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: modalities.map((modality) => _buildModalityChip(
            modality,
            true,
            theme,
            isDark,
          )).toList(),
        ),
      ),
    ], theme);
  }

  Widget _buildOutputModalitiesSection(ThemeData theme, bool isDark) {
    final outputModalities = _getOutputModalities();
    
    return _buildCapabilitySection('Output Modalities', [
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: outputModalities.map((modality) => _buildModalityChip(
            modality,
            true,
            theme,
            isDark,
          )).toList(),
        ),
      ),
    ], theme);
  }

  Widget _buildContextLengthSection(ThemeData theme, bool isDark) {
    final contextLength = widget.modelData?['context_length'] ?? 
                         widget.modelCapabilities?.contextLength;
    
    if (contextLength == null) return const SizedBox.shrink();
    
    return _buildCapabilitySection('Context Length', [
      _buildInfoItem(
        'Context Window',
        _formatContextLength(contextLength),
        Icons.memory,
        theme,
        isDark,
      ),
    ], theme);
  }

  Widget _buildUnitsPerRequestSection(ThemeData theme, bool isDark) {
    final requestEstimate = widget.modelData?['requestEstimate'] as Map<String, dynamic>?;
    final requestUnits = requestEstimate?['requestUnits'] as num?;
    
    if (requestUnits == null) return const SizedBox.shrink();
    
    return _buildCapabilitySection('Units per Request', [
      _buildInfoItem(
        'Request Units',
        'x${requestUnits.toStringAsFixed(1)}',
        Icons.speed,
        theme,
        isDark,
      ),
    ], theme);
  }

  Widget _buildModalityChip(String modality, bool supported, ThemeData theme, bool isDark) {
    final icon = _getModalityIcon(modality);
    final color = supported 
        ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            modality.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModalityIcon(String modality) {
    switch (modality.toLowerCase()) {
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audiotrack;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.help_outline;
    }
  }



  Widget _buildInfoItem(
    String title,
    String value,
    IconData icon,
    ThemeData theme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark 
                  ? AppColors.darkAccent.withValues(alpha: 0.1)
                  : AppColors.lightAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark 
                        ? AppColors.darkTextSecondary 
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  List<String> _getInputModalities() {
    if (widget.modelData == null) {
      // Fallback to modelCapabilities
      List<String> modalities = ['text'];
      if (widget.modelCapabilities?.supportsImages == true) modalities.add('image');
      if (widget.modelCapabilities?.supportsFiles == true) modalities.add('file');
      return modalities;
    }

    // Use the same logic as model_quick_switcher.dart
    final inputModalities = widget.modelData!['inputModalities'] as List<dynamic>? ??
                           widget.modelData!['input_modalities'] as List<dynamic>? ??
                           widget.modelData!['architecture']?['input_modalities'] as List<dynamic>? ??
                           [];
    
    List<String> modalities = inputModalities
        .map((modality) => modality.toString().toLowerCase())
        .toList();
    
    if (modalities.isEmpty) modalities = ['text'];
    
    // Debug: Print what we're getting in capabilities modal (only for specific models)
    final modelId = widget.modelData!['id']?.toString() ?? '';
    if (modelId.contains('gpt') || modelId.contains('claude') || modelId.contains('gemini')) {
      print('🔍 Model $modelId input modalities in capabilities:');
      print('  - inputModalities: ${widget.modelData!['inputModalities']}');
      print('  - input_modalities: ${widget.modelData!['input_modalities']}');
      print('  - architecture: ${widget.modelData!['architecture']}');
      print('  - extracted input modalities: $modalities');
    }
    
    return modalities;
  }

  List<String> _getOutputModalities() {
    if (widget.modelData == null) {
      // Default to text output
      return ['text'];
    }

    // Check for output modalities in the same way as input modalities
    final outputModalities = widget.modelData!['outputModalities'] as List<dynamic>? ??
                            widget.modelData!['output_modalities'] as List<dynamic>? ??
                            widget.modelData!['architecture']?['output_modalities'] as List<dynamic>? ??
                            [];
    
    List<String> modalities = outputModalities
        .map((modality) => modality.toString().toLowerCase())
        .toList();
    
    if (modalities.isEmpty) modalities = ['text'];
    
    // Debug: Print what we're getting in capabilities modal (only for specific models)
    final modelId = widget.modelData!['id']?.toString() ?? '';
    if (modelId.contains('gpt') || modelId.contains('claude') || modelId.contains('gemini')) {
      print('🔍 Model $modelId output modalities in capabilities:');
      print('  - outputModalities: ${widget.modelData!['outputModalities']}');
      print('  - output_modalities: ${widget.modelData!['output_modalities']}');
      print('  - architecture: ${widget.modelData!['architecture']}');
      print('  - extracted output modalities: $modalities');
    }
    
    return modalities;
  }

}
