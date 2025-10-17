import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mode_config.dart';
import '../services/optimized_llm_service.dart';
import '../providers/usage_quota_provider.dart';
import 'package:provider/provider.dart';
import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../utils/provider_priority.dart';

class ModelQuickSwitcher extends StatefulWidget {
  final ChatMode mode;
  final String selectedModel;
  final Function(String) onModelSelected;

  const ModelQuickSwitcher({
    super.key,
    required this.mode,
    required this.selectedModel,
    required this.onModelSelected,
  });

  @override
  State<ModelQuickSwitcher> createState() => _ModelQuickSwitcherState();
}

class _ModelQuickSwitcherState extends State<ModelQuickSwitcher> {
  Map<String, List<Map<String, dynamic>>> _providersIndexed = {};
  List<Map<String, dynamic>> _freeModels = [];
  String _selectedProvider = '';
  String _searchQuery = '';
  bool _isLoading = true;
  String _error = '';

  static const Map<String, String> _providerNormalization = {
    'google': 'Gemini',
    'anthropic': 'Claude',
    'x-ai': 'Grok',
    'xai': 'Grok',
    'meta': 'Llama',
    'mistral': 'Mistral',
    'mistralai': 'Mistral',
    'deepseek': 'DeepSeek',
    'openai': 'OpenAI',
    'qwen': 'Qwen',
    'moonshot': 'Moonshot',
    'z.ai': 'Z.ai',
    'stealth': 'Stealth',
  };

  @override
  void initState() {
    super.initState();
    _loadModelsByMode();
  }

  Future<void> _loadModelsByMode() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Clear cache to ensure fresh data
      ModelService.clearCache();
      final modelsData = await ModelService.getEnhancedModelsByMode(
        widget.mode,
      );
      List<Map<String, dynamic>> modelsList = [];
      if (modelsData['data'] != null) {
        final raw = modelsData['data'];
        if (raw is List) {
          modelsList = raw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } else if (modelsData['enhancedModels'] != null) {
        final enhancedModels = List<Map<String, dynamic>>.from(
          modelsData['enhancedModels'],
        );
        for (Map<String, dynamic> model in enhancedModels) {
          if (model['isAvailable'] == true) {
            modelsList.add(model);
          }
        }
      }
      _processModels(modelsList);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_selectedProvider.isEmpty && _providersIndexed.isNotEmpty) {
          _selectedProvider = _providersIndexed.keys.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _processModels(List<Map<String, dynamic>> models) {
    _providersIndexed.clear();
    _freeModels.clear();
    for (final model in models) {
      final provider = _normalizeProvider(model);
      
      // Use utility function to check if model is budget
      final isBudget = ProviderPriority.isBudgetModel(model);
      print('🔍 Model ${model['id']}: provider=$provider, isBudget=$isBudget, requestEstimate=${model['requestEstimate']}');
      
      // Add model to its provider category
      _providersIndexed.putIfAbsent(provider, () => []).add(model);
      
      // ALSO add to Budget category if it's a budget model
      if (isBudget) {
        _providersIndexed.putIfAbsent('Budget', () => []).add(model);
      }
    }

    // Sort providers by priority using utility function
    final sortedProviders = _providersIndexed.entries.toList()
      ..sort((a, b) => ProviderPriority.compareProviders(a.key, b.key));

    // Create a new map with sorted order
    _providersIndexed = Map.fromEntries(sortedProviders);
    
    print('📊 Final provider order: ${_providersIndexed.keys.toList()}');
    
    // Sort models within each provider by provider priority (for budget models)
    for (final entry in _providersIndexed.entries) {
      if (entry.key == 'Budget') {
        // Sort budget models by provider priority
        entry.value.sort((a, b) {
          final aProvider = (a['provider'] ?? '').toString().toLowerCase();
          final bProvider = (b['provider'] ?? '').toString().toLowerCase();
          final aPriority = ProviderPriority.getPriority(aProvider);
          final bPriority = ProviderPriority.getPriority(bProvider);
          
          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }
          
          // If same priority, sort by name
          return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
        });
      }
    }
  }

