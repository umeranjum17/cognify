import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import '../models/streaming_message.dart';
import '../theme/app_theme.dart';
import 'safe_mermaid_code_builder.dart';

/// Widget that displays message content with real-time streaming support
class StreamingMessageContent extends StatefulWidget {
  final Message message;
  final ThemeData theme;

  const StreamingMessageContent({
    super.key,
    required this.message,
    required this.theme,
  });

  @override
  State<StreamingMessageContent> createState() => _StreamingMessageContentState();
}

class _StreamingMessageContentState extends State<StreamingMessageContent> {
  // Minimal debouncing for smooth streaming - just one frame at 60fps
  static const Duration _debounceDelay = Duration(milliseconds: 16); // One frame at 60fps

  StreamingMessageController? _controller;
  StreamSubscription<String>? _streamSubscription;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Timer? _typingTimer;

  String _displayedContent = '';
  String _targetContent = '';
  int _currentCharIndex = 0;

  // Performance optimization - only for final markdown rendering
  String _lastParsedContent = '';
  Widget? _cachedMarkdownWidget;

  // Track if we need to update the UI
  final bool _needsUpdate = false;
  bool _isTyping = false;
  bool _isDisposed = false;

  @override
  Widget build(BuildContext context) {
    // Use the simple approach that works in the streaming test
    final String contentToRender = _displayedContent.isNotEmpty
        ? _displayedContent
        : widget.message.textContent;

    // Always use Text widget during streaming for consistent performance
    // Only use MarkdownBody when streaming is completely finished

      // Full markdown rendering when streaming is complete
      return _buildMarkdownContent(contentToRender);
  }

