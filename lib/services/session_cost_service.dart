import 'dart:async';
import 'dart:math' as math;

import '../utils/logger.dart';
import 'cost_service.dart';

/// Data class for session cost updates
class SessionCostData {
  final double sessionCost;
  final int messageCount;
  final double lastMessageCost;
  final Map<String, dynamic>? lastMessageBreakdown;
  final int totalGenerations;
  final bool hasAccurateCosts;
  final String? error;

  SessionCostData({
    required this.sessionCost,
    required this.messageCount,
    required this.lastMessageCost,
    this.lastMessageBreakdown,
    required this.totalGenerations,
    required this.hasAccurateCosts,
    this.error,
  });

  @override
  String toString() {
    return 'SessionCostData(sessionCost: $sessionCost, messageCount: $messageCount, '
           'lastMessageCost: $lastMessageCost, totalGenerations: $totalGenerations, '
           'hasAccurateCosts: $hasAccurateCosts, error: $error)';
  }
}

/// Service for managing session-level cost tracking with accurate generation ID-based calculation
class SessionCostService {
  static final SessionCostService _instance = SessionCostService._internal();
  
  // Session cost tracking
  double _sessionCost = 0.0;
  int _messageCount = 0;
  String? _currentSessionId;

  final List<Map<String, dynamic>> _sessionGenerations = [];
  final Map<String, bool> _processedGenerationIds = {}; // Track processed generation IDs to prevent duplicates
  
  // Retry mechanism for failed fetches
  Timer? _retryTimer;
  final List<Map<String, dynamic>> _failedGenerations = [];
  bool _isRetrying = false;
  
  // Stream controller for cost updates
  final StreamController<SessionCostData> _costController = StreamController<SessionCostData>.broadcast();
  
  factory SessionCostService() => _instance;
  
  SessionCostService._internal();
  
  /// Stream of session cost updates
  Stream<SessionCostData> get costUpdates => _costController.stream;
  
  /// Get current session ID
  String? get currentSessionId => _currentSessionId;
  
  /// Get current message count
  int get messageCount => _messageCount;
  
  /// Get current session cost
  double get sessionCost => _sessionCost;

  /// Get all generation IDs for this session
  List<Map<String, dynamic>> get sessionGenerations => List.from(_sessionGenerations);

  /// Add generation IDs from a chat response and update session cost
  Future<void> addGenerationIds(List<Map<String, dynamic>>? generationIds, {String? sessionId}) async {
    if (generationIds == null || generationIds.isEmpty) {
      Logger.debug('No generation IDs to add');
      return;
    }

    // Set or verify session ID
    if (sessionId != null) {
      if (_currentSessionId != null && _currentSessionId != sessionId) {
        Logger.info('New session detected, resetting cost tracking');
        resetSession();
      }
      _currentSessionId = sessionId;
    }

    Logger.debug('Adding ${generationIds.length} generation IDs to session');
    
    // Filter out already processed generation IDs to prevent duplicates
    final newGenerationIds = generationIds.where((gen) {
      final genId = gen['id']?.toString();
      if (genId == null) return false;
      
      if (_processedGenerationIds.containsKey(genId)) {
        Logger.debug('Skipping duplicate generation ID: $genId');
        return false;
      }
      
      _processedGenerationIds[genId] = true;
      return true;
    }).toList();

    if (newGenerationIds.isEmpty) {
      Logger.debug('All generation IDs were already processed');
      return;
    }

    Logger.debug('Processing ${newGenerationIds.length} new generation IDs');
    
    // Add to session tracking
    _sessionGenerations.addAll(newGenerationIds);
    _messageCount++;
    
    // Calculate accurate costs using the new generation IDs
    final costResult = await CostService.calculateAccurateCosts(newGenerationIds);
    
    if (costResult['hasAccurateCosts'] == true) {
      final messageCost = (costResult['totalCost'] ?? 0.0).toDouble();
      _sessionCost += messageCost;
      
      Logger.debug('Session cost updated: +\$${messageCost.toStringAsFixed(6)} = \$${_sessionCost.toStringAsFixed(6)}');
      
      // Emit cost update
      _costController.add(SessionCostData(
        sessionCost: _sessionCost,
        messageCount: _messageCount,
        lastMessageCost: messageCost,
        lastMessageBreakdown: costResult['breakdown'] as Map<String, dynamic>?,
        totalGenerations: _sessionGenerations.length,
        hasAccurateCosts: true,
      ));
    } else {
      Logger.warn('Could not calculate accurate costs: ${costResult['error']}');
      
      // Track failed generations for retry
      final failedCount = (costResult['failedFetches'] ?? 0) as int;
      if (failedCount > 0) {
        _addFailedGenerations(newGenerationIds);
        _startRetryTimer();
      }
      
      // Still increment message count even if cost calculation failed
      _costController.add(SessionCostData(
        sessionCost: _sessionCost,
        messageCount: _messageCount,
        lastMessageCost: 0.0,
        lastMessageBreakdown: null,
        totalGenerations: _sessionGenerations.length,
        hasAccurateCosts: false,
        error: costResult['error'] as String?,
      ));
    }
  }

