import 'package:cognify_flutter/models/message.dart';
import 'package:cognify_flutter/models/tool_result.dart';
import 'package:cognify_flutter/services/agents/writer_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Writer Agent Prompt Length Analysis', () {
    test('should analyze prompt length breakdown', () {
      final writerAgent = WriterAgent(
        modelName: 'gpt-4o',
        mode: 'chat',
      );

      // Create sample tool results
      final toolResults = [
        ToolResult(
          tool: 'brave_search_enhanced',
          input: {'query': 'test query'},
          output: {
            'results': [
              {
                'title': 'Sample Search Result',
                'url': 'https://example.com',
                'description': 'A sample search result for testing',
              }
            ],
            'searchTerms': 'test query',
            'extractedImages': [
              {
                'title': 'Sample Image',
                'url': 'https://example.com/image.jpg',
                'description': 'A sample image',
                'source': 'search result',
              }
            ],
            'extractedSources': [
              {
                'title': 'Sample Source',
                'url': 'https://example.com/source',
                'description': 'A sample source',
                'content': 'This is a sample content that will be randomized for testing purposes. ' * 100, // 100 repetitions
                'hasScrapedContent': true,
              }
            ],
          },
          failed: false,
          executionTime: 1500,
          timestamp: DateTime.now().toIso8601String(),
          order: 1,
        ),
      ];

      // Create sample conversation history
      final conversationHistory = [
        Message(
          id: '1',
          type: 'user',
          content: 'Hello, this is a test message',
          timestamp: DateTime.now().toIso8601String(),
        ),
        Message(
          id: '2',
          type: 'assistant',
          content: 'Hi! I\'m here to help you with your questions.',
          timestamp: DateTime.now().toIso8601String(),
        ),
      ];

      // Test the prompt creation with analysis
      final prompt = writerAgent.createWritingPrompt(
        'What is the latest version of Flutter?',
        toolResults,
        'deepsearch',
        false,
        'Professional Expert',
        'English',
        conversationHistory,
      );

      // Verify the prompt was created (the analysis will be logged automatically)
      expect(prompt, isNotEmpty);
      expect(prompt.contains('**USER QUERY:**'), isTrue);
      expect(prompt.contains('**TOOL RESULTS:**'), isTrue);
      expect(prompt.contains('**SOURCES WITH SCRAPED CONTENT**'), isTrue);
      expect(prompt.contains('**AVAILABLE IMAGES FOR MARKDOWN INCLUSION:**'), isTrue);
      expect(prompt.contains('**🧠 DEEPSEARCH MODE - ADVANCED REASONING REQUIRED:**'), isTrue);
    });

    test('should handle empty tool results gracefully', () {
      final writerAgent = WriterAgent(
        modelName: 'gpt-4o',
        mode: 'chat',
      );

      final prompt = writerAgent.createWritingPrompt(
        'Simple test query',
        [], // Empty tool results
        'chat',
        false,
        'Default',
        'English',
        [], // Empty conversation history
      );

      expect(prompt, isNotEmpty);
      expect(prompt.contains('**USER QUERY:**'), isTrue);
      expect(prompt.contains('No tool results available'), isTrue);
    });

    test('should analyze different personality modes', () {
      final writerAgent = WriterAgent(
        modelName: 'gpt-4o',
        mode: 'chat',
      );

      final personalities = ['Default', 'Comedian', 'Macho Cool', 'Friendly Helper', 'Professional Expert'];
      
      for (final personality in personalities) {
        final prompt = writerAgent.createWritingPrompt(
          'Test query for $personality personality',
          [],
          'chat',
          false,
          personality,
          'English',
          [],
        );

        expect(prompt, isNotEmpty);
        expect(prompt.contains('**USER QUERY:**'), isTrue);
      }
    });

    test('should handle different languages', () {
      final writerAgent = WriterAgent(
        modelName: 'gpt-4o',
        mode: 'chat',
      );

      final languages = ['English', 'Urdu', 'Arabic', 'French'];
      
      for (final language in languages) {
        final prompt = writerAgent.createWritingPrompt(
          'Test query in $language',
          [],
          'chat',
          false,
          'Default',
          language,
          [],
        );

        expect(prompt, isNotEmpty);
        expect(prompt.contains('**USER QUERY:**'), isTrue);
      }
    });
  });
} 