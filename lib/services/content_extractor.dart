import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../config/app_config.dart';
import '../utils/helpers.dart';

/// Content extraction service for web URLs and various content types
class ContentExtractor {
  static final ContentExtractor _instance = ContentExtractor._internal();
  late final Dio _dio;
  bool _initialized = false;

  factory ContentExtractor() => _instance;
  ContentExtractor._internal();

  /// Extract content from a URL (alias for extractFromUrl)
  Future<String> extractContent(String url) async {
    final result = await extractFromUrl(url);
    return result['content'] ?? result['text'] ?? '';
  }

  /// Extract content from a URL
  Future<Map<String, dynamic>> extractFromUrl(String url) async {
    await _ensureInitialized();
    
    try {
      print('🌐 Extracting content from URL: $url');
      
      // Determine content type and use appropriate extraction method
      if (_isYouTubeUrl(url)) {
        return await _extractYouTubeContent(url);
      } else if (_isRedditUrl(url)) {
        return await _extractRedditContent(url);
      } else if (_isMediumUrl(url)) {
        return await _extractMediumContent(url);
      } else if (_isGitHubUrl(url)) {
        return await _extractGitHubContent(url);
      } else {
        return await _extractGenericWebContent(url);
      }
      
    } catch (e) {
      print('🌐 Failed to extract content from URL: $url - $e');
      return {
        'error': e.toString(),
        'url': url,
        'extractedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    _dio = Dio(BaseOptions(
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      // Remove User-Agent header to avoid CORS issues in web
    ));
    
    _initialized = true;
    print('🌐 ContentExtractor initialized');
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  String _extractAuthor(dom.Document document) {
    return document.querySelector('meta[name="author"]')?.attributes['content'] ?? 
           document.querySelector('[rel="author"]')?.text ?? 
           '';
  }

  String _extractCleanText(dom.Document document) {
    // Remove noise elements first (aligned with server-side)
    document.querySelectorAll('script, style, noscript, iframe, object, embed, nav, footer, header, .sidebar, .ad, .related, .comments').forEach((element) {
      element.remove();
    });
    
    return _cleanElementText(document.body);
  }

  String _extractDescription(dom.Document document) {
    return document.querySelector('meta[name="description"]')?.attributes['content'] ?? 
           document.querySelector('meta[property="og:description"]')?.attributes['content'] ?? 
           '';
  }

  /// Extract content from generic web pages
  Future<Map<String, dynamic>> _extractGenericWebContent(String url) async {
    try {
      final response = await _dio.get(url);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: Failed to fetch content');
      }
      
      final htmlContent = response.data as String;
      final document = html_parser.parse(htmlContent);
      
      // Extract basic metadata
      final title = _extractTitle(document);
      final description = _extractDescription(document);
      final author = _extractAuthor(document);
      final publishedDate = _extractPublishedDate(document);
      
      // Extract main content
      final mainContent = _extractMainContent(document);
      final extractedText = _extractCleanText(document);
      
      // Use main content if available, otherwise fall back to cleaned body text
      final finalContent = mainContent.isNotEmpty ? mainContent : extractedText;
      
      // Extract images
      final images = _extractImages(document, url);
      
      // Extract links
      final links = _extractLinks(document, url);
      
      return {
        'url': url,
        'title': title,
        'description': description,
        'author': author,
        'publishedDate': publishedDate,
        'content': finalContent,
        'extractedText': finalContent,
        'images': images,
        'links': links,
        'wordCount': finalContent.split(RegExp(r'\s+')).length,
        'extractedAt': DateTime.now().toIso8601String(),
        'contentType': 'web_page',
        'metadata': {
          'domain': Helpers.extractDomain(url),
          'responseHeaders': response.headers.map,
        }
      };
      
    } catch (e) {
      throw Exception('Failed to extract web content: $e');
    }
  }

