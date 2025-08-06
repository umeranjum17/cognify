import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/logger.dart';
import '../widgets/cognify_logo.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.2) : AppColors.lightPrimary.withValues(alpha: 0.1))
            : (isDark ? AppColors.darkCard.withValues(alpha: 0.8) : AppColors.lightCard.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.4) : AppColors.lightPrimary.withValues(alpha: 0.3))
              : (isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : AppColors.lightBorder.withValues(alpha: 0.2)),
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: color ?? (isActive 
              ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
              : theme.textTheme.titleLarge?.color),
          size: 20,
        ),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        tooltip: tooltip,
      ),
    );
  }
}

class ModernAppHeader extends StatelessWidget implements PreferredSizeWidget {
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
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

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
        color: backgroundColor ?? theme.scaffoldBackgroundColor,
        boxShadow: elevation > 0 ? [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ] : null,
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
              // Leading section
              if (showBackButton) ...[
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard.withValues(alpha: 0.8)
                        : AppColors.lightCard.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder.withValues(alpha: 0.3)
                          : AppColors.lightBorder.withValues(alpha: 0.2),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: theme.textTheme.titleLarge?.color,
                      size: 20,
                    ),
                    onPressed: () => _handleBackButton(context),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 16),
              ],

              // Logo and title section
              if (showLogo && !centerTitle) ...[
                GestureDetector(
                  onTap: () => GoRouter.of(context).go('/'),
                  child: CognifyLogo(
                    size: isMobile ? 36 : 44,
                    variant: 'robot',
                  ),
                ),
              ],

              // Centered title
              if (centerTitle) ...[
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showLogo) ...[
                          GestureDetector(
                            onTap: () => GoRouter.of(context).go('/'),
                            child: CognifyLogo(
                              size: logoSizeCentered,
                              variant: 'robot',
                            ),
                          ),
                          SizedBox(width: isMobile ? 2 : 6),
                        ],
                        if (title != null)
                          Flexible(
                            child: Text(
                              title!,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: isMobile ? FontWeight.w500 : FontWeight.w600,
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

              // Actions section
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Theme toggle with modern styling
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard.withValues(alpha: 0.8)
                          : AppColors.lightCard.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.3)
                            : AppColors.lightBorder.withValues(alpha: 0.2),
                      ),
                    ),
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          key: ValueKey(isDark),
                          color: isDark
                              ? AppColors.darkAccentQuaternary
                              : AppColors.lightAccentQuaternary,
                          size: 20,
                        ),
                      ),
                      onPressed: () => themeProvider.toggleTheme(),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),

                  // New Chat button (always visible)
                  if (showNewChatButton) ...[
                    SizedBox(width: isMobile ? 6 : 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard.withValues(alpha: 0.8)
                            : AppColors.lightCard.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.3)
                              : AppColors.lightBorder.withValues(alpha: 0.2),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.add_comment,
                          color: theme.textTheme.titleLarge?.color,
                          size: 20,
                        ),
                        onPressed: () => GoRouter.of(context).push('/editor'),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        tooltip: 'New Chat',
                      ),
                    ),
                  ],

                  // Unified navigation menu
                  SizedBox(width: isMobile ? 6 : 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard.withValues(alpha: 0.8)
                          : AppColors.lightCard.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.3)
                            : AppColors.lightBorder.withValues(alpha: 0.2),
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.textTheme.titleLarge?.color,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      onSelected: (value) => _handleMenuSelection(context, value),
                      itemBuilder: (context) => _buildMenuItems(context),
                    ),
                  ),

                  // Custom actions (deprecated - use menu instead)
                  if (actions != null) ...[
                    SizedBox(width: isMobile ? 6 : 12),
                    ...actions!.map((action) => Padding(
                      padding: EdgeInsets.only(left: isMobile ? 4 : 8),
                      child: action,
                    )),
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
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 12),
            Text(
              'History',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'sources',
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 20,
              color: theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 12),
            Text(
              'Sources',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),

      // PopupMenuItem<String>(

      //   value: 'trending',
      //   child: Row(
      //     children: [
      //       Icon(
      //         Icons.trending_up,
      //         size: 20,
      //         color: theme.textTheme.bodyMedium?.color,
      //       ),
      //       const SizedBox(width: 12),
      //       Text(
      //         'Trending Topics',
      //         style: theme.textTheme.bodyMedium,
      //       ),
      //       const SizedBox(width: 8),
      //       Container(
      //         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      //         decoration: BoxDecoration(
      //           color: Colors.amber.withValues(alpha: 0.2),
      //           borderRadius: BorderRadius.circular(4),
      //         ),
      //         child: Text(
      //           'PRO',
      //           style: TextStyle(
      //             fontSize: 10,
      //             fontWeight: FontWeight.bold,
      //             color: Colors.amber.shade700,
      //           ),
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
    
    
    
    ];

    // Add additional menu items if provided
    if (additionalMenuItems != null) {
      items.add(const PopupMenuDivider());
      items.addAll(additionalMenuItems!);
    }

    return items;
  }

  void _handleBackButton(BuildContext context) {
    final router = GoRouter.of(context);
    final currentLocation = GoRouterState.of(context).uri.toString();

    Logger.debug('🔙 Header back button pressed. Current location: $currentLocation', tag: 'Navigation');
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
      case 'sources':
        router.push('/sources');
        break;
      case 'trending':
        // Navigate to trending topics screen (which has built-in premium gating)
        router.push('/trending-topics');
        break;
      default:
        // Handle additional menu items
        if (onMenuItemSelected != null) {
          onMenuItemSelected!(value);
        }
        break;
    }
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
            color: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
          ),
          label: Text(
            label!,
            style: TextStyle(
              color: isDark ? AppColors.darkButtonText : AppColors.lightButtonText,
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
