import 'package:flutter/material.dart';

class CognifyLogo extends StatelessWidget {
  final double size;
  final String? variant;

  const CognifyLogo({super.key, this.size = 100, this.variant});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      isDark ? 'assets/images/cognify_dark.png' : 'assets/images/cognify_robot_512x512.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
