import 'package:markdown/markdown.dart' as md;
import 'package:html/parser.dart' as html_parser;

/// Utility functions for text processing and formatting
class TextUtils {
  /// Robust markdown-to-plain-text conversion using markdown AST.
  /// Preserves newlines and list bullets; removes formatting.
  static String stripMarkdown(String source) {
    if (source.trim().isEmpty) return '';

    final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = document.parseLines(source.split('\n'));
    final buffer = StringBuffer();
    final List<int> olStack = [];

    void walk(md.Node node, {String? parentTag}) {
      if (node is md.Text) {
        buffer.write(node.text);
        return;
      }
      if (node is md.Element) {
        final tag = node.tag;
        if (tag == 'br') {
          buffer.writeln();
          return;
        }
        if (tag == 'img') {
          final alt = node.attributes['alt'] ?? '';
          buffer.write(alt);
          return;
        }
        if (tag == 'hr') {
          buffer.writeln();
          buffer.writeln();
          return;
        }
        if (tag == 'ul' || tag == 'ol') {
          if (tag == 'ol') olStack.add(1);
          for (final child in node.children ?? const <md.Node>[]) {
            if (child is md.Element && child.tag == 'li') {
              if (tag == 'ol') {
                final index = olStack.isNotEmpty ? olStack.last : 1;
                buffer.write('$index. ');
                walk(child, parentTag: 'ol');
                if (olStack.isNotEmpty) olStack[olStack.length - 1]++;
              } else {
                buffer.write('• ');
                walk(child, parentTag: 'ul');
              }
              buffer.writeln();
            } else {
              walk(child, parentTag: tag);
            }
          }
          if (tag == 'ol' && olStack.isNotEmpty) olStack.removeLast();
          return;
        }
        final isBlock = <String>{
          'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
          'blockquote', 'pre', 'table', 'tr', 'td', 'th', 'code',
        }.contains(tag);
        for (final child in node.children ?? const <md.Node>[]) {
          walk(child, parentTag: tag);
        }
        if (isBlock) {
          buffer.writeln();
          if (tag == 'h1' || tag == 'h2') buffer.writeln();
        }
        return;
      }
    }

    for (final node in nodes) {
      walk(node);
    }

    var result = buffer
        .toString()
        .replaceAll(RegExp(r'\s+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    // Decode any HTML entities that may have slipped through
    result = html_parser.parseFragment(result).text ?? result;
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
