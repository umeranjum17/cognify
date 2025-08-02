import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CognifyLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;
  final String variant;

  const CognifyLogo({
    super.key,
    this.size = 32,
    this.showText = false,
    this.color,
    this.variant = 'robot', // 'default', 'minimal', 'gradient', 'robot'
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (showText) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(context, isDark),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cognify',
                style: TextStyle(
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.titleLarge?.color,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                'AI Analysis',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodySmall?.color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return _buildIcon(context, isDark);
  }

  Widget _buildIcon(BuildContext context, bool isDark) {
    switch (variant) {
      case 'minimal':
        return _buildMinimalIcon(context, isDark);
      case 'gradient':
        return _buildGradientIcon(context, isDark);
      case 'robot':
        return _buildRobotIcon(context, isDark);
      case 'default':
        return _buildDefaultIcon(context, isDark);
      default:
        return _buildRobotIcon(context, isDark);
    }
  }

  Widget _buildDefaultIcon(BuildContext context, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkGradientStart, AppColors.darkGradientEnd]
              : [AppColors.lightGradientStart, AppColors.lightGradientEnd],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                .withValues(alpha: 0.3),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Modern geometric pattern
          CustomPaint(
            size: Size(size * 0.7, size * 0.7),
            painter: ModernLogoPainter(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalIcon(BuildContext context, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightBackgroundAlt,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          'C',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientIcon(BuildContext context, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkGradientSecondaryStart, AppColors.darkGradientSecondaryEnd]
              : [AppColors.lightGradientSecondaryStart, AppColors.lightGradientSecondaryEnd],
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary)
                .withValues(alpha: 0.4),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.2),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }

  Widget _buildRobotIcon(BuildContext context, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                .withValues(alpha: 0.025),
            blurRadius: size * 0.02,
            offset: Offset(0, size * 0.01),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: RobotLogoPainter(
          color: color ?? (isDark ? AppColors.darkAccentTertiary : AppColors.lightAccentQuaternary), // Use sophisticated charcoal/silver
          accentColor: isDark ? AppColors.darkAccent : AppColors.lightAccent, // Use gold accent
        ),
      ),
    );
  }
}

