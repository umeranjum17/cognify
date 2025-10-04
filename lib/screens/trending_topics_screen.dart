import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Trending topics screen
class TrendingTopicsScreen extends StatefulWidget {
  const TrendingTopicsScreen({super.key});

  @override
  State<TrendingTopicsScreen> createState() => _TrendingTopicsScreenState();
}

class _TrendingTopicsScreenState extends State<TrendingTopicsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trendingTopics = [];

  @override
  void initState() {
    super.initState();
    _loadTrendingTopics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trending Topics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTrendingTopics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTrendingTopicsContent(),
    );
  }

  Widget _buildTrendingTopicsContent() {
    return RefreshIndicator(
      onRefresh: _refreshTrendingTopics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Discover trending conversations and topics',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Join discussions on the most popular topics right now',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 24),
          ..._trendingTopics.map(_buildTopicCard),
        ],
      ),
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _startTopicConversation(topic),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      topic['icon'] as IconData,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic['title'] as String,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            topic['category'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                topic['description'] as String,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.forum,
                    size: 16,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    topic['engagement'] as String,
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadTrendingTopics() async {
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _trendingTopics = [
        {
          'title': 'AI and Machine Learning Trends',
          'description':
              'Latest developments in artificial intelligence and ML technologies',
          'category': 'Technology',
          'engagement': '2.3k discussions',
          'icon': Icons.psychology,
        },
        {
          'title': 'Climate Change Solutions',
          'description':
              'Innovative approaches to addressing environmental challenges',
          'category': 'Environment',
          'engagement': '1.8k discussions',
          'icon': Icons.eco,
        },
        {
          'title': 'Remote Work Best Practices',
          'description':
              'Tips and strategies for effective remote collaboration',
          'category': 'Business',
          'engagement': '1.5k discussions',
          'icon': Icons.work,
        },
        {
          'title': 'Cryptocurrency Market Analysis',
          'description': 'Current trends and predictions in digital currencies',
          'category': 'Finance',
          'engagement': '3.1k discussions',
          'icon': Icons.currency_bitcoin,
        },
        {
          'title': 'Health and Wellness Tech',
          'description': 'Technology innovations in healthcare and fitness',
          'category': 'Health',
          'engagement': '1.2k discussions',
          'icon': Icons.health_and_safety,
        },
      ];
      _isLoading = false;
    });
  }

  Future<void> _refreshTrendingTopics() async {
    setState(() {
      _isLoading = true;
    });
    await _loadTrendingTopics();
  }

  void _startTopicConversation(Map<String, dynamic> topic) {
    final prompt = 'Let\'s discuss: ${topic['title']}. ${topic['description']}';
    context.push('/editor?prompt=${Uri.encodeComponent(prompt)}');
  }
}
