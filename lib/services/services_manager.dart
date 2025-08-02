import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../database/database_service.dart';
import 'content_extractor.dart';
import 'cost_calculation_service.dart';
import 'document_processor.dart';
import 'file_upload_service.dart';
import 'llm_service.dart';
import 'prompt_service.dart';
import 'unified_api_service.dart';
import 'user_service.dart';

/// Central services manager for the application
/// Handles initialization and lifecycle of all services
class ServicesManager {
  static final ServicesManager _instance = ServicesManager._internal();
  // Service instances
  late final DatabaseService databaseService;
  late final AppConfig appConfig;

  late final DocumentProcessor documentProcessor;
  late final FileUploadService fileUploadService;
  late final ContentExtractor contentExtractor;
  late final UserService userService;
  late final LLMService llmService;
  late final PromptService promptService;
  late final CostCalculationService costCalculationService;
  late final UnifiedApiService unifiedApiService;
  bool _initialized = false;
  factory ServicesManager() => _instance;
  
  ServicesManager._internal();
  
  bool get isInitialized => _initialized;
  
  Future<void> dispose() async {
    print('🧹 Disposing ServicesManager...');

    try {
      await databaseService.dispose();
      await Hive.close();

      _initialized = false;
      print('✅ ServicesManager disposed successfully');
    } catch (e) {
      print('❌ Error disposing ServicesManager: $e');
    }
  }
  
  /// Get service health status
  Map<String, dynamic> getHealthStatus() {
    return {
      'initialized': _initialized,
      'services': {
        'database': databaseService.hashCode,
        'appConfig': appConfig.hashCode,
        'documentProcessor': documentProcessor.hashCode,
        'fileUploadService': fileUploadService.hashCode,
        'contentExtractor': contentExtractor.hashCode,
        'userService': userService.hashCode,
        'llmService': llmService.hashCode,
        'promptService': promptService.hashCode,
        'costCalculationService': costCalculationService.hashCode,
        'unifiedApiService': unifiedApiService.hashCode,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      print('🚀 Initializing ServicesManager...');

      // Initialize Hive first
      await Hive.initFlutter();
      print('✅ Hive initialized');

      // Initialize core services
      databaseService = DatabaseService();
      await databaseService.initialize();
      print('✅ DatabaseService initialized');

      appConfig = AppConfig();
      await appConfig.initialize();
      print('✅ AppConfig initialized');
      
      // Initialize document processing services
      documentProcessor = DocumentProcessor();
      await documentProcessor.initialize();
      print('✅ DocumentProcessor initialized');
      
      fileUploadService = FileUploadService();
      await fileUploadService.initialize();
      print('✅ FileUploadService initialized');

      contentExtractor = ContentExtractor();
      await contentExtractor.initialize();
      print('✅ ContentExtractor initialized');

      // Initialize user service
      userService = UserService();
      // Note: UserService doesn't have initialize method yet
      print('✅ UserService initialized');

      // Initialize LLM services
      llmService = LLMService();
      await llmService.initialize();
      print('✅ LLMService initialized');

      promptService = PromptService();
      await promptService.initialize();
      print('✅ PromptService initialized');

      costCalculationService = CostCalculationService();
      await costCalculationService.initialize();
      print('✅ CostCalculationService initialized');

      // Initialize unified API service (includes agent system)
      unifiedApiService = UnifiedApiService();
      await unifiedApiService.initialize();
      print('✅ UnifiedApiService initialized');

      _initialized = true;
      print('🎉 ServicesManager initialization completed successfully');
      
    } catch (e) {
      print('❌ ServicesManager initialization failed: $e');
      rethrow;
    }
  }
}
