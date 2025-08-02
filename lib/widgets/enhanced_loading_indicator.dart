import 'dart:math';

import 'package:flutter/material.dart';

class EnhancedLoadingIndicator extends StatefulWidget {
  final String? currentMilestone;
  final double? progress;
  final String? phase;

  const EnhancedLoadingIndicator({
    super.key,
    this.currentMilestone,
    this.progress,
    this.phase,
  });

  @override
  State<EnhancedLoadingIndicator> createState() => _EnhancedLoadingIndicatorState();
}

// Custom painter for morphing shapes
class MorphingShapePainter extends CustomPainter {
  final double progress;
  final Color color;

  MorphingShapePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 4;

    // Create a morphing shape that transitions between circle and square
    final path = Path();
    final angles = List.generate(8, (index) => index * 2 * pi / 8);
    
    for (int i = 0; i < angles.length; i++) {
      final angle = angles[i] + (progress * 2 * pi / 4);
      final morphFactor = sin(progress * 4 * pi + i * pi / 4) * 0.3 + 0.7;
      final r = radius * morphFactor;
      
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MorphingShapePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// Custom painter for wave ripples
class WaveRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  WaveRipplePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw multiple ripple rings
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.3) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.5;
      
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _EnhancedLoadingIndicatorState extends State<EnhancedLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _waveAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;
    final tertiaryColor = theme.colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact animated loading area
          SizedBox(
            width: 32,
            height: 32,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _rotationController,
                _pulseController,
                _particleController,
                _waveController,
              ]),
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Wave ripple background
                    CustomPaint(
                      size: const Size(40, 40),
                      painter: WaveRipplePainter(
                        progress: _waveAnimation.value,
                        color: primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    
                    // Floating particles
                    ...List.generate(6, (index) {
                      final angle = (index * 2 * pi / 6) + (_particleAnimation.value * 2 * pi);
                      final radius = 12 + (3 * sin(_particleAnimation.value * 2 * pi));
                      final x = radius * cos(angle);
                      final y = radius * sin(angle);
                      
                      return Transform.translate(
                        offset: Offset(x, y),
                        child: Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: secondaryColor.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                    
                    // Central morphing shape
                    Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationController.value * 2 * pi,
                        child: CustomPaint(
                          size: const Size(16, 16),
                          painter: MorphingShapePainter(
                            progress: _rotationController.value,
                            color: _getPhaseColor(widget.currentMilestone, isDark),
                          ),
                        ),
                      ),
                    ),
                    
                    // Progress indicator ring
                    if (widget.progress != null)
                      Transform.rotate(
                        angle: -pi / 2,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: widget.progress,
                            strokeWidth: 1.5,
                            backgroundColor: primaryColor.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(tertiaryColor),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Text content - prioritize currentMilestone over phase
          Flexible(
            child: Text(
              widget.currentMilestone ?? widget.phase ?? 'Loading...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.linear,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _particleController.repeat();
    _waveController.repeat();
  }

  Color _getPhaseColor(String? text, bool isDark) {
    if (text == null) {
      return Theme.of(context).colorScheme.primary;
    }
    
    final textLower = text.toLowerCase();
    final theme = Theme.of(context);
    
    if (textLower.contains('initializing') || textLower.contains('awakening') || textLower.contains('booting')) {
      return theme.colorScheme.secondary;
    } else if (textLower.contains('gathering') || textLower.contains('collecting') || textLower.contains('scanning')) {
      return theme.colorScheme.tertiary;
    } else if (textLower.contains('generating') || textLower.contains('formulating') || textLower.contains('crafting')) {
      return theme.colorScheme.primary;
    } else if (textLower.contains('finalizing') || textLower.contains('polishing') || textLower.contains('completing')) {
      return theme.colorScheme.secondary;
    } else if (textLower.contains('thinking') || textLower.contains('analyzing')) {
      return theme.colorScheme.tertiary;
    } else if (textLower.contains('processing') || textLower.contains('computing')) {
      return theme.colorScheme.primary;
    }
    
    // Default to theme primary color
    return theme.colorScheme.primary;
  }
}