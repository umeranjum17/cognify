import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ButtonSize {
  small,
  medium,
  large,
}

enum ButtonVariant {
  primary,
  secondary,
  accent,
  gradient,
  outline,
  ghost,
}

class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool iconRight;
  final bool loading;
  final bool fullWidth;
  final double? borderRadius;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.loading = false,
    this.fullWidth = false,
    this.borderRadius,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.loading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: isEnabled ? _onTapDown : null,
            onTapUp: isEnabled ? _onTapUp : null,
            onTapCancel: isEnabled ? _onTapCancel : null,
            onTap: isEnabled ? widget.onPressed : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.fullWidth ? double.infinity : null,
              height: _getButtonHeight(),
              decoration: _getButtonDecoration(isDark, isEnabled),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.borderRadius ?? _getBorderRadius()),
                  onTap: isEnabled ? widget.onPressed : null,
                  child: Container(
                    padding: _getButtonPadding(),
                    child: Row(
                      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.loading)
                          SizedBox(
                            width: _getIconSize(),
                            height: _getIconSize(),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getTextColor(isDark, isEnabled),
                              ),
                            ),
                          )
                        else if (widget.icon != null && !widget.iconRight) ...[
                          Icon(
                            widget.icon,
                            size: _getIconSize(),
                            color: _getTextColor(isDark, isEnabled),
                          ),
                          SizedBox(width: _getIconSpacing()),
                        ],
                        
                        if (!widget.loading)
                          Text(
                            widget.text,
                            style: _getTextStyle(theme, isDark, isEnabled),
                          ),
                        
                        if (widget.icon != null && widget.iconRight && !widget.loading) ...[
                          SizedBox(width: _getIconSpacing()),
                          Icon(
                            widget.icon,
                            size: _getIconSize(),
                            color: _getTextColor(isDark, isEnabled),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case ButtonSize.small:
        return 10;
      case ButtonSize.medium:
        return 12;
      case ButtonSize.large:
        return 14;
    }
  }

  BoxDecoration _getButtonDecoration(bool isDark, bool isEnabled) {
    final opacity = isEnabled ? 1.0 : 0.5;

    switch (widget.variant) {
      case ButtonVariant.primary:
        return BoxDecoration(
          color: isEnabled
              ? (isDark ? AppColors.darkButton : AppColors.lightButton)
              : (isDark
                  ? AppColors.darkButton.withValues(alpha: 0.5)
                  : AppColors.lightButton.withValues(alpha: 0.5)),
          borderRadius:
              BorderRadius.circular(widget.borderRadius ?? _getBorderRadius()),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        .withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        .withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        );

      case ButtonVariant.gradient:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.darkGradientStart.withValues(alpha: opacity),
                    AppColors.darkGradientEnd.withValues(alpha: opacity),
                  ]
                : [
                    AppColors.lightGradientStart.withValues(alpha: opacity),
                    AppColors.lightGradientEnd.withValues(alpha: opacity),
                  ],
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius ?? _getBorderRadius()),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  .withValues(alpha: 0.3),
              blurRadius: _isPressed ? 8 : 15,
              offset: Offset(0, _isPressed ? 3 : 6),
            ),
          ] : null,
        );

      case ButtonVariant.secondary:
        return BoxDecoration(
          color: isEnabled
              ? (isDark
                  ? AppColors.darkButtonSecondary
                  : AppColors.lightButtonSecondary)
              : (isDark
                  ? AppColors.darkButtonSecondary.withValues(alpha: 0.5)
                  : AppColors.lightButtonSecondary.withValues(alpha: 0.5)),
          borderRadius:
              BorderRadius.circular(widget.borderRadius ?? _getBorderRadius()),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.5,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        );

      case ButtonVariant.accent:
        return BoxDecoration(
          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
              .withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(widget.borderRadius ?? _getBorderRadius()),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                  .withValues(alpha: 0.3),
              blurRadius: _isPressed ? 8 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ] : null,
        );

      case ButtonVariant.outline:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius ?? _getBorderRadius()),
          border: Border.all(
            color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                .withValues(alpha: opacity),
            width: 2,
          ),
        );

      case ButtonVariant.ghost:
        return BoxDecoration(
          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
              .withValues(alpha: 0.1 * opacity),
          borderRadius: BorderRadius.circular(widget.borderRadius ?? _getBorderRadius()),
        );
    }
  }

  double _getButtonHeight() {
    switch (widget.size) {
      case ButtonSize.small:
        return 40;
      case ButtonSize.medium:
        return 48;
      case ButtonSize.large:
        return 56;
    }
  }

  EdgeInsets _getButtonPadding() {
    switch (widget.size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 14;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 18;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 20;
    }
  }

  double _getIconSpacing() {
    switch (widget.size) {
      case ButtonSize.small:
        return 6;
      case ButtonSize.medium:
        return 8;
      case ButtonSize.large:
        return 10;
    }
  }

  Color _getTextColor(bool isDark, bool isEnabled) {
    final opacity = isEnabled ? 1.0 : 0.5;

    switch (widget.variant) {
      case ButtonVariant.primary:
      case ButtonVariant.gradient:
      case ButtonVariant.accent:
        return (isDark ? AppColors.darkButtonText : AppColors.lightButtonText)
            .withValues(alpha: opacity);

      case ButtonVariant.secondary:
        return (isDark ? AppColors.darkButtonTextSecondary : AppColors.lightButtonTextSecondary)
            .withValues(alpha: opacity);

      case ButtonVariant.outline:
      case ButtonVariant.ghost:
        return (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
            .withValues(alpha: opacity);
    }
  }

  TextStyle _getTextStyle(ThemeData theme, bool isDark, bool isEnabled) {
    final baseStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ) ?? const TextStyle();

    return baseStyle.copyWith(
      color: _getTextColor(isDark, isEnabled),
      fontSize: _getFontSize(),
    );
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }
}
