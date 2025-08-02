import 'package:flutter/material.dart';

import 'lib/models/enhanced_roadmap_models.dart';
import 'lib/services/enhanced_roadmap_service.dart';
import 'lib/theme/app_theme.dart';
import 'lib/widgets/enhanced_mobile_roadmap_widget.dart';

void main() {
  runApp(const TestEnhancedRoadmapApp());
}

class TestEnhancedRoadmapApp extends StatelessWidget {
  const TestEnhancedRoadmapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced Roadmap Test',
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const TestEnhancedRoadmapScreen(),
    );
  }
}

class TestEnhancedRoadmapScreen extends StatefulWidget {
  const TestEnhancedRoadmapScreen({super.key});

  @override
  State<TestEnhancedRoadmapScreen> createState() => _TestEnhancedRoadmapScreenState();
}

class _TestEnhancedRoadmapScreenState extends State<TestEnhancedRoadmapScreen> {
  LearningRole _selectedRole = LearningRole.backend;
  final EnhancedRoadmapService _service = EnhancedRoadmapService();
  
  // Test data
  EnhancedRoadmap? _testRoadmap;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enhanced Roadmap Test'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Roadmap Widget'),
              Tab(text: 'Service Test'),
              Tab(text: 'Data Inspection'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Enhanced Roadmap Widget
            Column(
              children: [
                // Role selector
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('Role: '),
                      DropdownButton<LearningRole>(
                        value: _selectedRole,
                        onChanged: (LearningRole? newRole) {
                          if (newRole != null) {
                            setState(() {
                              _selectedRole = newRole;
                            });
                          }
                        },
                        items: [
                          LearningRole.backend,
                          LearningRole.frontend,
                          LearningRole.aiEngineer,
                          LearningRole.softwareArchitect,
                          LearningRole.engineeringManager,
                        ].map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.displayName),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
                // Enhanced roadmap widget
                Expanded(
                  child: EnhancedMobileRoadmapWidget(
                    role: _selectedRole,
                    onTopicSelected: (topic) {
                      print('📚 Topic selected: $topic');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected: $topic')),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            // Tab 2: Service Test Results
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Test Results',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('❌ Error:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_error!),
                          ],
                        ),
                      ),
                    )
                  else if (_testRoadmap != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              color: Colors.green.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('✅ Success!', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Loaded: ${_testRoadmap!.title}'),
                                    Text('Categories: ${_testRoadmap!.categories.length}'),
                                    Text('Topics: ${_testRoadmap!.metadata.totalTopics}'),
                                    Text('Hours: ${_testRoadmap!.metadata.estimatedHours}'),
                                    Text('Difficulty: ${_testRoadmap!.metadata.difficulty}'),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Categories overview
                            Text('Categories:', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ..._testRoadmap!.categories.map((category) => Card(
                              child: ListTile(
                                leading: Icon(category.iconData),
                                title: Text(category.title),
                                subtitle: Text('${category.topics.length} topics'),
                                trailing: Text('${category.estimatedHours}h'),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _testLoadRoadmap,
                    child: const Text('Reload Test'),
                  ),
                ],
              ),
            ),
            
            // Tab 3: Data Inspection
            Container(
              padding: const EdgeInsets.all(16),
              child: _testRoadmap == null
                  ? const Center(child: Text('Load a roadmap first'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data Structure Inspection',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          
                          // JSON preview
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('JSON Structure:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _formatJsonPreview(_testRoadmap!),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _testLoadRoadmap();
  }

  String _formatJsonPreview(EnhancedRoadmap roadmap) {
    return '''
{
  "id": "${roadmap.id}",
  "title": "${roadmap.title}",
  "categories": [${roadmap.categories.length} items],
  "metadata": {
    "totalTopics": ${roadmap.metadata.totalTopics},
    "totalCategories": ${roadmap.metadata.totalCategories},
    "estimatedHours": ${roadmap.metadata.estimatedHours},
    "difficulty": "${roadmap.metadata.difficulty}",
    "tags": ${roadmap.metadata.tags},
    "prerequisites": ${roadmap.metadata.prerequisites}
  }
}''';
  }

  Future<void> _testLoadRoadmap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🧪 Testing enhanced roadmap service...');
      final roadmap = await _service.getRoadmap(_selectedRole);
      
      setState(() {
        _testRoadmap = roadmap;
        _isLoading = false;
      });
      
      print('✅ Successfully loaded ${roadmap.title}');
      print('📊 Categories: ${roadmap.categories.length}');
      print('📋 Topics: ${roadmap.metadata.totalTopics}');
      print('⏱️ Estimated hours: ${roadmap.metadata.estimatedHours}');
      
      // Test topic completion update
      if (roadmap.getAllTopics().isNotEmpty) {
        final firstTopic = roadmap.getAllTopics().first;
        print('🧪 Testing topic completion update...');
        await _service.updateTopicCompletion(roadmap.id, firstTopic.id, true);
        print('✅ Topic completion update successful');
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('❌ Test failed: $e');
    }
  }
}
