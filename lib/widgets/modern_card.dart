import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CardVariant {
  primary,
  secondary,
  accent,
  gradient,
  minimal,
}

class ModernCard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool showShadow;
  final double borderRadius;

  const ModernCard({
    super.key,
    required this.child,
    this.variant = CardVariant.primary,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.showShadow = true,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: _getDecoration(isDark),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(bool isDark) {
    switch (variant) {
      case CardVariant.primary:
        return BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark 
                ? AppColors.darkBorder.withValues(alpha: 0.3)
                : AppColors.lightBorder.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: showShadow ? [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ] : null,
        );

      case CardVariant.secondary:
        return BoxDecoration(
          color: isDark 
              ? AppColors.darkAccentSecondary.withValues(alpha: 0.1)
              : AppColors.lightAccentSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark 
                ? AppColors.darkAccentSecondary.withValues(alpha: 0.3)
                : AppColors.lightAccentSecondary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: showShadow ? [
            BoxShadow(
              color: (isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary)
                  .withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 3),
            ),
          ] : null,
        );

      case CardVariant.accent:
        return BoxDecoration(
          color: isDark 
              ? AppColors.darkAccent.withValues(alpha: 0.1)
              : AppColors.lightAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark 
                ? AppColors.darkAccent.withValues(alpha: 0.4)
                : AppColors.lightAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: showShadow ? [
            BoxShadow(
              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                  .withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ] : null,
        );

      case CardVariant.gradient:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.darkGradientStart.withValues(alpha: 0.8),
                    AppColors.darkGradientEnd.withValues(alpha: 0.8),
                  ]
                : [
                    AppColors.lightGradientStart.withValues(alpha: 0.9),
                    AppColors.lightGradientEnd.withValues(alpha: 0.9),
                  ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: showShadow ? [
            BoxShadow(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  .withValues(alpha: 0.3),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ] : null,
        );

      case CardVariant.minimal:
        return BoxDecoration(
          color: isDark 
              ? AppColors.darkBackgroundAlt
              : AppColors.lightBackgroundAlt,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark 
                ? AppColors.darkBorder.withValues(alpha: 0.2)
                : AppColors.lightBorder.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: showShadow ? [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ] : null,
        );
    }
  }
}

// Enhanced conversation card with modern styling
class ConversationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? timestamp;
  final VoidCallback? onTap;
  final List<String>? tags;
  final IconData? icon;

  const ConversationCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.timestamp,
    this.onTap,
    this.tags,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ModernCard(
      variant: CardVariant.primary,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppColors.darkPrimary.withValues(alpha: 0.2)
                        : AppColors.lightPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              letterSpacing: -0.1,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (tags != null && tags!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags!.take(3).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark 
                      ? AppColors.darkAccentSecondary.withValues(alpha: 0.2)
                      : AppColors.lightAccentSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark 
                        ? AppColors.darkAccentSecondary.withValues(alpha: 0.3)
                        : AppColors.lightAccentSecondary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              )).toList(),
            ),
          ],
          if (timestamp != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timestamp!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