  String _normalizeProvider(Map<String, dynamic> model) {
    String? provider =
        model['provider'] as String? ??
        model['top_provider']?['name'] as String?;
    if (provider == null) return 'Other';
    final normalized = _providerNormalization[provider.toLowerCase()];
    if (normalized != null) return normalized;
    return provider
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  String _getProviderIcon(String? provider) {
    if (provider == null) return '🤖';
    switch (provider.toLowerCase()) {
      case 'openai':
        return '⚡';
      case 'anthropic':
      case 'claude':
        return '🧠';
      case 'google':
      case 'gemini':
        return '🎯';
      case 'meta':
      case 'llama':
        return '📘';
      case 'mistral':
      case 'mistralai':
        return '🌊';
      case 'deepseek':
        return '🔍';
      case 'cohere':
        return '💫';
      case 'perplexity':
        return '🌐';
      case 'x-ai':
      case 'xai':
      case 'grok':
        return '🚀';
      case 'qwen':
        return '🎨';
      case 'nvidia':
        return '💚';
      case 'free':
        return '🆓';
      default:
        return '🤖';
    }
  }

  String _getPriceDisplay(Map<String, dynamic>? pricing) {
    // Display Free only when pricing explicitly exists with zero values
    if (pricing == null || pricing.isEmpty) return 'Paid';
    final inputPrice = (pricing['input'] ?? 0.0) as double;
    final outputPrice = (pricing['output'] ?? 0.0) as double;
    if (inputPrice == 0 && outputPrice == 0) return 'Free';
    return 'Paid';
  }

  List<String> _getModalities(Map<String, dynamic> model) {
    List<String> modalities = [];
    
    // Try multiple sources for input modalities
    final inputModalities = model['inputModalities'] as List<dynamic>? ??
                           model['input_modalities'] as List<dynamic>? ??
                           model['architecture']?['input_modalities'] as List<dynamic>? ??
                           [];
    
    modalities = inputModalities
        .map((modality) => modality.toString().toLowerCase())
        .toList();
    
    // If no modalities found, default to text
    if (modalities.isEmpty) modalities = ['text'];
    
    // Debug: Print what we're getting in model switcher (only for specific models)
    if (model['id']?.toString().contains('gpt') == true || 
        model['id']?.toString().contains('claude') == true || 
        model['id']?.toString().contains('gemini') == true) {
      print('🔍 Model ${model['id']} modalities in switcher:');
      print('  - inputModalities: ${model['inputModalities']}');
      print('  - outputModalities: ${model['outputModalities']}');
      print('  - architecture: ${model['architecture']}');
      print('  - extracted modalities: $modalities');
      
      // Also check if the model supports images based on capabilities
      if (model['supportsImages'] == true && !modalities.contains('image')) {
        print('  - Adding image modality based on supportsImages flag');
        modalities.add('image');
      }
    }
    
    return modalities;
  }

  void _selectModel(String modelId) {
    widget.onModelSelected(modelId);
    OptimizedLLMService().setCurrentModel(modelId);
    Navigator.of(context).pop();
  }

  List<Map<String, dynamic>> _getFilteredModels() {
    if (_selectedProvider.isEmpty) return [];
    final models = _providersIndexed[_selectedProvider] ?? [];
    if (_searchQuery.isEmpty) return models;
    return models.where((model) {
      final name = model['name']?.toString().toLowerCase() ?? '';
      final id = model['id']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Quota provider to determine affordability
    final quotaProvider = context.read<UsageQuotaProvider?>();
    final remaining = quotaProvider?.quota?.remaining;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHandle(theme),
                const SizedBox(height: 24),
                Text(
                  'Switch Model',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState(theme, isDark)
                : _error.isNotEmpty
                ? _buildErrorState(theme, isDark)
                : Row(
                    children: [
                      _buildLeftRail(theme, isDark),
                      Expanded(child: _buildRightPanel(theme, isDark)),
                    ],
                  ),
          ),
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

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
          ),
          const SizedBox(height: 12),
          Text(
            'Loading models...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 36,
            color: isDark ? AppColors.darkError : AppColors.lightError,
          ),
          const SizedBox(height: 10),
          Text(
            'Failed to load models',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isDark ? AppColors.darkError : AppColors.lightError,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loadModelsByMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.darkAccent
                  : AppColors.lightAccent,
              foregroundColor: isDark
                  ? AppColors.darkButtonText
                  : AppColors.lightButtonText,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: theme.textTheme.bodySmall,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftRail(ThemeData theme, bool isDark) {
    return Container(
      width: 100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _providersIndexed.length,
        itemBuilder: (context, index) {
          final provider = _providersIndexed.keys.elementAt(index);
          final models = _providersIndexed[provider] ?? [];
          final isSelected = provider == _selectedProvider;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedProvider = provider;
                _searchQuery = '';
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? AppColors.darkAccent.withValues(alpha: 0.08)
                          : AppColors.lightAccent.withValues(alpha: 0.05))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    _getProviderIcon(provider),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent)
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground.withValues(alpha: 0.6)
                          : AppColors.lightBackground.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${models.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightPanel(ThemeData theme, bool isDark) {
    final filteredModels = _getFilteredModels();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search models...',
              prefixIcon: Icon(
                Icons.search,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  width: 1,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.4)
                  : AppColors.lightBackground.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: filteredModels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.model_training
                            : Icons.search_off,
                        size: 36,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No models available'
                            : 'No models found',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Try selecting a different provider'
                            : 'Try adjusting your search terms',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredModels.length,
                  itemBuilder: (context, index) {
                    final model = filteredModels[index];
                    return _buildModelCard(model, theme, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModelCard(
    Map<String, dynamic> model,
    ThemeData theme,
    bool isDark,
  ) {
    final modelId =
        model['id'] ?? model['canonical_slug'] ?? model['name'] ?? 'unknown';
    final isSelected = modelId == widget.selectedModel;
    final modalities = _getModalities(model);
    final pricing = model['pricing'] as Map<String, dynamic>?;
    final contextLength = model['contextLength'] ?? model['context_length'];

    // Get pre-calculated request estimate from model data
    final requestEstimate = model['requestEstimate'] as Map<String, dynamic>?;
    final double requestUnits =
        ((requestEstimate?['requestUnits'] as num?)?.toDouble() ?? 0.0);
    final double dollarCost = (requestEstimate?['dollarCost'] ?? 0.0).toDouble();

    // Simplified pricing check - backend handles detailed calculations
    final bool explicitZeroPricing = pricing != null &&
        pricing.containsKey('input') &&
        pricing.containsKey('output') &&
        ((pricing['input'] ?? 0.0) == 0.0) &&
        ((pricing['output'] ?? 0.0) == 0.0);
    // Do not label free; treat zero/unknown as cost unknown
    final bool isFree = false;

    // Determine remaining request units from quota provider
    final quotaProvider = context.read<UsageQuotaProvider?>();
    final int remainingUnits = quotaProvider?.quota?.remaining ?? 0;

    // Treat unknown/zero units as affordable; otherwise compare to remaining
    final bool isAffordable = requestUnits <= 0
        ? true
        : (remainingUnits > 0 && requestUnits <= remainingUnits);

    return GestureDetector(
      onTap: isAffordable
          ? () => _selectModel(modelId)
          : () => _showInsufficientCredits(
                context,
                theme,
                isDark,
                need: requestUnits,
                have: remainingUnits.toDouble(),
              ),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                        ? AppColors.darkAccent.withValues(alpha: 0.06)
                        : AppColors.lightAccent.withValues(alpha: 0.04))
                  : (isDark
                        ? AppColors.darkBackground.withValues(alpha: 0.3)
                        : AppColors.lightBackground.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
              // Visually indicate disabled/locked models
              border: !isAffordable
                  ? Border.all(
                      color: isDark ? Colors.redAccent.withValues(alpha: 0.6) : Colors.redAccent.withValues(alpha: 0.5),
                      width: 1.0,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Model info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model['name']?.toString() ?? modelId,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isSelected
                              ? (isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent)
                              : (isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Description if available
                      if (model['description'] != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model['description'],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _showDescriptionDialog(
                                context,
                                model['description'],
                                model['name']?.toString() ?? modelId,
                                theme,
                                isDark,
                              ),
                              child: Icon(
                                Icons.info_outline,
                                size: 14,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Features row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Text modality (always present)
                          _buildCompactFeatureChip(
                            Icons.text_fields,
                            isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground,
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          // Images if supported
                          if (modalities.contains('image'))
                            _buildCompactFeatureChip(
                              Icons.image,
                              isDark
                                  ? AppColors.darkInfo.withValues(alpha: 0.2)
                                  : AppColors.lightInfo.withValues(alpha: 0.15),
                              isDark ? AppColors.darkInfo : AppColors.lightInfo,
                            ),
                          // Files if supported
                          if (modalities.contains('file'))
                            _buildCompactFeatureChip(
                              Icons.attach_file,
                              isDark
                                  ? AppColors.darkAccentSecondary.withValues(
                                      alpha: 0.2,
                                    )
                                  : AppColors.lightAccentSecondary.withValues(
                                      alpha: 0.15,
                                    ),
                              isDark
                                  ? AppColors.darkAccentSecondary
                                  : AppColors.lightAccentSecondary,
                            ),
                          // Context length if available
                          if (contextLength != null)
                            _buildCompactFeatureChip(
                              Icons.memory,
                              isDark
                                  ? AppColors.darkAccentTertiary.withValues(
                                      alpha: 0.2,
                                    )
                                  : AppColors.lightAccentTertiary.withValues(
                                      alpha: 0.15,
                                    ),
                              isDark
                                  ? AppColors.darkAccentTertiary
                                  : AppColors.lightAccentTertiary,
                              label: '${(contextLength / 1000).round()}K',
                            ),
                        ],
                      ),
                      ],
                  ),
                ),

                const SizedBox(width: 24),

                // Price chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (requestUnits > 0 && requestUnits <= 0.5)
                        ? (isDark
                              ? AppColors.darkSuccess.withValues(alpha: 0.2)
                              : AppColors.lightSuccess.withValues(alpha: 0.15))
                        : (isDark
                              ? AppColors.darkAccent.withValues(alpha: 0.2)
                              : AppColors.lightAccent.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (requestUnits > 0 && requestUnits <= 0.5)
                          ? (isDark
                                ? AppColors.darkSuccess
                                : AppColors.lightSuccess)
                          : (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (pricing != null &&
                                (pricing['input'] == 0 || pricing['input'] == 0.0) &&
                                (pricing['output'] == 0 || pricing['output'] == 0.0))
                            ? (() {
                                // Use configurable free model rate from backend config
                                final quotaPricing = model['quotaPricing'] as Map<String, dynamic>?;
                                final freeModelRate = (quotaPricing?['freeModelRate'] as num?)?.toDouble() ?? 0.3;
                                return 'x${freeModelRate.toStringAsFixed(1)}';
                              })()
                            : (requestUnits > 0
                                  ? 'x${requestUnits.toStringAsFixed(1)}'
                                  : '—'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (requestUnits > 0 && requestUnits <= 0.5)
                              ? (isDark
                                    ? AppColors.darkSuccess
                                    : AppColors.lightSuccess)
                              : (isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent),
                        ),
                      ),
                      if (!isAffordable) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: isDark ? Colors.redAccent.withValues(alpha: 1.0) : Colors.redAccent.withValues(alpha: 0.9),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selection indicator in top-right corner
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 8),
              ),
            ),

          // If not affordable, overlay a faint scrim
          if (!isAffordable)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.grey).withValues(alpha: isDark ? 0.4 : 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactFeatureChip(
    IconData icon,
    Color bgColor,
    Color textColor, {
    String? label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: textColor),
          if (label != null) ...[
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDescriptionDialog(
    BuildContext context,
    String? description,
    String modelName,
    ThemeData theme,
    bool isDark,
  ) {
    if (description == null || description.isEmpty) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            modelName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 14,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Close',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showInsufficientCredits(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    required double need,
    required double have,
  }) {
    final snackBar = SnackBar(
      content: Text(
        'Not enough credits: need x${need.toStringAsFixed(1)}, have x${have.toStringAsFixed(0)}',
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Buy credits',
        textColor: Colors.white,
        onPressed: () {
          // The purchase sheet is attached elsewhere in UI; here we just hint.
        },
      ),
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
