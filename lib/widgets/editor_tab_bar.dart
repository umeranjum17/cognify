import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/editor_tab.dart';
import '../providers/tab_provider.dart';
import '../theme/app_theme.dart';

class EditorTabBar extends StatelessWidget {
  const EditorTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TabProvider>(
      builder: (context, tabProvider, _) {
        final tabs = tabProvider.tabs;
        
        if (tabs.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 48,
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 900),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // Tabs always start from the left and scroll if needed
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(tabs.length, (index) => _TabItem(
                          tab: tabs[index],
                          index: index,
                          isActive: index == tabProvider.activeTabIndex,
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NewTabButton(tabCount: tabs.length),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabItem extends StatefulWidget {
  final EditorTab tab;
  final int index;
  final bool isActive;

  const _TabItem({
    required this.tab,
    required this.index,
    required this.isActive,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabProvider = Provider.of<TabProvider>(context, listen: false);
    final bool isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: (widget.isActive || _isHovered) ? 1.0 : 0.985,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            boxShadow: (widget.isActive || _isHovered)
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: widget.isActive
                ? (isDark
                    ? AppColors.darkTextSecondary.withOpacity(0.12)
                    : AppColors.lightTextSecondary.withOpacity(0.10))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            elevation: 0,
            shadowColor: Colors.transparent,
            child: Stack(
              children: [
                // Tab content
                InkWell(
                  onTap: () => tabProvider.switchToTab(widget.index),
                  borderRadius: BorderRadius.circular(12),
                  splashColor: theme.colorScheme.primary.withOpacity(0.08),
                  highlightColor: theme.colorScheme.primary.withOpacity(0.04),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isActive
                            ? (isDark
                                ? AppColors.darkDivider.withOpacity(0.25)
                                : AppColors.lightDivider.withOpacity(0.25))
                            : (isDark
                                ? AppColors.darkDivider.withOpacity(0.35)
                                : AppColors.lightDivider.withOpacity(0.35)),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 140),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (widget.tab.hasUnsavedChanges)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 160),
                            style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                              color: widget.isActive
                                  ? (isDark ? AppColors.darkText : AppColors.lightText)
                                  : (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted),
                              fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 12,
                              letterSpacing: -0.1,
                            ),
                            child: Text(
                              widget.tab.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            onTap: () => tabProvider.closeTab(widget.index),
                            borderRadius: BorderRadius.circular(9),
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: widget.isActive
                                  ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
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
        ),
      ),
    );
  }
}

class _NewTabButton extends StatelessWidget {
  final int tabCount;
  
  const _NewTabButton({required this.tabCount});

  @override
  Widget build(BuildContext context) {
    return Consumer<TabProvider>(
      builder: (context, tabProvider, _) {
        // Hide the button if we already have 3 tabs
        if (tabCount >= 3) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        
        // Dynamic sizing only; icon style remains consistent
        final bool showCompact = tabCount >= 2;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: showCompact ? 4 : 6),
          child: Material(
            color: theme.cardColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(showCompact ? 8 : 10),
            elevation: 0,
            child: InkWell(
              onTap: () => tabProvider.createNewTab(),
              borderRadius: BorderRadius.circular(showCompact ? 8 : 10),
              splashColor: theme.colorScheme.primary.withOpacity(0.08),
              highlightColor: theme.colorScheme.primary.withOpacity(0.04),
              child: Container(
                padding: EdgeInsets.all(showCompact ? 6 : 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(showCompact ? 8 : 10),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.25),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: showCompact ? 16 : 18,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
