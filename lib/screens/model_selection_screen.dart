import 'dart:async';

import 'package:flutter/material.dart';

import '../models/mode_config.dart';
import '../services/llm_service.dart'; // Added import for LLMService
import '../services/model_service.dart';
import '../theme/app_theme.dart';

class ModelSelectionScreen extends StatefulWidget {
  final ChatMode mode;
  final String selectedModel;
  final Function(String) onModelSelected;

  const ModelSelectionScreen({
    super.key,
    required this.mode,
    required this.selectedModel,
    required this.onModelSelected,
  });

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  List<Map<String, dynamic>> _allModels = [];
  List<Map<String, dynamic>> _filteredModels = [];
  bool _isLoading = true;
  String _error = '';
  final ScrollController _scrollController = ScrollController();

  // Filter state
  String _searchQuery = '';
  final List<String> _selectedProviders = [];
  final List<String> _selectedModalities = [];
  bool _showFreeOnly = false;

  // Filter options
  List<String> _availableProviders = [];
  final List<String> _availableModalities = ['Text', 'Images', 'Files'];

  // Search debouncing
  Timer? _searchDebounce;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildModeHeader(theme, isDark),
            _buildFiltersSection(theme, isDark),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      ),
                    )
                  : _error.isNotEmpty
                    ? _buildErrorState(theme)
                    : _buildModelsList(theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  // Helper methods
  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allModels);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((model) {
        final name = (model['name'] ?? '').toString().toLowerCase();
        final id = (model['id'] ?? '').toString().toLowerCase();
        final provider = (model['provider'] ?? '').toString().toLowerCase();
        final description = (model['description'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        return name.contains(query) || id.contains(query) || provider.contains(query) || description.contains(query);
      }).toList();
    }

    // Provider filter (multi-select)
    if (_selectedProviders.isNotEmpty) {
      filtered = filtered.where((model) {
        final provider = model['provider']?.toString() ?? model['top_provider']?['name']?.toString();
        return _selectedProviders.contains(provider);
      }).toList();
    }

    // Free/paid filter
    if (_showFreeOnly) {
      // Known free model IDs as fallback
      final knownFreeModels = {
        'mistralai/mistral-7b-instruct:free',
        'deepseek/deepseek-chat:free',
        'deepseek/deepseek-chat-v3-0324:free',
        'deepseek/deepseek-r1:free',
        'google/gemini-2.0-flash-exp:free',
        'meta-llama/llama-3.2-3b-instruct:free',
        'meta-llama/llama-3.2-1b-instruct:free',
        'meta-llama/llama-3.1-8b-instruct:free',
        'meta-llama/llama-3.1-70b-instruct:free',
        'meta-llama/llama-3.1-405b-instruct:free',
        'meta-llama/llama-3-8b-instruct:free',
        'meta-llama/llama-3-70b-instruct:free',
        'meta-llama/codellama-34b-instruct:free',
        'microsoft/phi-3-medium-128k-instruct:free',
        'microsoft/phi-3-mini-128k-instruct:free',
        'mistralai/mixtral-8x7b-instruct:free',
      };

      filtered = filtered.where((model) {
        // Primary check: backend isFree field
        if (model['isFree'] == true) {
          return true;
        }

        // Fallback: check if model ID ends with :free
        final modelId = model['id'] as String? ?? '';
        if (modelId.endsWith(':free')) {
          return true;
        }

        // Fallback: check against known free models
        if (knownFreeModels.contains(modelId)) {
          return true;
        }

        // Additional fallback: check pricing if available
        final pricing = model['pricing'] as Map<String, dynamic>?;
        if (pricing != null) {
          final inputCost = double.tryParse(pricing['input']?.toString() ?? '0') ?? 0;
          final outputCost = double.tryParse(pricing['output']?.toString() ?? '0') ?? 0;
          if (inputCost == 0 && outputCost == 0) {
            return true;
          }
        }

        return false;
      }).toList();
    }

    // Modality filters (multi-select)
    if (_selectedModalities.isNotEmpty) {
      filtered = filtered.where((model) {
        // Use the same improved modalities extraction as in _buildModelCard
        final inputModalities = model['inputModalities'] as List<dynamic>? ?? 
                               model['input_modalities'] as List<dynamic>? ?? 
                               model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
        
        // Convert to string list and normalize
        final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
        
        // If no modalities found, assume text-only
        final modelModalities = modalities.isEmpty ? ['text'] : modalities;

        return _selectedModalities.every((modality) {
          switch (modality) {
            case 'Text':
              return modelModalities.contains('text');
            case 'Images':
              return modelModalities.contains('image');
            case 'Files':
              return modelModalities.contains('file');
            default:
              return false;
          }
        });
      }).toList();
    }

    // Sorting by name
    filtered.sort((a, b) {
      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    });

    setState(() {
      _filteredModels = filtered;
    });
  }

  Widget _buildErrorState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkError.withValues(alpha: 0.1) : AppColors.lightError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: isDark ? AppColors.darkError : AppColors.lightError,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load models',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadModels,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                foregroundColor: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, {Color? bgColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.lightBackgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor ?? AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildFiltersSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInput : AppColors.lightInput,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
                width: 1,
              ),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search models...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkInputPlaceholder : AppColors.lightInputPlaceholder,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: isDark ? AppColors.darkInputPlaceholder : AppColors.lightInputPlaceholder,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 16,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          const SizedBox(height: 20),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildModernFilterChip(
                  'Providers',
                  _selectedProviders.isEmpty ? 'All' : '${_selectedProviders.length} selected',
                  Icons.business,
                  () => _showProviderFilter(context, theme, isDark),
                  theme,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildModernFilterChip(
                  'Modalities',
                  _selectedModalities.isEmpty ? 'All' : '${_selectedModalities.length} selected',
                  Icons.category,
                  () => _showModalityFilter(context, theme, isDark),
                  theme,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildToggleChip(
                  'Free Only',
                  Icons.money_off,
                  _showFreeOnly,
                  (value) {
                    setState(() => _showFreeOnly = value);
                    _applyFilters();
                  },
                  theme,
                  isDark,
                ),
                const SizedBox(width: 16), // Extra padding at the end
              ],
            ),
          ),

          // Results count
          if (_filteredModels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Showing ${_filteredModels.length} models',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeHeader(ThemeData theme, bool isDark) {
    final isChat = widget.mode == ChatMode.chat;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccent.withValues(alpha: 0.15) : AppColors.lightAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isChat ? Icons.flash_on : Icons.search,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isChat ? 'Chat Mode' : 'DeepSearch Mode',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isChat
                          ? 'Lightning fast responses with minimal search'
                          : 'Ultra-comprehensive research with enhanced visual content',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(Map<String, dynamic> model, bool isSelected, ThemeData theme, bool isDark) {
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
    
    // Debug logging for modalities
    final modelId = model['id'] ?? model['canonical_slug'] ?? model['name'] ?? 'unknown';
    print('🔍 Model $modelId modalities: $modalities (raw: $inputModalities)');
    
    final pricing = model['pricing'] as Map<String, dynamic>?;
    
    // Debug logging for pricing
    if (pricing != null) {
      print('💰 Model $modelId pricing: $pricing');
    }
    
    final isFree = model['isFree'] == true || 
                  (pricing != null && 
                   (pricing['input'] == 0.0 && pricing['output'] == 0.0) ||
                   ((pricing?['prompt']?.toString() ?? '0') == '0' && (pricing?['completion']?.toString() ?? '0') == '0'));
    final provider = model['provider'] as String? ?? model['top_provider']?['name'] as String?;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    // Use the correct model identifier - try id first, then canonical_slug
    final modelIdForSelection = model['id'] ?? model['canonical_slug'] ?? model['name'] ?? 'unknown';

    return GestureDetector(
      onTap: () => _selectModel(modelIdForSelection),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: accentColor, width: 2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackgroundLight
                          : AppColors.lightBackgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getProviderIcon(provider),
                      style: TextStyle(fontSize: 20, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model['name'] ?? model['id'] ?? 'Unknown',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (provider != null)
                          Text(
                            provider,
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
              if (model['description'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  model['description'],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Always show Text modality since all models support text
                  _buildFeatureChip(
                    'Text',
                    bgColor: isDark ? AppColors.darkBackgroundLight : AppColors.lightBackgroundDark,
                    textColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  // Show Images if model supports it
                  if (modalities.contains('image'))
                    _buildFeatureChip(
                      'Images',
                      bgColor: isDark ? AppColors.darkInfo.withValues(alpha: 0.2) : AppColors.lightInfo.withValues(alpha: 0.15),
                      textColor: isDark ? AppColors.darkInfo : AppColors.lightInfo,
                    ),
                  // Show Files if model supports it
                  if (modalities.contains('file'))
                    _buildFeatureChip(
                      'Files',
                      bgColor: isDark ? AppColors.darkAccentTertiary.withValues(alpha: 0.2) : AppColors.lightAccentTertiary.withValues(alpha: 0.15),
                      textColor: isDark ? AppColors.darkAccentTertiary : AppColors.lightAccentTertiary,
                    ),
                  // Show pricing
                  _buildFeatureChip(
                    _getPriceDisplay(pricing),
                    bgColor: isFree
                        ? (isDark ? AppColors.darkSuccess.withValues(alpha: 0.2) : AppColors.lightSuccess.withValues(alpha: 0.15))
                        : (isDark ? AppColors.darkWarning.withValues(alpha: 0.2) : AppColors.lightWarning.withValues(alpha: 0.15)),
                    textColor: isFree
                        ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                        : (isDark ? AppColors.darkWarning : AppColors.lightWarning),
                  ),
                  // Show context length if available
                  if (model['contextLength'] != null || model['context_length'] != null)
                    _buildFeatureChip(
                      '${((model['contextLength'] ?? model['context_length'] ?? 0) / 1000).round()}K',
                      bgColor: isDark ? AppColors.darkAccentSecondary.withValues(alpha: 0.2) : AppColors.lightAccentSecondary.withValues(alpha: 0.15),
                      textColor: isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }





  Widget _buildModelsList(ThemeData theme, bool isDark) {
    if (_filteredModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackgroundLight : AppColors.lightBackgroundLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No models found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: _filteredModels.length,
            itemBuilder: (context, index) {
              final model = _filteredModels[index];
              final modelId = model['id'] ?? model['canonical_slug'] ?? model['name'] ?? 'unknown';
              final isSelected = modelId == widget.selectedModel;

              return _buildModelCard(model, isSelected, theme, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernFilterChip(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    ThemeData theme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56, // Fixed height for consistency
        constraints: const BoxConstraints(minWidth: 120), // Minimum width
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip(
    String label,
    IconData icon,
    bool isActive,
    Function(bool) onChanged,
    ThemeData theme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!isActive),
      child: Container(
        height: 56, // Fixed height to match filter chips
        constraints: const BoxConstraints(minWidth: 100), // Minimum width
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppColors.darkAccent.withValues(alpha: 0.15) : AppColors.lightAccent.withValues(alpha: 0.1))
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPriceDisplay(Map<String, dynamic>? pricing) {
    if (pricing == null) return 'Free';

    // Handle different pricing field names
    final input = pricing['input'] ?? pricing['prompt'];
    final output = pricing['output'] ?? pricing['completion'];

    // Debug logging for pricing calculation
    print('💰 Pricing calculation - input: $input (${input.runtimeType}), output: $output (${output.runtimeType})');

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

      print('💰 Calculated per-million - input: $inputPerMillion, output: $outputPerMillion');

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
      
      print('💰 String pricing calculated - input: $inputPerMillion, output: $outputPerMillion');
      
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
      
      print('💰 Mixed type pricing calculated - input: $inputPerMillion, output: $outputPerMillion');
      
      if (inputPerMillion == outputPerMillion) {
        return '\$$inputPerMillion/1M';
      }
      
      return '\$$inputPerMillion/\$$outputPerMillion';
    }

    print('💰 Unknown pricing format: input=$input (${input.runtimeType}), output=$output (${output.runtimeType})');
    return 'Paid';
  }





  String _getProviderIcon(String? provider) {
    if (provider == null) return '🤖';

    switch (provider.toLowerCase()) {
      case 'openai': return '⚡';
      case 'anthropic': return '🧠';
      case 'google': return '🎯';
      case 'meta': return '📘';
      case 'mistral': case 'mistralai': return '🌊';
      case 'deepseek': return '🔍';
      case 'cohere': return '💫';
      case 'perplexity': return '🌐';
      case 'x-ai': case 'xai': return '🚀';
      case 'qwen': return '🎨';
      case 'nvidia': return '💚';
      default: return '🤖';
    }
  }





  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('🔄 Loading models for mode: ${widget.mode}');
      final modelsData = await ModelService.getEnhancedModelsByMode(widget.mode);
      print('📦 Received models data: ${modelsData.keys}');

      List<Map<String, dynamic>> modelsList = [];

      // Check if we have data array directly (from getModelsByMode)
      if (modelsData['data'] != null) {
        final models = List<Map<String, dynamic>>.from(modelsData['data']);
        print('✅ Found ${models.length} models in data array');

        for (Map<String, dynamic> model in models) {
          // Include all models from the API response
          modelsList.add(model);
        }
      }
      // Fallback: Check if we have enhancedModels array (for backward compatibility)
      else if (modelsData['enhancedModels'] != null) {
        final enhancedModels = List<Map<String, dynamic>>.from(modelsData['enhancedModels']);
        print('✅ Found ${enhancedModels.length} models in enhancedModels array');

        for (Map<String, dynamic> model in enhancedModels) {
          // Only include models that are available
          if (model['isAvailable'] == true) {
            modelsList.add(model);
          }
        }
      } else {
        print('⚠️ No models found in expected data structure');
        print('📋 Available keys: ${modelsData.keys}');
      }

      print('📊 Total models processed: ${modelsList.length}');

      // Extract unique providers
      final providers = <String>{};
      for (final model in modelsList) {
        final provider = model['provider']?.toString() ?? model['top_provider']?['name']?.toString();
        if (provider != null && provider.isNotEmpty) {
          providers.add(provider);
        }
      }

      print('🏢 Found providers: ${providers.toList()}');

      setState(() {
        _allModels = modelsList;
        _availableProviders = providers.toList()..sort();
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      print('❌ Error loading models: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }



  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
      _applyFilters();
    });
  }



  void _selectModel(String modelId) {
    print('🤖 ModelSelectionScreen: Model selected: $modelId');
    widget.onModelSelected(modelId);
    
    // Also update the LLM service's current model to ensure API calls use the selected model
    LLMService().setCurrentModel(modelId);
    print('🤖 ModelSelectionScreen: Updated LLM service current model to: $modelId');
    Navigator.of(context).pop();
  }

  void _showModalityFilter(BuildContext context, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Select Modalities',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedModalities.clear());
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._availableModalities.map((modality) {
                final isSelected = _selectedModalities.contains(modality);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setModalState(() {
                      if (value == true) {
                        _selectedModalities.add(modality);
                      } else {
                        _selectedModalities.remove(modality);
                      }
                    });
                    setState(() {}); // Update parent widget
                    _applyFilters();
                  },
                  title: Text(modality, style: theme.textTheme.bodyMedium),
                  activeColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showProviderFilter(BuildContext context, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Select Providers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedProviders.clear());
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableProviders.length,
                  itemBuilder: (context, index) {
                    final provider = _availableProviders[index];
                    final isSelected = _selectedProviders.contains(provider);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            _selectedProviders.add(provider);
                          } else {
                            _selectedProviders.remove(provider);
                          }
                        });
                        setState(() {}); // Update parent widget
                        _applyFilters();
                      },
                      title: Text(
                        '${_getProviderIcon(provider)} $provider',
                        style: theme.textTheme.bodyMedium,
                      ),
                      activeColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
