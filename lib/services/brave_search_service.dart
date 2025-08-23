import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';

/// Direct Brave Search API client
class BraveSearchService {
  static final BraveSearchService _instance = BraveSearchService._internal();
  
  static const String baseUrl = 'https://api.search.brave.com/res/v1';
  static const String webSearchEndpoint = '/web/search';
  static const String imageSearchEndpoint = '/images/search';
  
  late final Dio _dio;
  bool _initialized = false;
  
  factory BraveSearchService() => _instance;
  BraveSearchService._internal();

  // Proxy function removed - using direct URLs in disabled security mode

  /// Get search suggestions (if supported by Brave API)
  Future<List<String>> getSuggestions(String query) async {
    await _ensureInitialized();
    
    try {
      // Brave Search API doesn't have a dedicated suggestions endpoint
      // Return empty list for now
      return [];
    } catch (e) {
      Logger.debug('Brave suggestions error: $e');
      return [];
    }
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
      },
    ));
    
    _initialized = true;
    Logger.debug('BraveSearchService initialized');
  }

  /// Check if Brave Search API is available
  Future<bool> isAvailable({String? apiKey}) async {
    await _ensureInitialized();
    
    try {
      final key = apiKey ?? await AppConfig().braveSearchApiKey ?? 'BSA6Crcr3bFuvfEOIgHdL-y7IO_YPqr';
      return key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Search using Brave Search API
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int count = 10,
    String? country,
    String? language,
    bool safesearch = true,
    String? apiKey,
  }) async {
    await _ensureInitialized();
    
    try {
      final key = apiKey ?? await AppConfig().braveSearchApiKey ?? 'BSA6Crcr3bFuvfEOIgHdL-y7IO_YPqr';
      if (key.isEmpty) {
        throw Exception('Brave Search API key not configured');
      }
      
      // Implement pagination: Brave supports max 20 per request. If count > 20,
      // perform multiple requests using the `offset` page parameter and merge results.
      final int requestedCount = count < 1 ? 1 : count;
      final int pageSize = 20;
      final int pages = ((requestedCount + pageSize - 1) / pageSize).floor();

      final List<Map<String, dynamic>> aggregated = [];
      final Set<String> seenUrls = {};

      for (int page = 0; page < pages; page++) {
        final int remaining = requestedCount - (page * pageSize);
        final int thisPageCount = remaining > pageSize ? pageSize : remaining;

        Logger.debug('Brave search service: Making API request for ' + '"' + query + '"' + ' page=' + page.toString() + ' count=' + thisPageCount.toString());
        final response = await _dio.get(
          webSearchEndpoint,
          queryParameters: {
            'q': query,
            'count': thisPageCount,
            'offset': page, // Brave pagination uses zero-based offset pages
            if (country != null) 'country': country,
            if (language != null) 'search_lang': language,
            'safesearch': safesearch ? 'strict' : 'off',
          },
          options: Options(
            headers: {
              'X-Subscription-Token': key,
            },
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          List<dynamic> results = [];
          if (data['web'] != null && data['web']['results'] != null) {
            results = data['web']['results'] as List<dynamic>;
          } else if (data['results'] != null) {
            results = data['results'] as List<dynamic>;
          } else {
            continue;
          }

          for (final item in results) {
            final url = (item['url'] ?? '') as String;
            if (url.isEmpty || seenUrls.contains(url)) continue;
            seenUrls.add(url);
            aggregated.add({
              'title': item['title'] ?? '',
              'url': url,
              'description': item['description'] ?? '',
              'source': item['source'] ?? '',
            });
            if (aggregated.length >= requestedCount) break;
          }
        } else {
          Logger.warn('Brave search service: API error status: ${response.statusCode}');
          throw Exception('Brave Search API error: ${response.statusCode}');
        }

        if (aggregated.length >= requestedCount) break;
      }

      Logger.debug('Brave search service: Returning ${aggregated.length} processed results');
      return aggregated;
    } catch (e) {
      Logger.error('Brave search error: $e');
      return [];
    }
  }

  /// Search for images using Brave Search API
  Future<Map<String, dynamic>> searchImages(
    String query, {
    int count = 10,
    String? country,
    String? language,
    bool safesearch = true,
    String? apiKey,
  }) async {
    await _ensureInitialized();
    
    try {
      final key = apiKey ?? await AppConfig().braveSearchApiKey ?? 'BSA6Crcr3bFuvfEOIgHdL-y7IO_YPqr';
      if (key.isEmpty) {
        throw Exception('Brave Search API key not configured');
      }
      // Clamp count to Brave API limit (max 20)
      final int requestedCount = count;
      final int clampedCount = requestedCount < 1
          ? 1
          : (requestedCount > 20 ? 20 : requestedCount);
      if (clampedCount != requestedCount) {
        Logger.debug('Brave image search: clamping count from ' + requestedCount.toString() + ' to ' + clampedCount.toString(), tag: 'BraveSearch');
      }
      
      final response = await _dio.get(
        imageSearchEndpoint,
        queryParameters: {
          'q': query,
          'count': clampedCount,
          if (country != null) 'country': country,
          if (language != null) 'search_lang': language,
          'safesearch': safesearch ? 'strict' : 'off',
        },
        options: Options(
          headers: {
            'X-Subscription-Token': key,
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final results = data['results'] ?? [];
        
        return {
          'success': true,
          'images': results.map((result) {
            // Prefer direct URLs over Brave proxy URLs for better reliability
            // properties.url is the direct image URL, thumbnail.src is Brave's proxy URL
            final originalImageUrl = result['properties']?['url'] ?? result['src'] ?? '';
            final originalThumbnailUrl = result['properties']?['url'] ?? result['src'] ?? '';

            if (originalImageUrl.isEmpty) {
              return null; // Skip images without valid URLs
            }

            return {
              'url': originalImageUrl,
              'thumbnail': originalThumbnailUrl,
              'title': result['title'] ?? 'Image',
              'description': result['description'] ?? '',
              'source': result['page_url'] ?? result['url'] ?? '', // result.url is the page URL
              'width': result['properties']?['width'] ?? result['thumbnail']?['width'],
              'height': result['properties']?['height'] ?? result['thumbnail']?['height'],
              'size': result['properties']?['size'],
              'page_fetched': result['page_fetched'],
              'confidence': result['confidence'] ?? 'unknown'
            };
          }).where((img) => img != null).toList(), // Remove null entries
          'query': query,
          'total': results.length,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } catch (e) {
      Logger.error('🔍 Brave image search error: $e', tag: 'BraveSearch');
      return {
        'success': false,
        'error': e.toString(),
        'images': [],
        'query': query,
        'total': 0,
      };
    }
  }

  /// Search the web using Brave Search API
  Future<Map<String, dynamic>> searchWeb(
    String query, {
    int count = 10,
    String? country,
    String? language,
    bool safesearch = true,
    String? apiKey,
  }) async {
    await _ensureInitialized();
    
    try {
      final key = apiKey ?? await AppConfig().braveSearchApiKey ?? 'BSA6Crcr3bFuvfEOIgHdL-y7IO_YPqr';
      if (key.isEmpty) {
        throw Exception('Brave Search API key not configured');
      }
      // Pagination-aware implementation up to requested count
      final int requestedCount = count < 1 ? 1 : count;
      final int pageSize = 20;
      final int pages = ((requestedCount + pageSize - 1) / pageSize).floor();

      final List<Map<String, dynamic>> aggregated = [];
      final Set<String> seenUrls = {};

      for (int page = 0; page < pages; page++) {
        final int remaining = requestedCount - (page * pageSize);
        final int thisPageCount = remaining > pageSize ? pageSize : remaining;

        final response = await _dio.get(
          webSearchEndpoint,
          queryParameters: {
            'q': query,
            'count': thisPageCount,
            'offset': page,
            if (country != null) 'country': country,
            if (language != null) 'search_lang': language,
            'safesearch': safesearch ? 'strict' : 'off',
          },
          options: Options(
            headers: {
              'X-Subscription-Token': key,
            },
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final current = (data['web']?['results'] ?? []) as List<dynamic>;
          for (final result in current) {
            final url = (result['url'] ?? '') as String;
            if (url.isEmpty || seenUrls.contains(url)) continue;
            seenUrls.add(url);
            aggregated.add({
              'title': result['title'] ?? '',
              'url': url,
              'description': result['description'] ?? '',
              'published': result['age'] ?? '',
            });
            if (aggregated.length >= requestedCount) break;
          }
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
        }

        if (aggregated.length >= requestedCount) break;
      }

      return {
        'success': true,
        'results': aggregated,
        'query': query,
        'total': aggregated.length,
      };
    } catch (e) {
      Logger.error('🔍 Brave web search error: $e', tag: 'BraveSearch');
      return {
        'success': false,
        'error': e.toString(),
        'results': [],
        'query': query,
        'total': 0,
      };
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
