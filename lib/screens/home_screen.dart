import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../models/tag_folder.dart';
import '../services/enhanced_content_processor.dart';
import '../services/services_manager.dart';
import '../services/unified_api_service.dart';
import '../theme/theme_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/cognify_logo.dart';
import '../widgets/modern_app_header.dart';

Widget _buildStatsItem(IconData icon, String value, ThemeData theme) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: theme.textTheme.bodySmall?.color),
      const SizedBox(width: 2),
      Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final UnifiedApiService _apiService;
  final EnhancedContentProcessor _contentProcessor = EnhancedContentProcessor();
  final TextEditingController _searchController = TextEditingController();

  List<Note> savedNotes = [];
  List<TagFolder> tagFolders = [];
  String? selectedTag;

  bool showAllNotes = false;
  String viewMode = 'folders'; // 'folders' or 'list'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const ModernAppHeader(
        showBackButton: false,
        showLogo: true,
        centerTitle: false,
        showNewChatButton: true,
      ),
      body: AnimatedGradientBackground(
        child: Stack(
          children: [
            // Floating particles for visual interest
            const Positioned.fill(
              child: FloatingParticles(
                particleCount: 15,
                particleSize: 3.0,
              ),
            ),

            // Main content
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 768),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ask anything section (quote now included here)
                        _buildAskAnythingSection(theme),

                        // Action buttons removed for cleaner hero section
                        const SizedBox(height: 24),

                        // Search input removed
                        // _buildSearchInput(theme),

                        const SizedBox(height: 48),

                        // Saved conversations
                        _buildSavedConversationsSection(theme),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
          ],
        ),
      ),
      floatingActionButton: ModernFloatingActionButton(
        icon: Icons.add,
        label: 'New Chat',
        onPressed: handleNewChat,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  List<Note> getCurrentNotes() {
    if (selectedTag != null) {
      final folder = tagFolders.firstWhere((f) => f.tag == selectedTag, orElse: () => TagFolder(tag: '', notes: [], count: 0));
      return folder.notes;
    }
    return savedNotes;
  }

  void handleNavigateToSources() {
    context.push('/sources');
  }

  void handleNewChat() {
    context.push('/editor');
  }



  void handleTopicSubmit(String finalTopic) {
    if (finalTopic.trim().isNotEmpty) {
      context.push('/editor', extra: {'initialTopic': finalTopic});
    }
  }



  @override
  void initState() {
    super.initState();

    // Get the globally initialized API service
    _apiService = ServicesManager().unifiedApiService;

    loadSavedNotes();

    // Add listener to search controller to update UI when text changes
    _searchController.addListener(() {
      setState(() {});
    });
  }

  Future<void> loadSavedNotes() async {
    // TODO: Replace with Hive or SharedPreferences integration
    if (mounted) {
      setState(() {
        savedNotes = [];
        tagFolders = [];
      });
    }
  }

  void organizeNotesByTags(List<Note> notes) {
    final Map<String, List<Note>> tagMap = {};
    final List<Note> untaggedNotes = [];

    for (final note in notes) {
      if (note.tags != null && note.tags!.isNotEmpty) {
        for (final tag in note.tags!) {
          tagMap.putIfAbsent(tag, () => []).add(note);
        }
      } else {
        untaggedNotes.add(note);
      }
    }

    final folders = tagMap.entries
        .map((e) => TagFolder(tag: e.key, notes: e.value, count: e.value.length))
        .toList();

    if (untaggedNotes.isNotEmpty) {
      folders.add(TagFolder(tag: 'Untagged', notes: untaggedNotes, count: untaggedNotes.length));
    }

    folders.sort((a, b) => b.count.compareTo(a.count));
    if (mounted) {
      setState(() {
        tagFolders = folders;
      });
    }
  }

  // _buildActionButtons removed: redundant with header and FAB

  Widget _buildAskAnythingSection(ThemeData theme) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
        margin: const EdgeInsets.only(top: 32, bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CognifyLogo(size: 48, variant: 'robot'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'How can I help you today?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.titleLarge?.color,
                height: 1.1,
                letterSpacing: -0.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation, analyze content with AI-powered insights',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                height: 1.4,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Inline daily wisdom quote
            FutureBuilder<Map<String, dynamic>>(
              future: _apiService.getDailyQuote(),
              builder: (context, snapshot) {
                final theme = Theme.of(context);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: _buildQuoteContent(snapshot, theme),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteContent(AsyncSnapshot<Map<String, dynamic>> snapshot, ThemeData theme) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(
        key: ValueKey('loading'),
        height: 120,
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('empty'));
    }

    final quote = snapshot.data?['quote'] ?? 'No quote available.';
    final author = snapshot.data?['author'] ?? 'Unknown';

    return Container(
      key: const ValueKey('quote'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            '"$quote"',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              fontSize: 15,
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                  : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "- $author",
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedConversationsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent conversations',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleLarge?.color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        if (savedNotes.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor.withValues(alpha: 0.15),
                          theme.primaryColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 28,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleMedium?.color,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      'Start a conversation to see your chat history here',
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.textTheme.bodySmall?.color,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: savedNotes.take(5).length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final note = savedNotes[index];
              return ListTile(
                title: Text(note.title),
                subtitle: Text(
                  note.content.length > 120
                      ? '${note.content.substring(0, 120)}...'
                      : note.content,
                ),
                trailing: Icon(Icons.chat_bubble_outline, color: theme.primaryColor),
                onTap: () {
                  // TODO: Navigate to conversation
                },
              );
            },
          ),
      ],
    );
  }

  // _buildSearchInput method fully removed as it is no longer used

  Widget _buildStatsItem(IconData icon, String value, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.textTheme.bodySmall?.color),
        const SizedBox(width: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Trending topics functionality moved to separate premium screen

  void _handleSharedUrl(String url) {
    if (url.isNotEmpty) {
      context.go('/sources?sharedUrl=${Uri.encodeComponent(url)}');
    }
  }
}
