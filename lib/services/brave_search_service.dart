// Brave search service stub
class BraveSearchService {
  Future<void> initialize() async {}

  Future<Map<String, dynamic>> searchImages(String query, {int? count}) async {
    return {
      'success': true,
      'images': [],
    };
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    return [];
  }
}
