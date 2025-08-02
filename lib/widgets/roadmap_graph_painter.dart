import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/roadmap_models.dart';
import '../theme/app_theme.dart';

class RoadmapGraphPainter extends CustomPainter {
  final RoadmapGraph roadmap;
  final double scale;
  final Offset offset;
  final bool isDark;
  final String? selectedNodeId;

  RoadmapGraphPainter({
    required this.roadmap,
    this.scale = 1.0,
    this.offset = Offset.zero,
    required this.isDark,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections first (so they appear behind nodes)
    for (final connection in roadmap.connections) {
      _drawConnection(canvas, connection);
    }

    // Draw nodes on top
    for (final node in roadmap.nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawConnection(Canvas canvas, RoadmapConnection connection) {
    final fromNode = roadmap.getNodeById(connection.fromNodeId);
    final toNode = roadmap.getNodeById(connection.toNodeId);
    
    if (fromNode == null || toNode == null) return;

    final fromPos = _transformPosition(fromNode.position);
    final toPos = _transformPosition(toNode.position);
    
    final paint = Paint()
      ..color = (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (connection.isDotted) {
      paint.strokeWidth = 1.5;
      _drawDottedLine(canvas, fromPos, toPos, paint);
    } else {
      if (connection.isCurved) {
        _drawCurvedLine(canvas, fromPos, toPos, paint);
      } else {
        canvas.drawLine(fromPos, toPos, paint);
      }
    }
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    
    final distance = (end - start).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();
    
    for (int i = 0; i < dashCount; i++) {
      final startRatio = i * (dashWidth + dashSpace) / distance;
      final endRatio = (i * (dashWidth + dashSpace) + dashWidth) / distance;
      
      final dashStart = Offset.lerp(start, end, startRatio)!;
      final dashEnd = Offset.lerp(start, end, endRatio)!;
      
      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  void _drawCurvedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    
    // Create a curved path using quadratic bezier
    final controlPoint = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - 30,
    );
    
    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      end.dx,
      end.dy,
    );
    
    canvas.drawPath(path, paint);
  }

  void _drawNode(Canvas canvas, RoadmapGraphNode node) {
    final position = _transformPosition(node.position);
    final isSelected = node.id == selectedNodeId;
    
    // Node dimensions
    const nodeWidth = 140.0;
    const nodeHeight = 40.0;
    
    final rect = Rect.fromCenter(
      center: position,
      width: nodeWidth,
      height: nodeHeight,
    );

    // Get node colors based on type
    final colors = _getNodeColors(node.type);
    
    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    final shadowRect = rect.translate(2, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(8)),
      shadowPaint,
    );

    // Draw node background
    final backgroundPaint = Paint()
      ..color = isSelected ? colors.selected : colors.background
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      backgroundPaint,
    );

    // Draw node border
    final borderPaint = Paint()
      ..color = colors.border
      ..strokeWidth = isSelected ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Draw node text
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.title,
        style: TextStyle(
          color: colors.text,
          fontSize: 12,
          fontWeight: node.type == NodeType.core ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout(maxWidth: nodeWidth - 16);
    
    final textOffset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, textOffset);

    // Draw completion indicator if completed
    if (node.isCompleted) {
      final checkPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      
      final checkRect = Rect.fromCenter(
        center: Offset(rect.right - 8, rect.top + 8),
        width: 12,
        height: 12,
      );
      
      canvas.drawCircle(checkRect.center, 6, checkPaint);
      
      // Draw checkmark
      final checkPath = Path();
      checkPath.moveTo(checkRect.center.dx - 3, checkRect.center.dy);
      checkPath.lineTo(checkRect.center.dx - 1, checkRect.center.dy + 2);
      checkPath.lineTo(checkRect.center.dx + 3, checkRect.center.dy - 2);
      
      final checkMarkPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      
      canvas.drawPath(checkPath, checkMarkPaint);
    }
  }

  NodeColors _getNodeColors(NodeType type) {
    switch (type) {
      case NodeType.core:
        return NodeColors(
          background: isDark ? const Color(0xFF2D5016) : const Color(0xFFFFF59D), // Yellow-ish
          border: isDark ? const Color(0xFF4CAF50) : const Color(0xFFF57F17),
          text: isDark ? Colors.white : Colors.black87,
          selected: isDark ? const Color(0xFF388E3C) : const Color(0xFFFFEB3B),
        );
      case NodeType.topic:
        return NodeColors(
          background: isDark ? const Color(0xFF3E2723) : const Color(0xFFF5F5DC), // Beige-ish
          border: isDark ? AppColors.darkAccent : const Color(0xFFD7CCC8),
          text: isDark ? Colors.white70 : Colors.black87,
          selected: isDark ? AppColors.darkAccent.withValues(alpha: 0.3) : const Color(0xFFEFEBE9),
        );
      default:
        return NodeColors(
          background: isDark ? const Color(0xFF424242) : Colors.grey[100]!,
          border: isDark ? Colors.grey[600]! : Colors.grey[400]!,
          text: isDark ? Colors.white70 : Colors.black87,
          selected: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        );
    }
  }

  Offset _transformPosition(NodePosition position) {
    return Offset(
      (position.x * scale) + offset.dx,
      (position.y * scale) + offset.dy,
    );
  }

  @override
  bool shouldRepaint(RoadmapGraphPainter oldDelegate) {
    return oldDelegate.scale != scale ||
           oldDelegate.offset != offset ||
           oldDelegate.selectedNodeId != selectedNodeId ||
           oldDelegate.isDark != isDark;
  }
}

class NodeColors {
  final Color background;
  final Color border;
  final Color text;
  final Color selected;

  NodeColors({
    required this.background,
    required this.border,
    required this.text,
    required this.selected,
  });
}
