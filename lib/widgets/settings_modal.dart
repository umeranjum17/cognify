import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tools_config.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';
import 'credits_usage_widget.dart';

class SettingsModal extends StatefulWidget {
  final String selectedModel;
  final ToolsConfig toolsConfig;
  final List<String> availableModels;
  final String selectedPersonality;
  final String selectedLanguage;
  final Function(String)? onModelChanged; // Made optional since model selection removed
  final Function(ToolsConfig) onToolsConfigChanged;
  final Function(String) onPersonalityChanged;
  final Function(String) onLanguageChanged;
  final VoidCallback onSave; // New callback for saving

  const SettingsModal({
    super.key,
    this.selectedModel = '', // Made optional with default
    required this.toolsConfig,
    this.availableModels = const [], // Made optional with default
    required this.selectedPersonality,
    required this.selectedLanguage,
    this.onModelChanged, // Made optional
    required this.onToolsConfigChanged,
    required this.onPersonalityChanged,
    required this.onLanguageChanged,
    required this.onSave, // New required parameter
  });

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

abstract class SettingsModalState {
  Future<void> saveSettings();
}

class _SettingsModalState extends State<SettingsModal> implements SettingsModalState {
  late ToolsConfig _toolsConfig;
  late String _selectedPersonality;
  late String _selectedLanguage;

  // Available personalities - Human personalities
  final List<String> _availablePersonalities = [
    'Default',
    'Comedian',
    'Macho Cool',
    'Friendly Helper',
    'Professional Expert',
  ];

  // Available languages
  final List<String> _availableLanguages = [
    'English',
    'Urdu',
    'Arabic',
    'French',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppColors.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Health Section
          _buildSection(
            theme,
            isDark,
            'Service Health',
            [
              const CreditsUsageWidget(),
            ],
          ),
          const SizedBox(height: AppColors.spacingLg),
          // Personality Selection
          _buildSection(
            theme,
            isDark,
            'AI Personality',
            [
              _buildSettingItem(
                theme,
                icon: Icons.psychology,
                title: 'Personality',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _availablePersonalities.contains(_selectedPersonality) 
                          ? _selectedPersonality 
                          : _availablePersonalities.first,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        size: 16,
                      ),
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      dropdownColor: theme.cardColor,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedPersonality = newValue;
                          });
                        }
                      },
                      items: _availablePersonalities.toSet().toList().map((String personality) {
                        return DropdownMenuItem<String>(
                          value: personality,
                          child: Text(
                            personality,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppColors.spacingLg),

          // Language Selection
          _buildSection(
            theme,
            isDark,
            'Language',
            [
              _buildSettingItem(
                theme,
                icon: Icons.language,
                title: 'Response Language',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _availableLanguages.contains(_selectedLanguage)
                          ? _selectedLanguage
                          : _availableLanguages.first,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        size: 16,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      dropdownColor: theme.cardColor,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLanguage = newValue;
                          });
                          widget.onLanguageChanged(newValue);
                        }
                      },
                      items: _availableLanguages.toSet().toList().map((String language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Text(
                            language,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppColors.spacingLg),

          // Appearance Section
          _buildSection(
            theme,
            isDark,
            'Appearance',
            [
              _buildSettingItem(
                theme,
                icon: isDark ? Icons.dark_mode : Icons.light_mode,
                title: 'Dark Mode',
                trailing: Switch(
                  value: isDark,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                  activeColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppColors.spacingLg),

          // Note: Model selection is now handled in the Modes tab for mode-specific configuration
          _buildSection(
            theme,
            isDark,
            'Available AI Tools',
            [
              Text(
                'All tools are automatically enabled and intelligently selected based on your content and requests.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppColors.spacingMd),

              // Core AI Tools
              _buildToolCategory(theme, isDark, 'Core AI', [
                _buildToolChip(theme, isDark, Icons.psychology, 'Sequential Thinking'),
                _buildToolChip(theme, isDark, Icons.search, 'Web Search'),
                _buildToolChip(theme, isDark, Icons.description, 'Documentation'),
              ]),

              const SizedBox(height: AppColors.spacingMd),

              // Analysis & Knowledge Tools
              _buildToolCategory(theme, isDark, 'Analysis & Knowledge', [
                _buildToolChip(theme, isDark, Icons.account_tree, 'Knowledge Graph'),
                _buildToolChip(theme, isDark, Icons.label, 'Entity Extractor'),
                _buildToolChip(theme, isDark, Icons.summarize, 'Summary Generator'),
                _buildToolChip(theme, isDark, Icons.share, 'Relationship Mapper'),
              ]),

              const SizedBox(height: AppColors.spacingMd),

              // Content Processing Tools
              _buildToolCategory(theme, isDark, 'Content Processing (Auto-Detecting)', [
                _buildToolChip(theme, isDark, Icons.cloud_download, 'Web Fetch'),
                _buildToolChip(theme, isDark, Icons.play_circle, 'YouTube'),
                _buildToolChip(theme, isDark, Icons.memory, 'Context7'),
                _buildToolChip(theme, isDark, Icons.code, 'Code Analysis'),
              ]),
            ],
          ),



          const SizedBox(height: AppColors.spacingLg),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _toolsConfig = widget.toolsConfig;
    _selectedPersonality = widget.selectedPersonality;
    _selectedLanguage = widget.selectedLanguage;

    // Ensure selected personality is in the available list
    if (!_availablePersonalities.contains(_selectedPersonality)) {
      _selectedPersonality = _availablePersonalities.first;
    }
  }

  @override
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Save tools configuration
    await prefs.setString('toolsConfig', jsonEncode(_toolsConfig.toJson()));

    // Save personality selection
    await prefs.setString('selectedPersonality', _selectedPersonality);

    // Save language selection
    await prefs.setString('selectedLanguage', _selectedLanguage);

    // Notify parent
    widget.onToolsConfigChanged(_toolsConfig);
    widget.onPersonalityChanged(_selectedPersonality);

    if (mounted) {
      widget.onSave(); // Call the parent's save callback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
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

  Widget _buildSettingItem(ThemeData theme, {
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingMd),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: AppColors.spacingMd),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildToolCategory(ThemeData theme, bool isDark, String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: AppColors.spacingSm),
        Wrap(
          spacing: AppColors.spacingSm,
          runSpacing: AppColors.spacingSm,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildToolChip(ThemeData theme, bool isDark, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.spacingMd,
        vertical: AppColors.spacingSm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
        borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          ),
          const SizedBox(width: AppColors.spacingXs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

}
