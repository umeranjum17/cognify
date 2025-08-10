import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mode_config.dart';
import '../models/tools_config.dart';
import '../providers/mode_config_provider.dart';
import '../screens/model_selection_screen.dart';
import '../services/llm_service.dart'; // Added import for LLMService
import '../services/premium_feature_gate.dart';
import '../theme/app_theme.dart';
import 'general_settings_tab.dart';

class UnifiedSettingsModal extends StatefulWidget {
  final String selectedModel;
  final Function(String) onModelChanged;

  const UnifiedSettingsModal({
    super.key,
    required this.selectedModel,
    required this.onModelChanged,
  });

  @override
  State<UnifiedSettingsModal> createState() => _UnifiedSettingsModalState();
}

class _UnifiedSettingsModalState extends State<UnifiedSettingsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _selectedChatModel = '';
  String _selectedDeepSearchModel = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.1) : AppColors.lightTextSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: isDark ? AppColors.darkText : AppColors.lightText,
                unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('General'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.psychology_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Models'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // General tab: new simplified settings
                  const GeneralSettingsTab(),
                  // Enhanced Models tab with mode-aware selection
                  _buildEnhancedModelsTab(),
                ],
              ),
            ),
            // Bottom action buttons - only show for Models tab
            if (_tabController.index == 1) // Models tab
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkDivider.withValues(alpha: 0.1) : AppColors.lightDivider.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.3) : AppColors.lightTextMuted.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shadowColor: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Settings',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
    });
    _loadModeModels();
  }





  Widget _buildCapabilityChip(String label, IconData icon, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedModelsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure AI models for different modes',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Mode Cards
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Chat Mode Card
                InkWell(
                  onTap: () => _showModelSelection(ChatMode.chat),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider.withValues(alpha: 0.2) : AppColors.lightDivider.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.1) : AppColors.lightTextSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.bolt,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chat',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lightning fast responses with minimal search',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _isModelFree(_selectedChatModel)
                                          ? (isDark ? AppColors.darkSuccess.withValues(alpha: 0.2) : AppColors.lightSuccess.withValues(alpha: 0.15))
                                          : (isDark ? AppColors.darkWarning.withValues(alpha: 0.2) : AppColors.lightWarning.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _isModelFree(_selectedChatModel) ? 'Free' : 'Paid',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: _isModelFree(_selectedChatModel)
                                            ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                                            : (isDark ? AppColors.darkWarning : AppColors.lightWarning),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatModelName(_selectedChatModel),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppColors.darkText : AppColors.lightText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildModelCapabilities(_selectedChatModel, isDark),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // DeepSearch Mode Card
                InkWell(
                  onTap: () => _showModelSelection(ChatMode.deepsearch),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider.withValues(alpha: 0.2) : AppColors.lightDivider.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.1) : AppColors.lightTextSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.search,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DeepSearch',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ultra-comprehensive research with enhanced visual content and 4x more detailed responses (10x resources)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _isModelFree(_selectedDeepSearchModel)
                                          ? (isDark ? AppColors.darkSuccess.withValues(alpha: 0.2) : AppColors.lightSuccess.withValues(alpha: 0.15))
                                          : (isDark ? AppColors.darkWarning.withValues(alpha: 0.2) : AppColors.lightWarning.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _isModelFree(_selectedDeepSearchModel) ? 'Free' : 'Paid',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: _isModelFree(_selectedDeepSearchModel)
                                            ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                                            : (isDark ? AppColors.darkWarning : AppColors.lightWarning),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatModelName(_selectedDeepSearchModel),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppColors.darkText : AppColors.lightText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildModelCapabilities(_selectedDeepSearchModel, isDark),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCapabilities(String modelId, bool isDark) {
    if (modelId.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract capabilities from model ID and common patterns
    final capabilities = <Widget>[];

    // Context length estimation (simplified)
    String contextInfo = '4K';
    if (modelId.contains('flash') || modelId.contains('gemini')) {
      contextInfo = '1M';
    } else if (modelId.contains('r1') || modelId.contains('reasoning')) {
      contextInfo = '128K';
    } else if (modelId.contains('gpt-4')) {
      contextInfo = '128K';
    }

    capabilities.add(_buildCapabilityChip(
      contextInfo,
      Icons.memory,
      isDark ? AppColors.darkInfo.withValues(alpha: 0.2) : AppColors.lightInfo.withValues(alpha: 0.15),
      isDark ? AppColors.darkInfo : AppColors.lightInfo,
    ));

    // Modality support
    if (modelId.contains('gpt-4') || modelId.contains('gemini') || modelId.contains('claude')) {
      capabilities.add(_buildCapabilityChip(
        'Images',
        Icons.image,
        isDark ? AppColors.darkAccentSecondary.withValues(alpha: 0.2) : AppColors.lightAccentSecondary.withValues(alpha: 0.15),
        isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary,
      ));
    }

    // Reasoning capability
    if (modelId.contains('r1') || modelId.contains('reasoning') || modelId.contains('think')) {
      capabilities.add(_buildCapabilityChip(
        'Reasoning',
        Icons.psychology,
        isDark ? AppColors.darkAccent.withValues(alpha: 0.2) : AppColors.lightAccent.withValues(alpha: 0.15),
        isDark ? AppColors.darkAccent : AppColors.lightAccent,
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: capabilities,
    );
  }

  String _formatModelName(String modelId) {
    if (modelId.contains('/')) {
      return modelId.split('/').last.replaceAll(':free', '');
    }
    return modelId;
  }

  void _handleChatModelChanged(String model) {
    print('🤖 UnifiedSettingsModal: Chat model changed to: $model');
    setState(() {
      _selectedChatModel = model;
    });
    _updateModeConfig(ChatMode.chat, model);
    widget.onModelChanged(model); // Also update the main selected model
    
    // Also update the LLM service's current model to ensure API calls use the selected model
    LLMService().setCurrentModel(model);
    print('🤖 UnifiedSettingsModal: Updated Chat model and set as current model');
  }

  void _handleDeepSearchModelChanged(String model) {
    print('🤖 UnifiedSettingsModal: DeepSearch model changed to: $model');
    setState(() {
      _selectedDeepSearchModel = model;
    });
    _updateModeConfig(ChatMode.deepsearch, model);
    
    // Also update the LLM service's current model to ensure API calls use the selected model
    LLMService().setCurrentModel(model);
    print('🤖 UnifiedSettingsModal: Updated DeepSearch model and set as current model');
  }



  void _handleSave() {
    // Save handled by individual components and mode config provider
    Navigator.of(context).pop();
  }

  bool _isModelFree(String modelId) {
    return modelId.endsWith(':free') || modelId.isEmpty;
  }

  Future<void> _loadModeModels() async {
    try {
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      final configs = modeConfigProvider.configs;
      
      setState(() {
        _selectedChatModel = configs[ChatMode.chat]?.model ?? widget.selectedModel;
        _selectedDeepSearchModel = configs[ChatMode.deepsearch]?.model ?? widget.selectedModel;
      });
    } catch (e) {
      print('Error loading mode models: $e');
      setState(() {
        _selectedChatModel = widget.selectedModel;
        _selectedDeepSearchModel = widget.selectedModel;
      });
    }
  }

  void _showModelSelection(ChatMode mode) {
    // Check if DeepSearch mode requires premium access
    if (mode.requiresPremium && !isPremiumUnlocked(context, listen: false)) {
      // Navigate to paywall for premium access
      Navigator.of(context).pushNamed('/paywall');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ModelSelectionScreen(
          mode: mode,
          selectedModel: mode == ChatMode.chat ? _selectedChatModel : _selectedDeepSearchModel,
          onModelSelected: (model) {
            if (mode == ChatMode.chat) {
              _handleChatModelChanged(model);
            } else {
              _handleDeepSearchModelChanged(model);
            }
          },
        ),
      ),
    );
  }

  Future<void> _updateModeConfig(ChatMode mode, String model) async {
    print('🤖 UnifiedSettingsModal: Updating mode config for $mode with model: $model');
    try {
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      final currentConfig = modeConfigProvider.getConfigForMode(mode) ?? 
                           ModeConfigManager.getDefaultConfigForMode(mode);
      
      final updatedConfig = currentConfig.copyWith(model: model);
      await modeConfigProvider.updateConfig(mode, updatedConfig);
      print('🤖 UnifiedSettingsModal: Successfully updated mode config for $mode');
    } catch (e) {
      print('Error updating mode config: $e');
    }
  }
}
