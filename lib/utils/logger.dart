import 'package:flutter/foundation.dart';

/// Log levels for structured logging
enum LogLevel {
  error(0, '❌'),
  warn(1, '⚠️'),
  info(2, 'ℹ️'),
  debug(3, '🔍'),
  trace(4, '🔧');

  const LogLevel(this.value, this.emoji);
  final int value;
  final String emoji;
}

/// Centralized logger to replace scattered print statements
class Logger {
  static LogLevel _currentLevel = LogLevel.warn; // Only errors and warnings by default
  static bool _initialized = false;
  static bool _verboseMode = false; // Always disabled by default

  /// Initialize logger with appropriate level based on build mode
  static void initialize() {
    if (_initialized) return;
    
    // Always use warn level - only errors and warnings
    _currentLevel = LogLevel.warn;
    _verboseMode = false; // Never enable verbose by default
    
    _initialized = true;
  }

  /// Set log level programmatically
  static void setLevel(LogLevel level) {
    _currentLevel = level;
  }

  /// Enable/disable verbose mode for detailed debugging
  static void setVerboseMode(bool enabled) {
    _verboseMode = enabled;
    if (enabled && _currentLevel == LogLevel.warn) {
      _currentLevel = LogLevel.debug;
    }
  }

  /// Enable verbose mode temporarily for debugging (call this in debug console)
  static void enableVerboseDebugging() {
    _verboseMode = true;
    _currentLevel = LogLevel.debug;
    info('Verbose debugging enabled - detailed logs will now be shown');
  }

  /// Disable verbose mode
  static void disableVerboseDebugging() {
    _verboseMode = false;
    _currentLevel = LogLevel.warn;
    info('Verbose debugging disabled - only warnings and errors will be shown');
  }

  /// Toggle verbose mode for easy debugging
  static void toggleVerboseDebugging() {
    if (_verboseMode) {
      disableVerboseDebugging();
    } else {
      enableVerboseDebugging();
    }
  }

  /// Check if debug output should be shown
  static bool get shouldShowDebug => false; // Never show debug by default

  /// Log error messages (always shown)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Log warning messages
  static void warn(String message) {
    _log(LogLevel.warn, message);
  }

  /// Log informational messages (key events, phase transitions)
  static void info(String message) {
    _log(LogLevel.info, message);
  }

  /// Log debug messages (detailed execution info) - only in verbose mode
  static void debug(String message) {
    // Never log debug messages by default
  }

  /// Log trace messages (very detailed, per-operation info) - only in verbose mode
  static void trace(String message) {
    // Never log trace messages by default
  }

  /// Log debug-specific messages that should only appear in debug builds with verbose mode
  static void debugOnly(String message) {
    // Never log debug messages by default
  }

  /// Internal logging implementation
  static void _log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized) initialize();
    
    if (level.value <= _currentLevel.value) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.SSS
      final prefix = '${level.emoji} [$timestamp]';
      
      if (kDebugMode) {
        // In debug mode, use debugPrint for better IDE integration
        debugPrint('$prefix $message');
        if (error != null) {
          debugPrint('$prefix Error details: $error');
        }
        if (stackTrace != null) {
          debugPrint('$prefix Stack trace: $stackTrace');
        }
      } else {
        // In release mode, use print (but this rarely executes due to level filtering)
        print('$prefix $message');
      }
    }
  }

  /// Create a scoped logger for specific components
  static ScopedLogger scope(String scope) {
    return ScopedLogger(scope);
  }
}

/// Scoped logger that prefixes all messages with a component name
class ScopedLogger {
  final String _scope;
  
  ScopedLogger(this._scope);

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    Logger.error('[$_scope] $message', error, stackTrace);
  }

  void warn(String message) {
    Logger.warn('[$_scope] $message');
  }

  void info(String message) {
    Logger.info('[$_scope] $message');
  }

  void debug(String message) {
    // Never log debug messages by default
  }

  void trace(String message) {
    // Never log trace messages by default
  }

  void debugOnly(String message) {
    // Never log debug messages by default
  }
}

/// Performance timing utility
class Stopwatch2 {
  final String _name;
  final ScopedLogger _logger;
  final Stopwatch _stopwatch;
  
  Stopwatch2(this._name, this._logger) : _stopwatch = Stopwatch()..start();
  
  void stop() {
    _stopwatch.stop();
    // Never log timing by default
  }
  
  void stopInfo() {
    _stopwatch.stop();
    _logger.info('$_name completed in ${_stopwatch.elapsedMilliseconds}ms');
  }
}
