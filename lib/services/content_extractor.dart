import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../utils/logger.dart';

class ContentExtractor {
  Future<String> extractContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        Logger.error('Failed to fetch URL: ${response.statusCode}');
        return '';
      }

      final document = html_parser.parse(response.body);

      // Remove script and style elements
      document.querySelectorAll('script, style').forEach((element) {
        element.remove();
      });

      // Extract text content
      final text = document.body?.text ?? '';

      // Clean up whitespace
      final cleaned = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');

      return cleaned;
    } catch (e) {
      Logger.error('Content extraction error: $e');
      return '';
    }
  }
}
