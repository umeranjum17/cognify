import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/trending_topic.dart';

/// Trending Service - Generates trending topics locally
class TrendingService {
  static const Duration _cacheTimeout = Duration(hours: 2);
  
  DateTime? _lastRefresh;
  List<TrendingTopic>? _cachedTopics;
  bool _isRefreshing = false;

  /// Get trending topics with caching
  Future<List<TrendingTopic>> getTrendingTopics({bool forceRefresh = false}) async {
    // Return cached data if available and not forcing refresh
    if (!forceRefresh && _cachedTopics != null && _lastRefresh != null) {
      final cacheAge = DateTime.now().difference(_lastRefresh!);
      if (cacheAge < _cacheTimeout) {
        print('📦 Returning ${_cachedTopics!.length} cached trending topics');
        return _cachedTopics!;
      }
    }

    // Prevent concurrent refreshes
    if (_isRefreshing) {
      print('⏳ Trending refresh in progress, waiting...');
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedTopics ?? [];
    }

    return _refreshTopics();
  }

  /// Refresh trending topics from all sources
  Future<List<TrendingTopic>> _refreshTopics() async {
    _isRefreshing = true;
    
    try {
      print('🔄 Fetching trending topics from real APIs...');
      
      // Fetch from all sources in parallel
      final fetchPromises = [
        _fetchRedditTopics(),
        _fetchHackerNewsTopics(),
        _fetchGitHubTopics(),
        _fetchDevToTopics(),
      ];
      
      final results = await Future.wait(fetchPromises);
      
      // Combine all topics
      final allTopics = <TrendingTopic>[];
      for (final topics in results) {
        allTopics.addAll(topics);
      }
      
      // Shuffle for variety
      final random = Random();
      allTopics.shuffle(random);
      
      _cachedTopics = allTopics;
      _lastRefresh = DateTime.now();
      
      print('✅ Fetched ${allTopics.length} trending topics from real APIs');
      return allTopics;
      
    } catch (error) {
      print('❌ Trending topics refresh failed: $error');
      return _cachedTopics ?? [];
    } finally {
      _isRefreshing = false;
    }
  }

