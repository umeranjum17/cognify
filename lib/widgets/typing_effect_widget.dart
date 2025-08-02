import 'dart:async';

import 'package:flutter/material.dart';

/// A more sophisticated typing effect that can handle streaming updates
class StreamingTypingEffect extends StatefulWidget {
  final String fullText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration typingSpeed;
  final VoidCallback? onComplete;
  final bool showCursor;

  const StreamingTypingEffect({
    super.key,
    required this.fullText,
    this.style,
    this.textAlign,
    this.typingSpeed = const Duration(milliseconds: 20),
    this.onComplete,
    this.showCursor = true,
  });

  @override
  State<StreamingTypingEffect> createState() => _StreamingTypingEffectState();
}

/// A widget that displays text with a typing effect
class TypingEffectWidget extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration typingSpeed;
  final VoidCallback? onComplete;
  final bool autoStart;

  const TypingEffectWidget({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.typingSpeed = const Duration(milliseconds: 30),
    this.onComplete,
    this.autoStart = true,
  });

  @override
  State<TypingEffectWidget> createState() => _TypingEffectWidgetState();
}

class _StreamingTypingEffectState extends State<StreamingTypingEffect>
    with TickerProviderStateMixin {
  String _displayedText = '';
  int _currentIndex = 0;
  Timer? _timer;
  bool _isTyping = false;
  final bool _showCursor = true;
  
  late AnimationController _cursorAnimationController;
  late Animation<double> _cursorAnimation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _displayedText,
            style: widget.style,
            textAlign: widget.textAlign,
          ),
        ),
        if (widget.showCursor && _isTyping)
          AnimatedBuilder(
            animation: _cursorAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _cursorAnimation.value,
                child: Container(
                  width: 2,
                  height: (widget.style?.fontSize ?? 14) + 4,
                  color: widget.style?.color ?? Theme.of(context).textTheme.bodyMedium?.color,
                  margin: const EdgeInsets.only(left: 2),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  void didUpdateWidget(StreamingTypingEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullText != widget.fullText) {
      _handleTextUpdate();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorAnimationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeCursorAnimation();
    _startTyping();
  }

  void _handleTextUpdate() {
    // If new text is longer, continue typing from where we left off
    if (widget.fullText.length > _currentIndex) {
      if (!_isTyping) {
        _startTyping();
      }
    } else if (widget.fullText.length < _currentIndex) {
      // Text was shortened, reset
      _resetTyping();
    }
  }

  void _initializeCursorAnimation() {
    _cursorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _cursorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cursorAnimationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.showCursor) {
      _cursorAnimationController.repeat(reverse: true);
    }
  }

  void _resetTyping() {
    _timer?.cancel();
    _currentIndex = 0;
    _displayedText = '';
    _isTyping = false;
    _startTyping();
  }

  void _startTyping() {
    if (_isTyping || _currentIndex >= widget.fullText.length) return;

    _isTyping = true;
    _timer = Timer.periodic(widget.typingSpeed, (timer) {
      if (_currentIndex < widget.fullText.length) {
        // Find the next 10 words to add at once for maximum speed
        final remainingText = widget.fullText.substring(_currentIndex);
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
        charsToAdd = charsToAdd.clamp(1, widget.fullText.length - _currentIndex);
        
        if (mounted) {
          try {
            setState(() {
              _displayedText += widget.fullText.substring(_currentIndex, _currentIndex + charsToAdd);
              _currentIndex += charsToAdd;
            });
          } catch (e) {
            print('⚠️ TypingEffectWidget: setState error (ignored): $e');
            timer.cancel();
            _isTyping = false;
          }
        } else {
          timer.cancel();
          _isTyping = false;
        }
      } else {
        timer.cancel();
        _isTyping = false;
        widget.onComplete?.call();
      }
    });
  }
}

class _TypingEffectWidgetState extends State<TypingEffectWidget> {
  String _displayedText = '';
  int _currentIndex = 0;
  Timer? _timer;
  bool _isTyping = false;

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }

  @override
  void didUpdateWidget(TypingEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _resetAndStart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _startTyping();
    }
  }

  void _resetAndStart() {
    _timer?.cancel();
    _currentIndex = 0;
    _displayedText = '';
    _isTyping = false;
    _startTyping();
  }

  void _startTyping() {
    if (_isTyping || _currentIndex >= widget.text.length) return;

    _isTyping = true;
    _timer = Timer.periodic(widget.typingSpeed, (timer) {
      if (_currentIndex < widget.text.length) {
        // Find the next 10 words to add at once for maximum speed
        final remainingText = widget.text.substring(_currentIndex);
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
        charsToAdd = charsToAdd.clamp(1, widget.text.length - _currentIndex);
        
        if (mounted) {
          try {
            setState(() {
              _displayedText += widget.text.substring(_currentIndex, _currentIndex + charsToAdd);
              _currentIndex += charsToAdd;
            });
          } catch (e) {
            print('⚠️ TypingEffectWidget: setState error (ignored): $e');
            timer.cancel();
            _isTyping = false;
          }
        } else {
          timer.cancel();
          _isTyping = false;
        }
      } else {
        timer.cancel();
        _isTyping = false;
        widget.onComplete?.call();
      }
    });
  }
} 