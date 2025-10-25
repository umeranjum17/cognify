import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/tab_provider.dart';
import '../providers/firebase_auth_provider.dart';
import '../providers/usage_quota_provider.dart';
import '../providers/credits_purchase_provider.dart';
import '../theme/theme_provider.dart';
import '../widgets/cognify_logo.dart';
import '../widgets/editor_tab_bar.dart';
import '../widgets/unified_settings_modal.dart';
import '../widgets/modern_app_header.dart';
import '../widgets/quick_credit_purchase_sheet.dart';
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

  void _showQuickCreditPurchase() {
    final subs = Provider.of<CreditsPurchaseProvider>(context, listen: false);
    final auth = Provider.of<FirebaseAuthProvider>(context, listen: false);
    final quotaProvider = Provider.of<UsageQuotaProvider>(
      context,
      listen: false,
    );
    final remaining = quotaProvider.quota?.remaining ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (ctx) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CreditsPurchaseProvider>.value(value: subs),
          ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
        ],
        child: QuickCreditPurchaseSheet(currentCredits: remaining),
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Drawer(
      backgroundColor: isDark
          ? const Color(0xFF0F0F0F)
          : const Color(0xFFFFFFFF),
      child: SafeArea(
        child: Column(
          children: [
            // Minimal header with theme toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Row(
                children: [
                  // Simple logo
                  SizedBox(width: 40, height: 40, child: CognifyLogo(size: 40)),
                  const SizedBox(width: 12),
                  // App name
                  Expanded(
                    child: Text(
                      'Cognify',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  // Theme toggle switch
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.light_mode_outlined,
                            size: 18,
                            color: !isDark
                                ? Colors.black87
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                          onPressed: () {
                            if (isDark) {
                              themeProvider.toggleTheme();
                            }
                          },
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.dark_mode_outlined,
                            size: 18,
                            color: isDark
                                ? Colors.white
                                : Colors.black.withValues(alpha: 0.3),
                          ),
                          onPressed: () {
                            if (!isDark) {
                              themeProvider.toggleTheme();
                            }
                          },
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),

            // Drawer items - clean and simple
            Expanded(
              child: Consumer<FirebaseAuthProvider>(
                builder: (context, authProvider, _) {
                  final isAnonymous = authProvider.isAnonymous;

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Sign In - only for anonymous users
                      if (isAnonymous) ...[
                        _buildMinimalDrawerItem(
                          context: context,
                          icon: Icons.login,
                          title: 'Sign In',
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/sign-in');
                          },
                        ),
                        const SizedBox(height: 4),
                      ],

                      // History
                      _buildMinimalDrawerItem(
                        context: context,
                        icon: Icons.history_outlined,
                        title: 'History',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/history');
                        },
                      ),

                      const SizedBox(height: 4),

                      // Settings
                      _buildMinimalDrawerItem(
                        context: context,
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          _showSettings();
                        },
                      ),

                      const SizedBox(height: 4),

                      // Help & Support
                      _buildMinimalDrawerItem(
                        context: context,
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/feedback');
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Minimal footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.7),
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    print('🔍 [TabbedEditorScreen] Building with showBuyCreditsButton: true');
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildNavigationDrawer(context),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        toolbarHeight: 0, // Hide the default app bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 10),
          child: SizedBox(
            height: kToolbarHeight + 10,
            child: ModernAppHeader(
              showBackButton: false,
              showLogo: true,
              centerTitle: false,
              title: _buildHeaderTitle(),
              showNewChatButton:
                  false, // Hide new chat button in tabbed interface
              onBuyCredits: _showQuickCreditPurchase,
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
            return const Center(child: CircularProgressIndicator());
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
