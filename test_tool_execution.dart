import 'dart:io';
import 'lib/services/tools.dart';

void main() async {
  print('🔧 Testing tool execution...');
  
  try {
    // Initialize tools manager
    final toolsManager = ToolsManager();
    print('🔧 ToolsManager created, available tools: ${toolsManager.allTools.length}');
    print('🔧 Available tools: ${toolsManager.allTools.map((t) => t.name).join(', ')}');
    
    // Test brave_search tool
    final braveSearchTool = toolsManager.getToolByName('brave_search');
    if (braveSearchTool != null) {
      print('🔧 Testing brave_search tool...');
      
      final testInput = {
        'query': 'Donald Trump',
        'count': 3
      };
      
      print('🔧 Executing brave_search with input: $testInput');
      final result = await braveSearchTool.invoke(testInput);
      print('🔧 brave_search result keys: ${result.keys.join(', ')}');
      print('🔧 brave_search result: $result');
    } else {
      print('❌ brave_search tool not found');
    }
    
    // Test image_search tool
    final imageSearchTool = toolsManager.getToolByName('image_search');
    if (imageSearchTool != null) {
      print('🔧 Testing image_search tool...');
      
      final testInput = {
        'query': 'Donald Trump',
        'count': 3
      };
      
      print('🔧 Executing image_search with input: $testInput');
      final result = await imageSearchTool.invoke(testInput);
      print('🔧 image_search result keys: ${result.keys.join(', ')}');
      print('🔧 image_search result: $result');
    } else {
      print('❌ image_search tool not found');
    }
    
  } catch (e) {
    print('❌ Error testing tools: $e');
  }
  
  exit(0);
}
