import 'package:flutter/material.dart';

class CognifyLogo extends StatelessWidget {
  final double size;
  final String? variant;

  const CognifyLogo({super.key, this.size = 100, this.variant});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/cognify_robot_512x512.png',
      width: size,
      height: size,
    );
  }
}
