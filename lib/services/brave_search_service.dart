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
      
      Logger.debug('Brave search service: Making API request for "$query"');
      final response = await _dio.get(
        webSearchEndpoint,
        queryParameters: {
          'q': query,
          'count': count,
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
        Logger.debug('Brave search service: API response status: ${response.statusCode}');
        Logger.debug('Brave search service: API response data keys: ${data.keys.toList()}');
        
        // Handle the complex API response structure
        List<dynamic> results = [];
        
        // Check if there's a 'web' section with results
        if (data['web'] != null && data['web']['results'] != null) {
          results = data['web']['results'] as List<dynamic>;
          Logger.debug('Brave search service: Found ${results.length} web results');
        } else if (data['results'] != null) {
          // Fallback to direct results
          results = data['results'] as List<dynamic>;
                      Logger.debug('Brave search service: Found ${results.length} direct results');
          } else {
            Logger.debug('Brave search service: No results found in API response');
          return [];
        }
        
        final processedResults = results.map<Map<String, dynamic>>((result) => {
          'title': result['title'] ?? '',
          'url': result['url'] ?? '',
          'description': result['description'] ?? '',
          'source': result['source'] ?? '',
        }).toList();
        
        Logger.debug('Brave search service: Returning ${processedResults.length} processed results');
        return processedResults;
      } else {
        Logger.warn('Brave search service: API error status: ${response.statusCode}');
        throw Exception('Brave Search API error: ${response.statusCode}');
      }
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
      
      final response = await _dio.get(
        imageSearchEndpoint,
        queryParameters: {
          'q': query,
          'count': count,
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
      
      final response = await _dio.get(
        webSearchEndpoint,
        queryParameters: {
          'q': query,
          'count': count,
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
        final results = data['web']?['results'] ?? [];
        
        return {
          'success': true,
          'results': results.map((result) => {
            'title': result['title'] ?? '',
            'url': result['url'] ?? '',
            'description': result['description'] ?? '',
            'published': result['age'] ?? '',
          }).toList(),
          'query': query,
          'total': results.length,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
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