  /// Fetch trending topics from Reddit
  Future<List<TrendingTopic>> _fetchRedditTopics() async {
    final topics = <TrendingTopic>[];
    final subreddits = ['programming', 'webdev', 'javascript', 'MachineLearning', 'technology'];
    
    // Randomize subreddit selection
    final selectedSubreddits = subreddits
        .toList()
        ..shuffle(Random())
        ..take(3);
    
    print('🔍 Reddit: Fetching from ${selectedSubreddits.join(', ')}');
    
    for (final subreddit in selectedSubreddits) {
      try {
        final sortMethods = ['hot', 'top'];
        final sortMethod = sortMethods[Random().nextInt(sortMethods.length)];
        
        final url = sortMethod == 'top' 
            ? 'https://www.reddit.com/r/$subreddit/top.json?t=week&limit=10'
            : 'https://www.reddit.com/r/$subreddit/hot.json?limit=10';
            
        print('📡 Reddit: Fetching r/$subreddit - $sortMethod...');
        
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'TrendingBot/1.0'},
        ).timeout(const Duration(seconds: 8));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final posts = data['data']?['children'] as List? ?? [];
          
          for (final post in posts) {
            final postData = post['data'];
            if (postData != null && !postData['stickied'] && postData['score'] > 30) {
              final postAge = (DateTime.now().millisecondsSinceEpoch - postData['created_utc'] * 1000) / (1000 * 60 * 60 * 24);
              
              topics.add(TrendingTopic(
                id: 'reddit_${postData['id']}',
                title: postData['title'],
                description: postData['selftext']?.substring(0, 200) ?? 'Reddit discussion',
                url: 'https://reddit.com${postData['permalink']}',
                source: TrendingTopicSource(
                  name: 'Reddit',
                  logo: 'https://www.redditstatic.com/desktop2x/img/favicon/android-icon-192x192.png',
                  url: 'https://reddit.com',
                  type: 'reddit',
                ),
                metadata: TrendingTopicMetadata(
                  score: postData['score'],
                  comments: postData['num_comments'],
                  publishedAt: DateTime.fromMillisecondsSinceEpoch(postData['created_utc'] * 1000).toIso8601String(),
                  tags: ['Reddit', 'r/$subreddit'],
                ),
                relevanceScore: 1.0 - (postAge / 30), // Boost recent posts
              ));
            }
          }
          
          print('✅ Reddit r/$subreddit: ${topics.where((t) => t.id.contains('reddit_')).length} topics');
        }
      } catch (e) {
        print('⚠️ Reddit r/$subreddit failed: $e');
      }
    }
    
    return topics;
  }

  /// Fetch trending topics from Hacker News
  Future<List<TrendingTopic>> _fetchHackerNewsTopics() async {
    final topics = <TrendingTopic>[];
    
    try {
      // Fetch top stories
      final response = await http.get(
        Uri.parse('https://hacker-news.firebaseio.com/v0/topstories.json'),
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final storyIds = json.decode(response.body) as List;
        final selectedIds = storyIds.take(15).toList();
        
        print('🔍 HackerNews: Fetching ${selectedIds.length} stories...');
        
        for (final id in selectedIds) {
          try {
            final storyResponse = await http.get(
              Uri.parse('https://hacker-news.firebaseio.com/v0/item/$id.json'),
            ).timeout(const Duration(seconds: 5));
            
            if (storyResponse.statusCode == 200) {
              final story = json.decode(storyResponse.body);
              if (story != null && story['type'] == 'story' && story['score'] > 20) {
                final storyAge = (DateTime.now().millisecondsSinceEpoch - story['time'] * 1000) / (1000 * 60 * 60 * 24);
                
                topics.add(TrendingTopic(
                  id: 'hn_${story['id']}',
                  title: story['title'],
                  description: 'Hacker News discussion',
                  url: story['url'] ?? 'https://news.ycombinator.com/item?id=${story['id']}',
                  source: TrendingTopicSource(
                    name: 'Hacker News',
                    logo: 'https://news.ycombinator.com/favicon.ico',
                    url: 'https://news.ycombinator.com',
                    type: 'hackernews',
                  ),
                  metadata: TrendingTopicMetadata(
                    score: story['score'],
                    comments: story['descendants'] ?? 0,
                    publishedAt: DateTime.fromMillisecondsSinceEpoch(story['time'] * 1000).toIso8601String(),
                    tags: ['Hacker News', 'Tech'],
                  ),
                  relevanceScore: 1.0 - (storyAge / 7), // Boost recent stories
                ));
              }
            }
          } catch (e) {
            print('⚠️ HackerNews story $id failed: $e');
          }
        }
        
        print('✅ HackerNews: ${topics.where((t) => t.id.contains('hn_')).length} stories');
      }
    } catch (e) {
      print('❌ HackerNews fetch failed: $e');
    }
    
    return topics;
  }

  /// Fetch trending repositories from GitHub
  Future<List<TrendingTopic>> _fetchGitHubTopics() async {
    final topics = <TrendingTopic>[];
    
    try {
      // Use different time windows for variety
      final timeWindows = [
        {'days': 7, 'name': '1 week'},
        {'days': 14, 'name': '2 weeks'},
        {'days': 30, 'name': '1 month'},
      ];
      
      final selectedWindow = timeWindows[Random().nextInt(timeWindows.length)];
      final windowStart = DateTime.now().subtract(Duration(days: selectedWindow['days'] as int));
      
      print('🔍 GitHub: Fetching repos created in last ${selectedWindow['name']}...');
      
      final response = await http.get(
        Uri.parse('https://api.github.com/search/repositories').replace(
          queryParameters: {
            'q': 'created:>${windowStart.toIso8601String().split('T')[0]} stars:>10 stars:<50000',
            'sort': 'stars',
            'order': 'desc',
            'per_page': '10',
          },
        ),
        headers: {'User-Agent': 'TrendingBot/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final repos = data['items'] as List? ?? [];
        
        for (final repo in repos) {
          final createdAt = DateTime.parse(repo['created_at']);
          final daysSinceCreated = DateTime.now().difference(createdAt).inDays;
          
          topics.add(TrendingTopic(
            id: 'github_${repo['id']}',
            title: repo['full_name'],
            description: repo['description'] ?? 'GitHub repository',
            url: repo['html_url'],
            source: TrendingTopicSource(
              name: 'GitHub',
              logo: 'https://github.com/favicon.ico',
              url: 'https://github.com',
              type: 'github',
            ),
            metadata: TrendingTopicMetadata(
              stars: repo['stargazers_count'],
              publishedAt: repo['created_at'],
              tags: ['GitHub', 'Open Source', repo['language'] ?? 'Unknown'],
            ),
            relevanceScore: 1.0 + (repo['stargazers_count'] / 1000) - (daysSinceCreated / 30), // Boost popular and recent repos
          ));
        }
        
        print('✅ GitHub: ${topics.where((t) => t.id.contains('github_')).length} repos');
      }
    } catch (e) {
      print('❌ GitHub fetch failed: $e');
    }
    
    return topics;
  }

  /// Fetch trending articles from Dev.to
  Future<List<TrendingTopic>> _fetchDevToTopics() async {
    final topics = <TrendingTopic>[];
    final tags = ['javascript', 'python', 'webdev', 'react', 'nodejs'];
    
    // Randomly select 2-3 tags
    final selectedTags = tags
        .toList()
        ..shuffle(Random())
        ..take(Random().nextInt(2) + 2);
    
    print('🔍 Dev.to: Fetching articles for ${selectedTags.join(', ')}');
    
    for (final tag in selectedTags) {
      try {
        final response = await http.get(
          Uri.parse('https://dev.to/api/articles').replace(
            queryParameters: {
              'tag': tag,
              'per_page': '8',
              'state': 'fresh',
            },
          ),
          headers: {'User-Agent': 'Cognify-TrendingService/1.0'},
        ).timeout(const Duration(seconds: 8));
        
        if (response.statusCode == 200) {
          final articles = json.decode(response.body) as List? ?? [];
          
          for (final article in articles) {
            final publishedDate = DateTime.parse(article['published_at']);
            final articleAge = DateTime.now().difference(publishedDate).inDays;
            
            // Filter recent articles with good engagement
            if (articleAge <= 30 && (article['public_reactions_count'] >= 5 || article['comments_count'] >= 2)) {
              topics.add(TrendingTopic(
                id: 'devto_${article['id']}',
                title: article['title'],
                description: article['description'] ?? 'Dev.to article',
                url: article['url'],
                source: TrendingTopicSource(
                  name: 'Dev.to',
                  logo: 'https://dev.to/favicon.ico',
                  url: 'https://dev.to',
                  type: 'devto',
                ),
                metadata: TrendingTopicMetadata(
                  reactions: article['public_reactions_count'],
                  comments: article['comments_count'],
                  readingTime: article['reading_time_minutes'],
                  publishedAt: article['published_at'],
                  tags: ['Dev.to', tag, ...(article['tag_list'] as List? ?? [])],
                ),
                relevanceScore: 1.0 - (articleAge / 30) + (article['public_reactions_count'] / 100), // Boost recent and popular articles
              ));
            }
          }
          
          print('✅ Dev.to $tag: ${topics.where((t) => t.id.contains('devto_')).length} articles');
        }
      } catch (e) {
        print('⚠️ Dev.to $tag failed: $e');
      }
    }
    
    return topics;
  }

  /// Generate realistic fallback trending topics (kept for emergency fallback)
  Future<List<TrendingTopic>> _generateFallbackTopics() async {
    final sources = [
      TrendingTopicSource(
        name: 'Reddit',
        logo: 'https://www.redditstatic.com/desktop2x/img/favicon/android-icon-192x192.png',
        url: 'https://reddit.com',
        type: 'reddit',
      ),
      TrendingTopicSource(
        name: 'Hacker News',
        logo: 'https://news.ycombinator.com/favicon.ico',
        url: 'https://news.ycombinator.com',
        type: 'hackernews',
      ),
      TrendingTopicSource(
        name: 'GitHub',
        logo: 'https://github.com/favicon.ico',
        url: 'https://github.com',
        type: 'github',
      ),
      TrendingTopicSource(
        name: 'Dev.to',
        logo: 'https://dev.to/favicon.ico',
        url: 'https://dev.to',
        type: 'devto',
      ),
    ];

    final topics = [
      TrendingTopic(
        id: 'reddit_1',
        title: 'Flutter 3.19 Released with Impressive Performance Improvements',
        description: 'Google releases Flutter 3.19 with 20% faster startup times, improved memory usage, and new Material 3 components.',
        url: 'https://reddit.com/r/FlutterDev/comments/example',
        source: sources[0],
        metadata: TrendingTopicMetadata(
          score: 156,
          comments: 23,
          publishedAt: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          tags: ['Flutter', 'Mobile Development', 'Performance'],
        ),
        relevanceScore: 0.92,
      ),
      TrendingTopic(
        id: 'hn_1',
        title: 'Show HN: I built a GPT-4 powered code review tool',
        description: 'A tool that uses GPT-4 to review pull requests and suggest improvements. Open source and free for personal use.',
        url: 'https://news.ycombinator.com/item?id=example',
        source: sources[1],
        metadata: TrendingTopicMetadata(
          score: 89,
          comments: 45,
          publishedAt: DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
          tags: ['AI', 'Code Review', 'Open Source'],
        ),
        relevanceScore: 0.88,
      ),
      TrendingTopic(
        id: 'github_1',
        title: 'microsoft/vscode: Visual Studio Code',
        description: 'The most popular code editor gets a major update with improved AI features, better performance, and enhanced debugging.',
        url: 'https://github.com/microsoft/vscode',
        source: sources[2],
        metadata: TrendingTopicMetadata(
          stars: 154000,
          publishedAt: DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
          tags: ['VS Code', 'Editor', 'Microsoft'],
        ),
        relevanceScore: 0.85,
      ),
      TrendingTopic(
        id: 'devto_1',
        title: 'How I Built a Real-time Chat App with Flutter and Firebase',
        description: 'A comprehensive guide to building a scalable chat application using Flutter for the frontend and Firebase for the backend.',
        url: 'https://dev.to/example/flutter-firebase-chat',
        source: sources[3],
        metadata: TrendingTopicMetadata(
          reactions: 42,
          readingTime: 8,
          publishedAt: DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
          tags: ['Flutter', 'Firebase', 'Tutorial'],
        ),
        relevanceScore: 0.91,
      ),
      TrendingTopic(
        id: 'reddit_2',
        title: 'TypeScript 5.3: What\'s New and Why It Matters',
        description: 'Deep dive into TypeScript 5.3 features including improved type inference, better performance, and new utility types.',
        url: 'https://reddit.com/r/typescript/comments/example',
        source: sources[0],
        metadata: TrendingTopicMetadata(
          score: 203,
          comments: 67,
          publishedAt: DateTime.now().subtract(const Duration(hours: 10)).toIso8601String(),
          tags: ['TypeScript', 'JavaScript', 'Programming'],
        ),
        relevanceScore: 0.87,
      ),
      TrendingTopic(
        id: 'hn_2',
        title: 'Ask HN: What programming language should I learn in 2025?',
        description: 'With AI tools changing the landscape, which programming language would you recommend for someone starting their career?',
        url: 'https://news.ycombinator.com/item?id=example2',
        source: sources[1],
        metadata: TrendingTopicMetadata(
          score: 156,
          comments: 89,
          publishedAt: DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
          tags: ['Programming', 'Career', 'Learning'],
        ),
        relevanceScore: 0.84,
      ),
      TrendingTopic(
        id: 'github_2',
        title: 'vercel/next.js: The React Framework',
        description: 'Next.js 15 brings improved performance, better developer experience, and enhanced AI integration capabilities.',
        url: 'https://github.com/vercel/next.js',
        source: sources[2],
        metadata: TrendingTopicMetadata(
          stars: 98000,
          publishedAt: DateTime.now().subtract(const Duration(hours: 14)).toIso8601String(),
          tags: ['Next.js', 'React', 'Vercel'],
        ),
        relevanceScore: 0.89,
      ),
      TrendingTopic(
        id: 'devto_2',
        title: 'Building Microservices with Go: A Complete Guide',
        description: 'Learn how to build scalable microservices using Go, including best practices, testing strategies, and deployment patterns.',
        url: 'https://dev.to/example/go-microservices-guide',
        source: sources[3],
        metadata: TrendingTopicMetadata(
          reactions: 38,
          readingTime: 12,
          publishedAt: DateTime.now().subtract(const Duration(hours: 16)).toIso8601String(),
          tags: ['Go', 'Microservices', 'Backend'],
        ),
        relevanceScore: 0.86,
      ),
    ];

    // Shuffle topics for variety
    final random = Random();
    topics.shuffle(random);
    
    return topics;
  }

  /// Clear cache and force refresh
  void clearCache() {
    _cachedTopics = null;
    _lastRefresh = null;
    print('🗑️ Trending topics cache cleared');
  }

  /// Get cache stats
  Map<String, dynamic> getCacheStats() {
    return {
      'hasCache': _cachedTopics != null,
      'lastRefresh': _lastRefresh?.toIso8601String(),
      'cacheAge': _lastRefresh != null 
          ? DateTime.now().difference(_lastRefresh!).inMinutes 
          : null,
      'topicsCount': _cachedTopics?.length ?? 0,
      'isRefreshing': _isRefreshing,
    };
  }
} 