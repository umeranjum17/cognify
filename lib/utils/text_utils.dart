/// Utility functions for text processing and formatting
class TextUtils {
  /// Strips markdown formatting from text while preserving structure
  /// Converts markdown to clean, readable plain text
  static String stripMarkdown(String text) {
    String result = text;

    // Remove code blocks (```code```) but keep the code content
    result = result.replaceAllMapped(
      RegExp(r'```[\w]*\n([\s\S]*?)```', multiLine: true),
      (match) => '\n${match.group(1)?.trim() ?? ''}\n',
    );

    // Remove inline code backticks (`code`)
    result = result.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // Remove bold (**text** or __text__)
    result = result.replaceAll(RegExp(r'\*\*([^\*]+)\*\*'), r'$1');
    result = result.replaceAll(RegExp(r'__([^_]+)__'), r'$1');

    // Remove italic (*text* or _text_)
    result = result.replaceAll(RegExp(r'\*([^\*]+)\*'), r'$1');
    result = result.replaceAll(RegExp(r'_([^_]+)_'), r'$1');

    // Remove strikethrough (~~text~~)
    result = result.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');

    // Remove headers (# Header)
    result = result.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // Remove blockquotes (> quote)
    result = result.replaceAll(RegExp(r'^>\s+', multiLine: true), '');

    // Remove horizontal rules (---, ___, ***)
    result = result.replaceAll(RegExp(r'^[\-_\*]{3,}$', multiLine: true), '');

    // Convert markdown links [text](url) to just text
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (match) => match.group(1) ?? '',
    );

    // Remove image syntax ![alt](url)
    result = result.replaceAll(RegExp(r'!\[([^\]]*)\]\([^\)]+\)'), r'$1');

    // Remove list markers (-, *, +, 1.)
    result = result.replaceAll(RegExp(r'^[\s]*[-\*\+]\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^[\s]*\d+\.\s+', multiLine: true), '');

    // Clean up multiple blank lines (more than 2 consecutive)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Trim leading/trailing whitespace
    result = result.trim();

    return result;
  }

  /// Extracts all code blocks from markdown text
  /// Returns list of maps with language and code
  static List<Map<String, String>> extractCodeBlocks(String text) {
    final List<Map<String, String>> codeBlocks = [];
    final regex = RegExp(r'```([\w]*)\n([\s\S]*?)```', multiLine: true);
    final matches = regex.allMatches(text);

    for (final match in matches) {
      codeBlocks.add({
        'language': match.group(1)?.trim() ?? '',
        'code': match.group(2)?.trim() ?? '',
      });
    }

    return codeBlocks;
  }

  /// Extracts only code content (all code blocks concatenated)
  static String extractCodeOnly(String text) {
    final codeBlocks = extractCodeBlocks(text);
    if (codeBlocks.isEmpty) return '';

    return codeBlocks
        .map((block) => block['code'] ?? '')
        .where((code) => code.isNotEmpty)
        .join('\n\n---\n\n');
  }

  /// Checks if text contains code blocks
  static bool hasCodeBlocks(String text) {
    return RegExp(r'```[\w]*\n[\s\S]*?```', multiLine: true).hasMatch(text);
  }

  /// Counts the number of code blocks in text
  static int countCodeBlocks(String text) {
    return RegExp(r'```[\w]*\n[\s\S]*?```', multiLine: true)
        .allMatches(text)
        .length;
  }

  /// Truncates text to a maximum length with ellipsis
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}
