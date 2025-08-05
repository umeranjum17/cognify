import 'dart:math' as math;

import '../models/chat_source.dart';
import '../utils/logger.dart';

/// Centralized tool result processing utility
/// Handles extraction of sources and images from tool results
/// Used by Executor Agent to process tool outputs - single source of truth
class ToolResultProcessor {
  static final ScopedLogger _logger = Logger.scope('ToolResultProcessor');
  
  /// Clean sources to remove any images that might have been accidentally added
  static List<ChatSource> cleanSources(List<ChatSource> sources) {
    return sources.where((s) => s.type != 'image').toList();
  }

  /// Deduplicate images by URL
  static List<Map<String, dynamic>> deduplicateImages(List<Map<String, dynamic>> images) {
    final uniqueImages = <Map<String, dynamic>>[];
    final seenUrls = <String>{};
    
    for (final image in images) {
      final url = image['url'] as String? ?? '';
      if (url.isNotEmpty && !seenUrls.contains(url)) {
        seenUrls.add(url);
        uniqueImages.add(image);
        _logger.trace('Added unique image: ${image['title'] ?? 'Image'} ($url)');
      } else {
        _logger.trace('Skipped duplicate image: ${image['title'] ?? 'Image'} ($url)');
      }
    }
    
    _logger.debug('Deduplicated ${images.length} images to ${uniqueImages.length} unique');
    return uniqueImages;
  }

  /// Deduplicate sources by URL
  static List<ChatSource> deduplicateSources(List<ChatSource> sources) {
    final uniqueSources = <ChatSource>[];
    final seenUrls = <String>{};
    
    for (final source in sources) {
      if (!seenUrls.contains(source.url)) {
        seenUrls.add(source.url);
        uniqueSources.add(source);
        _logger.trace('Added unique source: ${source.title} (${source.url})');
      } else {
        _logger.trace('Skipped duplicate source: ${source.title} (${source.url})');
      }
    }
    
    _logger.debug('Deduplicated ${sources.length} sources to ${uniqueSources.length} unique');
    return uniqueSources;
  }

  /// Extract sources and images from a single tool result
  /// This is the single source of truth for content extraction
  static Map<String, dynamic> extractSourcesAndImages(
    Map<String, dynamic> toolResult,
    String toolName
  ) {
    final sources = <ChatSource>[];
    final images = <Map<String, dynamic>>[];

    try {
      // Handle brave_search tool output format (URLs only, no content extraction)
      if (toolName == 'brave_search' || toolName == 'brave_search_enhanced') {
        if (toolResult['results'] != null && toolResult['results'] is List) {
          final results = toolResult['results'] as List<dynamic>;
          final braveSearchSources = results.map((result) {
            if (result is Map<String, dynamic>) {
              // Search tools only provide URLs, content comes from web_fetch
              return ChatSource(
                title: result['title'] ?? 'Search Result',
                url: result['url'] ?? '',
                description: result['description'] ?? '',
                type: result['type'] ?? 'web',
                content: null, // No content from search tools
                hasScrapedContent: false,
              );
            }
            return null;
          }).where((s) => s != null).cast<ChatSource>().toList();
          
          sources.addAll(braveSearchSources);
          _logger.debug('Extracted ${braveSearchSources.length} sources from $toolName (URLs only)');
        }
      }
      // Handle image_search tool output format
      else if (toolName == 'image_search' && toolResult['images'] != null && toolResult['images'] is List) {
        final imageResults = (toolResult['images'] as List<dynamic>).map((img) {
          if (img is Map<String, dynamic>) {
            return {
              'id': img['id'] ?? 'img_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}',
              'url': img['url'] ?? '',
              'thumbnail': img['thumbnail'] ?? img['url'] ?? '',
              'title': img['title'] ?? 'Image',
              'description': img['description'] ?? '',
              'source': img['source'] ?? img['url'] ?? '',
              'width': img['width'],
              'height': img['height'],
              'size': img['size'],
              'page_fetched': img['page_fetched'],
              'timestamp': DateTime.now().toIso8601String(),
              'toolSource': toolName
            };
          }
          return null;
        }).where((i) => i != null).cast<Map<String, dynamic>>().toList();
        
        images.addAll(imageResults);
        _logger.debug('Extracted ${imageResults.length} images from $toolName');
      }
      // Handle web_fetch tool
      else if (toolName == 'web_fetch' && toolResult['url'] != null) {
        final url = toolResult['url'] ?? '';
        final content = toolResult['content'];
        
        // Only add if we have content and haven't processed this URL before
        if (content != null && content.toString().isNotEmpty) {
          sources.add(ChatSource(
            title: toolResult['title'] ?? 'Fetched Content',
            url: url,
            description: toolResult['description'] ?? 'Web content',
            type: 'web',
            content: content, // Include scraped content
            hasScrapedContent: true,
          ));
          _logger.debug('Added web_fetch source with content: $url (${content.toString().length} chars)');
        } else {
          _logger.debug('Skipped web_fetch source without content: $url');
        }
      }
      // Handle youtube_processor tool
      else if (toolName == 'youtube_processor' && toolResult['url'] != null) {
        sources.add(ChatSource(
          title: toolResult['title'] ?? 'YouTube Video',
          url: toolResult['url'] ?? '',
          description: toolResult['description'] ?? 'YouTube video content',
          type: 'video',
          content: toolResult['content'], // Include scraped content if available
          hasScrapedContent: toolResult['content'] != null && toolResult['content'].toString().isNotEmpty,
        ));
      }
      // Handle keyword_extraction tool
      else if (toolName == 'keyword_extraction' && toolResult['keywords'] != null) {
        final keywords = toolResult['keywords'] as List<dynamic>? ?? [];
        if (keywords.isNotEmpty) {
          sources.add(ChatSource(
            title: 'Extracted Keywords',
            url: '',
            description: keywords.join(', '),
            type: 'text',
            content: keywords.join(', '), // Use keywords as content
            hasScrapedContent: true,
          ));
        }
      }
      // Handle other tools that have sources array
      else if (toolResult['sources'] != null && toolResult['sources'] is List) {
        final toolSources = (toolResult['sources'] as List<dynamic>).map((source) {
          if (source is Map<String, dynamic>) {
            return ChatSource(
              title: source['title'] ?? 'Source',
              url: source['url'] ?? '',
              description: source['description'] ?? '',
              type: source['type'] ?? 'web',
              content: source['content'], // Include scraped content if available
              hasScrapedContent: source['content'] != null && source['content'].toString().isNotEmpty,
            );
          }
          return null;
        }).where((s) => s != null).cast<ChatSource>().toList();
        
        sources.addAll(toolSources);
        _logger.debug('Extracted ${toolSources.length} sources from $toolName sources array');
      }
      // Handle generic tool results
      else if (toolResult['content'] != null) {
        sources.add(ChatSource(
          title: 'Tool Result',
          url: '',
          description: toolResult['content'].toString().substring(0, math.min(200, toolResult['content'].toString().length)),
          type: 'text',
          content: toolResult['content'].toString(), // Use full content
          hasScrapedContent: true,
        ));
        _logger.debug('Added generic content from $toolName');
      }

    } catch (error) {
      _logger.error('Error extracting sources/images from $toolName', error);
    }

    return {
      'sources': sources,
      'images': images,
    };
  }
}
