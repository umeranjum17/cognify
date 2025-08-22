import '../database/database_service.dart';
import '../utils/logger.dart';
import 'openrouter_client.dart';

/// Service for intelligently caching generation costs to avoid redundant API calls
/// This service implements a smart caching strategy that:
/// 1. Checks local cache first
/// 2. Only fetches uncached generation costs from API
/// 3. Tracks user spending automatically
/// 4. Provides batch operations for efficiency
class GenerationCostCacheService {
  static final GenerationCostCacheService _instance = GenerationCostCacheService._internal();
  
  final DatabaseService _databaseService = DatabaseService();
  OpenRouterClient? _openRouterClient;
  
  factory GenerationCostCacheService() => _instance;
  
  GenerationCostCacheService._internal();
  
  /// Initialize the service with OpenRouter client
  void initialize(OpenRouterClient openRouterClient) {
    _openRouterClient = openRouterClient;
  }
  
  /// Get generation costs with intelligent caching
  /// Returns map with cost data for each generation ID
  Future<Map<String, dynamic>> getGenerationCosts(List<Map<String, dynamic>> generationIds) async {
    if (generationIds.isEmpty) {
      return {
        'success': true,
        'totalApiCost': 0.0,
        'successfulFetches': 0,
        'failedFetches': 0,
        'cachedFetches': 0,
        'accuracy': 1.0,
        'generations': [],
      };
    }

    Logger.info('🔍 Fetching costs for ${generationIds.length} generations with smart caching');
    
    final List<Map<String, dynamic>> processedGenerations = [];
    int successfulFetches = 0;
    int failedFetches = 0;
    int cachedFetches = 0;
    double totalCost = 0.0;
    
    // First, check cache for all generation IDs
    final cachedCosts = <String, Map<String, dynamic>>{};
    final uncachedGenerations = <Map<String, dynamic>>[];
    
    for (final genInfo in generationIds) {
      final generationId = genInfo['id'] as String?;
      if (generationId == null) continue;
      
      final cachedCost = await _databaseService.getGenerationCost(generationId);
      if (cachedCost != null) {
        cachedCosts[generationId] = cachedCost;
        cachedFetches++;
        Logger.debug('✅ Found cached cost for generation $generationId');
      } else {
        uncachedGenerations.add(genInfo);
        Logger.debug('❌ No cached cost for generation $generationId');
      }
    }
    
    Logger.info('📊 Cache stats: ${cachedFetches} cached, ${uncachedGenerations.length} need fetching');
    
    // Process cached generations
    for (final genInfo in generationIds) {
      final generationId = genInfo['id'] as String?;
      if (generationId == null) continue;
      
      final stage = genInfo['stage'] as String? ?? 'unknown';
      final model = genInfo['model'] as String? ?? 'unknown';
      final inputTokens = genInfo['inputTokens'] as int? ?? 0;
      final outputTokens = genInfo['outputTokens'] as int? ?? 0;
      final totalTokens = genInfo['totalTokens'] as int? ?? 0;
      
      final cachedCost = cachedCosts[generationId];
      if (cachedCost != null) {
        final cost = (cachedCost['total_cost'] ?? 0.0).toDouble();
        totalCost += cost;
        
        processedGenerations.add({
          'id': generationId,
          'stage': stage,
          'model': model,
          'inputTokens': inputTokens,
          'outputTokens': outputTokens,
          'totalTokens': totalTokens,
          'success': true,
          'costData': cachedCost,
          'fetchedAt': cachedCost['cachedAt'],
          'fromCache': true,
        });
      }
    }
    
    // Fetch uncached generations from API
    if (uncachedGenerations.isNotEmpty && _openRouterClient != null) {
      Logger.info('🌐 Fetching ${uncachedGenerations.length} uncached generations from API');
      
      for (final genInfo in uncachedGenerations) {
        final generationId = genInfo['id'] as String?;
        final stage = genInfo['stage'] as String? ?? 'unknown';
        final model = genInfo['model'] as String? ?? 'unknown';
        final inputTokens = genInfo['inputTokens'] as int? ?? 0;
        final outputTokens = genInfo['outputTokens'] as int? ?? 0;
        final totalTokens = genInfo['totalTokens'] as int? ?? 0;
        
        if (generationId == null) {
          failedFetches++;
          continue;
        }
        
        try {
          final costData = await _openRouterClient!.getGenerationCost(generationId);
          
          if (costData != null) {
            final cost = (costData['total_cost'] ?? 0.0).toDouble();
            totalCost += cost;
            successfulFetches++;
            
            // Cache the successful result
            await _databaseService.saveGenerationCost(generationId, costData);
            
            processedGenerations.add({
              'id': generationId,
              'stage': stage,
              'model': model,
              'inputTokens': inputTokens,
              'outputTokens': outputTokens,
              'totalTokens': totalTokens,
              'success': true,
              'costData': costData,
              'fetchedAt': DateTime.now().toIso8601String(),
              'fromCache': false,
            });
            
            Logger.debug('✅ Fetched and cached cost for generation $generationId: \$${cost.toStringAsFixed(6)}');
          } else {
            failedFetches++;
            processedGenerations.add({
              'id': generationId,
              'stage': stage,
              'model': model,
              'inputTokens': inputTokens,
              'outputTokens': outputTokens,
              'totalTokens': totalTokens,
              'success': false,
              'costData': null,
              'error': 'Failed to fetch cost data',
              'fromCache': false,
            });
            
            Logger.warn('⚠️ Failed to fetch cost for generation $generationId');
          }
        } catch (e) {
          failedFetches++;
          processedGenerations.add({
            'id': generationId,
            'stage': stage,
            'model': model,
            'inputTokens': inputTokens,
            'outputTokens': outputTokens,
            'totalTokens': totalTokens,
            'success': false,
            'costData': null,
            'error': e.toString(),
            'fromCache': false,
          });
          
          Logger.error('❌ Error fetching cost for generation $generationId: $e');
        }
      }
    }
    
    // Update user spending if we have new costs
    if (totalCost > 0) {
      try {
        // Only add spending for newly fetched costs (not cached ones)
        final newCosts = processedGenerations
            .where((gen) => gen['success'] == true && gen['fromCache'] == false)
            .map((gen) => (gen['costData']['total_cost'] ?? 0.0).toDouble())
            .fold(0.0, (sum, cost) => sum + cost);
            
        if (newCosts > 0) {
          await _databaseService.addToUserSpending(newCosts);
          Logger.info('💰 Added \$${newCosts.toStringAsFixed(6)} to user spending');
        }
      } catch (e) {
        Logger.error('Error updating user spending: $e');
      }
    }
    
    final totalFetches = successfulFetches + failedFetches + cachedFetches;
    final accuracy = totalFetches > 0 ? (successfulFetches + cachedFetches) / totalFetches : 0.0;
    
    Logger.info('📊 Final stats: ${successfulFetches} API success, ${failedFetches} API failed, ${cachedFetches} cached, total cost: \$${totalCost.toStringAsFixed(6)}');
    
    return {
      'success': true,
      'totalApiCost': totalCost,
      'successfulFetches': successfulFetches,
      'failedFetches': failedFetches,
      'cachedFetches': cachedFetches,
      'accuracy': accuracy,
      'generations': processedGenerations,
    };
  }
  
