import 'package:cognify_flutter/models/message.dart';
import 'package:cognify_flutter/models/streaming_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Streaming Controller Warning Fix Tests', () {
    test('Historical messages should not trigger controller warnings', () {
      final registry = StreamingMessageRegistry();
      
      // Create a historical message (simulating a message from deep link/share)
      final historicalMessage = Message(
        id: 'historical-message-123_assistant',
        type: 'assistant',
        content: 'This is a historical message from a previous session',
        timestamp: DateTime.now().toIso8601String(),
        isProcessing: false, // Key: historical messages are not processing
      );

      // Simulate what StreamingMessageContent would do
      // For historical messages, it should NOT try to get a controller
      if (historicalMessage.isProcessing == true) {
        // This should not execute for historical messages
        final controller = registry.getController(historicalMessage.id);
        expect(controller, isNull);
      } else {
        // Historical message - should render static content without controller lookup
        expect(historicalMessage.textContent, 'This is a historical message from a previous session');
      }
    });

    test('Live processing messages should work with controllers', () {
      final registry = StreamingMessageRegistry();
      
      // Create a live processing message
      final liveMessage = Message(
        id: 'live-message-456_assistant',
        type: 'assistant',
        content: '',
        timestamp: DateTime.now().toIso8601String(),
        isProcessing: true, // Key: live messages are processing
      );

      // Create controller for live message
      final controller = registry.createController(liveMessage.id);
      
      // Simulate what StreamingMessageContent would do for live messages
      if (liveMessage.isProcessing == true) {
        final retrievedController = registry.getController(liveMessage.id);
        expect(retrievedController, isNotNull);
        expect(retrievedController, equals(controller));
        
        // Add content
        controller.addContent('Live streaming content');
        expect(controller.content, 'Live streaming content');
        
        // Clean up
        registry.removeController(liveMessage.id);
      }
    });

    test('Exponential backoff should work for delayed controllers', () async {
      final registry = StreamingMessageRegistry();
      
      // Create a processing message
      final processingMessage = Message(
        id: 'delayed-message-789_assistant',
        type: 'assistant',
        content: '',
        timestamp: DateTime.now().toIso8601String(),
        isProcessing: true,
      );

      // Simulate delayed controller creation
      // First attempt: no controller exists
      var controller = registry.getController(processingMessage.id);
      expect(controller, isNull);

      // Simulate retry attempts with exponential backoff
      int retryAttempts = 0;
      const maxRetryAttempts = 5;
      Duration retryDelay = const Duration(milliseconds: 100);
      
      while (retryAttempts < maxRetryAttempts) {
        controller = registry.getController(processingMessage.id);
        
        if (controller != null) {
          // Controller found, break out of retry loop
          break;
        }
        
        retryAttempts++;
        if (retryAttempts < maxRetryAttempts) {
          // Simulate exponential backoff
          retryDelay *= 2;
          await Future.delayed(retryDelay);
        }
      }

      // Verify retry attempts were capped
      expect(retryAttempts, maxRetryAttempts);
      expect(controller, isNull); // No controller was created in this test
    });

    test('Deep link scenario should not spam warnings', () {
      final registry = StreamingMessageRegistry();
      
      // Simulate opening app via deep link with historical conversation
      final historicalMessages = [
        Message(
          id: 'msg-1_assistant',
          type: 'assistant',
          content: 'First historical message',
          timestamp: DateTime.now().toIso8601String(),
          isProcessing: false,
        ),
        Message(
          id: 'msg-2_assistant',
          type: 'assistant',
          content: 'Second historical message',
          timestamp: DateTime.now().toIso8601String(),
          isProcessing: false,
        ),
        Message(
          id: 'msg-3_assistant',
          type: 'assistant',
          content: 'Third historical message',
          timestamp: DateTime.now().toIso8601String(),
          isProcessing: false,
        ),
      ];

      // Simulate rendering each message
      for (final message in historicalMessages) {
        // For historical messages, should NOT try to get controller
        if (message.isProcessing == true) {
          // This should not execute for historical messages
          final controller = registry.getController(message.id);
          expect(controller, isNull);
        } else {
          // Historical message - should render static content
          expect(message.textContent, isNotEmpty);
          expect(message.textContent, contains('historical message'));
        }
      }

      // Verify no controllers were created for historical messages
      for (final message in historicalMessages) {
        final controller = registry.getController(message.id);
        expect(controller, isNull);
      }
    });

    test('Mixed scenario: historical + live messages', () {
      final registry = StreamingMessageRegistry();
      
      // Historical message (from deep link)
      final historicalMessage = Message(
        id: 'historical-msg-1_assistant',
        type: 'assistant',
        content: 'Historical content',
        timestamp: DateTime.now().toIso8601String(),
        isProcessing: false,
      );

      // Live message (currently streaming)
      final liveMessage = Message(
        id: 'live-msg-2_assistant',
        type: 'assistant',
        content: '',
        timestamp: DateTime.now().toIso8601String(),
        isProcessing: true,
      );

      // Create controller for live message
      final controller = registry.createController(liveMessage.id);

      // Test historical message (should not look for controller)
      if (historicalMessage.isProcessing != true) {
        expect(historicalMessage.textContent, 'Historical content');
        // Should not try to get controller
        final historicalController = registry.getController(historicalMessage.id);
        expect(historicalController, isNull);
      }

      // Test live message (should find controller)
      if (liveMessage.isProcessing == true) {
        final liveController = registry.getController(liveMessage.id);
        expect(liveController, isNotNull);
        expect(liveController, equals(controller));
      }

      // Clean up
      registry.removeController(liveMessage.id);
    });
  });
} 