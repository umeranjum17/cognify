import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mode_config.dart';
import '../providers/mode_config_provider.dart';
import '../services/llm_service.dart'; // Added import for LLMService
import '../theme/app_theme.dart';

class ModeSettingsModal extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onReset;

  const ModeSettingsModal({
    super.key,
    required this.onSave,
    required this.onReset,
  });

  @override
  State<ModeSettingsModal> createState() => _ModeSettingsModalState();
}

abstract class ModeSettingsModalState {
  void resetToDefaults();
  Future<void> saveConfigs();
}

class _ModeSettingsModalState extends State<ModeSettingsModal> implements ModeSettingsModalState {
  Map<ChatMode, ModeConfig> _configs = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(AppColors.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header description
                Text(
                  'Configure AI models for different chat modes',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: AppColors.spacingLg),

                // Mode configurations
                _buildSection(
                  theme,
                  isDark,
                  'Chat Modes',
                  ChatMode.values.map((mode) => _buildModeListTile(mode, theme)).toList(),
                ),
              ],
            ),
          );
  }

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void resetToDefaults() {
    setState(() {
      _configs = {
        ChatMode.chat: ModeConfigManager.getDefaultConfigForMode(ChatMode.chat),
        ChatMode.deepsearch: ModeConfigManager.getDefaultConfigForMode(ChatMode.deepsearch),
      };
    });
    widget.onReset(); // Call the parent's reset callback
  }

  @override
  Future<void> saveConfigs() async {
    setState(() => _isSaving = true);

    try {
      // Save using the provider to ensure real-time updates
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      await modeConfigProvider.updateConfigs(_configs);

      if (mounted) {
        widget.onSave(); // Call the parent's save callback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mode settings saved successfully')),
        );
      }
    } catch (e) {
      print('Error saving configs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildModeCard(ChatMode mode, ModeConfig config, List<String> availableModels, Map<String, dynamic> stats, ThemeData theme) {

    return Card( // Use Card for a subtle separation instead of Container + BoxDecoration
      margin: const EdgeInsets.only(bottom: AppColors.spacingMd),
      elevation: 0, // Reduce elevation to make it less "chunky"
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd, horizontal: AppColors.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mode.iconData,
                  size: 24,
                ),
                const SizedBox(width: AppColors.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        config.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppColors.spacingMd),
            Text(
                  'AI Model: ${ModeConfigManager.formatModelName(config.model)}', // Display current model directly
                  style: theme.textTheme.bodyMedium,
                ),
            const SizedBox(height: AppColors.spacingSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown row
                DropdownButtonHideUnderline(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: availableModels.contains(config.model) ? config.model : availableModels.first,
                      isExpanded: true,
                      items: availableModels.map((model) {
                        final isRecommended = model == config.defaultModel;
                        final isFree = ModeConfigManager.isFreeModel(model);
                        
                        String displayText = ModeConfigManager.formatModelName(model);
                        if (isFree) displayText += ' (FREE)';
                        if (isRecommended) displayText += ' (REC)';

                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            displayText,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _updateModelForMode(mode, value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppColors.spacingSm),
                // Stats chips row
                Wrap(
                  spacing: AppColors.spacingSm,
                  runSpacing: AppColors.spacingSm,
                  children: [
                    _buildStatChip(theme, '${stats['totalModels']} models', Icons.memory),
                    _buildStatChip(theme, '${stats['freeModels']} free', Icons.money_off),
                    if (stats['reasoningModels'] > 0)
                      _buildStatChip(theme, '${stats['reasoningModels']} reasoning', Icons.psychology),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeListTile(ChatMode mode, ThemeData theme) {
    final config = _configs[mode];
    if (config == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadModeData(mode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.only(bottom: AppColors.spacingMd),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppColors.spacingMd),
              child: Row(
                children: [
                  Icon(mode.iconData, color: theme.colorScheme.primary),
                  const SizedBox(width: AppColors.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.displayName, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        const CircularProgressIndicator.adaptive(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.only(bottom: AppColors.spacingMd),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppColors.spacingMd),
              child: Row(
                children: [
                  Icon(mode.iconData, color: theme.colorScheme.error),
                  const SizedBox(width: AppColors.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.displayName, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Error loading models', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final availableModels = data['availableModels'] as List<String>;
        final stats = data['stats'] as Map<String, dynamic>;

        // Fix corrupted model values
        _fixCorruptedModelValue(mode, availableModels);

        return _buildModeCard(mode, config, availableModels, stats, theme);
      },
    );
  }

  Widget _buildSection(ThemeData theme, bool isDark, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppColors.spacingSm),
        ...children,
      ],
    );
  }

  Widget _buildStatChip(ThemeData theme, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _fixCorruptedModelValue(ChatMode mode, List<String> availableModels) {
    final config = _configs[mode]!;
    if (!availableModels.contains(config.model)) {
      // Model value is corrupted, reset to default
      final defaultModel = availableModels.first;
      _updateModelForMode(mode, defaultModel);
    }
  }

  Future<void> _loadConfigs() async {
    setState(() => _isLoading = true);

    try {
      final configs = await ModeConfigManager.loadConfigs();
      setState(() {
        _configs = configs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading configs: $e');
      setState(() => _isLoading = false);
    }
  }





  Future<Map<String, dynamic>> _loadModeData(ChatMode mode) async {
    try {
      final availableModels = await ModeConfigManager.getAvailableModelsForMode(mode);
      final stats = await ModeConfigManager.getModeStats(mode);
      return {
        'availableModels': availableModels,
        'stats': stats,
      };
    } catch (e) {
      throw Exception('Failed to load mode data: $e');
    }
  }

  void _updateModelForMode(ChatMode mode, String model) {
    setState(() {
      _configs[mode] = _configs[mode]!.copyWith(model: model);
    });
    // Save the updated config immediately
    ModeConfigManager.saveConfigs(_configs);
    
    // Also update the LLM service's current model to ensure API calls use the selected model
    LLMService().setCurrentModel(model);
    print('🤖 ModeSettingsModal: Updated model for $mode to $model and set as current model');
  }
}
