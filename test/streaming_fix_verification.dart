import 'package:cognify_flutter/models/message.dart';
import 'package:cognify_flutter/models/streaming_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Streaming Fix Verification', () {
    test('StreamingMessageController should emit events immediately', () async {
      final controller = StreamingMessageController('test');
      final events = <String>[];
      
      // Listen to the stream
      controller.contentStream.listen((content) {
        events.add(content);
      });

      // Add content
      controller.addContent('Test');
      
      // Wait a bit for stream processing
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Verify event was emitted immediately
      expect(events.length, 1);
      expect(events.first, 'Test');
      
      // Add more content
      controller.addContent(' Content');
      
      // Wait a bit for stream processing
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Verify second event was emitted immediately
      expect(events.length, 2);
      expect(events.last, 'Test Content');
      
      controller.dispose();
    });

    test('StreamingMessageContent should update without excessive debouncing', () async {
      // Create a test message
      final message = Message(
        id: 'test-message',
        type: 'assistant',
        content: '',
        timestamp: DateTime.now().toIso8601String(),
        isProcessing: true,
      );

      // Create a streaming controller
      final controller = StreamingMessageRegistry().createController(message.id);
      
      // Track content updates
      final contentUpdates = <String>[];
      
      // Listen to the controller stream
      controller.contentStream.listen((content) {
        contentUpdates.add(content);
      });

      // Add content
      controller.addContent('Hello');
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Add more content
      controller.addContent(' World');
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Verify content updates were received
      expect(contentUpdates.length, 2);
      expect(contentUpdates.first, 'Hello');
      expect(contentUpdates.last, 'Hello World');
      
      // Verify final content
      expect(controller.content, 'Hello World');
      
      controller.dispose();
    });
  });
} 