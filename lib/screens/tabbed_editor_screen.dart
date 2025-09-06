import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tab_provider.dart';
import '../widgets/editor_tab_bar.dart';
import '../widgets/unified_settings_modal.dart';
import '../widgets/modern_app_header.dart';
import 'editor_screen.dart';

class TabbedEditorScreen extends StatefulWidget {
  final String? conversationId;
  final String? prompt;
  final String? role;
  final String? contextInfo;

  const TabbedEditorScreen({
    super.key,
    this.conversationId,
    this.prompt,
    this.role,
    this.contextInfo,
  });

  @override
  State<TabbedEditorScreen> createState() => _TabbedEditorScreenState();
}

class _TabbedEditorScreenState extends State<TabbedEditorScreen> {
  final Map<String, Widget> _editorWidgets = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tabProvider = Provider.of<TabProvider>(context, listen: false);
      
      if (widget.conversationId != null) {
        await tabProvider.loadConversationInTab(widget.conversationId!);
      } else {
        await tabProvider.initializeWithFirstTab();
      }
    });
  }

  Widget _getEditorForTab(String tabId) {
    if (!_editorWidgets.containsKey(tabId)) {
      final tabProvider = Provider.of<TabProvider>(context, listen: false);
      final tab = tabProvider.tabs.firstWhere((t) => t.id == tabId);
      
      _editorWidgets[tabId] = EditorScreen(
        conversationId: tab.conversation?.id,
        prompt: widget.prompt,
        role: widget.role,
        contextInfo: widget.contextInfo,
        showAppBar: false,
        key: ValueKey(tabId),
      );
    }
    return _editorWidgets[tabId]!;
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => UnifiedSettingsModal(
        selectedModel: 'mistralai/mistral-small-3.2-24b-instruct:free',
        onModelChanged: (model) {
          // This callback is now handled by the ModeConfigProvider
          // The _onModeConfigChanged will be triggered automatically
        },
      ),
    );
  }

  String _buildHeaderTitle() {
    final tabProvider = Provider.of<TabProvider>(context, listen: false);
    if (tabProvider.isEmpty) return 'Chat';
    
    final activeTab = tabProvider.activeTab;
    if (activeTab?.conversation?.title?.isNotEmpty == true) {
      return activeTab!.conversation!.title!;
    }
    
    return 'Tab ${tabProvider.activeTabIndex + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        toolbarHeight: 0, // Hide the default app bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56), // Reduced height since no tabs
          child: SizedBox(
            height: 56, // Standard AppBar height
            child: ModernAppHeader(
              showBackButton: false,
              showLogo: true,
              centerTitle: false,
              title: _buildHeaderTitle(),
              showNewChatButton: false, // Hide new chat button in tabbed interface
              onMenuItemSelected: (value) {
                if (value == 'settings') {
                  _showSettings();
                }
              },
            ),
          ),
        ),
      ),
      body: Consumer<TabProvider>(
        builder: (context, tabProvider, _) {
          if (tabProvider.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            children: [
              // Tab bar positioned below header, will be below session cost widget
              const EditorTabBar(),
              // Editor content
              Expanded(
                child: IndexedStack(
                  index: tabProvider.activeTabIndex,
                  children: tabProvider.tabs.map((tab) {
                    return _getEditorForTab(tab.id);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _editorWidgets.clear();
    super.dispose();
  }
}
