import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/roadmap_graphs.dart';
import '../models/roadmap_models.dart';
import '../theme/app_theme.dart';
import '../widgets/roadmap_graph_painter.dart';

class RoadmapGraphWidget extends StatefulWidget {
  final LearningRole role;
  final Function(String topic)? onTopicSelected;

  const RoadmapGraphWidget({
    super.key,
    this.role = LearningRole.frontend,
    this.onTopicSelected,
  });

  @override
  State<RoadmapGraphWidget> createState() => _RoadmapGraphWidgetState();
}

class _RoadmapGraphWidgetState extends State<RoadmapGraphWidget> {
  late RoadmapGraph _roadmap;
  final double _scale = 0.5;
  final Offset _offset = const Offset(10, 10);
  String? _selectedNodeId;
  final TransformationController _transformationController = TransformationController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Controls
        _buildControls(theme),
        
        // Graph
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            margin: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(50),
                minScale: 0.2,
                maxScale: 3.0,
                constrained: false,
                child: CustomPaint(
                  size: Size(_roadmap.width, _roadmap.height),
                  painter: RoadmapGraphPainter(
                    roadmap: _roadmap,
                    scale: _scale,
                    offset: _offset,
                    isDark: isDark,
                    selectedNodeId: _selectedNodeId,
                  ),
                  child: GestureDetector(
                    onTapDown: _handleTapDown,
                    child: Container(
                      width: _roadmap.width,
                      height: _roadmap.height,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Selected node info
        if (_selectedNodeId != null) _buildSelectedNodeInfo(theme),
      ],
    );
  }

  @override
  void didUpdateWidget(RoadmapGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      setState(() {
        _roadmap = RoadmapGraphs.getRoadmapGraph(widget.role);
      });
      // Reset view when switching roadmaps
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _transformationController.value = Matrix4.identity()..scale(0.4);
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _roadmap = RoadmapGraphs.getRoadmapGraph(widget.role);
    // Set initial zoom to show the full roadmap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transformationController.value = Matrix4.identity()..scale(0.4);
    });
  }

  Widget _buildControls(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Role selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map,
                  size: 16,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  _roadmap.title,
                  style: TextStyle(
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Zoom controls
          Row(
            children: [
              _buildZoomButton(Icons.zoom_out, () => _zoomOut(), theme),
              const SizedBox(width: 8),
              _buildZoomButton(Icons.center_focus_strong, () => _resetView(), theme),
              const SizedBox(width: 8),
              _buildZoomButton(Icons.zoom_in, () => _zoomIn(), theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedNodeInfo(ThemeData theme) {
    final node = _roadmap.getNodeById(_selectedNodeId!);
    if (node == null) return const SizedBox.shrink();

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getNodeIcon(node.type),
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (node.subtitle != null)
                      Text(
                        node.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _learnAboutTopic(node),
                icon: const Icon(Icons.school, size: 16),
                label: const Text('Learn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          if (node.description != null) ...[
            const SizedBox(height: 12),
            Text(
              node.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed, ThemeData theme) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  IconData _getNodeIcon(NodeType type) {
    switch (type) {
      case NodeType.core:
        return Icons.star;
      case NodeType.topic:
        return Icons.topic;
      case NodeType.skill:
        return Icons.build;
      case NodeType.tool:
        return Icons.construction;
      case NodeType.concept:
        return Icons.lightbulb;
    }
  }

  void _handleTapDown(TapDownDetails details) {
    final localPosition = details.localPosition;
    
    // Find which node was tapped
    for (final node in _roadmap.nodes) {
      final nodePosition = Offset(
        (node.position.x * _scale) + _offset.dx,
        (node.position.y * _scale) + _offset.dy,
      );
      
      const nodeWidth = 140.0;
      const nodeHeight = 40.0;
      
      final nodeRect = Rect.fromCenter(
        center: nodePosition,
        width: nodeWidth,
        height: nodeHeight,
      );
      
      if (nodeRect.contains(localPosition)) {
        setState(() {
          _selectedNodeId = _selectedNodeId == node.id ? null : node.id;
        });
        break;
      }
    }
  }

  void _learnAboutTopic(RoadmapGraphNode node) {
    // Navigate to chat with the topic
    if (widget.onTopicSelected != null) {
      widget.onTopicSelected!(node.title);
    } else {
      // Default navigation to chat
      context.push('/chat?topic=${Uri.encodeComponent(node.title)}');
    }
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity()..scale(0.4);
  }

  void _zoomIn() {
    final currentTransform = _transformationController.value;
    _transformationController.value = currentTransform..scale(1.2);
  }

  void _zoomOut() {
    final currentTransform = _transformationController.value;
    _transformationController.value = currentTransform..scale(0.8);
  }
}
