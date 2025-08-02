import 'dart:convert';
import 'dart:io';

/// Simple verification script to test the enhanced roadmap integration
void main() async {
  print('🧪 Verifying Enhanced Roadmap Integration...\n');
  
  // Test 1: Check if JSON files exist
  print('📁 Test 1: Checking JSON files...');
  final assetDir = Directory('assets/roadmaps');
  if (!assetDir.existsSync()) {
    print('❌ Assets directory not found: ${assetDir.path}');
    return;
  }
  
  final jsonFiles = assetDir.listSync()
      .where((file) => file.path.endsWith('-enhanced.json'))
      .toList();
  
  print('✅ Found ${jsonFiles.length} enhanced JSON files:');
  for (final file in jsonFiles) {
    print('   📄 ${file.path.split('/').last}');
  }
  
  if (jsonFiles.isEmpty) {
    print('❌ No enhanced JSON files found!');
    return;
  }
  
  // Test 2: Validate JSON structure
  print('\n📊 Test 2: Validating JSON structure...');
  
  for (final file in jsonFiles) {
    try {
      final content = File(file.path).readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      final fileName = file.path.split('/').last;
      print('   📄 $fileName:');
      
      // Check required fields
      final requiredFields = ['id', 'title', 'categories', 'metadata'];
      final missingFields = <String>[];
      
      for (final field in requiredFields) {
        if (!json.containsKey(field)) {
          missingFields.add(field);
        }
      }
      
      if (missingFields.isNotEmpty) {
        print('      ❌ Missing fields: ${missingFields.join(', ')}');
        continue;
      }
      
      // Check categories structure
      final categories = json['categories'] as List<dynamic>?;
      if (categories == null || categories.isEmpty) {
        print('      ❌ No categories found');
        continue;
      }
      
      print('      ✅ ${categories.length} categories');
      
      // Check topics in categories
      int totalTopics = 0;
      for (final category in categories) {
        final topics = category['topics'] as List<dynamic>?;
        if (topics != null) {
          totalTopics += topics.length;
        }
      }
      
      print('      ✅ $totalTopics total topics');
      
      // Check metadata
      final metadata = json['metadata'] as Map<String, dynamic>?;
      if (metadata != null) {
        print('      ✅ Metadata: ${metadata['totalTopics']} topics, ${metadata['estimatedHours']}h');
      }
      
    } catch (e) {
      print('   ❌ Error parsing $file: $e');
    }
  }
  
  // Test 3: Check pubspec.yaml assets
  print('\n📦 Test 3: Checking pubspec.yaml assets...');
  
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ pubspec.yaml not found');
    return;
  }
  
  final pubspecContent = pubspecFile.readAsStringSync();
  if (pubspecContent.contains('assets/roadmaps/')) {
    print('✅ Assets configured in pubspec.yaml');
  } else {
    print('❌ Assets not configured in pubspec.yaml');
  }
  
  // Test 4: Check model files
  print('\n🏗️ Test 4: Checking model files...');
  
  final modelFiles = [
    'lib/models/enhanced_roadmap_models.dart',
    'lib/services/enhanced_roadmap_service.dart',
    'lib/widgets/enhanced_mobile_roadmap_widget.dart',
  ];
  
  for (final filePath in modelFiles) {
    final file = File(filePath);
    if (file.existsSync()) {
      print('   ✅ ${filePath.split('/').last}');
    } else {
      print('   ❌ Missing: ${filePath.split('/').last}');
    }
  }
  
  // Test 5: Summary
  print('\n📋 Integration Summary:');
  print('   📄 JSON Files: ${jsonFiles.length}/5 expected');
  print('   📦 Assets: ${pubspecContent.contains('assets/roadmaps/') ? 'Configured' : 'Missing'}');
  print('   🏗️ Models: ${modelFiles.where((f) => File(f).existsSync()).length}/${modelFiles.length}');
  
  // Test 6: Sample data inspection
  if (jsonFiles.isNotEmpty) {
    print('\n🔍 Sample Data Inspection:');
    try {
      final sampleFile = jsonFiles.first;
      final content = File(sampleFile.path).readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      print('   📊 Sample roadmap: ${json['title']}');
      
      final categories = json['categories'] as List<dynamic>;
      if (categories.isNotEmpty) {
        final firstCategory = categories.first as Map<String, dynamic>;
        print('   📂 First category: ${firstCategory['title']}');
        
        final topics = firstCategory['topics'] as List<dynamic>?;
        if (topics != null && topics.isNotEmpty) {
          final firstTopic = topics.first as Map<String, dynamic>;
          print('   📝 First topic: ${firstTopic['title']}');
          print('   🎯 Difficulty: ${firstTopic['difficulty']}');
          print('   ⏱️ Time: ${firstTopic['estimatedTime']}');
        }
      }
      
    } catch (e) {
      print('   ❌ Error inspecting sample data: $e');
    }
  }
  
  print('\n🎉 Verification complete!');
  print('💡 To test the UI, run the Flutter app and navigate to the roadmap section.');
}