  /// Dispose resources
  void dispose() {
    _stopRetryTimer();
    _costController.close();
  }

  /// Get formatted session cost string
  String getFormattedSessionCost() {
    return CostService.getSessionCostSummary(
      sessionCost: _sessionCost,
      messageCount: _messageCount,
    );
  }

  /// Get generation count by model
  Map<String, int> getGenerationCountsByModel() {
    final counts = <String, int>{};
    for (final gen in _sessionGenerations) {
      final model = gen['model']?.toString() ?? 'unknown';
      counts[model] = (counts[model] ?? 0) + 1;
    }
    return counts;
  }

  /// Get generation count by stage
  Map<String, int> getGenerationCountsByStage() {
    final counts = <String, int>{};
    for (final gen in _sessionGenerations) {
      final stage = gen['stage']?.toString() ?? 'unknown';
      counts[stage] = (counts[stage] ?? 0) + 1;
    }
    return counts;
  }

  /// Get detailed session cost summary
  Future<Map<String, dynamic>> getSessionSummary() async {
    if (_sessionGenerations.isEmpty) {
      return {
        'sessionCost': 0.0,
        'messageCount': 0,
        'totalGenerations': 0,
        'breakdown': <String, dynamic>{},
        'hasAccurateCosts': true,
        'accuracy': 1.0,
        'successfulFetches': 0,
        'failedFetches': 0,
        'enhancedGenerations': <Map<String, dynamic>>[],
      };
    }

    // Calculate costs for all generations in this session
    final costResult = await CostService.calculateAccurateCosts(_sessionGenerations);
    
    // Merge generation data with cost data for enhanced display
    final enhancedGenerations = <Map<String, dynamic>>[];
    final costBreakdown = costResult['breakdown'] as Map<String, dynamic>? ?? {};
    final rawResponse = costResult['rawResponse'] as Map<String, dynamic>?;
    final generations = rawResponse?['generations'] as List<dynamic>? ?? [];
    
    for (int i = 0; i < _sessionGenerations.length; i++) {
      final originalGen = _sessionGenerations[i];
      final genId = originalGen['id'];
      
      // Find matching generation in cost response
      final matchingGen = generations.cast<Map<String, dynamic>>()
          .firstWhere((gen) => gen['id'] == genId, orElse: () => <String, dynamic>{});
      
      // Merge original data with cost data
      final enhanced = Map<String, dynamic>.from(originalGen);
      enhanced['success'] = matchingGen['success'] ?? false;
      enhanced['cost'] = matchingGen['success'] == true 
          ? (matchingGen['costData']?['total_cost'] ?? 0.0).toDouble() 
          : 0.0;
      enhanced['costData'] = matchingGen['costData'];
      
      enhancedGenerations.add(enhanced);
    }
    
    return {
      'sessionCost': costResult['totalCost'] ?? 0.0,
      'messageCount': _messageCount,
      'totalGenerations': _sessionGenerations.length,
      'breakdown': costBreakdown,
      'hasAccurateCosts': costResult['hasAccurateCosts'] ?? false,
      'accuracy': costResult['accuracy'] ?? 0.0,
      'successfulFetches': costResult['successfulFetches'] ?? 0,
      'failedFetches': costResult['failedFetches'] ?? 0,
      'error': costResult['error'],
      'enhancedGenerations': enhancedGenerations,
    };
  }

