import 'package:flutter/material.dart';

import '../models/mode_config.dart';
import '../services/model_service.dart';
import '../theme/app_theme.dart';

class CombinedModelSelectionWidget extends StatefulWidget {
  final ChatMode mode;
  final String selectedModel;
  final Function(String) onModelChanged;
  final VoidCallback? onRefresh;

  const CombinedModelSelectionWidget({
    super.key,
    required this.mode,
    required this.selectedModel,
    required this.onModelChanged,
    this.onRefresh,
  });

  @override
  State<CombinedModelSelectionWidget> createState() => _CombinedModelSelectionWidgetState();
}

class _CombinedModelSelectionWidgetState extends State<CombinedModelSelectionWidget> {
  List<Map<String, dynamic>> _allModels = [];
  List<Map<String, dynamic>> _filteredModels = [];
  Map<String, dynamic>? _currentModelInfo;
  bool _isLoading = true;
  String _error = '';
  bool _showAdvancedFilters = false;
  
  // Filter state
  String _searchQuery = '';
  String? _selectedProvider;
  bool? _isFreeFilter;
  bool? _supportsImages;
  bool? _supportsFiles;
  bool? _isMultimodal;
  String _sortBy = 'name'; // name, provider, price, context_length
  bool _sortAscending = true;
  
  // Filter options
  List<String> _providers = [];
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading models',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadModels,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Model Section
        _buildCurrentModelSection(theme, isDark),
        
        const SizedBox(height: 24),
        
        // Search and Filter Section
        _buildSearchAndFilters(theme, isDark),
        
        const SizedBox(height: 16),
        
