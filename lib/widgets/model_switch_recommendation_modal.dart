import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/model_registry.dart';
import '../providers/mode_config_provider.dart';
import '../services/llm_service.dart';
import '../theme/app_theme.dart';
import '../screens/model_quick_switcher.dart';

class ModelSwitchRecommendationModal extends StatelessWidget {
  final String errorType;
  final String title;
  final String message;
  final String currentModel;
  final List<String> suggestedModels;
  final Function(String) onModelSelected;
  final VoidCallback onDismiss;
  final VoidCallback onTryAgain;

  const ModelSwitchRecommendationModal({
    super.key,
    required this.errorType,
    required this.title,
    required this.message,
    required this.currentModel,
    required this.suggestedModels,
    required this.onModelSelected,
    required this.onDismiss,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with warning icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getErrorColor(errorType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getErrorIcon(errorType),
                    color: _getErrorColor(errorType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error description
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 20),

            // Current model display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getErrorColor(errorType).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: _getErrorColor(errorType),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current Model: ${ModelRegistry.formatModelName(currentModel)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Show different content based on error type
            if (errorType == 'unauthorized') ...[
              // For unauthorized errors, show reconfigure button instead of model suggestions
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    onDismiss(); // Close this dialog
                    // Navigate to OAuth onboarding using GoRouter
                    context.go('/oauth-onboarding');
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Reconfigure OpenRouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ] else if (errorType == 'model_unavailable') ...[
              // For model unavailable, show switch model button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    onDismiss(); // Close this dialog
                    // Open the model quick switcher
                    _openModelSwitcher(context);
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Switch Model'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ] else ...[
              // For other errors, show model suggestions
              Text(
                'Suggested Alternatives',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Suggested models list
              ...suggestedModels.take(3).map((modelId) => _buildModelCard(
                context,
                modelId,
                theme,
                colorScheme,
              )),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDismiss,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onTryAgain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(
    BuildContext context,
    String modelId,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isFree = ModelRegistry.isModelFree(modelId);
    final capabilities = ModelRegistry.getModelCapabilities(modelId);
    final hasImages = capabilities.supportsImages;
    final hasFiles = capabilities.supportsFiles;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Provider icon
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getProviderColor(modelId),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getProviderIcon(modelId),
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ModelRegistry.formatModelName(modelId),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Free/Paid indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isFree 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFree ? 'FREE' : 'PAID',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isFree ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Model capabilities
          Row(
            children: [
              if (hasImages) ...[
                Icon(
                  Icons.image,
                  size: 16,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Images',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (hasFiles) ...[
                Icon(
                  Icons.attach_file,
                  size: 16,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Files',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Switch button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onModelSelected(modelId),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Switch to this model'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getErrorColor(String errorType) {
    switch (errorType) {
      case 'rate_limit':
        return Colors.orange;
      case 'quota_exceeded':
        return Colors.red;
      case 'model_unavailable':
        return Colors.purple;
      case 'unauthorized':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getErrorIcon(String errorType) {
    switch (errorType) {
      case 'rate_limit':
        return Icons.speed;
      case 'quota_exceeded':
        return Icons.account_balance_wallet;
      case 'model_unavailable':
        return Icons.error_outline;
      case 'unauthorized':
        return Icons.lock;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getProviderColor(String modelId) {
    if (modelId.contains('gpt')) return Colors.green;
    if (modelId.contains('gemini')) return Colors.blue;
    if (modelId.contains('claude')) return Colors.orange;
    if (modelId.contains('deepseek')) return Colors.purple;
    if (modelId.contains('mistral')) return Colors.indigo;
    return Colors.grey;
  }

  IconData _getProviderIcon(String modelId) {
    if (modelId.contains('gpt')) return Icons.chat;
    if (modelId.contains('gemini')) return Icons.auto_awesome;
    if (modelId.contains('claude')) return Icons.psychology;
    if (modelId.contains('deepseek')) return Icons.search;
    if (modelId.contains('mistral')) return Icons.cloud;
    return Icons.smart_toy;
  }
} 