import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/logger.dart';
import '../widgets/cognify_logo.dart';
import '../widgets/unified_settings_modal.dart';
import '../providers/firebase_auth_provider.dart';
import '../widgets/credits_button.dart';

// Modern action button for header
class HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final bool isActive;

  const HeaderActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.tooltip,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IconButton(
      icon: Icon(
        icon,
        color:
            color ??
            (isActive
                ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                : (isDark
                      ? AppColors.darkText
                      : theme.textTheme.titleLarge?.color)),
        size: 20,
      ),
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      tooltip: tooltip,
    );
  }
}

class ModernAppHeader extends StatefulWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final bool showLogo;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;
  final double elevation;
  final bool showNewChatButton;
  final List<PopupMenuEntry<String>>? additionalMenuItems;
  final Function(String)? onMenuItemSelected;
  final VoidCallback? onBuyCredits;

  const ModernAppHeader({
    super.key,
    this.title,
    this.showBackButton = false,
    this.showLogo = true,
    this.actions,
    this.centerTitle = false,
    this.backgroundColor,
    this.elevation = 0,
    this.showNewChatButton = true,
    this.additionalMenuItems,
    this.onMenuItemSelected,
    this.onBuyCredits,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  State<ModernAppHeader> createState() => _ModernAppHeaderState();
}

class _ModernAppHeaderState extends State<ModernAppHeader> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 500;
    final double logoSize = isMobile ? 22 : 28;
    final double logoSizeCentered = isMobile ? 18 : 22;
    final double textSize = isMobile ? 13 : 16;
    final double textSizeCentered = isMobile ? 12 : 15;

    return Container(
      decoration: BoxDecoration(
        // Use scaffold background for seamless integration
        color: widget.backgroundColor ?? theme.scaffoldBackgroundColor,
        boxShadow: widget.elevation > 0
            ? [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: isDark ? 6 : 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: Border(
          bottom: BorderSide(
            // Very subtle border for separation
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.3)
                : Colors.transparent,
            width: isDark ? 0.5 : 0,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: kToolbarHeight + 10,
          padding: EdgeInsets.only(
            left: isMobile ? 14 : 24,
            right: isMobile ? 6 : 14,
            top: isMobile ? 0 : 3,
            bottom: isMobile ? 0 : 3,
          ),
          child: Row(
            children: [
              // Leading section - Drawer and Back Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Navigation drawer button - minimal style
                  Builder(
                    builder: (context) => IconButton(
                      icon: _ModernMenuIcon(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.7),
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: 'Menu',
                    ),
                  ),

                  if (widget.showBackButton) ...[
                    SizedBox(width: isMobile ? 4 : 8),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: isDark
                            ? AppColors.darkText
                            : theme.textTheme.titleLarge?.color,
                        size: 20,
                      ),
                      onPressed: () => _handleBackButton(context),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ],
              ),

              // Centered title
              if (widget.centerTitle) ...[
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showLogo) ...[
                          GestureDetector(
                            onTap: () => GoRouter.of(context).go('/'),
                            child: CognifyLogo(size: logoSizeCentered),
                          ),
                          SizedBox(width: isMobile ? 2 : 6),
                        ],
                        if (widget.title != null)
                          Flexible(
                            child: Text(
                              widget.title!,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: isMobile
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                letterSpacing: isMobile ? -0.1 : -0.3,
                                fontSize: textSizeCentered,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ] else
                const Spacer(),

              // Actions section - Clean and minimal
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // New Chat button (primary action)
                  if (widget.showNewChatButton) ...[
                    IconButton(
                      icon: Icon(
                        Icons.add_comment,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightPrimary,
                        size: 22,
                      ),
                      onPressed: () => GoRouter.of(context).push('/editor'),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: 'New Chat',
                    ),
                    SizedBox(width: isMobile ? 4 : 8),
                  ],

                  // Credits button with balance display
                  CreditsButton(onTap: widget.onBuyCredits, isMobile: isMobile),

                  // Custom actions (deprecated - use menu instead)
                  if (widget.actions != null) ...[
                    SizedBox(width: isMobile ? 6 : 12),
                    ...widget.actions!.map(
                      (action) => Padding(
                        padding: EdgeInsets.only(left: isMobile ? 4 : 8),
                        child: action,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<PopupMenuEntry<String>> items = [
      PopupMenuItem<String>(
        value: 'history',
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkAccent.withValues(alpha: 0.15)
                    : AppColors.lightTextSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.history,
                size: 18,
                color: isDark
                    ? AppColors.darkAccent
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'History',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(height: 16),
      PopupMenuItem<String>(
        value: 'settings',
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkAccent.withValues(alpha: 0.15)
                    : AppColors.lightTextSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.settings,
                size: 18,
                color: isDark
                    ? AppColors.darkAccent
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Settings',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    ];

    // Add additional menu items if provided
    if (widget.additionalMenuItems != null) {
      items.add(const PopupMenuDivider());
      items.addAll(widget.additionalMenuItems!);
    }

    return items;
  }

  void _handleBackButton(BuildContext context) {
    final router = GoRouter.of(context);
    final currentLocation = GoRouterState.of(context).uri.toString();

    Logger.debug(
      '🔙 Header back button pressed. Current location: $currentLocation',
      tag: 'Navigation',
    );
    Logger.debug('🔙 Can pop: ${router.canPop()}', tag: 'Navigation');

    // Check if we can pop the current route
    if (router.canPop()) {
      Logger.debug('🔙 Popping route from header...', tag: 'Navigation');
      router.pop();
    } else {
      // If we can't pop (e.g., we're on the initial route), navigate to home
      Logger.debug('🔙 Cannot pop, navigating to home...', tag: 'Navigation');
      router.go('/');
    }
  }

  void _handleMenuSelection(BuildContext context, String value) {
    final router = GoRouter.of(context);

    switch (value) {
      case 'history':
        router.push('/history');
        break;
      case 'settings':
        // Show settings modal
        _showSettingsModal(context);
        break;
      default:
        // Handle additional menu items
        if (widget.onMenuItemSelected != null) {
          widget.onMenuItemSelected!(value);
        }
        break;
    }
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<FirebaseAuthProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Clean header with logo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Row(
                children: [
                  CognifyLogo(size: 36),
                  const SizedBox(width: 12),
                  Text(
                    'Cognify',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Simple divider
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.15)
                  : AppColors.lightTextSecondary.withValues(alpha: 0.08),
            ),

            const SizedBox(height: 16),

            // Drawer items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // Sign In option for anonymous users
                  if (authProvider.isAnonymous) ...[
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.login,
                      label: 'Sign In',
                      onTap: () {
                        Navigator.pop(context);
                        GoRouter.of(context).push('/sign-in');
                      },
                      isPrimary: true,
                    ),
                    const SizedBox(height: 8),
                    // Divider after sign in
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.15)
                            : AppColors.lightTextSecondary.withValues(
                                alpha: 0.08,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Theme toggle
                  _buildDrawerItem(
                    context: context,
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    label: isDark ? 'Light Mode' : 'Dark Mode',
                    onTap: () {
                      themeProvider.toggleTheme();
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 2),

                  // History
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.history_outlined,
                    label: 'History',
                    onTap: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push('/history');
                    },
                  ),

                  const SizedBox(height: 2),

                  // Settings
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      _showSettingsModal(context);
                    },
                  ),

                  const SizedBox(height: 2),

                  // Help & Support
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpDialog(context);
                    },
                  ),

                  const SizedBox(height: 2),

                  // About
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.info_outline,
                    label: 'About',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                ],
              ),
            ),

            // App version footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Version 1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary.withValues(alpha: 0.4)
                      : AppColors.lightTextSecondary.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isPrimary
          ? (isDark
                ? AppColors.darkAccent.withValues(alpha: 0.1)
                : AppColors.lightPrimary.withValues(alpha: 0.08))
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.lightAccent.withValues(alpha: 0.08),
        highlightColor: AppColors.lightAccent.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isPrimary
                    ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                    : AppColors.lightAccent,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 16,
                    letterSpacing: -0.2,
                    color: isPrimary
                        ? (isDark
                              ? AppColors.darkAccent
                              : AppColors.lightPrimary)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
            ),
            const SizedBox(width: 12),
            Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need assistance? We\'re here to help!',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildHelpOption(
              context,
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'support@cognify.app',
            ),
            const SizedBox(height: 12),
            _buildHelpOption(
              context,
              icon: Icons.description_outlined,
              title: 'Documentation',
              subtitle: 'View user guide',
            ),
            const SizedBox(height: 12),
            _buildHelpOption(
              context,
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Help us improve',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkAccent.withValues(alpha: 0.08)
            : AppColors.lightPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.2)
              : AppColors.lightTextSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
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
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            CognifyLogo(size: 64),
            const SizedBox(height: 16),
            Text(
              'Cognify',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI-Powered Assistant',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Cognify uses advanced AI to help you with creative tasks, problem-solving, and more.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAboutLink(
                  context,
                  icon: Icons.gavel,
                  label: 'Terms',
                  onTap: () {
                    // TODO: Open terms
                  },
                ),
                const SizedBox(width: 24),
                _buildAboutLink(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy',
                  onTap: () {
                    // TODO: Open privacy policy
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutLink(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: UnifiedSettingsModal(
          selectedModel: '', // This will be handled by the modal
          onModelChanged: (_) {}, // This will be handled internally
        ),
      ),
    );
  }
}

// Modern floating action button
class ModernFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final bool mini;

  const ModernFloatingActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.label,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (label != null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkButton : AppColors.lightButton,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: isDark
                ? AppColors.darkButtonText
                : AppColors.lightButtonText,
          ),
          label: Text(
            label!,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkButtonText
                  : AppColors.lightButtonText,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkButton : AppColors.lightButton,
        borderRadius: BorderRadius.circular(mini ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        mini: mini,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mini ? 12 : 16),
        ),
        child: Icon(
          icon,
          color: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
        ),
      ),
    );
  }
}

// Modern 2-line minimalistic menu icon
class _ModernMenuIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _ModernMenuIcon({required this.color, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
