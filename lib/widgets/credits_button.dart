import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/credits_provider.dart';

/// Elegant credits button that displays balance and allows purchasing
class CreditsButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isMobile;

  const CreditsButton({super.key, this.onTap, this.isMobile = false});

  @override
  State<CreditsButton> createState() => _CreditsButtonState();
}

class _CreditsButtonState extends State<CreditsButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updatePulseAnimation(double balance) {
    // Pulse animation only when credits are very low (under 5)
    if (balance < 5 && balance > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<CreditsProvider>(
      builder: (context, creditsProvider, child) {
        final balance = creditsProvider.balance;
        final isLoading = creditsProvider.isLoading;
        final isConnected = creditsProvider.isConnected;
        final isFallback = creditsProvider.isFallback;
        final precision = creditsProvider.precision;

        // Update pulse animation based on balance
        _updatePulseAnimation(balance);

        // Determine status text
        String? statusSuffix;
        if (isFallback) {
          statusSuffix = 'cached';
        } else if (!isConnected) {
          statusSuffix = 'offline';
        }

        // Format credits text
        String creditsText = balance.toStringAsFixed(precision);

        // Determine color scheme - proper secondary button styling
        Color backgroundColor;
        Color textColor;
        Color borderColor;

        if (!isConnected) {
          // Gray for disconnected
          backgroundColor = isDark
              ? Colors.grey.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.15);
          textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
          borderColor = isDark
              ? Colors.grey.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.25);
        } else if (balance <= 0) {
          // Subtle red for no credits
          backgroundColor = Colors.red.withValues(alpha: 0.15);
          textColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
          borderColor = Colors.red.withValues(alpha: 0.3);
        } else if (balance < 10) {
          // Subtle orange for low credits
          backgroundColor = Colors.orange.withValues(alpha: 0.15);
          textColor = isDark ? Colors.orange.shade300 : Colors.orange.shade700;
          borderColor = Colors.orange.withValues(alpha: 0.3);
        } else {
          // Secondary button style - subtle but visible
          backgroundColor = isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06);
          textColor = isDark
              ? Colors.white.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.8);
          borderColor = isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.1);
        }

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: balance < 5 && balance > 0 ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  widget.onTap ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchases are currently unavailable'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
              borderRadius: BorderRadius.circular(10),
              splashColor: textColor.withValues(alpha: 0.12),
              highlightColor: textColor.withValues(alpha: 0.06),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 10 : 12,
                  vertical: widget.isMobile ? 6 : 7,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Plus icon
                    Icon(
                      Icons.add_circle_outline,
                      size: widget.isMobile ? 14 : 15,
                      color: textColor,
                    ),
                    SizedBox(width: widget.isMobile ? 6 : 7),

                    // Credits label
                    Text(
                      'Credits',
                      style: TextStyle(
                        color: textColor,
                        fontSize: widget.isMobile ? 12 : 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),

                    SizedBox(width: widget.isMobile ? 6 : 8),

                    // Credit balance - show cached value with optional loading indicator
                    if (isLoading && balance == 0)
                      // Only show spinner if we have no data at all
                      SizedBox(
                        width: widget.isMobile ? 12 : 13,
                        height: widget.isMobile ? 12 : 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$creditsText×',
                            style: TextStyle(
                              color: textColor,
                              fontSize: widget.isMobile ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          // Subtle refresh indicator when loading with cached data
                          if (isLoading && balance > 0) ...[
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  textColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
