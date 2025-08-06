import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../database/database_service.dart';
import '../utils/logger.dart';
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
    Logger.info('🧹 Disposing ServicesManager...', tag: 'ServicesManager');

    try {
      await databaseService.dispose();
      await Hive.close();

      _initialized = false;
      Logger.info('✅ ServicesManager disposed successfully', tag: 'ServicesManager');
    } catch (e) {
      Logger.error('❌ Error disposing ServicesManager: $e', tag: 'ServicesManager');
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
      Logger.info('🚀 Initializing ServicesManager...', tag: 'ServicesManager');

      // Initialize Hive first
      await Hive.initFlutter();
      Logger.info('✅ Hive initialized', tag: 'ServicesManager');

      // Initialize core services
      databaseService = DatabaseService();
      await databaseService.initialize();
      Logger.info('✅ DatabaseService initialized', tag: 'ServicesManager');

      appConfig = AppConfig();
      await appConfig.initialize();
      Logger.info('✅ AppConfig initialized', tag: 'ServicesManager');
      
      // Initialize document processing services
      documentProcessor = DocumentProcessor();
      await documentProcessor.initialize();
      Logger.info('✅ DocumentProcessor initialized', tag: 'ServicesManager');
      
      fileUploadService = FileUploadService();
      await fileUploadService.initialize();
      Logger.info('✅ FileUploadService initialized', tag: 'ServicesManager');

      contentExtractor = ContentExtractor();
      await contentExtractor.initialize();
      Logger.info('✅ ContentExtractor initialized', tag: 'ServicesManager');

      // Initialize user service
      userService = UserService();
      // Note: UserService doesn't have initialize method yet
      Logger.info('✅ UserService initialized', tag: 'ServicesManager');

      // Initialize LLM services
      llmService = LLMService();
      await llmService.initialize();
      Logger.info('✅ LLMService initialized', tag: 'ServicesManager');

      promptService = PromptService();
      await promptService.initialize();
      Logger.info('✅ PromptService initialized', tag: 'ServicesManager');

      costCalculationService = CostCalculationService();
      await costCalculationService.initialize();
      Logger.info('✅ CostCalculationService initialized', tag: 'ServicesManager');

      // Initialize unified API service (includes agent system)
      unifiedApiService = UnifiedApiService();
      await unifiedApiService.initialize();
      Logger.info('✅ UnifiedApiService initialized', tag: 'ServicesManager');

      _initialized = true;
      Logger.info('🎉 ServicesManager initialization completed successfully', tag: 'ServicesManager');
      
    } catch (e) {
      Logger.error('❌ ServicesManager initialization failed: $e', tag: 'ServicesManager');
      rethrow;
    }
  }
}
