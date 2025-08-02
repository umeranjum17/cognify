import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/knowledge_graph_tab.dart';
import '../widgets/modern_app_header.dart';
import '../widgets/roadmap_learning_tab.dart';

class EntitiesScreen extends StatefulWidget {
  const EntitiesScreen({super.key});

  @override
  State<EntitiesScreen> createState() => _EntitiesScreenState();
}

class _EntitiesScreenState extends State<EntitiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Custom header with back button and title
          const ModernAppHeader(
            title: 'Knowledge Graph',
            showBackButton: true,
            showLogo: true,
            centerTitle: false,
            showNewChatButton: true,
          ),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 3,
              labelColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 20),
                      SizedBox(width: 8),
                      Text('Roadmap Learning'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_tree, size: 20),
                      SizedBox(width: 8),
                      Text('Knowledge Graph'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                RoadmapLearningTab(),
                KnowledgeGraphTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void handleNavigateToEntities() {
    GoRouter.of(context).push('/entities');
  }

  void handleNavigateToSources() {
    GoRouter.of(context).push('/sources');
  }

  void handleNewChat() {
    GoRouter.of(context).push('/editor');
  }



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

}