  /// Extract GitHub repository or file content
  Future<Map<String, dynamic>> _extractGitHubContent(String url) async {
    try {
      final response = await _dio.get(url);
      final document = html_parser.parse(response.data);
      
      // Extract repository information
      final title = document.querySelector('h1 strong a')?.text ?? _extractTitle(document);
      final description = document.querySelector('[data-pjax="#repo-content-pjax-container"] p')?.text ?? '';
      
      // Extract README content if available
      final readmeContent = document.querySelector('.markdown-body')?.text ?? '';
      
      return {
        'url': url,
        'title': title,
        'description': description,
        'content': readmeContent,
        'extractedText': '$title\n\n$description\n\n$readmeContent',
        'contentType': 'github_repository',
        'extractedAt': DateTime.now().toIso8601String(),
        'metadata': {
          'platform': 'github',
        }
      };
      
    } catch (e) {
      throw Exception('Failed to extract GitHub content: $e');
    }
  }

  List<String> _extractImages(dom.Document document, String baseUrl) {
    final images = <String>[];
    final imgElements = document.querySelectorAll('img[src]');
    
    for (final img in imgElements) {
      final src = img.attributes['src'];
      if (src != null) {
        final absoluteUrl = _makeAbsoluteUrl(src, baseUrl);
        if (absoluteUrl != null) {
          images.add(absoluteUrl);
        }
      }
    }
    
    return images;
  }

  List<Map<String, String>> _extractLinks(dom.Document document, String baseUrl) {
    final links = <Map<String, String>>[];
    final linkElements = document.querySelectorAll('a[href]');
    
    for (final link in linkElements) {
      final href = link.attributes['href'];
      final text = link.text.trim();
      
      if (href != null && text.isNotEmpty) {
        final absoluteUrl = _makeAbsoluteUrl(href, baseUrl);
        if (absoluteUrl != null) {
          links.add({
            'url': absoluteUrl,
            'text': text,
          });
        }
      }
    }
    
    return links;
  }

  String _extractMainContent(dom.Document document) {
    // Remove noise elements first (aligned with server-side)
    document.querySelectorAll('script, style, noscript, iframe, object, embed, nav, footer, header, .sidebar, .ad, .related, .comments').forEach((element) {
      element.remove();
    });
    
    // Enhanced candidate selectors in order of preference (aligned with server-side)
    final candidateSelectors = [
      // High-priority content containers
      'article', 'main', '[role="main"]', '.main-content', '.primary-content',
      
      // Common content classes
      '.content', '.post', '.entry', '.article', '.story', '.page-content',
      '.article-body', '.story-content', '.post-content', '.entry-content',
      '.text-content', '.body-content', '.main-text', '.article-text',
      
      // Blog and CMS patterns
      '.post-body', '.article-content', '.story-body', '.content-body',
      '.entry-body', '.page-body', '.blog-content', '.blog-post',
      
      // Documentation patterns
      '.documentation', '.docs', '.guide', '.tutorial', '.reference',
      
      // News and media patterns
      '.news-content', '.media-content', '.editorial-content',
      
      // Generic containers
      '.container', '.wrapper', '.inner', '.content-wrapper',
      
      // Semantic HTML5
      'section', 'div[class*="content"]', 'div[class*="text"]',
      
      // Last resort
      'div'
    ];
    
    // Extract all potential content blocks with scoring
    final candidates = <Map<String, dynamic>>[];
    
    for (final selector in candidateSelectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final text = _cleanElementText(element);
        if (text.length > 50) {
          final score = _scoreContentBlock(element, text);
          candidates.add({
            'text': text,
            'score': score,
            'length': text.length,
            'element': element,
            'selector': selector
          });
        }
      }
    }
    
    // Sort by score and length (aligned with server-side)
    candidates.sort((a, b) {
      if ((a['score'] - b['score']).abs() < 100) {
        return b['length'] - a['length']; // Prefer longer content if scores are close
      }
      return b['score'] - a['score'];
    });
    
    // If we have a high-scoring candidate, use it
    if (candidates.isNotEmpty && candidates[0]['score'] > 300) {
      return candidates[0]['text'];
    }
    
    // Otherwise, try to combine multiple good candidates
    String combinedContent = '';
    int totalScore = 0;
    
    for (final candidate in candidates.take(3)) { // Top 3 candidates
      if (candidate['score'] > 200 || candidate['length'] > 1000) {
        if (combinedContent.isNotEmpty && !combinedContent.contains(candidate['text'].substring(0, math.min(100, candidate['text'].length)))) {
          combinedContent += '\n\n${candidate['text']}';
        } else if (combinedContent.isEmpty) {
          combinedContent = candidate['text'];
        }
        totalScore += candidate['score'] as int;
      }
    }
    
