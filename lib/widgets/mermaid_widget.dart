import 'package:flutter/material.dart';

// Use the new image-based implementation
import 'mermaid_image_widget.dart';

/// Mermaid widget that renders diagrams using server-side image generation
/// This is a wrapper around MermaidImageWidget to maintain API compatibility
class MermaidWidget extends StatelessWidget {
  final String mermaidCode;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final String format;

  const MermaidWidget({
    super.key,
    required this.mermaidCode,
    this.height,
    this.width,
    this.backgroundColor,
    this.format = 'png', // Default to PNG for backward compatibility
  });

  @override
  Widget build(BuildContext context) {
    return MermaidImageWidget(
      mermaidCode: mermaidCode,
      height: height,
      width: width,
      backgroundColor: backgroundColor,
      enableFullscreen: true,
      format: format,
    );
  }
}
