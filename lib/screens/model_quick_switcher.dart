import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mode_config.dart';
import '../services/llm_service.dart';
import '../services/model_service.dart';
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

  static const Set<String> _knownFreeModels = {
    'gpt-3.5-turbo:free',
    'claude-3-haiku:free',
    'gemini-pro:free',
    'llama-2-7b-chat:free',
    'mistral-7b-instruct:free',
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
      final modelsData = await ModelService.getEnhancedModelsByMode(widget.mode);
      List<Map<String, dynamic>> modelsList = [];
      if (modelsData['data'] != null) {
        final models = List<Map<String, dynamic>>.from(modelsData['data']);
        modelsList = models;
      } else if (modelsData['enhancedModels'] != null) {
        final enhancedModels = List<Map<String, dynamic>>.from(modelsData['enhancedModels']);
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
      final isFree = _isFree(model);
      if (isFree) {
        _freeModels.add(model);
      } else {
        _providersIndexed.putIfAbsent(provider, () => []).add(model);
      }
    }
    if (_freeModels.isNotEmpty) {
      _providersIndexed['Free'] = _freeModels;
    }
  }

  String _normalizeProvider(Map<String, dynamic> model) {
    String? provider = model['provider'] as String? ?? model['top_provider']?['name'] as String?;
    if (provider == null) return 'Other';
    final normalized = _providerNormalization[provider.toLowerCase()];
    if (normalized != null) return normalized;
    return provider.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }

  bool _isFree(Map<String, dynamic> model) {
    if (model['isFree'] == true) return true;
    final modelId = model['id'] as String? ?? '';
    if (modelId.endsWith(':free')) return true;
    if (_knownFreeModels.contains(modelId)) return true;
    final pricing = model['pricing'] as Map<String, dynamic>?;
    if (pricing != null) {
      final input = pricing['input'] ?? pricing['prompt'];
      final output = pricing['output'] ?? pricing['completion'];
      if (input == 0 || input == 0.0 || input == '0') {
        if (output == 0 || output == 0.0 || output == '0') {
          return true;
        }
      }
    }
    return false;
  }

  String _getProviderIcon(String? provider) {
    if (provider == null) return '🤖';
    switch (provider.toLowerCase()) {
      case 'openai': return '⚡';
      case 'anthropic': case 'claude': return '🧠';
      case 'google': case 'gemini': return '🎯';
      case 'meta': case 'llama': return '📘';
      case 'mistral': case 'mistralai': return '🌊';
      case 'deepseek': return '🔍';
      case 'cohere': return '💫';
      case 'perplexity': return '🌐';
      case 'x-ai': case 'xai': case 'grok': return '🚀';
      case 'qwen': return '🎨';
      case 'nvidia': return '💚';
      case 'free': return '🆓';
      default: return '🤖';
    }
  }

  String _getPriceDisplay(Map<String, dynamic>? pricing) {
    if (pricing == null) return 'Free';
    final input = pricing['input'] ?? pricing['prompt'];
    final output = pricing['output'] ?? pricing['completion'];
    if ((input == 0 || input == 0.0) && (output == 0 || output == 0.0)) return 'Free';
    if (input == -1 || output == -1) return 'Paid';
    if (input is num && output is num) {
      final inputPerMillion = (input * 1000000).toStringAsFixed(2);
      final outputPerMillion = (output * 1000000).toStringAsFixed(2);
      if (inputPerMillion == outputPerMillion) {
        return '\$$inputPerMillion/1M';
      }
      return '\$$inputPerMillion/\$$outputPerMillion';
    }
    if (input is String || output is String) {
      final inputNum = input is num ? input.toDouble() : double.tryParse(input.toString()) ?? 0.0;
      final outputNum = output is num ? output.toDouble() : double.tryParse(output.toString()) ?? 0.0;
      if (inputNum == 0.0 && outputNum == 0.0) return 'Free';
      final inputPerMillion = (inputNum * 1000000).toStringAsFixed(2);
      final outputPerMillion = (outputNum * 1000000).toStringAsFixed(2);
      if (inputPerMillion == outputPerMillion) {
        return '\$$inputPerMillion/1M';
      }
      return '\$$inputPerMillion/\$$outputPerMillion';
    }
    return 'Paid';
  }

  List<String> _getModalities(Map<String, dynamic> model) {
    List<String> modalities = [];
    final inputModalities = model['inputModalities'] as List<dynamic>? ??
        model['input_modalities'] as List<dynamic>? ??
        model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
    modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Switch Model',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                          Expanded(
                            child: _buildRightPanel(theme, isDark),
                          ),
                        ],
                      ),
          ),
        ],
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
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loadModelsByMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              foregroundColor: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
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
      width: 96,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.darkAccent.withValues(alpha: 0.12) : AppColors.lightAccent.withValues(alpha: 0.08))
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _getProviderIcon(provider),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${models.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 9,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search models...',
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkInput : AppColors.lightInput,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: filteredModels.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'No models available' : 'No models found',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredModels.length,
                  itemBuilder: (context, index) {
                    final model = filteredModels[index];
                    return _buildModelRow(model, theme, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModelRow(Map<String, dynamic> model, ThemeData theme, bool isDark) {
    final modelId = model['id'] ?? model['canonical_slug'] ?? model['name'] ?? 'unknown';
    final isSelected = modelId == widget.selectedModel;
    final modalities = _getModalities(model);
    final pricing = model['pricing'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: () => _selectModel(modelId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkAccent.withValues(alpha: 0.08) : AppColors.lightAccent.withValues(alpha: 0.04))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Model info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model['name']?.toString() ?? modelId,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                                : (isDark ? AppColors.darkText : AppColors.lightText),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (modalities.contains('image'))
                        Container(
                          margin: const EdgeInsets.only(right: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccentSecondary.withValues(alpha: 0.18) : AppColors.lightAccentSecondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '👁',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      if (modalities.contains('file'))
                        Container(
                          margin: const EdgeInsets.only(right: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccentSecondary.withValues(alpha: 0.18) : AppColors.lightAccentSecondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '🧩',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      if (model['contextLength'] != null || model['context_length'] != null)
                        Container(
                          margin: const EdgeInsets.only(right: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.15) : AppColors.lightTextMuted.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${(model['contextLength'] ?? model['context_length'] ?? 0) ~/ 1000}k',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Price chip
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccent.withValues(alpha: 0.18) : AppColors.lightAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    _getPriceDisplay(pricing),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    ),
                  ),
                  if (_getPriceDisplay(pricing).contains('/1M'))
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        'per 1M',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 8,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}