  /// Get a single generation cost (with caching)
  Future<Map<String, dynamic>?> getGenerationCost(String generationId) async {
    // Check cache first
    final cachedCost = await _databaseService.getGenerationCost(generationId);
    if (cachedCost != null) {
      Logger.debug('✅ Retrieved cached cost for generation $generationId');
      return cachedCost;
    }
    
    // Fetch from API if not cached
    if (_openRouterClient != null) {
      try {
        final costData = await _openRouterClient!.getGenerationCost(generationId);
        if (costData != null) {
          // Cache the result
          await _databaseService.saveGenerationCost(generationId, costData);
          
          // Update user spending
          final cost = (costData['total_cost'] ?? 0.0).toDouble();
          if (cost > 0) {
            await _databaseService.addToUserSpending(cost);
          }
          
          Logger.debug('✅ Fetched and cached cost for generation $generationId');
          return costData;
        }
      } catch (e) {
        Logger.error('Error fetching cost for generation $generationId: $e');
      }
    }
    
    return null;
  }
  
  /// Preload costs for a list of generation IDs (fire and forget)
  void preloadGenerationCosts(List<String> generationIds) {
    // Run in background without awaiting
    _preloadCostsInBackground(generationIds);
  }
  
  Future<void> _preloadCostsInBackground(List<String> generationIds) async {
    try {
      final uncachedIds = <String>[];
      
      // Check which ones aren't cached
      for (final id in generationIds) {
        final cached = await _databaseService.getGenerationCost(id);
        if (cached == null) {
          uncachedIds.add(id);
        }
      }
      
      if (uncachedIds.isNotEmpty && _openRouterClient != null) {
        Logger.info('🔄 Preloading ${uncachedIds.length} generation costs in background');
        
        // Fetch them one by one (to avoid overwhelming the API)
        for (final id in uncachedIds) {
          try {
            final costData = await _openRouterClient!.getGenerationCost(id);
            if (costData != null) {
              await _databaseService.saveGenerationCost(id, costData);
            }
            
            // Small delay to avoid rate limiting
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            Logger.debug('Failed to preload cost for $id: $e');
          }
        }
      }
    } catch (e) {
      Logger.error('Error preloading generation costs: $e');
    }
  }
  
  /// Clear cache for specific generation IDs
  Future<void> clearCache(List<String> generationIds) async {
    for (final id in generationIds) {
      await _databaseService.deleteGenerationCost(id);
    }
    Logger.info('🗑️ Cleared cache for ${generationIds.length} generations');
  }
  
  /// Clear old cached costs (maintenance)
  Future<void> clearOldCache({int olderThanDays = 30}) async {
    await _databaseService.clearOldGenerationCosts(olderThanDays: olderThanDays);
  }
  
  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final stats = await _databaseService.getStats();
    final totalSpending = await _databaseService.getUserTotalSpending();
    
    return {
      'cachedGenerations': stats['generationCosts'] ?? 0,
      'totalUserSpending': totalSpending,
      'spendingHistory': await _databaseService.getUserSpendingHistory(),
    };
  }
}