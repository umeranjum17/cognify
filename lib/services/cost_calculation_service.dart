import '../database/database_service.dart';
import 'openai_client.dart';
import 'openrouter_client.dart';

/// Token counting and cost tracking service for API usage
class CostCalculationService {
  static final CostCalculationService _instance = CostCalculationService._internal();
  // Token estimation constants
  static const double _averageTokensPerWord = 1.3;
  static const double _averageCharsPerToken = 4.0;

  final DatabaseService _db = DatabaseService();
  bool _initialized = false;

  // Cost tracking
  double _totalCost = 0.0;
  int _totalInputTokens = 0;

  int _totalOutputTokens = 0;
  Map<String, Map<String, dynamic>> _modelUsage = {};
  factory CostCalculationService() => _instance;
  CostCalculationService._internal();

  /// Calculate cost for a specific model and token usage
  Future<double> calculateCost({
    required String model,
    required int inputTokens,
    required int outputTokens,
    String provider = 'openrouter',
  }) async {
    await _ensureInitialized();
    
    try {
      Map<String, double>? pricing;
      
      if (provider == 'openrouter') {
        final openRouterClient = OpenRouterClient();
        final modelsData = await openRouterClient.getModels();
        final modelPricing = modelsData['pricing'] as Map<String, Map<String, double>>;
        pricing = modelPricing[model];
      } else if (provider == 'openai') {
        pricing = OpenAIClient.modelPricing[model];
      }
      
      if (pricing == null) {
        print('💰 No pricing data found for model: $model');
        return 0.0;
      }
      
      final inputCost = (inputTokens / 1000000) * pricing['input']!;
      final outputCost = (outputTokens / 1000000) * pricing['output']!;
      
      return inputCost + outputCost;
      
    } catch (e) {
      print('💰 Failed to calculate cost for model: $model - $e');
      return 0.0;
    }
  }

  /// Estimate cost for a prompt before sending
  Future<Map<String, dynamic>> estimateCost({
    required String model,
    required List<Map<String, dynamic>> messages,
    int? maxOutputTokens,
    String provider = 'openrouter',
  }) async {
    await _ensureInitialized();
    
    final inputTokens = estimateMessagesTokenCount(messages);
    final estimatedOutputTokens = maxOutputTokens ?? (inputTokens * 0.3).ceil(); // Estimate 30% of input
    
    final estimatedCost = await calculateCost(
      model: model,
      inputTokens: inputTokens,
      outputTokens: estimatedOutputTokens,
      provider: provider,
    );
    
    return {
      'inputTokens': inputTokens,
      'estimatedOutputTokens': estimatedOutputTokens,
      'totalTokens': inputTokens + estimatedOutputTokens,
      'estimatedCost': estimatedCost,
      'model': model,
      'provider': provider,
    };
  }

  /// Estimate tokens for a list of messages
  int estimateMessagesTokenCount(List<Map<String, dynamic>> messages) {
    int totalTokens = 0;
    
    for (final message in messages) {
      final content = message['content'] as String? ?? '';
      final role = message['role'] as String? ?? '';
      
      // Add tokens for content
      totalTokens += estimateTokenCount(content);
      
      // Add overhead tokens for message structure
      totalTokens += 4; // Overhead for role, content structure
      
      // Add tokens for role
      totalTokens += estimateTokenCount(role);
    }
    
    // Add overhead for the messages array structure
    totalTokens += 2;
    
    return totalTokens;
  }

  /// Estimate token count from text
  int estimateTokenCount(String text) {
    if (text.isEmpty) return 0;
    
    // Method 1: Character-based estimation
    final charBasedTokens = (text.length / _averageCharsPerToken).ceil();
    
    // Method 2: Word-based estimation
    final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    final wordBasedTokens = (words * _averageTokensPerWord).ceil();
    
    // Use the average of both methods for better accuracy
    return ((charBasedTokens + wordBasedTokens) / 2).ceil();
  }

  /// Get all model usage statistics
  Map<String, Map<String, dynamic>> getAllModelStats() {
    return Map.from(_modelUsage);
  }

  /// Get cost breakdown by provider
  Map<String, Map<String, dynamic>> getCostByProvider() {
    final breakdown = <String, Map<String, dynamic>>{};
    
    for (final usage in _modelUsage.values) {
      final provider = usage['provider'] as String;
      
      if (!breakdown.containsKey(provider)) {
        breakdown[provider] = {
          'cost': 0.0,
          'inputTokens': 0,
          'outputTokens': 0,
          'requestCount': 0,
          'modelCount': 0,
        };
      }
      
      final providerStats = breakdown[provider]!;
      providerStats['cost'] = (providerStats['cost'] as double) + (usage['cost'] as double);
      providerStats['inputTokens'] = (providerStats['inputTokens'] as int) + (usage['inputTokens'] as int);
      providerStats['outputTokens'] = (providerStats['outputTokens'] as int) + (usage['outputTokens'] as int);
      providerStats['requestCount'] = (providerStats['requestCount'] as int) + (usage['requestCount'] as int);
      providerStats['modelCount'] = (providerStats['modelCount'] as int) + 1;
    }
    
    return breakdown;
  }

