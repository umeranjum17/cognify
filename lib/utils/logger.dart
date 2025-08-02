import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as pkg_logger;

/// Log levels enumeration
enum LogLevel {
  debug(0),
  info(1),
  warn(2),
  error(3);

  const LogLevel(this.value);
  final int value;
}

/// Enhanced logging utility with configurable log levels and file output
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  late pkg_logger.Logger _logger;
  LogLevel _logLevel = LogLevel.info;

  void initialize({LogLevel logLevel = LogLevel.info}) {
    _logLevel = logLevel;
    
    _logger = pkg_logger.Logger(
      printer: pkg_logger.PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: _mapLogLevel(logLevel),
    );
  }

  pkg_logger.Level _mapLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return pkg_logger.Level.debug;
      case LogLevel.info:
        return pkg_logger.Level.info;
      case LogLevel.warn:
        return pkg_logger.Level.warning;
      case LogLevel.error:
        return pkg_logger.Level.error;
    }
  }

  void setLogLevel(LogLevel level) {
    _logLevel = level;
  }

  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_logLevel.value <= LogLevel.debug.value) {
      _logger.d(message, error: error, stackTrace: stackTrace);
      if (kDebugMode) {
        developer.log('[DEBUG] $message', name: 'Cognify');
      }
    }
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_logLevel.value <= LogLevel.info.value) {
      _logger.i(message, error: error, stackTrace: stackTrace);
      if (kDebugMode) {
        developer.log('[INFO] $message', name: 'Cognify');
      }
    }
  }

  void warn(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_logLevel.value <= LogLevel.warn.value) {
      _logger.w(message, error: error, stackTrace: stackTrace);
      if (kDebugMode) {
        developer.log('[WARN] $message', name: 'Cognify');
      }
    }
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_logLevel.value <= LogLevel.error.value) {
      _logger.e(message, error: error, stackTrace: stackTrace);
      if (kDebugMode) {
        developer.log('[ERROR] $message', name: 'Cognify', error: error, stackTrace: stackTrace);
      }
    }
  }

  // Tool-specific logging methods
  void toolStart(String toolName, String? prompt) {
    debug('Starting tool execution: $toolName');
    if (prompt != null && prompt.length > 100) {
      debug('Prompt: ${prompt.substring(0, 100)}...');
    } else if (prompt != null) {
      debug('Prompt: $prompt');
    }
  }

  void toolComplete(String toolName, int durationMs) {
    debug('Tool $toolName completed in ${durationMs}ms');
  }

  void toolError(String toolName, dynamic error) {
    this.error('Tool $toolName failed: ${error.toString()}');
  }

  // LLM decision logging
  void llmDecisionStart(String prompt, Map<String, bool> enabledTools) {
    debug('LLM Decision Engine: Starting tool selection');
    final enabledToolNames = enabledTools.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .join(', ');
    debug('Enabled tools: $enabledToolNames');
  }

  void llmDecisionResult(Map<String, dynamic> decision) {
    if (_logLevel.value <= LogLevel.debug.value) {
      debug('LLM Decision Result: ${_prettyPrintJson(decision)}');
    } else {
      final tools = decision['tools'] as Map<String, dynamic>?;
      if (tools != null) {
        final toolsToUse = tools.entries
            .where((entry) => (entry.value as Map<String, dynamic>)['use'] == true)
            .map((entry) => entry.key)
            .join(', ');
        info('AI tools selected: ${toolsToUse.isEmpty ? 'none' : toolsToUse}');
      }
    }
  }

  void llmDecisionComplete(int iterations, int totalTimeMs, List<String> toolsExecuted) {
    info('Tool execution completed: ${toolsExecuted.join(', ')} ($iterations iterations, ${totalTimeMs}ms)');
  }

  // API request logging
  void apiRequest(String method, String url, {Map<String, dynamic>? data}) {
    debug('API Request: $method $url');
    if (data != null && _logLevel.value <= LogLevel.debug.value) {
      debug('Request data: ${_prettyPrintJson(data)}');
    }
  }

  void apiResponse(String method, String url, int statusCode, {dynamic data}) {
    if (statusCode >= 200 && statusCode < 300) {
      debug('API Response: $method $url - $statusCode');
    } else {
      warn('API Response: $method $url - $statusCode');
    }
    
    if (data != null && _logLevel.value <= LogLevel.debug.value) {
      debug('Response data: ${_prettyPrintJson(data)}');
    }
  }

  void apiError(String method, String url, dynamic error) {
    this.error('API Error: $method $url - ${error.toString()}');
  }

  // Database logging
  void dbOperation(String operation, String table, {String? id}) {
    debug('DB Operation: $operation on $table${id != null ? ' (id: $id)' : ''}');
  }

  void dbError(String operation, String table, dynamic error) {
    this.error('DB Error: $operation on $table - ${error.toString()}');
  }

  // Background service logging
  void backgroundService(String message) {
    info('Background Service: $message');
  }

  void backgroundServiceError(String message, dynamic error) {
    this.error('Background Service Error: $message - ${error.toString()}');
  }

  String _prettyPrintJson(dynamic data) {
    try {
      if (data is Map || data is List) {
        return data.toString();
      }
      return data.toString();
    } catch (e) {
      return 'Error formatting data: $e';
    }
  }
}

// Global logger instance
final logger = AppLogger();

// Convenience functions for quick access
void logDebug(String message, [dynamic error, StackTrace? stackTrace]) {
  logger.debug(message, error, stackTrace);
}

void logInfo(String message, [dynamic error, StackTrace? stackTrace]) {
  logger.info(message, error, stackTrace);
}

void logWarn(String message, [dynamic error, StackTrace? stackTrace]) {
  logger.warn(message, error, stackTrace);
}

void logError(String message, [dynamic error, StackTrace? stackTrace]) {
  logger.error(message, error, stackTrace);
}
