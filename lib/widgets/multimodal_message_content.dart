import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';

/// Widget that displays multimodal message content including text and images
class MultimodalMessageContent extends StatelessWidget {
  final Message message;
  final ThemeData theme;

  const MultimodalMessageContent({
    super.key,
    required this.message,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (message.content is String) {
      // Simple text content
      return _buildTextContent(message.content as String);
    } else if (message.content is List) {
      // Multimodal content
      return _buildMultimodalContent(message.content as List);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildTextContent(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    return SelectableText(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        height: 1.5,
        fontSize: 14,
      ),
      contextMenuBuilder: (context, selectableTextState) {
        return AdaptiveTextSelectionToolbar.selectable(
          anchors: selectableTextState.contextMenuAnchors,
          onCopy: () => selectableTextState.copySelection(SelectionChangedCause.toolbar),
          onSelectAll: () => selectableTextState.selectAll(SelectionChangedCause.toolbar),
          onShare: () => selectableTextState.shareSelection(SelectionChangedCause.toolbar),
          selectionGeometry: SelectionGeometry(
            status: SelectionStatus.uncollapsed,
            hasContent: true,
          ),
        );
      },
    );
  }

  Widget _buildMultimodalContent(List content) {
    final widgets = <Widget>[];
    
    for (final part in content) {
      if (part is Map<String, dynamic>) {
        final type = part['type'] as String?;
        
        switch (type) {
          case 'text':
            final dynamic rawText = part['text'];
            final text = _extractText(rawText);
            if (text.isNotEmpty) {
              widgets.add(_buildTextContent(text));
            }
            break;
            
          case 'image_url':
            {
              final imageUrl = part['image_url'] as Map<String, dynamic>?;
              final url = imageUrl?['url'] as String?;
              if (url != null) {
                widgets.add(_buildImageContent(url));
              }
            }
            break;
          case 'image':
            {
              // AI SDK-compliant format: { type: 'image', image: <string | { url: string }>} 
              final dynamic imageField = part['image'];
              String? url;
              if (imageField is String) {
                url = imageField;
              } else if (imageField is Map<String, dynamic>) {
                url = imageField['url'] as String?;
              }
              if (url != null) {
                widgets.add(_buildImageContent(url));
              }
            }
            break;
        }
      }
    }
    
    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _extractText(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is List) {
      final buffer = <String>[];
      for (final item in raw) {
        if (item is String) buffer.add(item);
        if (item is Map && item['text'] is String) buffer.add(item['text'] as String);
      }
      return buffer.join('\n');
    }
    if (raw is Map && raw['text'] is String) return raw['text'] as String;
    return raw.toString();
  }

  Widget _buildImageContent(String imageUrl) {
    // Handle both data URLs and regular URLs
    if (imageUrl.startsWith('data:')) {
      // Base64 data URL
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _decodeBase64Image(imageUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              color: theme.colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Regular URL
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              color: theme.colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Uint8List _decodeBase64Image(String dataUrl) {
    try {
      // Extract base64 data from data URL
      final base64Data = dataUrl.split(',')[1];
      return base64Decode(base64Data);
    } catch (e) {
      // Return empty bytes if decoding fails
      return Uint8List(0);
    }
  }
}