  /// Manually recalculate costs for all generations in the session
  /// This is useful for refreshing costs in the cost modal
  Future<void> recalculateSessionCosts() async {
    if (_sessionGenerations.isEmpty) {
      print('⚠️ No generations to recalculate');
      return;
    }

    print('🔄 Manually recalculating costs for ${_sessionGenerations.length} generations');
    
    // Calculate costs for all generations in this session
    final costResult = await CostService.calculateAccurateCosts(_sessionGenerations);
    
    if (costResult['hasAccurateCosts'] == true) {
      final newSessionCost = (costResult['totalCost'] ?? 0.0).toDouble();
      final costDifference = newSessionCost - _sessionCost;
      
      if (costDifference != 0) {
        _sessionCost = newSessionCost;
        print('✅ Session cost updated: \$${_sessionCost.toStringAsFixed(6)} (change: \$${costDifference.toStringAsFixed(6)})');
        
        // Emit updated cost
        _costController.add(SessionCostData(
          sessionCost: _sessionCost,
          messageCount: _messageCount,
          lastMessageCost: costDifference,
          lastMessageBreakdown: costResult['breakdown'] as Map<String, dynamic>?,
          totalGenerations: _sessionGenerations.length,
          hasAccurateCosts: true,
        ));
      } else {
        print('✅ Session cost unchanged: \$${_sessionCost.toStringAsFixed(6)}');
      }
      
      // Update failed generations list
      final failedFetches = (costResult['failedFetches'] ?? 0) as int;
      
      if (failedFetches > 0) {
        // Update failed generations list with any still-failed generations
        final rawResponse = costResult['rawResponse'] as Map<String, dynamic>?;
        final generations = rawResponse?['generations'] as List<dynamic>? ?? [];
        
        _failedGenerations.clear();
        for (final gen in generations) {
          if (gen['success'] == false) {
            _failedGenerations.add({
              'id': gen['id'],
              'stage': gen['stage'],
              'model': gen['model'],
              'inputTokens': gen['inputTokens'],
              'outputTokens': gen['outputTokens'],
              'totalTokens': gen['totalTokens'],
            });
          }
        }
        
        if (_failedGenerations.isNotEmpty) {
          print('⚠️ ${_failedGenerations.length} generations still failed, will continue retrying');
          _startRetryTimer();
        } else {
          _stopRetryTimer();
        }
      } else {
        _stopRetryTimer();
      }
    } else {
      print('⚠️ Could not recalculate accurate costs: ${costResult['error']}');
      
      // Emit error state
      _costController.add(SessionCostData(
        sessionCost: _sessionCost,
        messageCount: _messageCount,
        lastMessageCost: 0.0,
        lastMessageBreakdown: null,
        totalGenerations: _sessionGenerations.length,
        hasAccurateCosts: false,
        error: costResult['error'] as String?,
      ));
    }
  }

  /// Reset session cost tracking
  void resetSession() {
    print('🔄 Resetting session cost tracking');
    _stopRetryTimer();
    _sessionCost = 0.0;
    _messageCount = 0;
    _currentSessionId = null;
    _sessionGenerations.clear();
    _processedGenerationIds.clear();
    
    _costController.add(SessionCostData(
      sessionCost: 0.0,
      messageCount: 0,
      lastMessageCost: 0.0,
      lastMessageBreakdown: null,
      totalGenerations: 0,
      hasAccurateCosts: true,
    ));
  }

