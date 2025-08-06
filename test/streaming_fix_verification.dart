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

    test('StreamingMessageRegistry should handle historical messages correctly', () async {
      final registry = StreamingMessageRegistry();
      
      // Create a historical message (not processing)
      final historicalMessage = Message(
        id: 'historical-message',
        type: 'assistant',
        content: 'This is a historical message',
        timestamp: DateTime.now().toIso8601String(),
        isProcessing: false, // Historical message
      );

      // Verify no controller exists for historical message
      final controller = registry.getController(historicalMessage.id);
      expect(controller, isNull);
      
      // Verify historical message content is preserved
      expect(historicalMessage.textContent, 'This is a historical message');
    });

    test('StreamingMessageRegistry should manage live controllers correctly', () async {
      final registry = StreamingMessageRegistry();
      
      // Create a live message (processing)
      final liveMessageId = 'live-message';
      
      // Create controller for live message
      final controller = registry.createController(liveMessageId);
      expect(controller, isNotNull);
      
      // Verify controller can be retrieved
      final retrievedController = registry.getController(liveMessageId);
      expect(retrievedController, equals(controller));
      
      // Add content to controller
      controller.addContent('Live content');
      expect(controller.content, 'Live content');
      
      // Set final content
      controller.setFinalContent('Final live content');
      expect(controller.content, 'Final live content');
      
      // Clean up controller
      registry.removeController(liveMessageId);
      
      // Verify controller is removed
      final removedController = registry.getController(liveMessageId);
      expect(removedController, isNull);
    });

    test('StreamingMessageRegistry should handle controller replacement', () async {
      final registry = StreamingMessageRegistry();
      final messageId = 'replace-test';
      
      // Create first controller
      final controller1 = registry.createController(messageId);
      controller1.addContent('First controller');
      
      // Create second controller (should replace first)
      final controller2 = registry.createController(messageId);
      controller2.addContent('Second controller');
      
      // Verify second controller is active
      final retrievedController = registry.getController(messageId);
      expect(retrievedController, equals(controller2));
      expect(retrievedController!.content, 'Second controller');
      
      // Clean up
      registry.removeController(messageId);
    });

    test('StreamingMessageRegistry should handle multiple controllers', () async {
      final registry = StreamingMessageRegistry();
      
      // Create multiple controllers
      final controller1 = registry.createController('message-1');
      final controller2 = registry.createController('message-2');
      final controller3 = registry.createController('message-3');
      
      // Add content to each
      controller1.addContent('Content 1');
      controller2.addContent('Content 2');
      controller3.addContent('Content 3');
      
      // Verify each controller is independent
      expect(registry.getController('message-1')!.content, 'Content 1');
      expect(registry.getController('message-2')!.content, 'Content 2');
      expect(registry.getController('message-3')!.content, 'Content 3');
      
      // Clean up all controllers
      registry.disposeAll();
      
      // Verify all controllers are removed
      expect(registry.getController('message-1'), isNull);
      expect(registry.getController('message-2'), isNull);
      expect(registry.getController('message-3'), isNull);
    });

    test('StreamingMessageController should handle setFinalContent correctly', () async {
      final controller = StreamingMessageController('final-test');
      final events = <String>[];
      
      // Listen to the stream
      controller.contentStream.listen((content) {
        events.add(content);
      });

      // Add some content
      controller.addContent('Partial');
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Set final content
      controller.setFinalContent('Final content');
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Verify events
      expect(events.length, 2);
      expect(events.first, 'Partial');
      expect(events.last, 'Final content');
      
      // Verify final content is set
      expect(controller.content, 'Final content');
      
      controller.dispose();
    });

    test('StreamingMessageRegistry should handle cleanup on completion', () async {
      final registry = StreamingMessageRegistry();
      final messageId = 'completion-test';
      
      // Create controller
      final controller = registry.createController(messageId);
      controller.addContent('Some content');
      
      // Simulate completion
      controller.setFinalContent('Final content');
      
      // Clean up after completion
      registry.removeController(messageId);
      
      // Verify controller is removed
      expect(registry.getController(messageId), isNull);
    });
  });
} 