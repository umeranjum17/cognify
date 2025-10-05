import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../database/database_service.dart';
import '../utils/logger.dart';
import 'llm_service.dart';
import 'prompt_service.dart';
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
  late final UserService userService;
  late final LLMService llmService;
  late final PromptService promptService;
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
        'userService': userService.hashCode,
        'llmService': llmService.hashCode,
        'promptService': promptService.hashCode,
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

      _initialized = true;
      Logger.info('🎉 ServicesManager initialization completed successfully', tag: 'ServicesManager');
      
    } catch (e) {
      Logger.error('❌ ServicesManager initialization failed: $e', tag: 'ServicesManager');
      rethrow;
    }
  }
}