  /// Add failed generations to retry list
  void _addFailedGenerations(List<Map<String, dynamic>> generations) {
    for (final gen in generations) {
      if (!_failedGenerations.any((failed) => failed['id'] == gen['id'])) {
        _failedGenerations.add(gen);
      }
    }
    print('📝 Added ${generations.length} generations to retry list. Total failed: ${_failedGenerations.length}');
  }

  /// Retry failed generation cost fetches
  Future<void> _retryFailedGenerations() async {
    if (_failedGenerations.isEmpty) {
      _stopRetryTimer();
      return;
    }

    print('🔄 Retrying ${_failedGenerations.length} failed generations...');
    
    final retryGenerations = List<Map<String, dynamic>>.from(_failedGenerations);
    final costResult = await CostService.calculateAccurateCosts(retryGenerations);
    
    if (costResult['hasAccurateCosts'] == true) {
      final successfulFetches = (costResult['successfulFetches'] ?? 0) as int;
      final failedFetches = (costResult['failedFetches'] ?? 0) as int;
      
      if (successfulFetches > 0) {
        final additionalCost = (costResult['totalCost'] ?? 0.0).toDouble();
        _sessionCost += additionalCost;
        
        print('✅ Retry successful! Added \$${additionalCost.toStringAsFixed(6)} to session cost');
        
        // Remove successful generations from failed list
        final successfulGenerations = costResult['rawResponse']?['generations'] 
            ?.where((gen) => gen['success'] == true)
            ?.map((gen) => gen['id'])
            ?.toList() ?? [];
        
        _failedGenerations.removeWhere(
          (failed) => successfulGenerations.contains(failed['id'])
        );
        
        // Emit updated cost
        _costController.add(SessionCostData(
          sessionCost: _sessionCost,
          messageCount: _messageCount,
          lastMessageCost: additionalCost,
          lastMessageBreakdown: costResult['breakdown'] as Map<String, dynamic>?,
          totalGenerations: _sessionGenerations.length,
          hasAccurateCosts: true,
        ));
      }
      
      if (failedFetches == 0) {
        print('🎉 All failed generations successfully retried!');
        _stopRetryTimer();
      } else {
        print('⚠️ $failedFetches generations still failed, will retry again');
        // Continue retrying with exponential backoff
        _scheduleNextRetry();
      }
    } else {
      print('⚠️ Retry failed: ${costResult['error']}');
      // Continue retrying with exponential backoff
      _scheduleNextRetry();
    }
  }

  /// Schedule next retry with exponential backoff
  void _scheduleNextRetry() {
    if (_failedGenerations.isEmpty) {
      _stopRetryTimer();
      return;
    }
    
    // Calculate exponential backoff: 5s, 10s, 20s, 40s, max 60s
    final retryCount = _failedGenerations.isNotEmpty ? _failedGenerations.length : 1;
    final backoffSeconds = math.min(5 * math.pow(2, retryCount - 1), 60).toInt();
    
    print('⏰ Scheduling next retry in ${backoffSeconds}s for ${_failedGenerations.length} failed generations');
    
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: backoffSeconds), () {
      _retryFailedGenerations();
    });
  }

  /// Start retry timer for failed fetches
  void _startRetryTimer() {
    if (_isRetrying || _failedGenerations.isEmpty) return;
    
    _isRetrying = true;
    print('🔄 Starting retry timer for ${_failedGenerations.length} failed fetches');
    
    // Use exponential backoff scheduling instead of fixed interval
    _scheduleNextRetry();
  }

  /// Stop retry timer
  void _stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _isRetrying = false;
    _failedGenerations.clear();
    print('⏹️ Retry timer stopped');
  }
}