  @override
  void didUpdateWidget(StreamingMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _disposeSubscription();
      _resetState();
      _initializeController();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeSubscription();
    _typingTimer?.cancel();
    _cachedMarkdownWidget = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Widget _buildMarkdownContent(String content) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    // Memoization: only rebuild MarkdownBody if content has actually changed
    if (content == _lastParsedContent && _cachedMarkdownWidget != null) {
      return _cachedMarkdownWidget!;
    }

    // Build new markdown widget
    final markdownWidget = MarkdownBody(
      data: content,
      selectable: true,
      builders: {
        'code': SafeMermaidCodeBuilder(),
      },
      styleSheet: MarkdownStyleSheet(
        p: widget.theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          fontSize: 14,
        ),
        h1: widget.theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          height: 1.3,
        ),
        h2: widget.theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          height: 1.3,
          color: widget.theme.colorScheme.primary,
        ),
        h3: widget.theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          height: 1.3,
        ),
        strong: widget.theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        em: widget.theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        listBullet: widget.theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
        ),
        code: widget.theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: widget.theme.colorScheme.surface,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: widget.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
          border: Border.all(color: widget.theme.dividerColor),
        ),
        blockquoteDecoration: BoxDecoration(
          color: widget.theme.colorScheme.surface.withValues(alpha: 0.5),
          border: Border(
            left: BorderSide(
              color: widget.theme.colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.all(12),
      ),
      imageBuilder: (uri, title, alt) {
        // Only render actual image URLs, not webpage URLs
        final url = uri.toString();
        final isImageUrl = _isValidImageUrl(url);

        if (!isImageUrl) {
          // Return a link widget instead of trying to render as image
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 20,
                  color: widget.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alt ?? title ?? 'Link',
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      color: widget.theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => _showMarkdownImage(url, title, alt),
          child: Container(
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
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: widget.theme.colorScheme.surface,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: widget.theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          alt ?? 'Failed to load image',
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            color: widget.theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );

    // Cache the widget and content for memoization
    _lastParsedContent = content;
    _cachedMarkdownWidget = markdownWidget;

    return markdownWidget;
  }

  void _disposeSubscription() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _typingTimer?.cancel();
    _typingTimer = null;
  }

  void _handleContentUpdate(String content) {
    // Update target content immediately
    _targetContent = content;
    
    // If we're not currently typing, start the typing effect
    if (!_isTyping) {
      _startTypingEffect();
    }
  }

  void _initializeController() {
    _controller = StreamingMessageRegistry().getController(widget.message.id);

    if (_controller != null) {
      // Set initial content
      _displayedContent = _controller!.content;

      // Set up simple stream subscription
      _streamSubscription = _controller!.contentStream.listen(
        (content) {
          _handleContentUpdate(content);
        },
        onError: (error) {
          print('🎯 StreamingMessageContent: Stream error: $error');
        },
        onDone: () {
          // Ensure final content is displayed
          if (_controller != null) {
            _displayedContent = _controller!.content;
            if (mounted && !_isDisposed) {
              try {
                setState(() {});
              } catch (e) {
                print('⚠️ StreamingMessageContent: setState error in onDone (ignored): $e');
              }
            }
          }
        },
      );

      // Set initial content if available
      if (_displayedContent.isNotEmpty && mounted && !_isDisposed) {
        try {
          setState(() {});
        } catch (e) {
          print('⚠️ StreamingMessageContent: setState error in initial content (ignored): $e');
        }
      }
    } else {
      print('⚠️  StreamingMessageContent: No controller found for ${widget.message.id}, will retry...');
      // Retry after a short delay in case controller is created shortly after widget
      _retryTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && _controller == null) {
          _initializeController();
        }
      });
    }
  }

  bool _isValidImageUrl(String url) {
    // Check if URL ends with common image extensions
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
    final lowerUrl = url.toLowerCase();
    return imageExtensions.any((ext) => lowerUrl.endsWith(ext)) ||
           lowerUrl.contains('image') ||
           lowerUrl.contains('img');
  }

  void _resetState() {
    _controller = null;
    _displayedContent = '';
    _targetContent = '';
    _currentCharIndex = 0;
    _lastParsedContent = '';
    _cachedMarkdownWidget = null;
    _isTyping = false;
  }

  void _showMarkdownImage(String imageUrl, String? title, String? alt) {
    // This would need to be implemented with a proper context
    // For now, we'll just try to launch the URL
    launchUrl(Uri.parse(imageUrl), mode: LaunchMode.externalApplication);
  }

  void _startTypingEffect() {
    if (_isTyping) return;
    
    _isTyping = true;
    _currentCharIndex = _displayedContent.length;
    
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (_currentCharIndex < _targetContent.length) {
        // Find the next 10 words to add at once for maximum speed
        final remainingText = _targetContent.substring(_currentCharIndex);
        final words = remainingText.split(' ');
        
        // Add 10 words at a time, or remaining characters if less than 10 words
        int charsToAdd;
        if (words.length >= 10) {
          // Add 10 words
          charsToAdd = words.take(10).join(' ').length + (words.length > 10 ? 1 : 0); // +1 for space
        } else {
          // Add remaining characters (less than 10 words)
          charsToAdd = remainingText.length;
        }
        
        // Ensure we don't exceed the target content length
        charsToAdd = charsToAdd.clamp(1, _targetContent.length - _currentCharIndex);
        
        _displayedContent = _targetContent.substring(0, _currentCharIndex + charsToAdd);
        _currentCharIndex += charsToAdd;
        
        if (mounted && !_isDisposed) {
          try {
            setState(() {});
          } catch (e) {
            print('⚠️ StreamingMessageContent: setState error in typing effect (ignored): $e');
            timer.cancel();
            _isTyping = false;
          }
        } else {
          timer.cancel();
          _isTyping = false;
        }
      } else {
        // Typing complete
        _isTyping = false;
        timer.cancel();
        _displayedContent = _targetContent; // Ensure we have the complete content
        
        if (mounted && !_isDisposed) {
          try {
            setState(() {});
          } catch (e) {
            print('⚠️ StreamingMessageContent: setState error in typing complete (ignored): $e');
          }
        }
      }
    });
  }
}
