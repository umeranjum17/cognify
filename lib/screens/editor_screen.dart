// Conditional import for vibration support
// ignore: uri_does_not_exist
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_source.dart';
import '../models/chat_stream_event.dart';
import '../models/file_attachment.dart';
import '../models/message.dart';
import '../models/mode_config.dart';
import '../models/source.dart';
import '../models/streaming_message.dart';
import '../models/tools_config.dart';
import '../providers/mode_config_provider.dart';
import '../services/conversation_service.dart';
import '../services/llm_service.dart';
import '../services/model_service.dart';
import '../services/openrouter_client.dart';
import '../services/services_manager.dart';
import '../services/session_cost_service.dart';
import '../services/unified_api_service.dart';
import '../services/environment_service.dart';
import '../config/feature_flags.dart';
import '../config/model_registry.dart';
import '../services/premium_feature_gate.dart';
import '../services/paywall_coordinator.dart';
import '../providers/subscription_provider.dart';
import '../providers/app_access_provider.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';
import '../widgets/cost_display_widget.dart';
import '../widgets/enhanced_loading_indicator.dart';
import '../widgets/model_switch_recommendation_modal.dart';
import '../widgets/modern_app_header.dart';
import '../widgets/organized_post_message_content.dart';
import '../widgets/session_info_widget.dart';
import '../widgets/stacked_media_bubbles.dart';
import '../widgets/streaming_message_content.dart';
import '../widgets/unified_settings_modal.dart';
import '../widgets/model_quick_switcher_modal.dart';
import '../widgets/model_capabilities_bottom_sheet.dart';
import 'model_selection_screen.dart';
import 'vibration_stub.dart'
    if (dart.library.io) 'vibration_impl.dart';

class EditorScreen extends StatefulWidget {
  final String? conversationId;
  final String? prompt;
  final String? role;
  final String? contextInfo;

  const EditorScreen({
    super.key,
    this.conversationId,
    this.prompt,
    this.role,
    this.contextInfo,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}


class _EditorScreenState extends State<EditorScreen> {
  late final UnifiedApiService _apiService;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final Uuid _uuid = const Uuid();
  List<Message> _messages = [];
  List<String> _selectedSourceIds = [];

  List<Source> _selectedSources = [];
  final List<FileAttachment> _attachments = [];
  String _title = '';
  bool _isFirstMessage = true;
  bool _hasInitialData = false;
  bool _hasSentInitialPrompt = false; // Prevent duplicate auto-send
  Map<String, dynamic>? _topicContext;
  String? _role;
  String? _contextInfo;
  bool _isProcessing = false;
  bool _showLoader = false;
  String _selectedModel = 'mistralai/mistral-small-3.2-24b-instruct:free';
  ModelCapabilities? _currentModelCapabilities;
  double _sessionCost = 0.0;
  double _lastOperationCost = 0.0;
  String? _expandedSourcesMessageId;
  String? _expandedImagesMessageId;

  // Missing variable declarations
  String? _currentConversationId;
  List<String> _availableModels = [];
  String _selectedPersonality = 'helpful';
  String _selectedLanguage = 'English';

  bool _isDeepSearchMode = false;
  bool _isOfflineMode = true;
  String? _currentMilestone;
  String? _currentPhase;
  double? _currentProgress;
  ChatMode _currentMode = ChatMode.chat;
  Map<ChatMode, ModeConfig> _modeConfigs = {};
  ToolsConfig? _toolsConfig;
  // NEW VARIABLES:
  String? _lastUsedLLM;
  String? _lastUsedModel;
  Map<String, dynamic>? _lastToolResults;

  // Mode dropdown variables
  bool _showModeDropdown = false;
  late GlobalKey _modeDropdownKey;
  
  // Cost service stream subscription
  StreamSubscription<SessionCostData>? _costSubscription;

  // Services ready state
  bool _servicesReady = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: ModernAppHeader(
        showBackButton: true,
        showLogo: true,
        centerTitle: false,
        title: _buildHeaderTitle(),
        showNewChatButton: true,
        onMenuItemSelected: (value) {
          if (value == 'settings') {
            _showSettings();
          }
        },
      ),
      body: GestureDetector(
        onTap: () {
          if (_showModeDropdown) {
            setState(() {
              _showModeDropdown = false;
            });
          }
        },
        child: Stack(
          children: [
            _buildMainContent(context, theme),
            // Mode dropdown overlay
            _buildModeDropdownOverlay(),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If a prompt is provided, show it as a system message and pre-fill the input box
    if (widget.prompt != null && widget.prompt!.trim().isNotEmpty) {
      final alreadyHasPrompt = _messages.isNotEmpty &&
        _messages.first.type == 'system' &&
        _messages.first.textContent == widget.prompt;
      if (!alreadyHasPrompt) {
        setState(() {
          _messages.insert(
            0,
            Message(
              id: _uuid.v4(),
              type: 'system',
              content: widget.prompt!,
              timestamp: DateTime.now().toIso8601String(),
            ),
          );
          _messageController.text = widget.prompt!;
        });
      }
      // Auto-send the prompt as the first message if not already sent
      if (!_hasSentInitialPrompt && _messages.length == 1 && _messages.first.type == 'system') {
        _hasSentInitialPrompt = true;
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _sendMessage(widget.prompt!);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
    modeConfigProvider.removeListener(_onModeConfigChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _costSubscription?.cancel();

    // Stop auto-save when leaving the screen
    ConversationService().stopAutoSave();

    super.dispose();
  }

  void handleNavigateToEntities() {
    GoRouter.of(context).push('/entities');
  }

  void handleNavigateToSources() {
    GoRouter.of(context).push('/sources');
  }

  @override
  void initState() {
    super.initState();

    // Get the globally initialized API service
    _apiService = ServicesManager().unifiedApiService;

    // Start auto-save for conversations
    ConversationService().startAutoSave();

    // Check if services are ready
    _checkServicesReady();

    _currentConversationId = widget.conversationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _role = widget.role;
    _contextInfo = widget.contextInfo;
    _modeDropdownKey = GlobalKey();
    _loadInitialData();
    _loadAvailableModels();
    _loadLanguageSettings();
    _loadToolsConfig();
    _loadModeConfigs();
    _subscribeToSessionCostUpdates();
    // Load saved model after mode configs are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSavedModel();
      _checkModelCapabilities();
    });

    // Listen to mode config changes for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      modeConfigProvider.addListener(_onModeConfigChanged);
      
    });

    // Load conversation if conversationId is provided via route
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadConversation();
      });
    }
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.conversationId;
    if (newId != null && newId.isNotEmpty && newId != oldWidget.conversationId) {
      setState(() {
        _currentConversationId = newId;
      });
      _loadConversation();
    }
  }

