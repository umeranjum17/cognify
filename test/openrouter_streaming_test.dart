import 'package:cognify_flutter/models/streaming_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenRouter Streaming Test', () {
    test('Should handle real OpenRouter streaming data correctly', () async {
      final controller = StreamingMessageController('test-openrouter');
      final events = <String>[];
      
      // Subscribe to content stream
      controller.contentStream.listen((content) {
        events.add(content);
        print('📱 UI: Received content update: ${content.length} chars');
      });
      
      // Real OpenRouter streaming chunks from your data
      final openRouterChunks = [
        'Im',
        'ran',
        ' Khan',
        ' is',
        ' a',
        ' prominent',
        ' Pakistani',
        ' politician',
        '**:**',
        ' Ar',
        'rest',
        'ed',
        ' multiple',
        ' times',
        ' (',
        '2023',
        '–',
        '2024',
        ')',
        ' on',
        ' charges',
        ' including',
        ' corruption',
        ' and',
        ' terrorism',
        '.',
        '\n',
        '-',
        ' **',
        'Ass',
        'ass',
        'ination',
        ' Attempt',
        '**:',
        ' Sur',
        'v',
        'ived',
        ' a',
        ' shooting',
        ' in',
        ' November',
        ' ',
        '2023',
        ' and',
        ' popul',
        'ist',
        ' rhetoric',
        ',',
        ' Khan',
        ' has',
        ' a',
        ' significant',
        ' following',
        ' both',
        ' domest',
        'ically',
        ' and',
        ' among',
        ' the',
        ' Pakistani',
        ' dias',
        'pora',
        '.',
        '\n\n',
        'For',
        ' deeper',
        ' insights',
        ',',
        ' his',
        ' political',
        ' activism',
        ' and',
        ' cricket',
        ' achievements',
        ' remain',
        ' central',
        ' to',
        ' his',
        ' public',
        ' identity',
        '.',
        ' Would',
        ' you',
        ' like',
        ' details',
        ' on',
        ' a',
        ' specific',
        ' aspect',
        ' of',
        ' his',
        ' life',
        ' or',
        ' career',
        '?',
      ];
      
      // Simulate realistic streaming timing (like your OpenRouter data)
      for (final chunk in openRouterChunks) {
        controller.addContent(chunk);
        
        // Small delay to simulate real network streaming
        await Future.delayed(const Duration(milliseconds: 30));
      }
      
      // Wait for stream processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify that all chunks were received
      expect(events.length, greaterThan(0));
      
      // Verify the final content matches expected output
      final finalContent = controller.content;
      expect(finalContent, contains('Imran Khan'));
      expect(finalContent, contains('prominent Pakistani politician'));
      expect(finalContent, contains('Arrested multiple times'));
      expect(finalContent, contains('2023–2024'));
      expect(finalContent, contains('corruption and terrorism'));
      expect(finalContent, contains('Assassination Attempt'));
      expect(finalContent, contains('Survived a shooting'));
      expect(finalContent, contains('November 2023'));
      expect(finalContent, contains('populist rhetoric'));
      expect(finalContent, contains('significant following'));
      expect(finalContent, contains('domestically and among'));
      expect(finalContent, contains('Pakistani diaspora'));
      expect(finalContent, contains('political activism'));
      expect(finalContent, contains('cricket achievements'));
      expect(finalContent, contains('public identity'));
      expect(finalContent, contains('Would you like details'));
      
      print('✅ OpenRouter streaming test passed!');
      print('📊 Final content length: ${finalContent.length} chars');
      print('📊 Total events received: ${events.length}');
      print('📊 Expected chunks: ${openRouterChunks.length}');
    });
    
    test('Should handle rapid OpenRouter-style streaming without UI jank', () async {
      final controller = StreamingMessageController('test-rapid-openrouter');
      final events = <String>[];
      
      // Subscribe to content stream
      controller.contentStream.listen((content) {
        events.add(content);
      });
      
      // Simulate rapid OpenRouter streaming (like your data)
      final rapidChunks = [
        'Hello',
        ' there',
        '! How',
        ' are',
        ' you',
        ' doing',
        ' today',
        '?',
        ' I',
        ' hope',
        ' you',
        ' are',
        ' having',
        ' a',
        ' great',
        ' day',
        '.',
      ];
      
      // Add chunks rapidly (simulating fast OpenRouter streaming)
      for (final chunk in rapidChunks) {
        controller.addContent(chunk);
        // No delay - simulate fast streaming like your OpenRouter data
      }
      
      // Wait for stream processing
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify rapid streaming worked
      expect(events.length, greaterThan(0));
      expect(controller.content, equals('Hello there! How are you doing today? I hope you are having a great day.'));
      
      print('✅ Rapid OpenRouter streaming test passed!');
      print('📊 Events received: ${events.length}');
      print('📊 Final content: "${controller.content}"');
    });
    
    test('Should handle OpenRouter data format with empty content chunks', () async {
      final controller = StreamingMessageController('test-empty-chunks');
      final events = <String>[];
      
      // Subscribe to content stream
      controller.contentStream.listen((content) {
        events.add(content);
      });
      
      // Simulate OpenRouter data with empty chunks (like your data format)
      final chunksWithEmpty = [
        '', // Empty chunk (like role: assistant, content: "")
        'Im',
        'ran',
        ' Khan',
        ' is',
        ' a',
        ' prominent',
        ' Pakistani',
        ' politician',
        '', // Another empty chunk
        '**:**',
        ' Ar',
        'rest',
        'ed',
        ' multiple',
        ' times',
      ];
      
      // Add chunks including empty ones
      for (final chunk in chunksWithEmpty) {
        controller.addContent(chunk);
        await Future.delayed(const Duration(milliseconds: 20));
      }
      
      // Wait for stream processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify that empty chunks are handled correctly
      expect(events.length, greaterThan(0));
      expect(controller.content, contains('Imran Khan'));
      expect(controller.content, contains('prominent Pakistani politician'));
      expect(controller.content, contains('Arrested multiple times'));
      
      print('✅ OpenRouter empty chunks test passed!');
      print('📊 Events received: ${events.length}');
      print('📊 Final content: "${controller.content}"');
    });
    
    test('Should handle OpenRouter streaming with markdown formatting', () async {
      final controller = StreamingMessageController('test-markdown');
      final events = <String>[];
      
      // Subscribe to content stream
      controller.contentStream.listen((content) {
        events.add(content);
      });
      
      // Simulate OpenRouter streaming with markdown (like your data)
      final markdownChunks = [
        'Here',
        ' is',
        ' some',
        ' **bold',
        ' text**',
        ' and',
        ' *italic',
        ' text*',
        '.',
        '\n\n',
        '##',
        ' Heading',
        '\n\n',
        'This',
        ' is',
        ' a',
        ' paragraph',
        ' with',
        ' `code`',
        ' and',
        ' [links](https://example.com)',
        '.',
      ];
      
      // Add markdown chunks
      for (final chunk in markdownChunks) {
        controller.addContent(chunk);
        await Future.delayed(const Duration(milliseconds: 25));
      }
      
      // Wait for stream processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify markdown streaming worked
      expect(events.length, greaterThan(0));
      expect(controller.content, contains('**bold text**'));
      expect(controller.content, contains('*italic text*'));
      expect(controller.content, contains('## Heading'));
      expect(controller.content, contains('`code`'));
      expect(controller.content, contains('[links](https://example.com)'));
      
      print('✅ OpenRouter markdown streaming test passed!');
      print('📊 Events received: ${events.length}');
      print('📊 Final content: "${controller.content}"');
    });
  });
} 