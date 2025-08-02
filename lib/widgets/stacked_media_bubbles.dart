import 'package:flutter/material.dart';

import '../models/chat_source.dart';

class StackedMediaBubbles extends StatelessWidget {
  final List<ChatSource> sources;
  final List<Map<String, dynamic>> images;
  final double size;
  final Function(bool, bool) onExpandedChanged;
  final bool areSourcesExpanded;
  final bool areImagesExpanded;

  const StackedMediaBubbles({
    super.key,
    this.sources = const [],
    this.images = const [],
    this.size = 28.0,
    required this.onExpandedChanged,
    this.areSourcesExpanded = false,
    this.areImagesExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty && images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (sources.isNotEmpty)
          _buildStackedSourceBubbles(context),
        if (sources.isNotEmpty && images.isNotEmpty)
          const SizedBox(width: 16),
        if (images.isNotEmpty)
          _buildStackedImageBubbles(context),
      ],
    );
  }

  Widget _buildCountBubble(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context, Map<String, dynamic> image) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
      ),
      child: ClipOval(
        child: Image.network(
          image['thumbnail'] ?? image['url'] ?? '',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.image_not_supported,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSourceBubble(BuildContext context, ChatSource source) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getSourceColor(source),
        shape: BoxShape.circle,
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
      ),
      child: Icon(_getSourceIcon(source), size: size * 0.5, color: Colors.white),
    );
  }

  Widget _buildStackedImageBubbles(BuildContext context) {
    final theme = Theme.of(context);
    const maxVisible = 3;
    final visibleImages = images.take(maxVisible).toList();
    final remainingCount = images.length - maxVisible;

    return GestureDetector(
      onTap: () => onExpandedChanged(false, true),
      child: SizedBox(
        height: size,
        width: size * (maxVisible * 0.6) + (remainingCount > 0 ? size * 0.6 : 0),
        child: Stack(
          children: [
            ...visibleImages.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return Positioned(
                left: index * (size * 0.5),
                child: _buildImageBubble(context, image),
              );
            }),
            if (remainingCount > 0)
              Positioned(
                left: maxVisible * (size * 0.5),
                child: _buildCountBubble(context, remainingCount),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedSourceBubbles(BuildContext context) {
    final theme = Theme.of(context);
    const maxVisible = 3;
    final visibleSources = sources.take(maxVisible).toList();
    final remainingCount = sources.length - maxVisible;

    return GestureDetector(
      onTap: () => onExpandedChanged(true, false),
      child: SizedBox(
        height: size,
        width: size * (maxVisible * 0.6) + (remainingCount > 0 ? size * 0.6 : 0),
        child: Stack(
          children: [
            ...visibleSources.asMap().entries.map((entry) {
              final index = entry.key;
              final source = entry.value;
              return Positioned(
                left: index * (size * 0.5),
                child: _buildSourceBubble(context, source),
              );
            }),
            if (remainingCount > 0)
              Positioned(
                left: maxVisible * (size * 0.5),
                child: _buildCountBubble(context, remainingCount),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSourceColor(ChatSource source) {
    final domain = Uri.tryParse(source.url)?.host.toLowerCase() ?? '';
    if (domain.contains('reddit.com')) return Colors.orange;
    if (domain.contains('twitter.com') || domain.contains('x.com')) return Colors.blue;
    if (domain.contains('medium.com')) return Colors.green;
    if (domain.contains('dev.to')) return Colors.purple;
    if (domain.contains('github.com')) return Colors.grey[800]!;
    if (domain.contains('stackoverflow.com')) return Colors.orange[800]!;
    return Colors.blue[600]!;
  }

  IconData _getSourceIcon(ChatSource source) {
    final domain = Uri.tryParse(source.url)?.host.toLowerCase() ?? '';
    if (domain.contains('reddit.com')) return Icons.reddit;
    if (domain.contains('twitter.com') || domain.contains('x.com')) return Icons.alternate_email;
    if (domain.contains('medium.com')) return Icons.article;
    if (domain.contains('dev.to')) return Icons.code;
    if (domain.contains('github.com')) return Icons.code_outlined;
    if (domain.contains('stackoverflow.com')) return Icons.help_outline;
    return source.type == 'search' ? Icons.search : Icons.link;
  }
}