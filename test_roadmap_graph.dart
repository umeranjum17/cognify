import 'package:flutter/material.dart';

import 'lib/models/roadmap_models.dart';
import 'lib/theme/app_theme.dart';
import 'lib/widgets/mobile_roadmap_widget.dart';

void main() {
  runApp(const TestRoadmapApp());
}

class TestRoadmapApp extends StatelessWidget {
  const TestRoadmapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roadmap Graph Test',
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const TestRoadmapScreen(),
    );
  }
}

class TestRoadmapScreen extends StatelessWidget {
  const TestRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Knowledge Graph Test'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Roadmap Learning'),
              Tab(text: 'Personal Knowledge'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const MobileRoadmapWidget(
              role: LearningRole.frontend,
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text(
                  'Personal Knowledge Graph\n(Based on conversation history)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
