import 'package:cognify_flutter/models/streaming_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Streaming Performance Tests', () {
    test('StreamingMessageController should handle content updates efficiently', () {
      final controller = StreamingMessageController('test-message');
      
      // Test initial state
      expect(controller.content, '');
      
      // Test adding content chunks
      controller.addContent('Hello');
      expect(controller.content, 'Hello');
      
      controller.addContent(' World');
      expect(controller.content, 'Hello World');
      
      // Test final content
      controller.setFinalContent('Hello World!');
      expect(controller.content, 'Hello World!');
      
      controller.dispose();
    });

    test('StreamingMessageRegistry should manage controllers correctly', () {
      final registry = StreamingMessageRegistry();
      
      // Test creating controller
      final controller1 = registry.createController('message-1');
      expect(controller1.messageId, 'message-1');
      
      // Test getting existing controller
      final retrievedController = registry.getController('message-1');
      expect(retrievedController, isNotNull);
      expect(retrievedController!.messageId, 'message-1');
      
      // Test creating new controller for same message (should replace old one)
      final controller2 = registry.createController('message-1');
      expect(controller2.messageId, 'message-1');
      
      // Test removing controller
      registry.removeController('message-1');
      final nullController = registry.getController('message-1');
      expect(nullController, isNull);
      
      // Test disposing all controllers
      registry.createController('message-2');
      registry.createController('message-3');
      registry.disposeAll();
      
      expect(registry.getController('message-2'), isNull);
      expect(registry.getController('message-3'), isNull);
    });

    test('Content streaming should work with realistic chunks', () async {
      final controller = StreamingMessageController('test-streaming');
      final chunks = <String>[];
      
      // Subscribe to content stream
      controller.contentStream.listen((content) {
        chunks.add(content);
      });
      
      // Simulate realistic streaming chunks
      final testChunks = [
        'Hello',
        ' there',
        '! How',
        ' are',
        ' you',
        ' doing',
        ' today',
        '?',
      ];
      
      // Add chunks with small delays to simulate real streaming
      for (final chunk in testChunks) {
        controller.addContent(chunk);
        // Small delay to ensure stream processing
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Wait a bit more to ensure all events are processed
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify chunks were received
      expect(chunks.length, testChunks.length);
      
      // Verify final content
      expect(controller.content, 'Hello there! How are you doing today?');
      
      controller.dispose();
    });

    test('Large content should be handled efficiently', () async {
      final controller = StreamingMessageController('test-large-content');
      final chunks = <String>[];
      
      controller.contentStream.listen((content) {
        chunks.add(content);
      });
      
      // Simulate large content in chunks
      const largeText = 'This is a very long piece of text that should be handled efficiently by the streaming system. '
          'It contains multiple sentences and should be processed in chunks without causing performance issues. '
          'The system should be able to handle large amounts of content while maintaining smooth user experience.';
      
      // Split into realistic chunks
      final words = largeText.split(' ');
      String currentChunk = '';
      
      for (final word in words) {
        currentChunk += '$word ';
        if (currentChunk.length > 50) {
          controller.addContent(currentChunk);
          currentChunk = '';
          // Small delay to ensure stream processing
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
      
      // Add remaining content
      if (currentChunk.isNotEmpty) {
        controller.addContent(currentChunk);
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Wait a bit more to ensure all events are processed
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify content was streamed correctly
      expect(controller.content.trim(), largeText.trim());
      expect(chunks.length, greaterThan(1)); // Should have multiple chunks
      
      controller.dispose();
    });
  });
}