  /// Get cost efficiency metrics
  Map<String, dynamic> getEfficiencyMetrics() {
    if (_modelUsage.isEmpty) {
      return {
        'mostEfficientModel': null,
        'leastEfficientModel': null,
        'averageCostPerRequest': 0.0,
        'averageTokensPerRequest': 0.0,
      };
    }
    
    // Calculate cost per token for each model
    final modelEfficiency = <String, double>{};
    double totalRequests = 0;
    double totalCostPerRequest = 0;
    double totalTokensPerRequest = 0;
    
    for (final entry in _modelUsage.entries) {
      final usage = entry.value;
      final totalTokens = (usage['inputTokens'] as int) + (usage['outputTokens'] as int);
      final cost = usage['cost'] as double;
      final requests = usage['requestCount'] as int;
      
      if (totalTokens > 0) {
        modelEfficiency[entry.key] = cost / totalTokens;
      }
      
      totalRequests += requests;
      totalCostPerRequest += cost;
      totalTokensPerRequest += totalTokens;
    }
    
    String? mostEfficient;
    String? leastEfficient;
    double bestEfficiency = double.infinity;
    double worstEfficiency = 0.0;
    
    for (final entry in modelEfficiency.entries) {
      if (entry.value < bestEfficiency) {
        bestEfficiency = entry.value;
        mostEfficient = entry.key;
      }
      if (entry.value > worstEfficiency) {
        worstEfficiency = entry.value;
        leastEfficient = entry.key;
      }
    }
    
    return {
      'mostEfficientModel': mostEfficient,
      'leastEfficientModel': leastEfficient,
      'averageCostPerRequest': totalRequests > 0 ? totalCostPerRequest / totalRequests : 0.0,
      'averageTokensPerRequest': totalRequests > 0 ? totalTokensPerRequest / totalRequests : 0.0,
    };
  }

  /// Get usage statistics for a specific model
  Map<String, dynamic>? getModelStats(String model, {String provider = 'openrouter'}) {
    final modelKey = '$provider:$model';
    return _modelUsage[modelKey];
  }

  /// Get top models by request count
  List<Map<String, dynamic>> getTopModelsByRequests({int limit = 10}) {
    final sortedModels = _modelUsage.values.toList()
      ..sort((a, b) => (b['requestCount'] as int).compareTo(a['requestCount'] as int));
    
    return sortedModels.take(limit).toList();
  }

  /// Get top models by usage
  List<Map<String, dynamic>> getTopModelsByUsage({int limit = 10}) {
    final sortedModels = _modelUsage.values.toList()
      ..sort((a, b) => (b['cost'] as double).compareTo(a['cost'] as double));
    
    return sortedModels.take(limit).toList();
  }

  /// Get total cost and usage statistics
  Map<String, dynamic> getTotalStats() {
    return {
      'totalCost': _totalCost,
      'totalInputTokens': _totalInputTokens,
      'totalOutputTokens': _totalOutputTokens,
      'totalTokens': _totalInputTokens + _totalOutputTokens,
      'averageCostPerToken': _totalInputTokens + _totalOutputTokens > 0 
          ? _totalCost / (_totalInputTokens + _totalOutputTokens)
          : 0.0,
      'modelCount': _modelUsage.length,
    };
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _db.initialize();
    await _loadCostData();
    
    _initialized = true;
    print('💰 CostCalculationService initialized');
  }

  /// Reset all cost and usage data
  Future<void> resetStats() async {
    await _ensureInitialized();
    
    _totalCost = 0.0;
    _totalInputTokens = 0;
    _totalOutputTokens = 0;
    _modelUsage.clear();
    
    await _saveCostData();
    
    print('💰 Cost and usage statistics reset');
  }

  /// Track usage and cost for a model
  Future<void> trackUsage({
    required String model,
    required int inputTokens,
    required int outputTokens,
    required double cost,
    String provider = 'openrouter',
  }) async {
    await _ensureInitialized();
    
    // Update totals
    _totalCost += cost;
    _totalInputTokens += inputTokens;
    _totalOutputTokens += outputTokens;
    
    // Update model-specific usage
    final modelKey = '$provider:$model';
    if (!_modelUsage.containsKey(modelKey)) {
      _modelUsage[modelKey] = {
        'model': model,
        'provider': provider,
        'inputTokens': 0,
        'outputTokens': 0,
        'cost': 0.0,
        'requestCount': 0,
        'firstUsed': DateTime.now().toIso8601String(),
      };
    }
    
    final usage = _modelUsage[modelKey]!;
    usage['inputTokens'] = (usage['inputTokens'] as int) + inputTokens;
    usage['outputTokens'] = (usage['outputTokens'] as int) + outputTokens;
    usage['cost'] = (usage['cost'] as double) + cost;
    usage['requestCount'] = (usage['requestCount'] as int) + 1;
    usage['lastUsed'] = DateTime.now().toIso8601String();
    
    // Save to database
    await _saveCostData();
    
    // Usage tracked silently
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Load cost data from database
  Future<void> _loadCostData() async {
    try {
      _totalCost = await _db.getSetting<double>('total_cost', defaultValue: 0.0) ?? 0.0;
      _totalInputTokens = await _db.getSetting<int>('total_input_tokens', defaultValue: 0) ?? 0;
      _totalOutputTokens = await _db.getSetting<int>('total_output_tokens', defaultValue: 0) ?? 0;
      
      final modelUsageJson = await _db.getSetting<String>('model_usage');
      if (modelUsageJson != null) {
        final decoded = Map<String, dynamic>.from(
          Map<String, dynamic>.from(
            Map<String, dynamic>.from(modelUsageJson as Map)
          )
        );
        _modelUsage = decoded.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
      }
      
    } catch (e) {
      print('💰 Failed to load cost data: $e');
    }
  }

  /// Save cost data to database
  Future<void> _saveCostData() async {
    try {
      await _db.saveSetting('total_cost', _totalCost);
      await _db.saveSetting('total_input_tokens', _totalInputTokens);
      await _db.saveSetting('total_output_tokens', _totalOutputTokens);
      await _db.saveSetting('model_usage', _modelUsage);
    } catch (e) {
      print('💰 Failed to save cost data: $e');
    }
  }
}