        // Model List
        Expanded(
          child: _buildModelList(theme, isDark),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(CombinedModelSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.selectedModel != widget.selectedModel) {
      _loadModels();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allModels);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((model) {
        final name = (model['name'] ?? '').toString().toLowerCase();
        final id = (model['id'] ?? '').toString().toLowerCase();
        final provider = (model['provider'] ?? model['top_provider']?['name'] ?? '').toString().toLowerCase();
        final description = (model['description'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        return name.contains(query) ||
               id.contains(query) ||
               provider.contains(query) ||
               description.contains(query);
      }).toList();
    }

    // Apply provider filter
    if (_selectedProvider != null) {
      filtered = filtered.where((model) {
        final provider = model['provider'] ?? model['top_provider']?['name'];
        return provider == _selectedProvider;
      }).toList();
    }

    // Apply free/paid filter
    if (_isFreeFilter != null) {
      filtered = filtered.where((model) {
        final pricing = model['pricing'] as Map<String, dynamic>?;
        final isFree = pricing == null || 
                      (pricing['input'] == 0.0 && pricing['output'] == 0.0) ||
                      (pricing['prompt']?.toString() == '0' && pricing['completion']?.toString() == '0');
        return _isFreeFilter == isFree;
      }).toList();
    }

    // Apply modality filters
    if (_supportsImages == true) {
      filtered = filtered.where((model) {
        // Use improved modalities extraction
        final inputModalities = model['inputModalities'] as List<dynamic>? ?? 
                               model['input_modalities'] as List<dynamic>? ?? 
                               model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
        
        // Convert to string list and normalize
        final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
        
        return modalities.contains('image');
      }).toList();
    }

    if (_supportsFiles == true) {
      filtered = filtered.where((model) {
        // Use improved modalities extraction
        final inputModalities = model['inputModalities'] as List<dynamic>? ?? 
                               model['input_modalities'] as List<dynamic>? ?? 
                               model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
        
        // Convert to string list and normalize
        final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
        
        return modalities.contains('file');
      }).toList();
    }

    if (_isMultimodal == true) {
      filtered = filtered.where((model) {
        // Use improved modalities extraction
        final inputModalities = model['inputModalities'] as List<dynamic>? ?? 
                               model['input_modalities'] as List<dynamic>? ?? 
                               model['architecture']?['input_modalities'] as List<dynamic>? ?? [];
        
        // Convert to string list and normalize
        final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
        
        return modalities.length > 1;
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'name':
          comparison = (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
          break;
        case 'provider':
          final aProvider = (a['provider'] ?? a['top_provider']?['name'] ?? '').toString();
          final bProvider = (b['provider'] ?? b['top_provider']?['name'] ?? '').toString();
          comparison = aProvider.compareTo(bProvider);
          break;
        case 'price':
          final aPrice = _getModelPrice(a);
          final bPrice = _getModelPrice(b);
          comparison = aPrice.compareTo(bPrice);
          break;
        case 'context_length':
          final aContext = a['context_length'] as int? ?? 0;
          final bContext = b['context_length'] as int? ?? 0;
          comparison = bContext.compareTo(aContext); // Descending by default
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredModels = filtered;
    });
  }

  Widget _buildAdvancedFilters(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters & Sorting',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                'Free Only',
                _isFreeFilter == true,
                () => setState(() {
                  _isFreeFilter = _isFreeFilter == true ? null : true;
                  _applyFilters();
                }),
              ),
              _buildFilterChip(
                'Supports Images',
                _supportsImages == true,
                () => setState(() {
                  _supportsImages = _supportsImages == true ? null : true;
                  _applyFilters();
                }),
              ),
              _buildFilterChip(
                'Supports Files',
                _supportsFiles == true,
                () => setState(() {
                  _supportsFiles = _supportsFiles == true ? null : true;
                  _applyFilters();
                }),
              ),
              _buildFilterChip(
                'Multimodal',
                _isMultimodal == true,
                () => setState(() {
                  _isMultimodal = _isMultimodal == true ? null : true;
                  _applyFilters();
                }),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedProvider,
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Providers'),
                    ),
                    ..._providers.map((provider) => DropdownMenuItem(
                      value: provider,
                      child: Row(
                        children: [
                          Text(_getProviderIcon(provider)),
                          const SizedBox(width: 8),
                          Text(provider),
                        ],
                      ),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedProvider = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'provider', child: Text('Provider')),
                    DropdownMenuItem(value: 'price', child: Text('Price')),
                    DropdownMenuItem(value: 'context_length', child: Text('Context Length')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    _applyFilters();
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                  _applyFilters();
                },
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                tooltip: _sortAscending ? 'Ascending' : 'Descending',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentModelSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.mode == ChatMode.chat ? Icons.chat_outlined : Icons.search,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.mode == ChatMode.chat ? 'Chat' : 'DeepSearch'} Mode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const Spacer(),
              if (widget.onRefresh != null)
                IconButton(
                  icon: Icon(
                    Icons.refresh_outlined,
                    size: 16,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  onPressed: () {
                    _loadModels();
                    widget.onRefresh?.call();
                  },
                  tooltip: 'Refresh models',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            _formatModelName(widget.selectedModel),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.selectedModel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),

          if (_currentModelInfo != null) ...[
            const SizedBox(height: 12),
            _buildModelFeatures(_currentModelInfo!, theme, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color, bool enabled, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
          ? (isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.1) : AppColors.lightTextSecondary.withValues(alpha: 0.1))
          : (isDark ? AppColors.darkTextMuted.withValues(alpha: 0.1) : AppColors.lightTextMuted.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: enabled
            ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.1) : AppColors.lightTextSecondary.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                : (isDark ? AppColors.darkTextMuted.withValues(alpha: 0.3) : AppColors.lightTextMuted.withValues(alpha: 0.3)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: selected
                ? (isDark ? AppColors.darkText : AppColors.lightText)
                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildModelCard(Map<String, dynamic> model, bool isSelected, ThemeData theme, bool isDark) {
    final modalities = model['input_modalities'] as List<dynamic>? ?? [];
    final pricing = model['pricing'] as Map<String, dynamic>?;
    final isFree = pricing == null ||
                  (pricing['input'] == 0.0 && pricing['output'] == 0.0) ||
                  (pricing['prompt']?.toString() == '0' && pricing['completion']?.toString() == '0');
    final provider = model['provider'] as String? ?? model['top_provider']?['name'] as String?;
    final providerColor = _getProviderColor(provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onModelChanged(model['id']),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.1) : AppColors.lightTextSecondary.withValues(alpha: 0.1))
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              width: 1,
            ) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: providerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getProviderIcon(provider),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model['name'] ?? model['id'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        if (provider != null)
                          Text(
                            provider,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_outline,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      size: 18,
                    ),
                ],
              ),
              
              if (model['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  model['description'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildFeatureChip('Text', isDark ? AppColors.darkAccent : AppColors.lightAccent, true, isDark),
                  if (modalities.contains('image'))
                    _buildFeatureChip('Images', isDark ? AppColors.darkSuccess : AppColors.lightSuccess, true, isDark),
                  if (modalities.contains('file'))
                    _buildFeatureChip('Files', isDark ? AppColors.darkInfo : AppColors.lightInfo, true, isDark),
                  _buildFeatureChip(
                    isFree ? 'Free' : 'Paid', 
                    isFree 
                      ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                      : (isDark ? AppColors.darkWarning : AppColors.lightWarning), 
                    true,
                    isDark
                  ),
                  if (model['context_length'] != null)
                    _buildFeatureChip(
                      '${(model['context_length'] / 1000).round()}K',
                      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      true,
                      isDark,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelFeatures(Map<String, dynamic> modelInfo, ThemeData theme, bool isDark) {
    // Use improved modalities extraction
    final inputModalities = modelInfo['inputModalities'] as List<dynamic>? ?? 
                           modelInfo['input_modalities'] as List<dynamic>? ?? 
                           modelInfo['architecture']?['input_modalities'] as List<dynamic>? ?? [];
    
    // Convert to string list and normalize
    final modalities = inputModalities.map((modality) => modality.toString().toLowerCase()).toList();
    
    // If no modalities found, assume text-only
    final modelModalities = modalities.isEmpty ? ['text'] : modalities;
    
    final pricing = modelInfo['pricing'] as Map<String, dynamic>?;
    final isFree = pricing == null || 
                  (pricing['prompt']?.toString() == '0' && pricing['completion']?.toString() == '0');

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _buildFeatureChip('Text', isDark ? AppColors.darkAccent : AppColors.lightAccent, true, isDark),
        if (modelModalities.contains('image'))
          _buildFeatureChip('Images', isDark ? AppColors.darkSuccess : AppColors.lightSuccess, true, isDark),
        if (modelModalities.contains('file'))
          _buildFeatureChip('Files', isDark ? AppColors.darkInfo : AppColors.lightInfo, true, isDark),
        _buildFeatureChip(
          isFree ? 'Free' : 'Paid', 
          isFree 
            ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
            : (isDark ? AppColors.darkWarning : AppColors.lightWarning), 
          true,
          isDark
        ),
        if (modelInfo['context_length'] != null)
          _buildFeatureChip(
            '${(modelInfo['context_length'] / 1000).round()}K',
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            true,
            isDark,
          ),
      ],
    );
  }

  Widget _buildModelList(ThemeData theme, bool isDark) {
    if (_filteredModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No models found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredModels.length,
      itemBuilder: (context, index) {
        final model = _filteredModels[index];
        final isSelected = model['id'] == widget.selectedModel;
        
        return _buildModelCard(model, isSelected, theme, isDark);
      },
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Available Models (${_filteredModels.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAdvancedFilters = !_showAdvancedFilters;
                });
              },
              icon: Icon(
                _showAdvancedFilters ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              label: Text(
                _showAdvancedFilters ? 'Hide Filters' : 'Show Filters',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Search bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Search models...',
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            prefixIcon: Icon(
              Icons.search_outlined,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.3) : AppColors.lightTextMuted.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.3) : AppColors.lightTextMuted.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
            _applyFilters();
          },
        ),
        
        if (_showAdvancedFilters) ...[
          const SizedBox(height: 16),
          _buildAdvancedFilters(theme, isDark),
        ],
      ],
    );
  }

  String _formatModelName(String modelId) {
    // Extract the model name from the ID (remove provider prefix)
    if (modelId.contains('/')) {
      return modelId.split('/').last;
    }
    return modelId;
  }

  double _getModelPrice(Map<String, dynamic> model) {
    final pricing = model['pricing'] as Map<String, dynamic>?;
    if (pricing == null) return 0.0;
    
    final prompt = double.tryParse(pricing['prompt']?.toString() ?? '0') ?? 0.0;
    final completion = double.tryParse(pricing['completion']?.toString() ?? '0') ?? 0.0;
    return (prompt + completion) / 2; // Average price
  }

  Color _getProviderColor(String? provider) {
    if (provider == null) return AppColors.lightTextMuted;
    
    switch (provider.toLowerCase()) {
      case 'openai': return AppColors.lightAccent; // Gold for OpenAI
      case 'anthropic': return AppColors.lightWarning; // Amber for Anthropic
      case 'google': return AppColors.lightInfo; // Blue for Google
      case 'meta': return AppColors.lightPrimary; // Charcoal for Meta
      case 'mistral': case 'mistralai': return AppColors.lightAccentSecondary; // Deep amber for Mistral
      case 'deepseek': return AppColors.lightAccentTertiary; // Gray for DeepSeek
      case 'cohere': return AppColors.lightAccentQuaternary; // Rich charcoal for Cohere
      case 'perplexity': return AppColors.lightSuccess; // Green for Perplexity
      case 'x-ai': case 'xai': return AppColors.lightError; // Red for xAI
      case 'qwen': return AppColors.lightAccentSecondary; // Deep amber for Qwen
      case 'nvidia': return AppColors.lightSuccess; // Green for NVIDIA
      default: return AppColors.lightTextMuted;
    }
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
      print('🔄 Combined widget: Loading models for mode: ${widget.mode}');
      // Load models for the specific mode using the correct static method
      final modelsData = await ModelService.getEnhancedModelsByMode(widget.mode);
      print('📦 Combined widget: Received models data: ${modelsData.keys}');
      
      // Get current model info - convert ModelCapabilities to Map for compatibility
      Map<String, dynamic>? currentModelInfo;
      try {
        final capabilities = await ModelService.getModelCapabilities(widget.selectedModel);
        currentModelInfo = {
          'input_modalities': capabilities.inputModalities,
          'context_length': capabilities.contextLength,
          'supportsImages': capabilities.supportsImages,
          'supportsFiles': capabilities.supportsFiles,
          'isMultimodal': capabilities.isMultimodal,
        };
      } catch (e) {
        print('Could not load current model info: $e');
      }

      // Extract models list from the response
      List<Map<String, dynamic>> modelsList = [];
      
      // Check if we have data array directly (from getModelsByMode)
      if (modelsData['data'] != null) {
        final models = List<Map<String, dynamic>>.from(modelsData['data']);
        print('✅ Combined widget: Found ${models.length} models in data array');
        modelsList = models;
      }
      // Fallback: Check if we have available/all structure (for backward compatibility)
      else if (modelsData['available'] != null && modelsData['available']['all'] != null) {
        final availableModels = List<String>.from(modelsData['available']['all']);
        final modelInfo = modelsData['modelInfo'] as Map<String, dynamic>? ?? {};
        print('✅ Combined widget: Found ${availableModels.length} models in available/all structure');
        
        for (String modelId in availableModels) {
          final info = modelInfo[modelId] as Map<String, dynamic>?;
          if (info != null) {
            modelsList.add({
              'id': modelId,
              'name': info['name'] ?? modelId,
              'provider': info['provider'],
              'description': info['description'],
              'input_modalities': info['inputModalities'] ?? ['text'],
              'pricing': info['pricing'],
              'context_length': info['contextLength'],
            });
          }
        }
      } else {
        print('⚠️ Combined widget: No models found in expected data structure');
        print('📋 Combined widget: Available keys: ${modelsData.keys}');
      }

      print('📊 Combined widget: Total models processed: ${modelsList.length}');

      // Extract unique providers
      final providers = modelsList
          .map((model) => model['provider'] as String? ?? model['top_provider']?['name'] as String?)
          .where((provider) => provider != null)
          .cast<String>()
          .toSet()
          .toList()
        ..sort();

      print('🏢 Combined widget: Found providers: ${providers}');

      setState(() {
        _allModels = modelsList;
        _currentModelInfo = currentModelInfo;
        _providers = providers;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      print('❌ Combined widget: Error loading models: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}
