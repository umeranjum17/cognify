import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mode_config.dart';
import '../services/llm_service.dart';
import '../services/model_service.dart';
import '../services/request_usage_estimator.dart';
import '../theme/app_theme.dart';

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
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final modelsData = await ModelService.getEnhancedModelsByMode(
        widget.mode,
      );
      List<Map<String, dynamic>> modelsList = [];
      if (modelsData['data'] != null) {
        final models = List<Map<String, dynamic>>.from(modelsData['data']);
        modelsList = models;
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
      setState(() {
        _isLoading = false;
        if (_selectedProvider.isEmpty && _providersIndexed.isNotEmpty) {
          _selectedProvider = _providersIndexed.keys.first;
        }
      });
    } catch (e) {
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
      final pricing = model['pricing'] as Map<String, dynamic>?;
      final isFree =
          model['isFree'] == true ||
          (model['id']?.toString().endsWith(':free') ?? false) ||
          pricing == null || pricing.isEmpty;
      if (isFree) {
        _freeModels.add(model);
      } else {
        _providersIndexed.putIfAbsent(provider, () => []).add(model);
      }
    }
    if (_freeModels.isNotEmpty) {
      _providersIndexed['Free'] = _freeModels;
    }

    // Sort providers by number of models in descending order
    final sortedProviders = _providersIndexed.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Create a new map with sorted order
    _providersIndexed = Map.fromEntries(sortedProviders);
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
    // Pricing display simplified - backend calculates actual costs
    if (pricing == null) return 'Free';
    final inputPrice = (pricing['input'] ?? 0.0) as double;
    final outputPrice = (pricing['output'] ?? 0.0) as double;
    if (inputPrice == 0 && outputPrice == 0) return 'Free';
    return 'Paid';
  }

  List<String> _getModalities(Map<String, dynamic> model) {
    List<String> modalities = [];
    final inputModalities =
        model['inputModalities'] as List<dynamic>? ??
        model['input_modalities'] as List<dynamic>? ??
        model['architecture']?['input_modalities'] as List<dynamic>? ??
        [];
    modalities = inputModalities
        .map((modality) => modality.toString().toLowerCase())
        .toList();
    if (modalities.isEmpty) modalities = ['text'];
    return modalities;
  }

  void _selectModel(String modelId) {
    widget.onModelSelected(modelId);
    LLMService().setCurrentModel(modelId);
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
    // Simplified pricing check - backend handles detailed calculations
    final isFree =
        model['isFree'] == true ||
        (modelId is String && modelId.endsWith(':free')) ||
        (pricing != null && (pricing['input'] ?? 0.0) == 0.0 && (pricing['output'] ?? 0.0) == 0.0);
    final priceLabel = isFree ? 'Free' : 'Paid';

    return GestureDetector(
      onTap: () => _selectModel(modelId),
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
                    color: isFree
                        ? (isDark
                              ? AppColors.darkSuccess.withValues(alpha: 0.2)
                              : AppColors.lightSuccess.withValues(alpha: 0.15))
                        : (isDark
                              ? AppColors.darkAccent.withValues(alpha: 0.2)
                              : AppColors.lightAccent.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isFree
                          ? (isDark
                                ? AppColors.darkSuccess
                                : AppColors.lightSuccess)
                          : (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    priceLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isFree
                          ? (isDark
                                ? AppColors.darkSuccess
                                : AppColors.lightSuccess)
                          : (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent),
                    ),
                    textAlign: TextAlign.center,
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
}