    return combinedContent.isNotEmpty ? combinedContent : (candidates.isNotEmpty ? candidates[0]['text'] : '');
  }
  
  String _cleanElementText(dom.Element? element) {
    if (element == null) return '';
    
    // Remove script, style, nav, header, footer elements
    element.querySelectorAll('script, style, nav, header, footer, .nav, .header, .footer, .sidebar, .advertisement, .ads').forEach((el) {
      el.remove();
    });
    
    // Get clean text with proper spacing
    final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
  
  /// Enhanced content scoring algorithm (aligned with server-side)
  int _scoreContentBlock(dom.Element element, String text) {
    if (text.isEmpty || text.length < 50) return 0;
    
    double score = math.log(text.length) * 100; // Logarithmic base score
    
    // Get element attributes
    final tagName = element.localName?.toLowerCase() ?? '';
    final className = element.attributes['class'] ?? '';
    final id = element.attributes['id'] ?? '';
    final attributes = '$tagName $className $id';
    
    // Universal positive indicators
    final positivePatterns = RegExp(r'article|main|content|post|entry|story|body|text|description', caseSensitive: false);
    if (positivePatterns.hasMatch(attributes)) {
      score += 500;
    }
    
    // Structure analysis
    final headings = element.querySelectorAll('h1,h2,h3,h4,h5,h6').length;
    final paragraphs = element.querySelectorAll('p').length;
    final lists = element.querySelectorAll('ul,ol,dl').length;
    final codeBlocks = element.querySelectorAll('pre,code,.highlight,.code-block').length;
    final images = element.querySelectorAll('img').length;
    final tables = element.querySelectorAll('table').length;
    
    // Content structure bonuses
    score += headings * 40;      // Headings are very important for structure
    score += paragraphs * 30;    // Paragraphs indicate substantial content
    score += lists * 25;         // Lists often contain valuable information
    score += codeBlocks * 35;    // Code blocks are highly valuable
    score += images * 10;        // Images add content value
    score += tables * 20;        // Tables often contain structured data
    
    // Content quality indicators
    final sentences = text.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 10).toList();
    final words = text.split(RegExp(r'\s+')).length;
    final avgSentenceLength = words / math.max(sentences.length, 1);
    
    // Reward good sentence structure
    if (avgSentenceLength > 8 && avgSentenceLength < 25) {
      score += 200; // Good readability
    }
    
    // Reward content with good information density
    final infoWords = RegExp(r'\b(the|and|or|but|however|therefore|because|since|when|where|what|how|why|who)\b', caseSensitive: false).allMatches(text.toLowerCase()).length;
    final infoRatio = infoWords / words;
    if (infoRatio > 0.05 && infoRatio < 0.15) {
      score += 150; // Good information density
    }
    
    // Universal negative indicators
    final negativePatterns = RegExp(r'nav|footer|header|sidebar|ad|advertisement|cookie|banner|popup|modal|share|social|menu|breadcrumb|pagination|related|similar|recommended|trending', caseSensitive: false);
    if (negativePatterns.hasMatch(attributes)) {
      score -= 400;
    }
    
    // Link density penalty
    final links = element.querySelectorAll('a').length;
    final linkDensity = links / math.max(text.length / 100, 1);
    if (linkDensity > 0.4) score -= linkDensity * 200;
    
    // Penalty for very short content
    if (text.length < 200) score *= 0.7;
    
    // Bonus for substantial content
    if (text.length > 2000) score += 300;
    if (text.length > 5000) score += 500;
    
    // Penalty for repetitive content
    final uniqueWords = text.toLowerCase().split(RegExp(r'\s+')).toSet().length;
    final repetitionRatio = uniqueWords / words;
    if (repetitionRatio < 0.3) score *= 0.8; // High repetition penalty
    
    return math.max(0, score.round());
  }

  /// Extract Medium article content
  Future<Map<String, dynamic>> _extractMediumContent(String url) async {
    try {
      // Medium articles can be extracted like regular web content
      // but with specific selectors for better content extraction
      final response = await _dio.get(url);
      final document = html_parser.parse(response.data);
      
      // Medium-specific selectors
      final title = document.querySelector('h1')?.text ?? _extractTitle(document);
      final author = document.querySelector('[data-testid="authorName"]')?.text ?? _extractAuthor(document);
      
      // Extract article content
      final contentElements = document.querySelectorAll('article p, article h1, article h2, article h3');
      final content = contentElements.map((e) => e.text).join('\n\n');
      
      return {
        'url': url,
        'title': title,
        'author': author,
        'content': content,
        'extractedText': content,
        'contentType': 'medium_article',
        'extractedAt': DateTime.now().toIso8601String(),
        'metadata': {
          'platform': 'medium',
        }
      };
      
    } catch (e) {
      throw Exception('Failed to extract Medium content: $e');
    }
  }

  String? _extractPublishedDate(dom.Document document) {
    final dateSelectors = [
      'meta[property="article:published_time"]',
      'meta[name="date"]',
      'time[datetime]',
      '.published',
      '.date',
    ];
    
    for (final selector in dateSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final dateStr = element.attributes['content'] ?? 
                       element.attributes['datetime'] ?? 
                       element.text;
        if (dateStr.isNotEmpty) {
          return dateStr;
        }
      }
    }
    
    return null;
  }

  /// Extract Reddit post content
  Future<Map<String, dynamic>> _extractRedditContent(String url) async {
    try {
      // Add .json to Reddit URL for API access
      final jsonUrl = url.endsWith('/') ? '$url.json' : '$url.json';
      
      final response = await _dio.get(jsonUrl);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch Reddit content');
      }
      
      final jsonData = response.data;
      final postData = jsonData[0]['data']['children'][0]['data'];
      
      return {
        'url': url,
        'title': postData['title'],
        'description': postData['selftext'] ?? '',
        'author': postData['author'],
        'publishedDate': DateTime.fromMillisecondsSinceEpoch(
          (postData['created_utc'] as num).toInt() * 1000
        ).toIso8601String(),
        'extractedText': '${postData['title']}\n\n${postData['selftext'] ?? ''}',
        'contentType': 'reddit_post',
        'extractedAt': DateTime.now().toIso8601String(),
        'metadata': {
          'platform': 'reddit',
          'subreddit': postData['subreddit'],
          'score': postData['score'],
          'numComments': postData['num_comments'],
        }
      };
      
    } catch (e) {
      throw Exception('Failed to extract Reddit content: $e');
    }
  }

  // Helper methods for content extraction

  String _extractTitle(dom.Document document) {
    return document.querySelector('title')?.text.trim() ?? 
           document.querySelector('h1')?.text.trim() ?? 
           'Untitled';
  }

  /// Extract YouTube video information
  Future<Map<String, dynamic>> _extractYouTubeContent(String url) async {
    try {
      // Extract video ID from URL
      final videoId = _extractYouTubeVideoId(url);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }
      
      // For now, return basic information
      // Full YouTube API integration would require API key
      return {
        'url': url,
        'videoId': videoId,
        'title': 'YouTube Video',
        'description': 'YouTube video content extraction requires API integration',
        'extractedText': 'YouTube transcript extraction not yet implemented',
        'contentType': 'youtube_video',
        'extractedAt': DateTime.now().toIso8601String(),
        'metadata': {
          'platform': 'youtube',
          'videoId': videoId,
        }
      };
      
    } catch (e) {
      throw Exception('Failed to extract YouTube content: $e');
    }
  }

  String? _extractYouTubeVideoId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([^&]+)'),
      RegExp(r'youtu\.be/([^?]+)'),
      RegExp(r'youtube\.com/embed/([^?]+)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }
    
    return null;
  }

  bool _isGitHubUrl(String url) {
    return url.contains('github.com');
  }

  bool _isMediumUrl(String url) {
    return url.contains('medium.com') || url.contains('@');
  }

  bool _isRedditUrl(String url) {
    return url.contains('reddit.com');
  }

  // URL type detection methods

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  String? _makeAbsoluteUrl(String url, String baseUrl) {
    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme) {
        return url;
      }
      
      final baseUri = Uri.parse(baseUrl);
      return baseUri.resolve(url).toString();
    } catch (e) {
      return null;
    }
  }
}