// Custom painter for classy roboty pirate logo
class RobotLogoPainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  RobotLogoPainter({required this.color, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final accentStrokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Main robot head - sophisticated hexagonal shape (more robotic/technical)
    final headPath = Path();
    final headRadius = size.width * 0.28;
    final headCenter = Offset(center.dx, center.dy - size.height * 0.05);

    // Create hexagonal robot head
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (3.14159 / 180);
      final x = headCenter.dx + headRadius * cos(angle);
      final y = headCenter.dy + headRadius * sin(angle);
      if (i == 0) {
        headPath.moveTo(x, y);
      } else {
        headPath.lineTo(x, y);
      }
    }
    headPath.close();

    canvas.drawPath(headPath, paint);
    canvas.drawPath(headPath, strokePaint);

    // Pirate captain's hat visor (sophisticated metallic band)
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - size.height * 0.22),
        width: size.width * 0.45,
        height: size.height * 0.08,
      ),
      Radius.circular(size.width * 0.04),
    );
    canvas.drawRRect(visorRect, accentPaint);
    canvas.drawRRect(visorRect, strokePaint);

    // Sophisticated robot eyes (hexagonal LED displays)
    final eyeSize = size.width * 0.08;
    final eyeY = center.dy - size.height * 0.08;

    // Left eye - hexagonal LED
    final leftEyePath = Path();
    final leftEyeCenter = Offset(center.dx - size.width * 0.12, eyeY);
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (3.14159 / 180);
      final x = leftEyeCenter.dx + eyeSize * cos(angle);
      final y = leftEyeCenter.dy + eyeSize * sin(angle);
      if (i == 0) {
        leftEyePath.moveTo(x, y);
      } else {
        leftEyePath.lineTo(x, y);
      }
    }
    leftEyePath.close();
    canvas.drawPath(leftEyePath, accentPaint);
    canvas.drawPath(leftEyePath, strokePaint);

    // Right eye - hexagonal LED
    final rightEyePath = Path();
    final rightEyeCenter = Offset(center.dx + size.width * 0.12, eyeY);
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (3.14159 / 180);
      final x = rightEyeCenter.dx + eyeSize * cos(angle);
      final y = rightEyeCenter.dy + eyeSize * sin(angle);
      if (i == 0) {
        rightEyePath.moveTo(x, y);
      } else {
        rightEyePath.lineTo(x, y);
      }
    }
    rightEyePath.close();
    canvas.drawPath(rightEyePath, accentPaint);
    canvas.drawPath(rightEyePath, strokePaint);

    // Eye pupils (glowing centers)
    canvas.drawCircle(leftEyeCenter, eyeSize * 0.4, paint);
    canvas.drawCircle(rightEyeCenter, eyeSize * 0.4, paint);

    // Sophisticated mouth/communication array (geometric pattern)
    final mouthY = center.dy + size.height * 0.05;
    final mouthWidth = size.width * 0.2;

    // Central communication grid
    final gridRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, mouthY),
        width: mouthWidth,
        height: size.height * 0.12,
      ),
      Radius.circular(size.width * 0.02),
    );
    canvas.drawRRect(gridRect, strokePaint);

    // Grid lines (technical/robotic pattern)
    for (int i = 1; i < 4; i++) {
      final lineX = center.dx - mouthWidth/2 + (i * mouthWidth/4);
      canvas.drawLine(
        Offset(lineX, mouthY - size.height * 0.06),
        Offset(lineX, mouthY + size.height * 0.06),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.015,
      );
    }

    for (int i = 1; i < 3; i++) {
      final lineY = mouthY - size.height * 0.06 + (i * size.height * 0.04);
      canvas.drawLine(
        Offset(center.dx - mouthWidth/2, lineY),
        Offset(center.dx + mouthWidth/2, lineY),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.015,
      );
    }

    // Pirate navigation compass (bottom - sophisticated design)
    final compassCenter = Offset(center.dx, center.dy + size.height * 0.28);
    final compassRadius = size.width * 0.09;

    // Outer compass ring
    canvas.drawCircle(compassCenter, compassRadius, strokePaint);
    canvas.drawCircle(compassCenter, compassRadius * 0.8, accentStrokePaint);

    // Compass rose (8-point star - navigation/pirate theme)
    final starPath = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final outerRadius = compassRadius * 0.6;
      final innerRadius = compassRadius * 0.3;

      final outerX = compassCenter.dx + outerRadius * cos(angle);
      final outerY = compassCenter.dy + outerRadius * sin(angle);
      final innerAngle = ((i + 0.5) * 45) * (3.14159 / 180);
      final innerX = compassCenter.dx + innerRadius * cos(innerAngle);
      final innerY = compassCenter.dy + innerRadius * sin(innerAngle);

      if (i == 0) {
        starPath.moveTo(outerX, outerY);
      } else {
        starPath.lineTo(outerX, outerY);
      }
      starPath.lineTo(innerX, innerY);
    }
    starPath.close();
    canvas.drawPath(starPath, accentPaint);

    // Central compass dot
    canvas.drawCircle(compassCenter, size.width * 0.02, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for modern geometric logo
class ModernLogoPainter extends CustomPainter {
  final Color color;

  ModernLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.15;

    // Draw interconnected nodes (representing AI/cognition)
    final nodes = [
      Offset(center.dx - radius, center.dy - radius),
      Offset(center.dx + radius, center.dy - radius),
      Offset(center.dx, center.dy),
      Offset(center.dx - radius, center.dy + radius),
      Offset(center.dx + radius, center.dy + radius),
    ];

    // Draw connections
    canvas.drawLine(nodes[0], nodes[2], strokePaint);
    canvas.drawLine(nodes[1], nodes[2], strokePaint);
    canvas.drawLine(nodes[2], nodes[3], strokePaint);
    canvas.drawLine(nodes[2], nodes[4], strokePaint);
    canvas.drawLine(nodes[0], nodes[3], strokePaint);
    canvas.drawLine(nodes[1], nodes[4], strokePaint);

    // Draw nodes
    for (final node in nodes) {
      canvas.drawCircle(node, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