  Widget _buildCompactModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? AppColors.darkButtonText : AppColors.lightButtonText)
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppColors.darkButtonText : AppColors.lightButtonText)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedImagesContent(List<Map<String, dynamic>> images, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
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
                Icons.image,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Images (${images.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedImagesMessageId = null;
                  });
                },
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal scrollable image cards (same style as sources)
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return _buildImageCard(images[index], index, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSourcesContent(List<ChatSource> sources, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
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
                Icons.source,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Sources (${sources.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedSourcesMessageId = null;
                  });
                },
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal scrollable source cards
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                return _buildSourceCard(sources[index], index, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  // _addToStreamingContent removed

  String _buildHeaderTitle() {
    if (_topicContext != null) {
      final topicName = _topicContext!['topicName'] as String;
      final role = _topicContext!['role'] as String;
      return '🎓 Learning: $topicName';
    }
    return _title.isNotEmpty ? _title : 'Chat';
  }

  Widget _buildModelChip(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final modelName = _formatModelName(_selectedModel);
    final isFree = _isModelFree(_selectedModel);
    
    return GestureDetector(
      onTap: () => _showModelQuickSwitcher(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isFree
                    ? (isDark ? AppColors.darkSuccess.withValues(alpha: 0.2) : AppColors.lightSuccess.withValues(alpha: 0.15))
                    : (isDark ? AppColors.darkWarning.withValues(alpha: 0.2) : AppColors.lightWarning.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isFree ? 'Free' : 'Paid',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isFree
                      ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                      : (isDark ? AppColors.darkWarning : AppColors.lightWarning),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              modelName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatModelName(String modelId) {
    // Extract the model name from the ID
    final parts = modelId.split('/');
    if (parts.length > 1) {
      final modelName = parts.last;
      // Remove :free suffix if present
      return modelName.replaceAll(':free', '');
    }
    return modelId;
  }

  bool _isModelFree(String modelId) {
    return modelId.endsWith(':free') || 
           modelId.contains('gpt-3.5-turbo') ||
           modelId.contains('claude-3-haiku') ||
           modelId.contains('gemini-pro') ||
           modelId.contains('llama-2-7b') ||
           modelId.contains('mistral-7b');
  }

  void _showModelQuickSwitcher() {
    showModelQuickSwitcher(
      context: context,
      mode: _currentMode,
      selectedModel: _selectedModel,
      onModelSelected: (modelId) {
        setState(() {
          _selectedModel = modelId;
        });
        _checkModelCapabilities();
      },
    );
  }

  Widget _buildImageCard(Map<String, dynamic> image, int index, ThemeData theme) {
    return Container(
      width: 140,
      margin: EdgeInsets.only(
        left: index == 0 ? 0 : 8,
        right: 8,
      ),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () => _showExpandedImage(context, image),
            child: Stack(
              children: [
                // Background Image
                Positioned.fill(
                  child: Image.network(
                    image['url'] ?? image['thumbnail'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.surface,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                // Text Overlay with Gradient Background
                if ((image['title'] != null && image['title'].toString().isNotEmpty) ||
                    (image['description'] != null && image['description'].toString().isNotEmpty))
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title text
                          if (image['title'] != null && image['title'].toString().isNotEmpty)
                            Text(
                              image['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          // Description text
                          if (image['description'] != null && image['description'].toString().isNotEmpty)
                            Text(
                              image['description'],
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // void _showModeSettings() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => const ModeSettingsModal(),
  //   ).then((_) {
  //     // Reload mode configs after settings are saved
  //     _loadModeConfigs();
  //   });
  // }

  Widget _buildMainContent(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected Sources Banner
        if (_selectedSources.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppColors.spacingMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppColors.spacingSm),
                Text(
                  'Using sources:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppColors.spacingSm),
                Expanded(
                  child: Wrap(
                    spacing: AppColors.spacingSm,
                    children: _selectedSources.map((source) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppColors.spacingSm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Text(
                            source.title ?? source.filename,
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          // Session Info
          StreamBuilder<SessionCostData>(
            stream: SessionCostService().costUpdates,
            builder: (context, snapshot) {
              final costData = snapshot.data;
              
              final finalSessionCost = costData?.sessionCost ?? _sessionCost;
              final finalLastCost = costData?.lastMessageCost ?? _lastOperationCost;
              
              
              return Consumer<ModeConfigProvider>(
                builder: (context, modeConfigProvider, child) {
                  return SessionInfoWidget(
                    llmUsed: _lastUsedLLM,
                    modelName: _lastUsedModel ?? _getModelForCurrentMode(),
                    cost: finalLastCost,
                    sessionCost: finalSessionCost,
                    toolResults: _lastToolResults,
                    messageCount: costData?.messageCount ?? SessionCostService().messageCount,
                    modelCapabilities: _currentModelCapabilities,
                    mode: _currentMode,
                    onModelSwitched: (modelId) {
                      setState(() {
                        _selectedModel = modelId;
                      });
                      // Save the selected model
                      _saveSelectedModel(modelId);
                      // Update provider for the current mode
                      final provider = Provider.of<ModeConfigProvider>(context, listen: false);
                      final currentConfig = provider.getConfigForMode(_currentMode);
                      if (currentConfig != null) {
                        provider.updateConfig(_currentMode, currentConfig.copyWith(model: modelId));
                      }
                      // Update LLM service
                      LLMService().setCurrentModel(modelId);
                      _checkModelCapabilities();
                    },
                  );
                },
              );
            },
          ),

          // Messages List (fills available space, avoids extra bottom space)
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedSourceIds.isNotEmpty
                              ? Icons.auto_awesome_outlined
                              : Icons.chat_bubble_outline,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: AppColors.spacingMd),
                        Text(
                          _selectedSourceIds.isNotEmpty
                              ? 'Quick actions for your sources:'
                              : 'Start a conversation...',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),

                        // Quick action buttons for source grounded chat
                        if (_selectedSourceIds.isNotEmpty || _selectedSources.isNotEmpty) ...[
                          const SizedBox(height: AppColors.spacingLg),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildQuickActionButton(
                                  icon: Icons.summarize_outlined,
                                  label: 'Concise Summary',
                                  onPressed: () => _sendMessage('Provide a concise summary of the key points from the selected sources.'),
                                  theme: theme,
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.article_outlined,
                                  label: 'Detailed Summary',
                                  onPressed: () => _sendMessage('Provide a detailed summary with comprehensive analysis of the selected sources.'),
                                  theme: theme,
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.quiz_outlined,
                                  label: 'Key Points',
                                  onPressed: () => _sendMessage('Extract and list the key points from the selected sources in bullet format.'),
                                  theme: theme,
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.lightbulb_outline,
                                  label: 'Insights',
                                  onPressed: () => _sendMessage('What are the main insights and takeaways from the selected sources?'),
                                  theme: theme,
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.help_outline,
                                  label: 'Explain Concepts',
                                  onPressed: () => _sendMessage('Explain the main concepts covered in the selected sources.'),
                                  theme: theme,
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.school_outlined,
                                  label: 'Learning Guide',
                                  onPressed: () => _sendMessage('Create a learning guide based on the selected sources with recommended study approach.'),
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppColors.spacingMd),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      // Use simple key for streaming messages to avoid rebuild optimization issues
                      return KeyedSubtree(
                        key: ValueKey(message.id),
                        child: _buildMessageWidget(message, theme),
                      );
                    },
                  ),
          ),

          // Compact attachment preview
          if (_attachments.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_attachments.length} attachment${_attachments.length > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachments.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final attachment = _attachments[index];
                        return Container(
                          width: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                          ),
                          child: Stack(
                            children: [
                              // Preview content
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: attachment.type == 'image'
                                      ? Image.memory(
                                          attachment.bytes,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: theme.colorScheme.errorContainer,
                                            child: Icon(
                                              Icons.broken_image,
                                              color: theme.colorScheme.onErrorContainer,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                attachment.type == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                                                color: theme.colorScheme.onSurfaceVariant,
                                                size: 20,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                attachment.extension.toUpperCase(),
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              // Remove button
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeAttachment(attachment.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Model selector layer (NEW)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? AppColors.darkBackgroundAlt : AppColors.lightBackgroundAlt,
              border: Border(
                bottom: BorderSide(
                  color: theme.brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.memory,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showModelCapabilitiesBottomSheet(context),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        _getModelDisplayTextForSelector(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showModelQuickSwitcher(
                      context: context,
                      mode: _currentMode,
                      selectedModel: _selectedModel,
                      onModelSelected: (modelId) {
                        setState(() {
                          _selectedModel = modelId;
                        });
                        // Save the selected model
                        _saveSelectedModel(modelId);
                        // Update provider for the current mode
                        final provider = Provider.of<ModeConfigProvider>(context, listen: false);
                        final currentConfig = provider.getConfigForMode(_currentMode);
                        if (currentConfig != null) {
                          provider.updateConfig(_currentMode, currentConfig.copyWith(model: modelId));
                        }
                        // Update LLM service
                        LLMService().setCurrentModel(modelId);
                        _checkModelCapabilities();
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Switch',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Input Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: AppColors.spacingSm),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? AppColors.darkBackgroundAlt : AppColors.lightBackgroundAlt,
            ),
            child: Column(
              children: [                // Unified input container with separated text and controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark ? AppColors.darkInput : AppColors.lightInput,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (theme.brightness == Brightness.dark ? Colors.black : Colors.grey).withValues(alpha: 0.03),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      // Prevent input area from forcing overflow by capping height
                      maxHeight: 240,
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      // Text input area (top section)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          maxHeight: 100,
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          maxLines: null,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.brightness == Brightness.dark ? AppColors.darkInputText : AppColors.lightInputText,
                            fontSize: 16,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: 'What do you want to know?',
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.brightness == Brightness.dark ? AppColors.darkInputPlaceholder : AppColors.lightInputPlaceholder,
                              fontSize: 16,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.all(0),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),

                      // Controls row (bottom section)
                      const SizedBox(height: 2),

                      // Services status indicator
                      if (!_servicesReady)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Initializing services...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          // Left side controls: attachment and mode dropdown
                          IconButton(
                            icon: Icon(
                              Icons.attach_file,
                              size: 20,
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                            onPressed: () {
                              Logger.debug('📎 Attachment button pressed', tag: 'EditorScreen');
                              Logger.debug('📎 Current model capabilities: supportsFiles=${_currentModelCapabilities?.supportsFiles}, supportsImages=${_currentModelCapabilities?.supportsImages}', tag: 'EditorScreen');
                              _showAttachmentOptions();
                            },
                            tooltip: 'Attach files',
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(28, 28),
                            ),
                          ),

                          // Mode dropdown
                          if (_selectedSourceIds.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _buildModeDropdown(),
                            ),

                          // Globe toggle (only in normal chat mode) - PREMIUM FEATURE
                          if (_selectedSourceIds.isEmpty && FeatureAccess.canShow('search_agents'))
                            Builder(
                              builder: (context) {
                                final hasAccess = FeatureAccess.isEnabledForUser(context, 'search_agents');

                                return GestureDetector(
                                  onTap: () async {
                                    if (hasAccess) {
                                      // Check if trying to turn off globe in DeepSearch mode
                                      if (!_isOfflineMode && _isDeepSearchMode) {
                                        // Show warning toast when turning off globe in DeepSearch mode
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('DeepSearch requires globe search to be enabled'),
                                            backgroundColor: Colors.orange,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      setState(() {
                                        _isOfflineMode = !_isOfflineMode;
                                      });
                                    } else {
                                      // Direct RevenueCat purchase flow
                                      try {
                                        final ok = await PaywallCoordinator.showNativePurchaseFlow(context);
                                        if (ok) {
                                          // Flip the globe or refresh UI as premium is now active
                                          setState(() {
                                            _isOfflineMode = false; // enable online tools
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Premium unlocked')),
                                          );
                                        }
                                      } catch (e) {
                                        // Optional: show a small toast/snackbar on fail
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Purchase failed: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: Tooltip(
                                    message: hasAccess
                                        ? (_isOfflineMode ? 'Offline Mode (No Internet Tools)' : 'Online Mode (All Tools Available)')
                                        : 'Web Search - Premium Feature',
                                    child: Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: BoxDecoration(
                                            color: hasAccess && !_isOfflineMode
                                                ? (theme.brightness == Brightness.dark ? AppColors.darkAccent.withValues(alpha: 0.2) : AppColors.lightAccent.withValues(alpha: 0.2))
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: hasAccess && !_isOfflineMode ? Border.all(
                                              color: theme.brightness == Brightness.dark ? AppColors.darkAccent.withValues(alpha: 0.3) : AppColors.lightAccent.withValues(alpha: 0.3),
                                              width: 1,
                                            ) : null,
                                          ),
                                          child: Icon(
                                            Icons.public,
                                            size: 16,
                                            color: hasAccess && !_isOfflineMode
                                                ? (theme.brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent)
                                                : (theme.brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                          ),
                                        ),
                                        if (!hasAccess)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.lock,
                                                size: 6,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                          const Spacer(),

                          // Right side: Send button
                          Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 4),
                            child: IconButton(
                              onPressed: (_isProcessing || !_servicesReady) ? null : () => _sendMessage(),
                              icon: _showLoader
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          theme.brightness == Brightness.dark ? AppColors.darkButtonText : AppColors.lightButtonText,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.keyboard_arrow_up,
                                      size: 26,
                                      color: theme.brightness == Brightness.dark ? AppColors.darkButtonText : AppColors.lightButtonText,
                                    ),
                              style: IconButton.styleFrom(
                                backgroundColor: _isProcessing
                                    ? (theme.brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                                    : (theme.brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(38, 38),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(19),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),


             ],
           ),
         ),
       ],
     );
   }

  Widget _buildMessageWidget(Message message, ThemeData theme) {
    final isUser = message.type == 'user';
    final isSystem = message.type == 'system';
    final messageTime = DateTime.parse(message.timestamp);
    final timeString = '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    
    // Debug print for assistant messages to track content updates
    if (message.type == 'assistant') {
      
      
      
      
    }

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: AppColors.spacingSm),
        padding: const EdgeInsets.all(AppColors.spacingSm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info,
              size: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppColors.spacingSm),
            Text(
              'SYSTEM',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: AppColors.spacingSm),
            Expanded(
              child: Text(
                message.textContent,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppColors.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppColors.spacingSm),
              Text(
                isUser ? 'You' : 'Cognify',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                timeString,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              // Retry with different model button (for user messages)
              if (isUser)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: () => _retryUserMessageWithModel(message),
                    icon: const Icon(Icons.sync_alt, size: 14),
                    iconSize: 14,
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    tooltip: 'Switch model and retry',
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),

          // Attachments
          if (message.attachments != null && message.attachments!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 40, bottom: AppColors.spacingSm),
              child: Wrap(
                spacing: AppColors.spacingSm,
                children: message.attachments!.map((attachment) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppColors.spacingSm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          attachment.type == 'pdf'
                              ? Icons.picture_as_pdf
                              : attachment.type == 'image'
                                  ? Icons.image
                                  : Icons.description,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          attachment.name,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Message Content
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            alignment: Alignment.centerLeft,
            child: isUser
                ? Text(
                    message.textContent,
                    style: theme.textTheme.bodyMedium,
                  )
                : Builder(
                    builder: (context) {
                      // Always show streaming content for assistant, even if isProcessing is true
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sources and Images at the top of the message bubble
                          if ((message.sources != null && message.sources!.isNotEmpty) || _getMessageImages(message).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: StackedMediaBubbles(
                                  sources: message.sources ?? [],
                                  images: _getMessageImages(message),
                                  onExpandedChanged: (isSources, isImages) {
                                    setState(() {
                                      if (isSources) {
                                        _expandedSourcesMessageId = _expandedSourcesMessageId == message.id ? null : message.id;
                                        _expandedImagesMessageId = null;
                                      } else if (isImages) {
                                        _expandedImagesMessageId = _expandedImagesMessageId == message.id ? null : message.id;
                                        _expandedSourcesMessageId = null;
                                      }
                                    });
                                  },
                                  areSourcesExpanded: _expandedSourcesMessageId == message.id,
                                  areImagesExpanded: _expandedImagesMessageId == message.id,
                                ),
                              ),
                            ),

                          // Full-width expanded content inside the message bubble
                          if ((message.sources != null && message.sources!.isNotEmpty) || _getMessageImages(message).isNotEmpty) ...[
                            if (_expandedSourcesMessageId == message.id && message.sources != null && message.sources!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _buildExpandedSourcesContent(message.sources!, theme),
                              ),

                            if (_expandedImagesMessageId == message.id && _getMessageImages(message).isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _buildExpandedImagesContent(_getMessageImages(message), theme),
                              ),
                          ],

                          StreamingMessageContent(
                            message: message,
                            theme: theme,
                          ),
                          if (message.isProcessing == true || (_isProcessing && _messages.last.id == message.id))
                            Padding(
                              padding: const EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
                              child: EnhancedLoadingIndicator(
                                currentMilestone: _currentMilestone,
                                progress: _currentProgress,
                                phase: _currentPhase,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),



          // Organized post-message content (follow-up questions, images, quick actions)
          // Only show when the answer is finalized and non-empty
          if (!isUser && message.isProcessing != true && message.textContent.trim().isNotEmpty)
            OrganizedPostMessageContent(
              message: message,
              getModelForCurrentMode: _getModelForCurrentMode,
              messages: _messages,
              sendMessage: _sendMessage,
              selectedSourceIds: _selectedSourceIds,
              selectedSources: _selectedSources,
            ),

          // Cost display for assistant messages
          if (!isUser && message.isProcessing != true && (message.messageCost != null || message.sessionCost != null))
            Container(
              margin: const EdgeInsets.only(top: AppColors.spacingSm),
              child: CostDisplayWidget(
                messageCost: message.messageCost,
                costBreakdown: message.costBreakdown,
                compact: true,
              ),
            ),

          // Standard action buttons for assistant messages
          if (!isUser && message.isProcessing != true)
            Container(
              margin: const EdgeInsets.only(top: AppColors.spacingSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Standard action buttons
                  Wrap(
                    spacing: 8,
                    children: [
                      // Copy button
                      TextButton.icon(
                        onPressed: () => _copyMessage(message),
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppColors.spacingSm,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Retry button for user messages when next response failed
          if (isUser && _shouldShowRetryButton(message))
            Container(
              margin: const EdgeInsets.only(left: 40, top: AppColors.spacingSm),
              child: TextButton.icon(
                onPressed: () => _retryUserMessage(message),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppColors.spacingSm,
                    vertical: 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppColors.spacingMd,
              vertical: AppColors.spacingSm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                  : (isDark ? AppColors.darkBackgroundAlt : AppColors.lightBackgroundAlt),
              borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? (isDark ? AppColors.darkButtonText : AppColors.lightButtonText)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: AppColors.spacingXs),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? (isDark ? AppColors.darkButtonText : AppColors.lightButtonText)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      key: _modeDropdownKey,
      onTap: () {
        setState(() {
          _showModeDropdown = !_showModeDropdown;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container to match dropdown items
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _isDeepSearchMode ? Icons.manage_search : Icons.flash_on,
                size: 14,
                color: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isDeepSearchMode ? 'DeepSearch' : 'Chat',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
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

  Widget _buildModeDropdownItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    bool requiresPremium = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Left icon - always primary color regardless of selection
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Right indicator - checkmark when selected, lock when premium required and no access
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 12,
                    color: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
                  ),
                )
              else if (requiresPremium && !isPremiumUnlocked(context, listen: false))
                Container(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeDropdownOverlay() {
    if (!_showModeDropdown) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      bottom: 60, // Position above the input
      left: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chat option
              _buildModeDropdownItem(
                icon: Icons.flash_on,
                title: 'Chat',
                description: 'Lightning fast responses with minimal search',
                isSelected: !_isDeepSearchMode,
                onTap: () {
                  setState(() {
                    _isDeepSearchMode = false;
                    _currentMode = ChatMode.chat;
                    _showModeDropdown = false;
                  });
                  // Load the appropriate model for the new mode
                  _loadModelForCurrentMode();
                  // Update model capabilities when mode changes
                  _checkModelCapabilities();
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              // DeepSearch option
              _buildModeDropdownItem(
                icon: Icons.manage_search,
                title: 'DeepSearch',
                description: 'Advanced search and reasoning (Premium)',
                isSelected: _isDeepSearchMode,
                requiresPremium: true,
                onTap: () async {
                  // Check if user has premium access for DeepSearch
                  if (!isPremiumUnlocked(context, listen: false)) {
                    // Direct RevenueCat purchase flow (same as globe toggle)
                    try {
                      final ok = await PaywallCoordinator.showNativePurchaseFlow(context);
                      if (ok) {
                        // Enable DeepSearch and globe as premium is now active
                        setState(() {
                          _isDeepSearchMode = true;
                          _currentMode = ChatMode.deepsearch;
                          _showModeDropdown = false;
                          _isOfflineMode = false; // enable online tools
                        });
                        // Load the appropriate model for the new mode
                        _loadModelForCurrentMode();
                        // Update model capabilities when mode changes
                        _checkModelCapabilities();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Premium unlocked - DeepSearch enabled')),
                        );
                      } else {
                        setState(() {
                          _showModeDropdown = false;
                        });
                      }
                    } catch (e) {
                      // Optional: show a small toast/snackbar on fail
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Purchase failed: $e')),
                      );
                      setState(() {
                        _showModeDropdown = false;
                      });
                    }
                    return;
                  }

                  setState(() {
                    _isDeepSearchMode = true;
                    _currentMode = ChatMode.deepsearch;
                    _showModeDropdown = false;
                    // Auto-enable globe for DeepSearch mode (premium users only)
                    _isOfflineMode = false;
                  });
                  // Load the appropriate model for the new mode
                  _loadModelForCurrentMode();
                  // Update model capabilities when mode changes
                  _checkModelCapabilities();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.8)
            : AppColors.lightSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
        border: Border.all(
          color: isDark
              ? AppColors.darkAccent.withValues(alpha: 0.3)
              : AppColors.lightAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceCard(ChatSource source, int index, ThemeData theme) {
    final domain = Uri.tryParse(source.url)?.host ?? 'Unknown';
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 200,
      margin: EdgeInsets.only(
        left: index == 0 ? 0 : 8,
        right: 8,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            try {
              Logger.debug('🔗 Attempting to open source URL from expanded card: ${source.url}', tag: 'EditorScreen');
              final uri = Uri.parse(source.url);

              if (await canLaunchUrl(uri)) {
                Logger.debug('🔗 URL can be launched, opening in external browser...', tag: 'EditorScreen');
                await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                  webViewConfiguration: const WebViewConfiguration(
                    enableJavaScript: true,
                  ),
                );
                Logger.debug('🔗 URL launched successfully', tag: 'EditorScreen');
              } else {
                Logger.warn('❌ Cannot launch URL: ${source.url}', tag: 'EditorScreen');
                // Show user feedback
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not open link: ${source.url}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              Logger.error('❌ Error launching URL: $e', tag: 'EditorScreen');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error opening link: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getSourceColor(source),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _getSourceColor(source).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getSourceIcon(source),
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        domain,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    source.title ?? 'Untitled',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkModelCapabilities() async {
    try {
      final currentModel = _getModelForCurrentMode();
      Logger.debug('🔍 Checking capabilities for model: $currentModel', tag: 'EditorScreen');

      try {
        final capabilities = await ModelService.getModelCapabilities(currentModel);
        setState(() {
          _currentModelCapabilities = capabilities;
        });
        Logger.debug('🔍 Model capabilities: supportsImages=${capabilities.supportsImages}, supportsFiles=${capabilities.supportsFiles}, inputModalities=${capabilities.inputModalities}', tag: 'EditorScreen');
        
        // Check context size for DeepSearch mode
        _checkContextSizeForDeepSearch(capabilities);
      } catch (e) {
        Logger.warn('🔍 Failed to get capabilities from API: $e', tag: 'EditorScreen');
        // Fallback: if it's a Gemini model, assume it supports images and files
        final supportsImages = currentModel.contains('gemini');
        final supportsFiles = currentModel.contains('gemini'); // Gemini models typically support both
        setState(() {
          _currentModelCapabilities = ModelCapabilities(
            inputModalities: supportsImages ? ['text', 'image'] : ['text'],
            outputModalities: ['text'],
            supportsImages: supportsImages,
            supportsFiles: supportsFiles,
            isMultimodal: supportsImages || supportsFiles,
          );
        });
        Logger.debug('🔍 Using fallback capabilities: supportsImages=$supportsImages, supportsFiles=$supportsFiles', tag: 'EditorScreen');
      }
    } catch (e) {
      
      setState(() {
        _currentModelCapabilities = const ModelCapabilities(
          inputModalities: ['text'],
          outputModalities: ['text'],
          supportsImages: false,
          supportsFiles: false,
          isMultimodal: false,
        );
      });
    }
  }

  /// Check context size for DeepSearch mode and show warning if needed
  void _checkContextSizeForDeepSearch(ModelCapabilities capabilities) {
    // Only check if we're in DeepSearch mode
    if (!_isDeepSearchMode) return;
    
    final contextLength = capabilities.contextLength;
    if (contextLength != null && contextLength < 150000) {
      // Show warning toast for low context size
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('DeepSearch works best with models having 160k+ context. Current model: ${(contextLength / 1000).round()}k context'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  /// Check if services are ready for use
  void _checkServicesReady() {
    // Check if ServicesManager is initialized and agent system is ready
    final servicesManager = ServicesManager();
    if (servicesManager.isInitialized) {
      final agentStatus = _apiService.getAgentSystemStatus();
      final isReady = agentStatus['enabled'] == true;

      setState(() {
        _servicesReady = isReady;
      });

      if (!_servicesReady) {
        
        // Continue retrying if not ready
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_servicesReady) {
            _checkServicesReady();
          }
        });
      } else {
        
      }
    } else {
      
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkServicesReady();
        }
      });
    }
  }

  // Premium feature methods
  Future<bool> _checkWebSearchAccess() async {
    try {
      // Dev override: allow internet globe in development when the explicit dev flag is enabled.
      // Production or dev without override: require active subscription entitlement.
      try {
        final sub = Provider.of<SubscriptionProvider>(context, listen: false);
        // active -> access granted, otherwise locked (unknown/inactive fail-closed)
        return sub.isEntitled;
      } catch (_) {
        // If provider not available, fail closed
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  void _copyMessage(Message message) async {
    try {
      await Clipboard.setData(ClipboardData(text: message.textContent));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy message'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }



  // Debug function to check current model state
  void _debugModelState() {
    
    
    
    
    
    
    
    
    
    // Check provider state
    try {
      final provider = Provider.of<ModeConfigProvider>(context, listen: false);
      
      
      
    } catch (e) {
      
    }
  }

  String _getChatModeModel() {
    final chatConfig = _modeConfigs[ChatMode.chat];
    final model = chatConfig?.model ?? ModeConfigManager.getDefaultConfigForMode(ChatMode.chat).model;
    
    return model;
  }

  String _getCurrentModeName() {
    // Determine current mode based on flags and return its string representation
    if (_isDeepSearchMode) {
      return 'deepsearch';
    } else {
      return 'chat';
    }
  }

  String _getDeepSearchModeModel() {
    final deepsearchConfig = _modeConfigs[ChatMode.deepsearch];
    final model = deepsearchConfig?.model ?? ModeConfigManager.getDefaultConfigForMode(ChatMode.deepsearch).model;
    
    return model;
  }

  // Helper method to get message images
  List<Map<String, dynamic>> _getMessageImages(Message message) {
    return (message.images as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  String _getModelForCurrentMode() {
    // Determine current mode based on flags
    if (_isDeepSearchMode) {
      _currentMode = ChatMode.deepsearch;
    } else {
      _currentMode = ChatMode.chat;
    }

    // Get model from mode config (mode-specific models take precedence)
    final config = _modeConfigs[_currentMode];
    if (config != null) {
      return config.model;
    }

    // Fallback to default model for mode
    return ModeConfigManager.getDefaultConfigForMode(_currentMode).model;
  }

  Color _getSourceColor(ChatSource source) {
    final domain = Uri.tryParse(source.url)?.host ?? '';
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    return colors[domain.hashCode % colors.length];
  }

  IconData _getSourceIcon(ChatSource source) {
    final url = source.url.toLowerCase();
    if (url.contains('youtube')) return Icons.play_circle;
    if (url.contains('github')) return Icons.code;
    if (url.contains('stackoverflow')) return Icons.help;
    if (url.contains('medium') || url.contains('blog')) return Icons.article;
    if (url.contains('wikipedia')) return Icons.menu_book;
    return Icons.link;
  }





  // Helper method to validate if a URL is actually an image
  bool _isValidImageUrl(String url) {
    // Check for common image file extensions
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.tiff'];
    final lowerUrl = url.toLowerCase();
    
    // Check if URL ends with image extension
    for (final ext in imageExtensions) {
      if (lowerUrl.endsWith(ext)) {
        return true;
      }
    }
    
    // Check for data URLs (base64 images)
    if (lowerUrl.startsWith('data:image/')) {
      return true;
    }
    
    // Check for common image CDN patterns
    final imagePatterns = [
      'images.',
      'img.',
      'cdn.',
      'static.',
      'media.',
      'assets.',
      'uploads/',
      '/images/',
      '/img/',
      '/media/',
      '/assets/',
    ];
    
    for (final pattern in imagePatterns) {
      if (lowerUrl.contains(pattern)) {
        return true;
      }
    }
    
    // If it's a Wikipedia media URL, it's likely an image
    if (lowerUrl.contains('wikipedia.org') && lowerUrl.contains('/media/')) {
      return true;
    }
    
    return false;
  }

  Future<void> _loadAvailableModels() async {
    try {
      // Use OpenRouter client directly with context for proper error handling
      final openRouterClient = OpenRouterClient();
      final modelsResponse = await openRouterClient.getModels(context: context);

      final models = modelsResponse['models'] as List<String>?;
      if (models != null) {
        setState(() {
          _availableModels = models;
        });
      } else {
        throw Exception('Failed to fetch models: ${modelsResponse['error'] ?? 'Unknown error'}');
      }

      // Load saved model preference with better fallback logic
      await _loadSavedModel();
    } catch (e) {
      
      // Set fallback models if API fails
      setState(() {
        _availableModels = [
          'mistralai/mistral-7b-instruct:free',
          'deepseek/deepseek-chat:free',
          'deepseek/deepseek-chat-v3-0324:free',
          'deepseek/deepseek-r1:free',
          'google/gemini-2.0-flash-exp:free',
        ];
      });
      
      // Try to load saved model even with fallback models
      await _loadSavedModel();
    }
  }

  Future<void> _loadSavedModel() async {
    try {
      // Always load model from mode config (mode-specific models take precedence)
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      final currentConfig = modeConfigProvider.getConfigForMode(_currentMode);
      
      if (currentConfig != null && currentConfig.model.isNotEmpty) {
        setState(() {
          _selectedModel = currentConfig.model;
        });
        Logger.info('🤖 Loaded model from mode config: ${currentConfig.model}', tag: 'EditorScreen');
      } else {
        // Fallback to default model for current mode
        final defaultModel = ModeConfigManager.getDefaultConfigForMode(_currentMode).model;
        setState(() {
          _selectedModel = defaultModel;
        });
        Logger.info('🤖 Using default model for mode: $defaultModel', tag: 'EditorScreen');
        
        // Save the default model to the mode config
        await modeConfigProvider.updateConfig(_currentMode, 
          ModeConfigManager.getDefaultConfigForMode(_currentMode));
      }
      
      // Also update the LLM service with the selected model
      LLMService().setCurrentModel(_selectedModel);
    } catch (e) {
      Logger.error('❌ Error loading saved model: $e', tag: 'EditorScreen');
      // Keep the current _selectedModel value
    }
  }

  Future<void> _saveSelectedModel(String modelId) async {
    try {
      // Save model to the current mode's config instead of global SharedPreferences
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      final currentConfig = modeConfigProvider.getConfigForMode(_currentMode);
      
      if (currentConfig != null) {
        await modeConfigProvider.updateConfig(_currentMode, 
          currentConfig.copyWith(model: modelId));
      } else {
        // Create new config if none exists
        final defaultConfig = ModeConfigManager.getDefaultConfigForMode(_currentMode);
        await modeConfigProvider.updateConfig(_currentMode, 
          defaultConfig.copyWith(model: modelId));
      }
      
      Logger.info('🤖 Saved model for current mode ($_currentMode): $modelId', tag: 'EditorScreen');
    } catch (e) {
      Logger.error('❌ Error saving selected model: $e', tag: 'EditorScreen');
    }
  }

  Future<void> _loadModelForCurrentMode() async {
    try {
      // Get the model for the current mode from the provider
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      final currentConfig = modeConfigProvider.getConfigForMode(_currentMode);
      
      if (currentConfig != null && currentConfig.model.isNotEmpty) {
        setState(() {
          _selectedModel = currentConfig.model;
        });
        Logger.info('🤖 Loaded model for current mode: ${currentConfig.model}', tag: 'EditorScreen');
      } else {
        // Fallback to default model for the mode
        final defaultModel = ModeConfigManager.getDefaultConfigForMode(_currentMode).model;
        setState(() {
          _selectedModel = defaultModel;
        });
        Logger.info('🤖 Using default model for current mode: $defaultModel', tag: 'EditorScreen');
      }
      
      // Save the selected model and update LLM service
      await _saveSelectedModel(_selectedModel);
      LLMService().setCurrentModel(_selectedModel);
    } catch (e) {
      Logger.error('❌ Error loading model for current mode: $e', tag: 'EditorScreen');
    }
  }

  Future<void> _loadConversation() async {
    if (_currentConversationId == null) return;

    try {
      final conversationData = await ConversationService().loadConversation(_currentConversationId!);

      if (conversationData != null && conversationData.isNotEmpty) {
        final messages = (conversationData['messages'] as List?)
            ?.map((json) => Message.fromJson(json))
            .toList() ?? [];

        final metadata = conversationData['metadata'] as Map<String, dynamic>?;

        setState(() {
          _messages = messages;
          _title = conversationData['title'] as String? ?? 'Untitled Conversation';
          _sessionCost = metadata?['sessionCost']?.toDouble() ?? 0.0;
          _isFirstMessage = false;

          // Restore other metadata if available
          if (metadata != null) {
            _selectedModel = metadata['selectedModel'] as String? ?? _selectedModel;
            _selectedPersonality = metadata['selectedPersonality'] as String? ?? _selectedPersonality;
            _selectedLanguage = metadata['selectedLanguage'] as String? ?? _selectedLanguage;
          }
        });

        Logger.info('📖 [CONVERSATION] Loaded conversation: $_currentConversationId (${messages.length} messages)', tag: 'EditorScreen');
      } else {
        // Set up empty conversation
        setState(() {
          _title = 'New Conversation';
          _sessionCost = 0.0;
          _isFirstMessage = true;
        });
      }
    } catch (e) {
      Logger.error('❌ [CONVERSATION] Error loading conversation: $e', tag: 'EditorScreen');
      // Set up empty conversation
      setState(() {
        _title = 'New Conversation';
        _sessionCost = 0.0;
        _isFirstMessage = true;
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final initialDataJson = prefs.getString('editorInitialData');

      if (initialDataJson != null) {
        final initialData = jsonDecode(initialDataJson);
        setState(() {
          _hasInitialData = true;
        });

        // Handle selected source IDs for NotebookLM-style context
        if (initialData['selectedSourceIds'] != null) {
          final sourceIds = List<String>.from(initialData['selectedSourceIds']);
          setState(() {
            _selectedSourceIds = sourceIds;
          });

          // Fetch source details for display
          try {
            final allSources = await _apiService.getSources();
            final filtered = allSources.where((s) => sourceIds.contains(s.id)).toList();
            setState(() {
              _selectedSources = filtered;
            });
          } catch (e) {
            // Ignore error, just don't display source names
          }
        }

        // Handle topic context for roadmap learning
        if (initialData['topicContext'] != null) {
          setState(() {
            _topicContext = Map<String, dynamic>.from(initialData['topicContext']);
          });
        }

        if (initialData['conversationId'] != null) {
          final prefsConvId = initialData['conversationId'] as String;
          // If a route provided the same id, skip duplicate load
          if (_currentConversationId != null && _currentConversationId == prefsConvId) {
            // No-op
          } else {
            _currentConversationId = prefsConvId;
            await _loadConversation();
          }
        } else if (initialData['content'] != null) {
          if (initialData['isNewConversation'] == true) {
            _messageController.text = initialData['content'];
            _title = initialData['title'] ?? '';
            _isFirstMessage = false;

            // Auto-send the message after a brief delay
            Future.delayed(const Duration(milliseconds: 100), () {
              _sendMessage(initialData['content']);
            });
          }
        }

        await prefs.remove('editorInitialData');
      }
    } catch (e) {
      
    }
  }

  Future<void> _loadLanguageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('selectedLanguage') ?? 'English';
      final savedPersonality = prefs.getString('selectedPersonality') ?? 'Default';
      setState(() {
        _selectedLanguage = savedLanguage;
        _selectedPersonality = savedPersonality;
      });
    } catch (e) {
      
    }
  }

  Future<void> _loadModeConfigs() async {
    try {
      // Use the provider to get the latest configs that include any changes from the settings modal
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      final configs = modeConfigProvider.configs;
      
      // If provider doesn't have configs yet, load from storage as fallback
      if (configs.isEmpty) {
        final storageConfigs = await ModeConfigManager.loadConfigs();
        setState(() {
          _modeConfigs = storageConfigs;
        });
      } else {
        setState(() {
          _modeConfigs = configs;
        });
      }
      
      
    } catch (e) {
      
      // Fallback to defaults
      setState(() {
        _modeConfigs = {
          ChatMode.chat: ModeConfigManager.getDefaultConfigForMode(ChatMode.chat),
          ChatMode.deepsearch: ModeConfigManager.getDefaultConfigForMode(ChatMode.deepsearch),
        };
      });
    }
  }

  Future<void> _loadToolsConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('toolsConfig');
      if (configJson != null) {
        final config = ToolsConfig.fromJson(jsonDecode(configJson));
        setState(() {
          _toolsConfig = config;
        });
      } else {
        // Create default tools configuration to enable agent system
        const defaultConfig = ToolsConfig(
          braveSearch: true,
          sequentialThinking: true,
          webFetch: true,
          youtubeProcessor: true,
          browserRoadmap: true,
          imageSearch: true,
          keywordExtraction: true,
          memoryManager: true,
          sourceQuery: true,
          sourceContent: true,
          timeTool: true,
        );
        setState(() {
          _toolsConfig = defaultConfig;
        });
        Logger.info('🔧 Created default tools configuration to enable agent system', tag: 'EditorScreen');
      }
    } catch (e) {
      
      // Create default tools configuration as fallback
      const defaultConfig = ToolsConfig(
        braveSearch: true,
        sequentialThinking: true,
        webFetch: true,
        youtubeProcessor: true,
        browserRoadmap: true,
        imageSearch: true,
        keywordExtraction: true,
        memoryManager: true,
        sourceQuery: true,
        sourceContent: true,
        timeTool: true,
      );
      setState(() {
        _toolsConfig = defaultConfig;
      });
      Logger.info('🔧 Created fallback tools configuration to enable agent system', tag: 'EditorScreen');
    }
  }

  Future<void> _markTopicAsExplored() async {
    if (_topicContext == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final exploredTopicsJson = prefs.getString('explored_topics') ?? '{}';
      final exploredTopics = Map<String, dynamic>.from(jsonDecode(exploredTopicsJson));

      final topicId = _topicContext!['topicId'] as String;
      exploredTopics[topicId] = {
        'exploredAt': DateTime.now().toIso8601String(),
        'conversationId': _currentConversationId,
        'topicName': _topicContext!['topicName'],
        'role': _topicContext!['role'],
      };

      await prefs.setString('explored_topics', jsonEncode(exploredTopics));
    } catch (e) {
      
    }
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _messageController.clear();
      _attachments.clear();
      _title = '';
      _isFirstMessage = true;
      _sessionCost = 0.0;
      _lastOperationCost = 0.0;
      _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
      _topicContext = null; // Clear topic context on new chat
    });
    
    // Reset session cost tracking
    SessionCostService().resetSession();
    
    // Preserve the current model from mode config for new chat
    _loadModelForCurrentMode();
  }



  // Real-time mode config update handler
  void _onModeConfigChanged() {
    if (mounted) {
      final provider = Provider.of<ModeConfigProvider>(context, listen: false);
      final newConfigs = provider.configs;
      
      setState(() {
        _modeConfigs = newConfigs;
      });
      
      // Update the selected model based on current mode and new configs
      final currentConfig = newConfigs[_currentMode];
      if (currentConfig != null && currentConfig.model.isNotEmpty) {
        setState(() {
          _selectedModel = currentConfig.model;
        });
        // Update LLM service immediately
        LLMService().setCurrentModel(_selectedModel);
      }
      
      _checkModelCapabilities(); // Check capabilities when mode changes
      
      Logger.info('🔄 Mode config updated - Current mode: $_currentMode, Model: $_selectedModel', tag: 'EditorScreen');
    }
  }

  Future<void> _pickDocument() async {
    try {
      Logger.debug('📄 Starting document picker...', tag: 'EditorScreen');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );

      Logger.debug('📄 Document picker result: ${result?.files.length ?? 0} files', tag: 'EditorScreen');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Logger.debug('📄 Selected file: ${file.name}, size: ${file.size}, extension: ${file.extension}', tag: 'EditorScreen');
        
        if (file.bytes != null) {
          String mimeType;
          switch (file.extension?.toLowerCase()) {
            case 'pdf':
              mimeType = 'application/pdf';
              break;
            case 'doc':
              mimeType = 'application/msword';
              break;
            case 'docx':
              mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
              break;
            default:
              mimeType = 'text/plain';
          }
          
          final attachment = FileAttachment.fromBytes(
            name: file.name,
            bytes: file.bytes!,
            mimeType: mimeType,
          );

          setState(() {
            _attachments.add(attachment);
          });
          
          Logger.debug('📄 Document attached successfully: ${file.name}', tag: 'EditorScreen');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📄 Attached: ${file.name}'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          Logger.warn('⚠️ File bytes are null for: ${file.name}', tag: 'EditorScreen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to read file: ${file.name}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        Logger.debug('📄 No file selected or picker cancelled', tag: 'EditorScreen');
      }
    } catch (e) {
      Logger.error('❌ Error picking document: $e', tag: 'EditorScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final attachment = FileAttachment.fromBytes(
          name: image.name,
          bytes: bytes,
          mimeType: image.mimeType ?? 'image/jpeg',
        );

        setState(() {
          _attachments.add(attachment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeAttachment(String attachmentId) {
    setState(() {
      _attachments.removeWhere((att) => att.id == attachmentId);
    });
  }

  void _requestInsights(Message message) {
    // Debug logging for quick actions
    Logger.debug('🔍 Quick Action - Insights:', tag: 'EditorScreen');
    
    

    // If this was a source-grounded conversation, maintain the source context
    if (_selectedSourceIds.isNotEmpty || _selectedSources.isNotEmpty) {
      
      _sendMessage('What are the main insights and takeaways from the sources you just analyzed?');
    } else {
      
      _sendMessage('What are the main insights and takeaways from your previous response?');
    }
  }

  void _requestKeyPoints(Message message) {
    // Debug logging for quick actions
    Logger.debug('🔍 Quick Action - Key Points:', tag: 'EditorScreen');
    
    

    // If this was a source-grounded conversation, maintain the source context
    if (_selectedSourceIds.isNotEmpty || _selectedSources.isNotEmpty) {
      
      _sendMessage('Extract and list the key points from the sources in bullet format.');
    } else {
      
      _sendMessage('Extract and list the key points from your last answer in bullet format.');
    }
  }

  void _requestSummary(Message message, String type) {
    // Debug logging for quick actions
    Logger.debug('🔍 Quick Action - Summary ($type):', tag: 'EditorScreen');
    
    

    // If this was a source-grounded conversation, maintain the source context
    if (_selectedSourceIds.isNotEmpty || _selectedSources.isNotEmpty) {
      final prompt = type == 'concise'
          ? 'Provide a concise summary of the key points from the sources.'
          : 'Provide a detailed summary with comprehensive analysis of the sources.';
      
      _sendMessage(prompt);
    } else {
      final prompt = type == 'concise'
          ? 'Provide a concise summary of the key points from your previous response.'
          : 'Provide a detailed summary with comprehensive analysis of your previous response.';
      
      _sendMessage(prompt);
    }
  }

  void _retryUserMessage(Message userMessage) async {
    // Remove any failed assistant responses after this user message
    final userIndex = _messages.indexWhere((m) => m.id == userMessage.id);
    if (userIndex != -1) {
      // Remove all messages after this user message (including the user message itself)
      setState(() {
        _messages.removeRange(userIndex, _messages.length);
      });

      // Set the text in the input field and send the message again
      _messageController.text = userMessage.textContent;
      await _sendMessage();
    }
  }

  void _retryUserMessageWithModel(Message userMessage) {
    showModelQuickSwitcher(
      context: context,
      mode: _currentMode,
      selectedModel: _selectedModel,
      onModelSelected: (modelId) async {
        // Remove any responses after this user message
        final userIndex = _messages.indexWhere((m) => m.id == userMessage.id);
        if (userIndex != -1) {
          setState(() {
            _messages.removeRange(userIndex, _messages.length);
            // Permanently switch to selected model
            _selectedModel = modelId;
          });

          // Save model selection for this mode
          final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
          final currentConfig = modeConfigProvider.getConfigForMode(_currentMode);
          if (currentConfig != null) {
            modeConfigProvider.updateConfig(_currentMode, currentConfig.copyWith(model: modelId));
          }
          // Update LLM service
          LLMService().setCurrentModel(modelId);

          // Set the text in the input field and send the message again
          _messageController.text = userMessage.textContent;
          await _sendMessage();
          
          _checkModelCapabilities();
        }
      },
    );
  }



  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? initialText]) async {
    final textToSend = initialText ?? _messageController.text.trim();
    if (textToSend.isEmpty && _attachments.isEmpty) return;

    // Check if services are ready
    if (!_servicesReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Text('Services are still initializing. Please wait a moment...'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Retry checking services readiness
      _checkServicesReady();
      return;
    }

    // Set conversation title on first message
    if (_isFirstMessage && textToSend.isNotEmpty) {
      final suggestedTitle = textToSend.length > 50
          ? '${textToSend.substring(0, 50)}...'
          : textToSend;
      setState(() {
        _title = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - $suggestedTitle';
        _isFirstMessage = false;
      });
    }

    final messageId = _uuid.v4();
    final messageContent = <Map<String, dynamic>>[];

    // Add text content
    if (textToSend.isNotEmpty) {
      messageContent.add({
        'type': 'text',
        'text': textToSend,
      });
    }

    // Add attachment info for display
    if (_attachments.isNotEmpty) {
      messageContent.add({
        'type': 'text',
        'text': '📎 Uploaded ${_attachments.length} file(s): ${_attachments.map((a) => a.name).join(', ')}',
      });
    }

    final userMessage = Message(
      id: messageId,
      type: 'user',
      content: messageContent,
      timestamp: DateTime.now().toIso8601String(),
      attachments: _attachments.isNotEmpty
          ? _attachments.map((fa) => Attachment.fromFileAttachment(fa)).toList()
          : null,
      fileAttachments: _attachments.isNotEmpty ? List.from(_attachments) : null,
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _attachments.clear();

      // Reset milestone state for new request
      _currentMilestone = null;
      _currentPhase = null;
      _currentProgress = null;
    });

    // Dismiss the keyboard after sending the message
    _messageFocusNode.unfocus();

    // _scrollToBottom();

    // Add processing message
    final processingMessage = Message(
      id: '${messageId}_processing',
      type: 'assistant',
      content: 'Processing your request...',
      timestamp: DateTime.now().toIso8601String(),
      isProcessing: true,
    );

    setState(() {
      _messages.add(processingMessage);
      _isProcessing = true;
      _showLoader = true;
    });

    // _scrollToBottom();

    // Create streaming message placeholder
    final streamingMessage = Message(
      id: '${messageId}_assistant',
      type: 'assistant',
      content: '',
      timestamp: DateTime.now().toIso8601String(),
      isProcessing: true,
    );
    

    // Create streaming controller for real-time content updates
    final streamingController = StreamingMessageRegistry().createController(streamingMessage.id);
    

    try {
      // Prepare files for upload
      final files = <PlatformFile>[];
      for (final fileAttachment in userMessage.fileAttachments ?? []) {
        // Convert FileAttachment to PlatformFile
        final bytes = base64Decode(fileAttachment.base64Data);
        files.add(PlatformFile(
          name: fileAttachment.name,
          size: fileAttachment.size,
          bytes: bytes,
        ));
      }

      // Replace processing message with streaming message
      setState(() {
        _messages.removeWhere((m) => m.id == processingMessage.id);
        _messages.add(streamingMessage);
      });

      String streamingContent = '';
      String? finalConversationId;
      double? finalCost;
      List<ChatSource>? finalSources;
      List<String>? finalFollowUpQuestions;

      // Typing effect variables removed for instant streaming

      // Choose the appropriate streaming endpoint
      final modelToUse = _getModelForCurrentMode();
      final currentMode = _getCurrentModeName();
      // Determine if this is a source grounded conversation
      final isSourceGrounded = _selectedSourceIds.isNotEmpty || _selectedSources.isNotEmpty;
      final sourceIdsToUse = _selectedSourceIds.isNotEmpty
          ? _selectedSourceIds
          : _selectedSources.map((s) => s.id).toList();

      // Debug logging for source grounded requests
              Logger.debug('Quick Action Debug:', tag: 'EditorScreen');
      
      
      
      
      
      
      
      // Debug logging for model selection
      final chatModel = _getChatModeModel();
      final deepsearchModel = _getDeepSearchModeModel();
      
      
      
      
      
      
      
      // Debug current model state
      _debugModelState();

      final stream = isSourceGrounded
          ? _apiService.sourceGroundedChatStream(
              model: modelToUse,
              messages: _messages.where((m) => m.isProcessing != true).toList(),
              selectedSourceIds: sourceIdsToUse,
              enabledTools: _toolsConfig,
              attachments: files,
              textInput: textToSend,
              conversationId: _currentConversationId,
              isDeepSearchMode: _isDeepSearchMode,
              isOfflineMode: _isOfflineMode,
              personality: _selectedPersonality,
              language: _selectedLanguage,
              mode: currentMode,
              chatModel: chatModel,
              deepsearchModel: deepsearchModel,
            )
          : _apiService.streamChat(
              model: modelToUse,
              messages: _messages.where((m) => m.isProcessing != true).toList(),
              enabledTools: _toolsConfig,
              attachments: files,
              textInput: textToSend,
              conversationId: _currentConversationId,
              isDeepSearchMode: _isDeepSearchMode,
              isOfflineMode: _isOfflineMode,
              personality: _selectedPersonality,
              language: _selectedLanguage,
              mode: currentMode,
              chatModel: chatModel,
              deepsearchModel: deepsearchModel,
              isEntitled: context.read<AppAccessProvider>().hasPremiumAccess,
            );

            await for (final event in stream) {
              
        // Handle both Map<String, dynamic> (legacy) and ChatStreamEvent (unified) formats
         
        // Handle unified ChatStreamEvent
        switch (event.type) {
          case StreamEventType.milestone:
            // Handle milestone events
            setState(() { 
              _currentMilestone = event.message;
              _currentPhase = event.metadata?['phase'];
              _currentProgress = event.metadata?['progress']?.toDouble();
            });
            // Only log milestone changes, not every event
            if (_currentPhase != event.metadata?['phase']) {
              
            }
            break;
            
          case StreamEventType.sourcesReady:
            // Handle sources and images ready event - display them immediately
            final sources = event.sources ?? [];
            final images = event.images ?? [];

            // Update the streaming message with sources and images
            final index = _messages.indexWhere((m) => m.id == streamingMessage.id);
            if (index != -1) {
              setState(() {
                _messages[index] = Message(
                  id: streamingMessage.id,
                  type: 'assistant',
                  content: streamingContent,
                  timestamp: streamingMessage.timestamp,
                  isProcessing: true,
                  sources: sources,
                  images: images,
                );
              });
            }
            Logger.debug('📋 Sources ready: ${sources.length} sources, ${images.length} images', tag: 'EditorScreen');
            break;
            
          case StreamEventType.content:
            // Append streaming content
            final newContent = event.content ?? '';

            // Update streaming controller for real-time UI updates FIRST (no setState needed!)
            streamingController.addContent(newContent);
            

            // Hide loader as soon as first content chunk arrives
            if (_showLoader) {
              setState(() {
                _showLoader = false;
              });
            }

            // Trigger vibration AFTER updating UI (non-blocking)
            if (newContent.isNotEmpty) {
              try {
                // Use unawaited to prevent vibration from blocking streaming
                unawaited(onSSETextReceived(newContent));
              } catch (e) {
                // Silently handle vibration errors to prevent crashes
                
              }
            }

            // Check for sentence completion vibration triggers (non-blocking)
            if (newContent.contains('.') || newContent.contains('!') || newContent.contains('?')) {
              try {
                unawaited(onSSESentenceComplete());
              } catch (e) {
                
              }
            }

            // Check for paragraph completion vibration triggers (non-blocking)
            if (newContent.contains('\n\n') || newContent.contains('\n---') || newContent.contains('\n##')) {
              try {
                unawaited(onSSEParagraphComplete());
              } catch (e) {
                
              }
            }
            break;
            
          case StreamEventType.complete:
            // Stop vibration when stream completes
            try {
              stopVibration();
            } catch (e) {
              
            }
            // Finalize the message
            finalConversationId = event.conversationId;
            finalCost = event.metadata?['cost']?.toDouble();

            // Extract cost information
            final messageCost = event.metadata?['messageCost']?.toDouble();
            final sessionCost = event.metadata?['sessionCost']?.toDouble();
            final costBreakdown = event.metadata?['costBreakdown'] as Map<String, dynamic>?;

            finalSources = event.sources;
            finalFollowUpQuestions = event.metadata?['followUpQuestions'] as List<String>?;

            // Extract images from completion event, but preserve existing ones if they exist
            List<Map<String, dynamic>>? finalImages = event.images;

            final index = _messages.indexWhere((m) => m.id == streamingMessage.id);
            if (index != -1) {
              final finalContent = event.message; // Use event.message directly for final content
              // Finalize the streaming controller with the final content
              streamingController.setFinalContent(finalContent ?? ''); // Ensure it's not null

              // Get the current message to preserve existing sources and images
              final currentMessage = _messages[index];
              
              // Preserve sources and images from sources_ready event if they exist
              final preservedSources = currentMessage.sources?.isNotEmpty == true
                  ? currentMessage.sources
                  : finalSources;
              final preservedImages = currentMessage.images?.isNotEmpty == true
                  ? currentMessage.images
                  : finalImages;

              // Create the message object with cost information and final content
              final updatedMessage = Message(
                id: streamingMessage.id,
                type: 'assistant',
                content: finalContent,
                timestamp: streamingMessage.timestamp,
                isProcessing: false,
                sources: preservedSources,
                followUpQuestions: finalFollowUpQuestions,
                images: preservedImages,
                messageCost: messageCost,
                sessionCost: sessionCost,
                costBreakdown: costBreakdown,
              );

              // Update the message in the list
              setState(() {
                _messages[index] = updatedMessage;
                // Clear milestone state when complete
                _currentMilestone = null;
                _currentPhase = null;
                _currentProgress = null;
              });

              // Clean up streaming controller after finalization (optional)
              StreamingMessageRegistry().removeController(streamingMessage.id);

              // No longer fetch additional follow-up questions here.
              // FollowUpQuestionsWidget will handle async loading and skeleton display.

              // Fetch accurate costs using generation IDs (async, like follow-up questions)
              final generationIds = event.metadata?['generationIds'] as List<dynamic>?;
              final sessionId = event.metadata?['sessionId'] as String?;
              if (generationIds != null && generationIds.isNotEmpty) {
                Logger.debug('🔗 Fetching accurate costs for ${generationIds.length} generation IDs', tag: 'EditorScreen');
                final sessionCostService = SessionCostService();
                await sessionCostService.addGenerationIds(
                  generationIds.map((g) => Map<String, dynamic>.from(g)).toList(),
                  sessionId: sessionId ?? finalConversationId,
                );
              }
            }

            // Update costs and LLM info
            setState(() {
              // Don't manually update costs - let SessionCostService handle it
              // The SessionCostService will emit updates through the stream
              // if (finalCost != null) {
              //   _lastOperationCost = finalCost;
              //   _sessionCost += finalCost;
              // }
              
              // Update LLM and model info
              _lastUsedLLM = event.llmUsed;
              _lastUsedModel = event.model;
              _lastToolResults = event.metadata?['toolResults'] as Map<String, dynamic>?;
            });
            break;
            
          case StreamEventType.status:
            print('🐛 DEBUG: EditorScreen received StreamEventType.status: ${event.message}');
            // Check if this is an error status with classification metadata
            if (event.message == 'writing_error' && event.metadata != null && event.metadata!['showModal'] == true) {
              print('🐛 DEBUG: EditorScreen found error classification in status metadata, showing modal');
              
              // Clean up UI state
              setState(() {
                _messages.removeWhere((m) => m.id == streamingMessage.id);
                _isProcessing = false;
                _showLoader = false;
                _currentMilestone = null;
                _currentPhase = null;
                _currentProgress = null;
              });
              StreamingMessageRegistry().removeController(streamingMessage.id);
              
              // Use the classification from AgentSystem
              final errorClassification = {
                'type': event.metadata!['code'],
                'showModal': true,
                'title': 'Model Unavailable',
                'message': 'The selected model is not available. Please choose a different model to continue.',
                'suggestedModels': <String>[], // Don't show suggestions, use switcher instead
              };
              
              _showModelSwitchModal(errorClassification);
              break;
            }
            break;
            
          case StreamEventType.error:
            print('🐛 DEBUG: EditorScreen received StreamEventType.error: ${event.error}');
            
            // Stop vibration on error
            try {
              stopVibration();
            } catch (e) {
              // Handle vibration error silently
            }
            
            // ALWAYS clean up UI state first, regardless of error type
            setState(() {
              _messages.removeWhere((m) => m.id == streamingMessage.id);
              _isProcessing = false;
              _showLoader = false;
              _currentMilestone = null;
              _currentPhase = null;
              _currentProgress = null;
            });
            StreamingMessageRegistry().removeController(streamingMessage.id);
            
            // Classify the error to determine if modal should be shown
            print('🐛 DEBUG: EditorScreen calling _classifyStreamError with: ${event.error}');
            final errorClassification = _classifyStreamError(event.error, _selectedModel);
            print('🐛 DEBUG: EditorScreen _classifyStreamError result: $errorClassification');
            
            if (errorClassification['showModal'] == true) {
              print('🐛 DEBUG: EditorScreen about to show modal for error classification: $errorClassification');
              _showModelSwitchModal(errorClassification);
              break; // Don't rethrow - UI already cleaned up
            } else {
              // Show standard error snackbar
              throw Exception(event.error ?? 'Unknown streaming error');
            }
            break;
          default:
            // Handle any other event types
            
            break;
        }
            }

      setState(() {
        _isProcessing = false;
        _showLoader = false; // Always reset loader on completion
      });

      // Update knowledge graph with new conversation data
      await _updateKnowledgeGraph();

      // _scrollToBottom();
    } catch (e) {
      // Stop vibration on error
      try {
        stopVibration();
      } catch (vibrationError) {
        
      }

      // Clean up streaming controller on error
      StreamingMessageRegistry().removeController(streamingMessage.id);
      

      // Remove streaming message on error (no typing effect) and reset all UI state
      setState(() {
        _messages.removeWhere((m) => m.id == streamingMessage.id);
        _isProcessing = false;
        _showLoader = false; // Ensure loader is hidden
        _currentMilestone = null; // Clear milestone state
        _currentPhase = null; // Clear phase state  
        _currentProgress = null; // Clear progress state
      });

      // Show user-friendly error messages
      if (mounted) {
        String errorMessage;
        String actionMessage = '';
        Color backgroundColor = Theme.of(context).colorScheme.error;
        
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('openrouter api key not configured') || 
            errorString.contains('api key not configured')) {
          errorMessage = 'API key not configured';
          actionMessage = 'Please configure your OpenRouter API key in settings to continue.';
          
          // Show dialog to guide user
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.key_off, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('API Key Required'),
                ],
              ),
              content: const Text(
                'Your OpenRouter API key is not configured. Would you like to set it up now?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/oauth-onboarding'); // Navigate to onboarding
                  },
                  child: const Text('Setup Now'),
                ),
              ],
            ),
          );
        } else if (errorString.contains('rate limit') || errorString.contains('429')) {
          errorMessage = 'Rate limit exceeded';
          actionMessage = 'Please wait a moment before trying again.';
          backgroundColor = Colors.orange;
        } else if (errorString.contains('network') || errorString.contains('connection')) {
          errorMessage = 'Network error';
          actionMessage = 'Please check your internet connection and try again.';
          backgroundColor = Colors.orange;
        } else if (errorString.contains('401') || errorString.contains('unauthorized')) {
          errorMessage = 'Authentication failed';
          actionMessage = 'Your API key may be invalid. Please check your settings.';
        } else if (errorString.contains('insufficient') || errorString.contains('credits')) {
          errorMessage = 'Insufficient credits';
          actionMessage = 'You may have run out of API credits. Please check your OpenRouter account.';
          backgroundColor = Colors.orange;
        } else if (errorString.contains('404') || 
                   errorString.contains('model not found') ||
                   (errorString.contains('not found') && errorString.contains('model'))) {
          errorMessage = 'Model Unavailable';
          actionMessage = 'The selected model is unavailable. Try switching to another model.';
          backgroundColor = Colors.orange;
          
          // Show model switch modal for 404 errors
          if (mounted) {
            _showModelSwitchModal({
              'type': 'model_unavailable',
              'showModal': true,
              'title': 'Model Unavailable',
              'message': 'The selected model is unavailable or not found. Try switching to another model.',
              'suggestedModels': _getSuggestedModelsForError('model_unavailable', _selectedModel),
            });
          }
        } else {
          // Generic error
          errorMessage = 'Something went wrong';
          actionMessage = 'Please try again. If the problem persists, check your settings.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (actionMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    actionMessage,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => _showSettings(),
            ),
          ),
        );
      }
    }
  }

  bool _shouldShowRetryButton(Message userMessage) {
    // Find the index of this user message
    final userIndex = _messages.indexWhere((m) => m.id == userMessage.id);
    if (userIndex == -1) return false;

    // Check if this is the last user message
    final isLastUserMessage = userIndex == _messages.length - 1;

    // If this is the last user message and we're not processing, show retry
    // This handles the case where a request failed completely (no assistant response was created)
    if (isLastUserMessage && !_isProcessing) {
      return true;
    }

    // Check messages after this user message
    final messagesAfterUser = _messages.skip(userIndex + 1).toList();

    // If there are assistant messages after this user message, don't show retry
    // (the assistant response was successful)
    if (messagesAfterUser.any((m) => m.type == 'assistant' && m.isProcessing != true)) {
      return false;
    }

    // If we're currently processing, don't show retry
    if (_isProcessing) {
      return false;
    }

    return false;
  }

  void _showAttachmentOptions() {
    final capabilities = _currentModelCapabilities;
    final List<Widget> options = [];
    
    Logger.debug('📎 Showing attachment options modal', tag: 'EditorScreen');
    Logger.debug('📎 Model capabilities: $capabilities', tag: 'EditorScreen');

    // Add image options if model supports images
    if (capabilities?.supportsImages == true) {
      options.addAll([
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('Choose from Gallery'),
          onTap: () {
            Navigator.pop(context);
            Logger.debug('🖼️ Gallery option selected', tag: 'EditorScreen');
            _pickImage();
          },
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('Take Photo'),
          onTap: () {
            Navigator.pop(context);
            Logger.debug('📷 Camera option selected', tag: 'EditorScreen');
            _takePhoto();
          },
        ),
      ]);
    } else {
      // Show disabled option with warning
      options.add(
        ListTile(
          leading: const Icon(Icons.image, color: Colors.grey),
          title: const Text('Choose from Gallery'),
          subtitle: const Text('Not supported by current model'),
          enabled: false,
          onTap: () {
            Navigator.pop(context);
            _showModelCapabilityWarning('Images');
          },
        ),
      );
      options.add(
        ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.grey),
          title: const Text('Take Photo'),
          subtitle: const Text('Not supported by current model'),
          enabled: false,
          onTap: () {
            Navigator.pop(context);
            _showModelCapabilityWarning('Images');
          },
        ),
      );
    }

    // Add file options - Always show as enabled for now, let the model handle the error
    options.add(
      ListTile(
        leading: const Icon(Icons.picture_as_pdf),
        title: const Text('Choose Document (PDF, DOC, TXT)'),
        subtitle: capabilities?.supportsFiles != true 
            ? const Text('May not be supported by current model')
            : null,
        onTap: () {
          Navigator.pop(context);
          Logger.debug('📄 Document option selected', tag: 'EditorScreen');
          _pickDocument();
        },
      ),
    );

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attach Files',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...options,
            const SizedBox(height: 16),
            Text(
              'Current model: ${_selectedModel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpandedImage(BuildContext context, Map<String, dynamic> image) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final screenSize = MediaQuery.of(context).size;
        final imageUrl = image['url'] ?? image['thumbnail'] ?? '';
        final title = image['title']?.toString() ?? '';
        final description = image['description']?.toString() ?? '';
        final source = image['source']?.toString() ?? image['sourceUrl']?.toString() ?? '';
        
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.95,
              maxHeight: screenSize.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button and actions
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Action buttons
                      Row(
                        children: [
                          // Copy URL button
                          if (imageUrl.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: imageUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Image URL copied to clipboard'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.colorScheme.primary,
                                    ),
                                  );
                                },
                                tooltip: 'Copy Image URL',
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Visit source button
                          if (source.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.open_in_new, color: Colors.white, size: 20),
                                onPressed: () async {
                                  try {
                                    final uri = Uri.parse(source);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Could not open source: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                tooltip: 'Visit Source',
                              ),
                            ),
                        ],
                      ),
                      // Close button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 24),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                ),
                // Main image container
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(20),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 300,
                            height: 300,
                            color: theme.colorScheme.surface,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Image information panel
                if (title.isNotEmpty || description.isNotEmpty || source.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        if (title.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.title,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Title',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Description
                        if (description.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.description,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Description',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Source
                        if (source.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.source,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Source',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              try {
                                final uri = Uri.parse(source);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not open source: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    source,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.open_in_new,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }




  void _showMarkdownImage(BuildContext context, String imageUrl, String? title, String? alt) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final screenSize = MediaQuery.of(context).size;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.95,
              maxHeight: screenSize.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button and actions
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Action buttons
                      Row(
                        children: [
                          // Copy URL button
                          if (imageUrl.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: imageUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Image URL copied to clipboard'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.colorScheme.primary,
                                    ),
                                  );
                                },
                                tooltip: 'Copy URL',
                              ),
                            ),
                        ],
                      ),
                      // Close button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                ),

                // Main image
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(20),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[900],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    alt ?? 'Failed to load image',
                                    style: const TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Image info (title/alt text)
                if ((title != null && title.isNotEmpty) || (alt != null && alt.isNotEmpty))
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null && title.isNotEmpty) ...[
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (alt != null && alt.isNotEmpty && alt != title)
                            const SizedBox(height: 8),
                        ],
                        if (alt != null && alt.isNotEmpty && alt != title)
                          Text(
                            alt,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }



  void _showModelCapabilityWarning(String capabilityType) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.brightness == Brightness.dark 
                  ? AppColors.darkWarning 
                  : AppColors.lightWarning,
            ),
            const SizedBox(width: 8),
            const Text('Model Limitation'),
          ],
        ),
        content: Text(
          'The current model does not support $capabilityType. '
          'To use $capabilityType, please select a different model that supports this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showModelSelection();
            },
            child: const Text('Change Model'),
          ),
        ],
      ),
    );
  }

  void _showModelSelection() {
    // Navigate to model selection screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModelSelectionScreen(
          mode: _currentMode,
          selectedModel: _selectedModel,
          onModelSelected: (modelId) {
            setState(() {
              _selectedModel = modelId;
            });
            // Save the selected model
            _saveSelectedModel(modelId);
            _checkModelCapabilities();
          },
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => UnifiedSettingsModal(
        selectedModel: _selectedModel,
        onModelChanged: (model) {
          // This callback is now handled by the ModeConfigProvider
          // The _onModeConfigChanged will be triggered automatically
        },
      ),
    ).then((_) async {
      // Reload model configs and update current model based on current mode
      await _loadModeConfigs();
      
      // Update the selected model from the current mode's config
      final modeConfigProvider = Provider.of<ModeConfigProvider>(context, listen: false);
      final currentConfig = modeConfigProvider.getConfigForMode(_currentMode);
      if (currentConfig != null && currentConfig.model.isNotEmpty) {
        setState(() {
          _selectedModel = currentConfig.model;
        });
        LLMService().setCurrentModel(_selectedModel);
      }
      
      // Ensure services are still ready after settings close
      _checkServicesReady();
      
      // Reload the API key from storage to ensure it's still available
      await _apiService.initialize();
    });
  }

  void _showWebSearchUpgrade() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final cardWidth = maxWidth > 560 ? 520.0 : maxWidth - 32;

              return Center(
                child: Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Subtle top accent
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withValues(alpha: 0.9),
                                  theme.colorScheme.secondary.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.public,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Unlock Web Search',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Close',
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Web search integration is available in Premium. Get better, up‑to‑date answers with one toggle.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Benefits list
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withValues(alpha: 0.12),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    _BenefitRow(icon: Icons.travel_explore, text: 'Online AI responses (real-time web)'),
                                    _BenefitRow(icon: Icons.public, text: 'Internet globe toggle for live info'),
                                    _BenefitRow(icon: Icons.trending_up, text: 'Access to trending topics'),
                                    _BenefitRow(icon: Icons.picture_as_pdf, text: 'Export to PDF and Markdown'),
                                    _BenefitRow(icon: Icons.color_lens, text: 'Custom themes and UI personalization'),
                                    _BenefitRow(icon: Icons.support_agent, text: 'Priority support'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Pricing pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.price_check, color: theme.colorScheme.primary),
                                    const SizedBox(width: 10),
                                    RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        children: const [
                                          TextSpan(text: 'Only '),
                                          TextSpan(text: '\$7.99', style: TextStyle(fontSize: 18)),
                                          TextSpan(text: '/month', style: TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Maybe Later'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        try {
                                          final ok = await PaywallCoordinator.showNativePurchaseFlow(context);
                                          if (ok) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Premium unlocked')),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Purchase failed: $e')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.upgrade_rounded),
                                      label: const Text('Upgrade Now'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

// Helper: subscribe to session cost updates (restored if missing)
  void _subscribeToSessionCostUpdates() {
    
    _costSubscription = SessionCostService().costUpdates.listen((costData) {
      
      if (mounted) {
        setState(() {
          _sessionCost = costData.sessionCost;
          _lastOperationCost = costData.lastMessageCost;
        });
        
      }
    });
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final attachment = FileAttachment.fromBytes(
          name: image.name,
          bytes: bytes,
          mimeType: image.mimeType ?? 'image/jpeg',
        );

        setState(() {
          _attachments.add(attachment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  // Typing effect methods removed

  Future<void> _updateKnowledgeGraph() async {
    try {
      // Store current conversation using the conversation service
      if (_currentConversationId != null && _messages.isNotEmpty) {
        await ConversationService().saveConversation(
          id: _currentConversationId!,
          title: _title.isNotEmpty ? _title : 'Untitled Conversation',
          messages: _messages,
          metadata: {
            'sessionCost': _sessionCost,
            'selectedModel': _selectedModel,
            'selectedPersonality': _selectedPersonality,
            'selectedLanguage': _selectedLanguage,
          },
        );
      }

      // Trigger knowledge graph refresh by updating a timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('knowledge_graph_last_update', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      
    }
  }

  /// Classify stream errors to determine if modal should be shown
  Map<String, dynamic> _classifyStreamError(String? error, String currentModel) {
    if (error == null) return {'showModal': false};
    
    final errorLower = error.toLowerCase();
    print('🐛 DEBUG: EditorScreen._classifyStreamError processing: $errorLower');
    
    if (errorLower.contains('429') || errorLower.contains('rate limit')) {
      return {
        'type': 'rate_limit',
        'showModal': true,
        'title': 'Rate Limit Reached',
        'message': 'The current model has reached its rate limit. Try switching to a different model to continue.',
        'suggestedModels': _getSuggestedModelsForError('rate_limit', currentModel),
      };
    }
    
    if (errorLower.contains('quota') || errorLower.contains('insufficient')) {
      return {
        'type': 'quota_exceeded',
        'showModal': true,
        'title': 'Usage Quota Exceeded',
        'message': 'You\'ve reached the usage limit for this model. Switch to a free model or upgrade your plan.',
        'suggestedModels': _getSuggestedModelsForError('quota', currentModel),
      };
    }
    
    if (errorLower.contains('401') || errorLower.contains('unauthorized')) {
      return {
        'type': 'unauthorized',
        'showModal': true,
        'title': 'OpenRouter Authorization Error',
        'message': 'We\'ve been receiving unauthorized errors from OpenRouter. Your API key may be expired, revoked, or your credits exhausted. Please reconfigure your OpenRouter account.',
        'suggestedModels': [], // No model suggestions for auth errors
      };
    }
    
    // Model unavailable / invalid endpoint
    if (errorLower.contains('404') ||
        errorLower.contains('model not found') ||
        (errorLower.contains('not found') && errorLower.contains('model'))) {
      print('🐛 DEBUG: EditorScreen._classifyStreamError matched 404 pattern for: $errorLower');
      return {
        'type': 'model_unavailable',
        'showModal': true,
        'title': 'Model Unavailable',
        'message': 'The selected model is unavailable or not found. Try switching to another model.',
        'suggestedModels': _getSuggestedModelsForError('model_unavailable', currentModel),
      };
    }
    
    return {'showModal': false};
  }

  /// Show model switch recommendation modal
  void _showModelSwitchModal(Map<String, dynamic> errorClassification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModelSwitchRecommendationModal(
        errorType: errorClassification['type'],
        title: errorClassification['title'],
        message: errorClassification['message'],
        currentModel: _selectedModel,
        suggestedModels: errorClassification['suggestedModels'] ?? [],
        onModelSelected: (modelId) {
          Navigator.of(context).pop();
          _switchToModel(modelId);
          _retryLastMessage();
        },
        onDismiss: () {
          Navigator.of(context).pop();
        },
        onTryAgain: () {
          Navigator.of(context).pop();
          _retryLastMessage();
        },
      ),
    );
  }

  /// Get suggested models for error types
  List<String> _getSuggestedModelsForError(String errorType, String currentModel) {
    try {
      // Use ModelRegistry to get intelligent suggestions
      switch (errorType) {
        case 'rate_limit':
          return ModelRegistry.getFreeModels().take(3).toList();
        case 'quota':
          return ModelRegistry.getFreeModels().take(3).toList();
        case 'model_unavailable':
          return ModelRegistry.getFreeModels().take(3).toList();
        default:
          return ModelRegistry.getAllModels().take(3).toList();
      }
    } catch (e) {
      // Fallback to default models if registry fails
      return [
        'google/gemini-2.0-flash-exp:free',
        'deepseek/deepseek-r1:free',
        'mistralai/mistral-7b-instruct:free',
      ];
    }
  }

  /// Switch to a different model
  void _switchToModel(String modelId) {
    setState(() {
      _selectedModel = modelId;
    });
    
    // Save the selected model
    _saveSelectedModel(modelId);
    
    // Update mode config provider
    final provider = Provider.of<ModeConfigProvider>(context, listen: false);
    final currentConfig = provider.getConfigForMode(_currentMode);
    if (currentConfig != null) {
      provider.updateConfig(_currentMode, currentConfig.copyWith(model: modelId));
    }
    
    // Update LLM service
    LLMService().setCurrentModel(modelId);
    
    // Check new model capabilities
    _checkModelCapabilities();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${ModelRegistry.formatModelName(modelId)}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// Retry the last user message
  void _retryLastMessage() {
    if (_messages.isNotEmpty) {
      final lastUserMessage = _messages.lastWhere(
        (msg) => msg.type == 'user',
        orElse: () => _messages.last,
      );
      _retryUserMessage(lastUserMessage);
    }
  }

  /// Get model display text for the model selector layer
  String _getModelDisplayText() {
    // Get the actual model name, not the default fallback
    final actualModelName = _selectedModel ?? 'Unknown';

    final displayName = actualModelName.contains('/')
      ? actualModelName.split('/').last.replaceAll(':free', '')
      : actualModelName;
    return 'Model: $displayName';
  }

  /// Get model display text for the model selector layer (syncs with session info)
  String _getModelDisplayTextForSelector() {
    // Use the selected model for immediate feedback, but fall back to last used model
    final actualModelName = _selectedModel ?? _lastUsedModel ?? _getModelForCurrentMode() ?? 'Unknown';

    final displayName = actualModelName.contains('/')
      ? actualModelName.split('/').last.replaceAll(':free', '')
      : actualModelName;
    

    return 'Model: $displayName';
  }

  /// Show model capabilities bottom sheet
  void _showModelCapabilitiesBottomSheet(BuildContext context) async {
    final currentModel = _selectedModel ?? _lastUsedModel ?? _getModelForCurrentMode();
    
    // Fetch the full model data including pricing
    final modelData = await ModelService.getModelData(currentModel);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModelCapabilitiesBottomSheet(
        modelCapabilities: _currentModelCapabilities,
        modelName: currentModel,
        modelData: modelData,
      ),
    );
  }
}

// A compact benefit row used in the premium modal.
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _getModelShortName(String? modelName) {
  if (modelName == null) return 'Model';
  
  // Extract short name from full model name
  final parts = modelName.split('/');
  final lastPart = parts.last;
  
  // Handle common model name patterns
  if (lastPart.contains('mistral')) return 'Mistral';
  if (lastPart.contains('llama')) return 'Llama';
  if (lastPart.contains('gpt')) return 'GPT';
  if (lastPart.contains('claude')) return 'Claude';
  if (lastPart.contains('gemini')) return 'Gemini';
  
  // Fallback: take first word or first 8 characters
  final shortName = lastPart.split('-').first;
  return shortName.length > 8 ? shortName.substring(0, 8) : shortName;
}
