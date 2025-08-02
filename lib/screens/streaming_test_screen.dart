import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/message.dart';
import '../models/streaming_message.dart';
import '../widgets/streaming_message_content.dart';

class StreamingTestScreen extends StatefulWidget {
  const StreamingTestScreen({super.key});

  @override
  State<StreamingTestScreen> createState() => _StreamingTestScreenState();
}

class _StreamingTestScreenState extends State<StreamingTestScreen> {
  String _streamingText = '';
  bool _isStreaming = false;
  Timer? _streamTimer;
  int _currentIndex = 0;

  // Add streaming message components
  late Message _testMessage;
  late StreamingMessageController _streamingController;

  // Sample text to simulate streaming
  final String _fullText = '''
Hello! This is a streaming text simulation.

**What is streaming?**
Streaming is the process of delivering content in real-time, piece by piece, rather than waiting for the entire content to be ready before displaying it.

**Key benefits:**
- Improved user experience with immediate feedback
- Reduced perceived latency
- Better engagement through progressive content reveal

**Technical implementation:**
- Uses Dart Streams for reactive programming
- Flutter's setState() for UI updates
- Timer-based content delivery simulation

This test helps us verify that the streaming mechanism works correctly in isolation, without the complexity of the main chat interface.

Let's see if you can observe the typing effect as this text appears character by character! 🚀
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Streaming Test'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
            onPressed: _isStreaming ? _stopStreaming : _startStreaming,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetStreaming,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isStreaming ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isStreaming ? Colors.green : Colors.grey,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isStreaming ? Icons.stream : Icons.pause_circle_outline,
                    color: _isStreaming ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isStreaming ? 'Streaming...' : 'Ready',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isStreaming ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress indicator
            Text(
              'Progress: ${_streamingText.length} / ${_fullText.length} characters',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 8),

            LinearProgressIndicator(
              value: _fullText.isEmpty ? 0 : _streamingText.length / _fullText.length,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),

            const SizedBox(height: 24),

            // Control buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isStreaming ? null : _startStreaming,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Streaming'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isStreaming ? _stopStreaming : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _resetStreaming,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Streaming content area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Streaming Content (using StreamingMessageContent):',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Use StreamingMessageContent widget
                      StreamingMessageContent(
                        message: _testMessage,
                        theme: theme,
                      ),
                      // Cursor effect when streaming
                      if (_isStreaming)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          child: AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 500),
                            child: Container(
                              width: 2,
                              height: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _streamingController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Initialize test message for StreamingMessageContent
    _testMessage = Message(
      id: 'streaming-test-message',
      type: 'assistant',
      content: '',
      timestamp: DateTime.now().toIso8601String(),
      isProcessing: true,
    );

    // Create streaming controller
    _streamingController = StreamingMessageRegistry().createController(_testMessage.id);
  }

  void _resetStreaming() {
    _streamTimer?.cancel();
    setState(() {
      _isStreaming = false;
      _streamingText = '';
      _currentIndex = 0;
    });

    // Reset the streaming controller
    _streamingController.dispose();
    _streamingController = StreamingMessageRegistry().createController(_testMessage.id);

    print('🔥 Streaming reset');
  }

  void _startStreaming() {
    if (_isStreaming) return;

    setState(() {
      _isStreaming = true;
      _streamingText = '';
      _currentIndex = 0;
    });

    print('🔥 Starting streaming simulation...');

    _streamTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentIndex >= _fullText.length) {
        timer.cancel();
        setState(() {
          _isStreaming = false;
        });
        print('🔥 Streaming completed!');
        return;
      }

      // Add 1-3 characters at a time to simulate realistic streaming
      final chunkSize = Random().nextInt(3) + 1;
      final endIndex = (_currentIndex + chunkSize).clamp(0, _fullText.length);
      final newChunk = _fullText.substring(_currentIndex, endIndex);

      setState(() {
        _streamingText += newChunk;
        _currentIndex = endIndex;
      });

      // Update the streaming controller for StreamingMessageContent
      _streamingController.addContent(newChunk);

      print('🔥 Streaming: Added ${newChunk.length} chars, total: ${_streamingText.length}');
    });
  }

  void _stopStreaming() {
    _streamTimer?.cancel();
    setState(() {
      _isStreaming = false;
    });
    print('🔥 Streaming stopped by user');
  }
}
