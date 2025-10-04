// Simplified content extractor stub
class ContentExtractor {
  Future<void> initialize() async {}

  Future<String> extractTextFromFile(String filePath) async {
    return '';
  }

  Future<Map<String, dynamic>> extractFromUrl(String url) async {
    return {'content': '', 'title': '', 'description': '', 'author': '', 'publishedDate': '', 'wordCount': 0, 'metadata': {}};
  }

  Future<Map<String, dynamic>> extractContent(String url) async {
    return extractFromUrl(url);
  }
}
