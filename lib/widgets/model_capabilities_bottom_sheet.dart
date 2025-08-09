import 'package:flutter/material.dart';

import '../models/file_attachment.dart';
import '../theme/app_theme.dart';

class ModelCapabilitiesBottomSheet extends StatelessWidget {
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

  String _getInputPrice() {
    final pricingData = pricing ?? modelCapabilities?.pricing ?? modelData?['pricing'];
    if (pricingData == null) return '0.00';
    final input = pricingData['input'] ?? pricingData['prompt'];
    
    if (input == 0 || input == 0.0 || input == '0') return '0.00';
    if (input == -1) return '0.00';
    
    double inputNum = 0.0;
    if (input is num) {
      inputNum = input.toDouble();
    } else if (input is String) {
      inputNum = double.tryParse(input) ?? 0.0;
    }
    
    return inputNum.toStringAsFixed(2);
  }

  String _getOutputPrice() {
    final pricingData = pricing ?? modelCapabilities?.pricing ?? modelData?['pricing'];
    if (pricingData == null) return '0.00';
    final output = pricingData['output'] ?? pricingData['completion'];
    
    if (output == 0 || output == 0.0 || output == '0') return '0.00';
    if (output == -1) return '0.00';
    
    double outputNum = 0.0;
    if (output is num) {
      outputNum = output.toDouble();
    } else if (output is String) {
      outputNum = double.tryParse(output) ?? 0.0;
    }
    
    return outputNum.toStringAsFixed(2);
  }

  bool _isFree() {
    // Check model data first (same logic as ModelQuickSwitcher)
    if (modelData != null) {
      if (modelData!['isFree'] == true) return true;
      final modelId = modelData!['id'] as String? ?? '';
      if (modelId.endsWith(':free')) return true;
      
      // Check known free models (could be extended if needed)
      final knownFreeModels = {
        'gpt-3.5-turbo:free',
        'claude-3-haiku:free',
        'gemini-pro:free',
        'llama-2-7b-chat:free',
        'mistral-7b-instruct:free',
      };
      if (knownFreeModels.contains(modelId)) return true;
    }
    
    // Check pricing data
    final pricingData = pricing ?? modelCapabilities?.pricing ?? modelData?['pricing'];
    if (pricingData != null) {
      final input = pricingData['input'] ?? pricingData['prompt'];
      final output = pricingData['output'] ?? pricingData['completion'];
      if (input == 0 || input == 0.0 || input == '0') {
        if (output == 0 || output == 0.0 || output == '0') {
          return true;
        }
      }
    }
    
    // Default to true if no pricing data available
    return pricingData == null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (modelCapabilities == null) {
      return Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
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
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(theme),
          const SizedBox(height: 24),
          
          // Title
          Text(
            'Model Capabilities',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          
          // Model name
          Text(
            _getModelDisplayText(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          // Capabilities grid
          _buildCapabilitiesGrid(context),
          
          const SizedBox(height: 24),
        ],
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
    
    return Column(
      children: [
        // Input Modalities
        _buildCapabilitySection(
          'Input Modalities',
          [
            _buildCapabilityItem('Text', true, Icons.text_fields, theme),
            _buildCapabilityItem('Images', modelCapabilities!.supportsImages, Icons.image, theme),
            _buildCapabilityItem('Files', modelCapabilities!.supportsFiles, Icons.attach_file, theme),
          ],
          theme,
        ),
        const SizedBox(height: 16),
        
        // Context & Performance
        _buildCapabilitySection(
          'Context & Performance',
          [
            if (modelCapabilities!.contextLength != null)
              _buildCapabilityItem(
                'Context Length',
                true,
                Icons.memory,
                theme,
                subtitle: _formatContextLength(modelCapabilities!.contextLength!),
              ),
            if (modelCapabilities!.maxCompletionTokens != null)
              _buildCapabilityItem(
                'Max Output',
                true,
                Icons.output,
                theme,
                subtitle: _formatContextLength(modelCapabilities!.maxCompletionTokens!),
              ),
            _buildCapabilityItem(
              'Multimodal',
              modelCapabilities!.isMultimodal,
              Icons.category,
              theme,
            ),
          ],
          theme,
        ),
        
        // Pricing Details
        const SizedBox(height: 16),
        _buildCapabilitySection(
          'Pricing',
          [
            _buildPricingItem(
              'Input',
              _isFree() ? 'Free' : '\$${_getInputPrice()}/M',
              Icons.arrow_downward,
              theme,
            ),
            _buildPricingItem(
              'Output',
              _isFree() ? 'Free' : '\$${_getOutputPrice()}/M',
              Icons.arrow_upward,
              theme,
            ),
          ],
          theme,
        ),
      ],
    );
  }

  Widget _buildCapabilitySection(String title, List<Widget> items, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildCapabilityItem(String title, bool supported, IconData icon, ThemeData theme, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: supported ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: supported ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
            color: supported ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingItem(String title, String value, IconData icon, ThemeData theme) {
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
                Text(
                  title,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isFreeValue 
                        ? Colors.green 
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: isFreeValue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isFreeValue ? Icons.check_circle : Icons.monetization_on,
            size: 16,
            color: isFreeValue ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  String _formatContextLength(int length) {
    if (length >= 1000000) {
      return '${(length / 1000000).toStringAsFixed(1)}M tokens';
    } else if (length >= 1000) {
      return '${(length / 1000).toStringAsFixed(0)}K tokens';
    } else {
      return '$length tokens';
    }
  }

  String _getModelDisplayText() {
    if (modelName == null) return 'Unknown Model';
    
    final displayName = modelName!.contains('/')
      ? modelName!.split('/').last.replaceAll(':free', '')
      : modelName!;
    return 'Model: $displayName';
  }
}
