import 'package:flutter_test/flutter_test.dart';
import 'package:cognify_flutter/models/source_type.dart';

void main() {
  group('SourceType Auto-Detection Tests', () {
    test('should detect YouTube URLs correctly', () {
      expect(SourceType.detectSourceType('https://youtube.com/watch?v=dQw4w9WgXcQ'), 'youtube');
      expect(SourceType.detectSourceType('https://youtu.be/dQw4w9WgXcQ'), 'youtube');
      expect(SourceType.detectSourceType('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'youtube');
      expect(SourceType.detectSourceType('https://m.youtube.com/watch?v=dQw4w9WgXcQ'), 'youtube');
      expect(SourceType.detectSourceType('https://youtube.com/shorts/dQw4w9WgXcQ'), 'youtube');
    });

    test('should detect Medium URLs correctly', () {
      expect(SourceType.detectSourceType('https://medium.com/@author/article-title'), 'medium');
      expect(SourceType.detectSourceType('https://www.medium.com/publication/article'), 'medium');
      expect(SourceType.detectSourceType('medium.com/article'), 'medium');
    });

    test('should detect Substack URLs correctly', () {
      expect(SourceType.detectSourceType('https://newsletter.substack.com/p/article'), 'substack');
      expect(SourceType.detectSourceType('https://author.substack.com/p/post'), 'substack');
      expect(SourceType.detectSourceType('something.substack.com'), 'substack');
    });

    test('should detect Reddit URLs correctly', () {
      expect(SourceType.detectSourceType('https://reddit.com/r/programming/comments/123'), 'reddit');
      expect(SourceType.detectSourceType('https://www.reddit.com/r/flutter'), 'reddit');
      expect(SourceType.detectSourceType('reddit.com/user/username'), 'reddit');
    });

    test('should detect GitHub URLs correctly', () {
      expect(SourceType.detectSourceType('https://github.com/flutter/flutter'), 'github');
      expect(SourceType.detectSourceType('https://www.github.com/user/repo'), 'github');
      expect(SourceType.detectSourceType('github.com/organization/project'), 'github');
    });

    test('should detect Blinkist URLs correctly', () {
      expect(SourceType.detectSourceType('https://blinkist.com/books/book-title'), 'blink');
      expect(SourceType.detectSourceType('https://www.blinkist.com/en/books/book'), 'blink');
      expect(SourceType.detectSourceType('blinkist.com/books'), 'blink');
    });

    test('should fallback to website for unknown URLs', () {
      expect(SourceType.detectSourceType('https://example.com/article'), 'website');
      expect(SourceType.detectSourceType('https://news.ycombinator.com'), 'website');
      expect(SourceType.detectSourceType('https://stackoverflow.com/questions/123'), 'website');
      expect(SourceType.detectSourceType('https://flutter.dev/docs'), 'website');
    });

    test('should handle case insensitive URLs', () {
      expect(SourceType.detectSourceType('HTTPS://YOUTUBE.COM/WATCH?V=123'), 'youtube');
      expect(SourceType.detectSourceType('HTTPS://MEDIUM.COM/ARTICLE'), 'medium');
      expect(SourceType.detectSourceType('HTTPS://GITHUB.COM/USER/REPO'), 'github');
    });

    test('should handle URLs without protocol', () {
      expect(SourceType.detectSourceType('youtube.com/watch?v=123'), 'youtube');
      expect(SourceType.detectSourceType('medium.com/article'), 'medium');
      expect(SourceType.detectSourceType('github.com/user/repo'), 'github');
    });

    test('should handle empty or invalid URLs', () {
      expect(SourceType.detectSourceType(''), 'website');
      expect(SourceType.detectSourceType('   '), 'website');
      expect(SourceType.detectSourceType('not-a-url'), 'website');
    });
  });
}
