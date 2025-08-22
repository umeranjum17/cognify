import '../database/database_service.dart';
import '../utils/logger.dart';

/// Service for advanced user spending tracking and analytics
/// Provides spending summaries, limits, alerts, and detailed breakdowns
class UserSpendingService {
  static final UserSpendingService _instance = UserSpendingService._internal();
  
  final DatabaseService _databaseService = DatabaseService();
  
  factory UserSpendingService() => _instance;
  
  UserSpendingService._internal();
  
  /// Get total user spending
  Future<double> getTotalSpending() async {
    return await _databaseService.getUserTotalSpending();
  }
  
  /// Add spending amount (called automatically by cache service)
  Future<void> addSpending(double amount, {
    String? model,
    String? stage,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    await _databaseService.addToUserSpending(amount);
    
    // Store detailed spending record
    final detailedRecord = {
      'amount': amount,
      'model': model,
      'stage': stage,
      'sessionId': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      ...?metadata,
    };
    
    await _storeDetailedSpending(detailedRecord);
  }
  
  /// Get spending history with optional filters
  Future<List<Map<String, dynamic>>> getSpendingHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? model,
    String? stage,
    String? sessionId,
  }) async {
    final allHistory = await _databaseService.getUserSpendingHistory();
    
    return allHistory.where((record) {
      final recordDate = DateTime.parse(record['timestamp']);
      
      // Date filters
      if (startDate != null && recordDate.isBefore(startDate)) return false;
      if (endDate != null && recordDate.isAfter(endDate)) return false;
      
      // Model filter
      if (model != null && record['model'] != model) return false;
      
      // Stage filter  
      if (stage != null && record['stage'] != stage) return false;
      
      // Session filter
      if (sessionId != null && record['sessionId'] != sessionId) return false;
      
      return true;
    }).toList();
  }
  
  /// Get spending summary for different time periods
  Future<Map<String, dynamic>> getSpendingSummary() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);
    
    final history = await getSpendingHistory();
    
    double todaySpending = 0.0;
    double yesterdaySpending = 0.0;
    double weekSpending = 0.0;
    double monthSpending = 0.0;
    double yearSpending = 0.0;
    double totalSpending = 0.0;
    
    for (final record in history) {
      final recordDate = DateTime.parse(record['timestamp']);
      final amount = (record['amount'] ?? 0.0).toDouble();
      
      totalSpending += amount;
      
      if (recordDate.isAfter(today)) {
        todaySpending += amount;
      }
      
      if (recordDate.isAfter(yesterday) && recordDate.isBefore(today)) {
        yesterdaySpending += amount;
      }
      
      if (recordDate.isAfter(weekStart)) {
        weekSpending += amount;
      }
      
      if (recordDate.isAfter(monthStart)) {
        monthSpending += amount;
      }
      
      if (recordDate.isAfter(yearStart)) {
        yearSpending += amount;
      }
    }
    
    return {
      'today': todaySpending,
      'yesterday': yesterdaySpending,
      'thisWeek': weekSpending,
      'thisMonth': monthSpending,
      'thisYear': yearSpending,
      'total': totalSpending,
      'recordCount': history.length,
    };
  }
  
  /// Get spending breakdown by model
  Future<Map<String, double>> getSpendingByModel() async {
    final history = await getSpendingHistory();
    final breakdown = <String, double>{};
    
    for (final record in history) {
      final model = record['model'] as String? ?? 'unknown';
      final amount = (record['amount'] ?? 0.0).toDouble();
      breakdown[model] = (breakdown[model] ?? 0.0) + amount;
    }
    
    return breakdown;
  }
  
  /// Get spending breakdown by stage
  Future<Map<String, double>> getSpendingByStage() async {
    final history = await getSpendingHistory();
    final breakdown = <String, double>{};
    
    for (final record in history) {
      final stage = record['stage'] as String? ?? 'unknown';
      final amount = (record['amount'] ?? 0.0).toDouble();
      breakdown[stage] = (breakdown[stage] ?? 0.0) + amount;
    }
    
    return breakdown;
  }
  
  /// Get daily spending over the last N days
  Future<List<Map<String, dynamic>>> getDailySpending({int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    
    final history = await getSpendingHistory(startDate: startDate);
    final dailyMap = <String, double>{};
    
    // Initialize all days with 0
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyMap[dateKey] = 0.0;
    }
    
    // Aggregate spending by day
    for (final record in history) {
      final recordDate = DateTime.parse(record['timestamp']);
      final dateKey = '${recordDate.year}-${recordDate.month.toString().padLeft(2, '0')}-${recordDate.day.toString().padLeft(2, '0')}';
      final amount = (record['amount'] ?? 0.0).toDouble();
      dailyMap[dateKey] = (dailyMap[dateKey] ?? 0.0) + amount;
    }
    
    // Convert to list format
    return dailyMap.entries.map((entry) => {
      'date': entry.key,
      'amount': entry.value,
    }).toList()..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }
  
  /// Check if user has exceeded spending limits
  Future<Map<String, dynamic>> checkSpendingLimits() async {
    final limits = await _getSpendingLimits();
    final summary = await getSpendingSummary();
    
    final alerts = <String, dynamic>{};
    
    if (limits['daily'] != null && summary['today'] > limits['daily']) {
      alerts['daily'] = {
        'limit': limits['daily'],
        'current': summary['today'],
        'exceeded': true,
      };
    }
    
    if (limits['weekly'] != null && summary['thisWeek'] > limits['weekly']) {
      alerts['weekly'] = {
        'limit': limits['weekly'],
        'current': summary['thisWeek'],
        'exceeded': true,
      };
    }
    
    if (limits['monthly'] != null && summary['thisMonth'] > limits['monthly']) {
      alerts['monthly'] = {
        'limit': limits['monthly'],
        'current': summary['thisMonth'],
        'exceeded': true,
      };
    }
    
    return {
      'hasAlerts': alerts.isNotEmpty,
      'alerts': alerts,
      'summary': summary,
      'limits': limits,
    };
  }
  
  /// Set spending limits
  Future<void> setSpendingLimits({
    double? daily,
    double? weekly,
    double? monthly,
  }) async {
    final limits = {
      if (daily != null) 'daily': daily,
      if (weekly != null) 'weekly': weekly,
      if (monthly != null) 'monthly': monthly,
    };
    
    await _databaseService.setSetting('spending_limits', limits);
    Logger.info('Updated spending limits: $limits');
  }
  
  /// Get current spending limits
  Future<Map<String, double>> _getSpendingLimits() async {
    final limits = await _databaseService.getSetting<Map<String, dynamic>>('spending_limits');
    if (limits == null) return {};
    
    return limits.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }
  
  /// Export spending data to CSV format
  Future<String> exportSpendingData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final history = await getSpendingHistory(
      startDate: startDate,
      endDate: endDate,
    );
    
    final csv = StringBuffer();
    csv.writeln('timestamp,amount,model,stage,sessionId');
    
    for (final record in history) {
      csv.writeln([
        record['timestamp'],
        record['amount'],
        record['model'] ?? '',
        record['stage'] ?? '',
        record['sessionId'] ?? '',
      ].join(','));
    }
    
    return csv.toString();
  }
  
  /// Reset all spending data (with confirmation)
  Future<void> resetSpendingData() async {
    await _databaseService.resetUserSpending();
    await _databaseService.deleteSetting('detailed_spending');
    Logger.info('🗑️ Reset all spending data');
  }
  
  /// Store detailed spending record
  Future<void> _storeDetailedSpending(Map<String, dynamic> record) async {
    final existing = await _databaseService.getSetting<List<dynamic>>('detailed_spending') ?? [];
    existing.add(record);
    
    // Keep only last 10000 records to avoid storage bloat
    if (existing.length > 10000) {
      existing.removeRange(0, existing.length - 10000);
    }
    
    await _databaseService.setSetting('detailed_spending', existing);
  }
  
  /// Get formatted spending summary text
  String formatSpendingSummary(Map<String, dynamic> summary) {
    final today = summary['today'] as double;
    final thisWeek = summary['thisWeek'] as double;
    final thisMonth = summary['thisMonth'] as double;
    final total = summary['total'] as double;
    
    return '''
📊 Spending Summary
Today: \$${today.toStringAsFixed(4)}
This Week: \$${thisWeek.toStringAsFixed(4)}
This Month: \$${thisMonth.toStringAsFixed(4)}
Total: \$${total.toStringAsFixed(4)}
''';
  }
}