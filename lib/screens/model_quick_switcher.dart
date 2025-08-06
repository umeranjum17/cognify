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

  // Provider normalization map
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

  // Known free models set (from model_selection_screen.dart:134)
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
      print('🔄 QuickSwitcher: Loading models for mode: ${widget.mode}');
      final modelsData = await ModelService.getEnhancedModelsByMode(widget.mode);
      print('📦 QuickSwitcher: Received models data: ${modelsData.keys}');

      List<Map<String, dynamic>> modelsList = [];

      // Check if we have data array directly (from getModelsByMode)
      if (modelsData['data'] != null) {
        final models = List<Map<String, dynamic>>.from(modelsData['data']);
        print('✅ QuickSwitcher: Found ${models.length} models in data array');
        modelsList = models;
      }
      // Fallback: Check if we have enhancedModels array (for backward compatibility)
      else if (modelsData['enhancedModels'] != null) {
        final enhancedModels = List<Map<String, dynamic>>.from(modelsData['enhancedModels']);
        print('✅ QuickSwitcher: Found ${enhancedModels.length} models in enhancedModels array');

        for (Map<String, dynamic> model in enhancedModels) {
          // Only include models that are available
          if (model['isAvailable'] == true) {
            modelsList.add(model);
          }
        }
      } else {
        print('⚠️ QuickSwitcher: No models found in expected data structure');
        print('📋 Available keys: ${modelsData.keys}');
      }

      print('📊 QuickSwitcher: Total models processed: ${modelsList.length}');

      // Process models and group by provider
      _processModels(modelsList);

      setState(() {
        _isLoading = false;
        // Set first provider as selected if none selected
        if (_selectedProvider.isEmpty && _providersIndexed.isNotEmpty) {
          _selectedProvider = _providersIndexed.keys.first;
        }
      });
    } catch (e) {
      print('❌ QuickSwitcher: Error loading models: $e');
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

    // Add Free category if we have free models
    if (_freeModels.isNotEmpty) {
      _providersIndexed['Free'] = _freeModels;
    }

    print('🏢 QuickSwitcher: Processed providers: ${_providersIndexed.keys.toList()}');
  }

  String _normalizeProvider(Map<String, dynamic> model) {
    // Try different provider field names
    String? provider = model['provider'] as String? ?? 
                      model['top_provider']?['name'] as String?;

    if (provider == null) return 'Other';

    final normalized = _providerNormalization[provider.toLowerCase()];
    if (normalized != null) {
      return normalized;
    }

    // TitleCase the original if not in normalization map
    return provider.split(' ').map((word) => 
      word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
    ).join(' ');
  }

  bool _isFree(Map<String, dynamic> model) {
    // Primary: model["isFree"] == true
    if (model['isFree'] == true) return true;

    // Fallback 1: model["id"] endsWith ":free"
    final modelId = model['id'] as String? ?? '';
    if (modelId.endsWith(':free')) return true;

    // Fallback 2: model["id"] contained in knownFreeModels set
    if (_knownFreeModels.contains(modelId)) return true;

    // Fallback 3: pricing fields input/output or prompt/completion are both zero
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

    // Handle different pricing field names
    final input = pricing['input'] ?? pricing['prompt'];
    final output = pricing['output'] ?? pricing['completion'];

    // Check if it's free (both input and output are 0)
    if ((input == 0 || input == 0.0) && (output == 0 || output == 0.0)) {
      return 'Free';
    }

    // Check if pricing is unavailable (-1 values)
    if (input == -1 || output == -1) {
      return 'Paid';
    }

    // Convert to per-million tokens for better readability
    if (input is num && output is num) {
      // The values are already per token, so multiply by 1M to get per-million
      final inputPerMillion = (input * 1000000).toStringAsFixed(2);
      final outputPerMillion = (output * 1000000).toStringAsFixed(2);

      // If both are the same, show single price
      if (inputPerMillion == outputPerMillion) {
        return '\$$inputPerMillion/1M';
      }

      // Show input/output prices in a clearer format
      return '\$$inputPerMillion/\$$outputPerMillion';
    }

    // Handle string values (some APIs return strings)
    if (input is String && output is String) {
      final inputNum = double.tryParse(input) ?? 0.0;
      final outputNum = double.tryParse(output) ?? 0.0;
      
      if (inputNum == 0.0 && outputNum == 0.0) {
        return 'Free';
      }
      
      final inputPerMillion = (inputNum * 1000000).toStringAsFixed(2);
      final outputPerMillion = (outputNum * 1000000).toStringAsFixed(2);
      
      if (inputPerMillion == outputPerMillion) {
        return '\$$inputPerMillion/1M';
      }
      
      return '\$$inputPerMillion/\$$outputPerMillion';
    }

    // Handle mixed types
    if (input is String || output is String) {
      final inputNum = input is num ? input.toDouble() : double.tryParse(input.toString()) ?? 0.0;
      final outputNum = output is num ? output.toDouble() : double.tryParse(output.toString()) ?? 0.0;
      
      if (inputNum == 0.0 && outputNum == 0.0) {
        return 'Free';
      }
      
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
    // Improved modalities extraction - handle multiple possible field names and data structures
    List<String> modalities = [];
    final inputModalities = model['inputModalities'] as List<dynamic>? ?? 
                           model['input_modalities'] as List<dynamic>? ?? 
                           model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
    
    // Convert to string list and normalize
    modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
    
    // If no modalities found, assume text-only
    if (modalities.isEmpty) {
      modalities = ['text'];
    }
    
    return modalities;
  }

  void _selectModel(String modelId) {
    print('🤖 QuickSwitcher: Model selected: $modelId');
    widget.onModelSelected(modelId);
    
    // Also update the LLM service's current model to ensure API calls use the selected model
    LLMService().setCurrentModel(modelId);
    print('🤖 QuickSwitcher: Updated LLM service current model to: $modelId');
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
            padding: const EdgeInsets.all(20),
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
                  style: theme.textTheme.titleLarge?.copyWith(
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
                          // Left rail - providers
                          _buildLeftRail(theme, isDark),
                          
                          // Right panel - models
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
          const SizedBox(height: 16),
          Text(
            'Loading models...',
            style: theme.textTheme.bodyMedium?.copyWith(
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
            size: 48,
            color: isDark ? AppColors.darkError : AppColors.lightError,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load models',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? AppColors.darkError : AppColors.lightError,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadModelsByMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              foregroundColor: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftRail(ThemeData theme, bool isDark) {
    return Container(
      width: 120,
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
                _searchQuery = ''; // Clear search when switching providers
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.darkAccent.withValues(alpha: 0.15) : AppColors.lightAccent.withValues(alpha: 0.1))
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _getProviderIcon(provider),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${models.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 10,
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
        // Search field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search models...',
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkInput : AppColors.lightInput,
            ),
          ),
        ),
        
        // Models list
        Expanded(
          child: filteredModels.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'No models available' : 'No models found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkAccent.withValues(alpha: 0.1) : AppColors.lightAccent.withValues(alpha: 0.05))
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                                : (isDark ? AppColors.darkText : AppColors.lightText),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Capability badges
                      if (modalities.contains('image'))
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccentSecondary.withValues(alpha: 0.2) : AppColors.lightAccentSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '👁',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      if (modalities.contains('file'))
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccentSecondary.withValues(alpha: 0.2) : AppColors.lightAccentSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🧩',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      // Context length if available
                      if (model['contextLength'] != null || model['context_length'] != null)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.2) : AppColors.lightTextMuted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(model['contextLength'] ?? model['context_length'] ?? 0) ~/ 1000}k',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccent.withValues(alpha: 0.2) : AppColors.lightAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getPriceDisplay(pricing),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 