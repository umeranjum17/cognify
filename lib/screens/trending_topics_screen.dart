import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_access_provider.dart';
import '../widgets/cognify_logo.dart';

/// Trending topics screen - Premium feature only
class TrendingTopicsScreen extends StatefulWidget {
  const TrendingTopicsScreen({super.key});

  @override
  State<TrendingTopicsScreen> createState() => _TrendingTopicsScreenState();
}

class _TrendingTopicsScreenState extends State<TrendingTopicsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trendingTopics = [];

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
      body: Consumer<AppAccessProvider>(
        builder: (context, appAccess, child) {
          final hasAccess = appAccess.hasPremiumAccess;
          
          if (!hasAccess) {
            return _buildPremiumPrompt();
          }
          
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          return _buildTrendingTopicsContent();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTrendingTopics();
  }

  Widget _buildPremiumPrompt() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CognifyLogo(size: 60, variant: 'robot'),
            const SizedBox(height: 24),
            Icon(
              Icons.trending_up,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Trending Topics',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Discover what\'s trending and join conversations on the latest topics.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lock,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Premium Feature',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trending topics are available in the Premium version. Upgrade to access real-time trending content and join discussions.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/subscription');
                },
                icon: const Icon(Icons.star),
                label: const Text('Upgrade to Premium'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Back to Chat'),
            ),
          ],
        ),
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

  Widget _buildTrendingTopicsContent() {
    return RefreshIndicator(
      onRefresh: _refreshTrendingTopics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Discover trending conversations and topics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join discussions on the most popular topics right now',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 24),
          ..._trendingTopics.map((topic) => _buildTopicCard(topic)),
        ],
      ),
    );
  }

  Future<void> _loadTrendingTopics() async {
    // Check if user has access to this premium feature
    final appAccess = Provider.of<AppAccessProvider>(context, listen: false);
    final hasAccess = appAccess.hasPremiumAccess;
    
    if (!hasAccess) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Simulate loading trending topics
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _trendingTopics = [
        {
          'title': 'AI and Machine Learning Trends',
          'description': 'Latest developments in artificial intelligence and ML technologies',
          'category': 'Technology',
          'engagement': '2.3k discussions',
          'icon': Icons.psychology,
        },
        {
          'title': 'Climate Change Solutions',
          'description': 'Innovative approaches to addressing environmental challenges',
          'category': 'Environment',
          'engagement': '1.8k discussions',
          'icon': Icons.eco,
        },
        {
          'title': 'Remote Work Best Practices',
          'description': 'Tips and strategies for effective remote collaboration',
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
    // Navigate to editor with the topic as initial prompt
    final prompt = 'Let\'s discuss: ${topic['title']}. ${topic['description']}';
    context.push('/editor?prompt=${Uri.encodeComponent(prompt)}');
  }
}
