import 'package:flutter/material.dart';

class CognifyLogo extends StatelessWidget {
  final double size;
  final String? variant;

  const CognifyLogo({super.key, this.size = 100, this.variant});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.15),
      child: Image.asset(
        isDark ? 'assets/images/cognify_dark.png' : 'assets/images/cognify_robot_512x512.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
