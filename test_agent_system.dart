import 'dart:async';
import 'dart:convert';

import 'lib/services/agent_service.dart';
import 'lib/models/tools_config.dart';

void main() async {
  print('🧪 Testing Agent System...');
  
  try {
    // Initialize agent service
    final agentService = AgentService();
    await agentService.initialize();
    
    print('✅ Agent Service initialized');
    
    // Create test tools config
    final toolsConfig = ToolsConfig(
      braveSearch: true,
      sequentialThinking: true,
      webFetch: true,
      imageSearch: true,
      timeTool: true,
    );
    
    print('🔧 Testing agent system with query...');
    
    // Test the agent system
    await for (final response in agentService.processChat(
      query: 'What is the current time?',
      messages: [],
      enabledTools: toolsConfig,
      conversationId: 'test-123',
    )) {
      print('📤 Response: ${response.type} - ${response.content}');
      
      if (response.type == 'complete' || response.type == 'error') {
        break;
      }
    }
    
    print('✅ Agent system test completed');
    
  } catch (e) {
    print('❌ Agent system test failed: $e');
  }
} 