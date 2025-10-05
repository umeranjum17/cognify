import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class BraveSearchService {
  static const String _baseUrl = 'https://api.search.brave.com/res/v1';

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int count = 5,
    String? apiKey,
  }) async {
    try {
      if (apiKey == null || apiKey.isEmpty) {
        Logger.warn('No Brave API key provided, returning empty results');
        return [];
      }

      final uri = Uri.parse('$_baseUrl/web/search').replace(
        queryParameters: {
          'q': query,
          'count': count.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
          'X-Subscription-Token': apiKey,
        },
      );

      if (response.statusCode != 200) {
        Logger.error('Brave search failed with status ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final webResults = data['web']?['results'] as List<dynamic>? ?? [];

      return webResults.map((result) {
        return {
          'title': result['title'] ?? '',
          'url': result['url'] ?? '',
          'description': result['description'] ?? '',
        };
      }).toList();
    } catch (e) {
      Logger.error('Brave search error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> searchImages(
    String query, {
    int count = 5,
    String? apiKey,
  }) async {
    try {
      if (apiKey == null || apiKey.isEmpty) {
        Logger.warn('No Brave API key provided, returning empty results');
        return {'images': []};
      }

      final uri = Uri.parse('$_baseUrl/images/search').replace(
        queryParameters: {
          'q': query,
          'count': count.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
          'X-Subscription-Token': apiKey,
        },
      );

      if (response.statusCode != 200) {
        Logger.error('Brave image search failed with status ${response.statusCode}');
        return {'images': []};
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final imageResults = data['results'] as List<dynamic>? ?? [];

      final images = imageResults.map((result) {
        return {
          'title': result['title'] ?? '',
          'url': result['url'] ?? '',
          'thumbnail': result['thumbnail']?['src'] ?? '',
          'source': result['source'] ?? '',
        };
      }).toList();

      return {'images': images};
    } catch (e) {
      Logger.error('Brave image search error: $e');
      return {'images': []};
    }
  }
}
