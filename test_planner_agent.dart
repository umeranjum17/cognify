import 'lib/services/agents/planner_agent.dart';

void main() async {
  // Test the enhanced planner agent with mode-specific behavior
  final planner = PlannerAgent(modelName: 'google/gemini-2.0-flash-exp:free');

  print('🧪 Testing Enhanced Planner Agent with Mode-Specific Sequential Thinking');
  print('=' * 70);

  // Test DeepSearch mode (with sequential thinking)
  print('\n🔍 Testing DeepSearch Mode (with Sequential Thinking):');
  print('-' * 50);

  try {
    final deepSearchResult = await planner.createExecutionPlan(
      query: 'What are the latest developments in artificial intelligence?',
      enabledTools: ['brave_search_enhanced', 'brave_search', 'web_fetch', 'sequential_thinking'],
      mode: 'deepsearch',
    );

    print('✅ DeepSearch test completed successfully!');
    print('📊 DeepSearch Results:');
    print('- Tool specs: ${deepSearchResult['toolSpecs']?.length ?? 0}');
    print('- Model: ${deepSearchResult['model']}');
    print('- Stage: ${deepSearchResult['stage']}');
    print('- Has thinking result: ${deepSearchResult['thinkingResult'] != null}');

    if (deepSearchResult['thinkingResult'] != null) {
      final thinking = deepSearchResult['thinkingResult'] as Map<String, dynamic>;
      print('🧠 Sequential Thinking Analysis:');
      print('- Understanding: ${thinking['understanding']}');
      print('- Key concepts: ${thinking['key_concepts']}');
      print('- Search strategies: ${(thinking['search_strategies'] as List?)?.length ?? 0}');
      print('- Complexity: ${thinking['complexity']}');
    }

    final toolSpecs = deepSearchResult['toolSpecs'] as List?;
    if (toolSpecs != null) {
      print('🔧 Generated Tool Specs (DeepSearch):');
      for (int i = 0; i < toolSpecs.length; i++) {
        final spec = toolSpecs[i];
        print('  ${i + 1}. ${spec.name} (order: ${spec.order})');
        print('     Query: ${spec.input['query'] ?? 'N/A'}');
        print('     Reasoning: ${spec.reasoning}');
      }
    }

  } catch (e) {
    print('❌ DeepSearch test failed: $e');
  }

  // Test Chat mode (without sequential thinking)
  print('\n💬 Testing Chat Mode (without Sequential Thinking):');
  print('-' * 50);

  try {
    final chatResult = await planner.createExecutionPlan(
      query: 'What are the latest developments in artificial intelligence?',
      enabledTools: ['brave_search_enhanced', 'brave_search', 'web_fetch', 'sequential_thinking'],
      mode: 'chat',
    );

    print('✅ Chat test completed successfully!');
    print('📊 Chat Results:');
    print('- Tool specs: ${chatResult['toolSpecs']?.length ?? 0}');
    print('- Model: ${chatResult['model']}');
    print('- Stage: ${chatResult['stage']}');
    print('- Has thinking result: ${chatResult['thinkingResult'] != null}');

    final chatToolSpecs = chatResult['toolSpecs'] as List?;
    if (chatToolSpecs != null) {
      print('🔧 Generated Tool Specs (Chat):');
      for (int i = 0; i < chatToolSpecs.length; i++) {
        final spec = chatToolSpecs[i];
        print('  ${i + 1}. ${spec.name} (order: ${spec.order})');
        print('     Query: ${spec.input['query'] ?? 'N/A'}');
        print('     Reasoning: ${spec.reasoning}');
      }
    }

  } catch (e) {
    print('❌ Chat test failed: $e');
  }

  print('\n🎯 Summary:');
  print('- DeepSearch mode: Uses sequential thinking for strategic planning');
  print('- Chat mode: Skips sequential thinking for faster responses');
}
