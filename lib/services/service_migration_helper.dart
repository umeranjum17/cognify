import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Helper class to migrate from old services to optimized services
class ServiceMigrationHelper {
  static const String _migrationKey = 'service_migration_completed';
  static const String _migrationVersion = 'v2.0.0';

  /// Check if migration has been completed
  static Future<bool> isMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedVersion = prefs.getString(_migrationKey);
      return completedVersion == _migrationVersion;
    } catch (e) {
      Logger.error('❌ Failed to check migration status: $e', tag: 'Migration');
      return false;
    }
  }

  /// Mark migration as completed
  static Future<void> markMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_migrationKey, _migrationVersion);
      Logger.info('✅ Service migration completed', tag: 'Migration');
    } catch (e) {
      Logger.error('❌ Failed to mark migration as completed: $e', tag: 'Migration');
    }
  }

  /// Perform migration if needed
  static Future<void> performMigrationIfNeeded() async {
    try {
      final isCompleted = await isMigrationCompleted();
      if (isCompleted) {
        Logger.info('✅ Service migration already completed', tag: 'Migration');
        return;
      }

      Logger.info('🔄 Starting service migration...', tag: 'Migration');
      
      // Clear old cache data that might conflict
      await _clearOldCacheData();
      
      // Mark migration as completed
      await markMigrationCompleted();
      
      Logger.info('✅ Service migration completed successfully', tag: 'Migration');
    } catch (e) {
      Logger.error('❌ Service migration failed: $e', tag: 'Migration');
    }
  }

  /// Clear old cache data that might conflict with new optimized services
  static Future<void> _clearOldCacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear old service-related cache keys
      final keysToRemove = [
        'llm_service_cache',
        'database_cache',
        'service_initialization_state',
        'old_llm_initialized',
      ];
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      Logger.info('🗑️ Cleared old cache data', tag: 'Migration');
    } catch (e) {
      Logger.warn('⚠️ Failed to clear old cache data: $e', tag: 'Migration');
    }
  }

  /// Reset migration status (for testing)
  static Future<void> resetMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_migrationKey);
      Logger.info('🔄 Migration status reset', tag: 'Migration');
    } catch (e) {
      Logger.error('❌ Failed to reset migration status: $e', tag: 'Migration');
    }
  }
}
