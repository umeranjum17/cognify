// Lightweight Logger utility for Flutter/Dart projects
import 'package:flutter/foundation.dart';

enum LogLevel { trace, debug, info, warn, error, none }

class Logger {
  static LogLevel _level = kReleaseMode ? LogLevel.warn : LogLevel.warn;
  static Set<String> _enabledTags = {};

  /// Set log level globally (e.g. from main or env)
  static void setLevel(LogLevel level) {
    _level = level;
  }

  /// Enable specific tags for verbose logging (optional)
  static void enableTag(String tag) {
    _enabledTags.add(tag);
  }

  /// Check if debug logging should be shown
  static bool get shouldShowDebug => _level.index <= LogLevel.debug.index;

  static bool _shouldLog(LogLevel level, [String? tag]) {
    if (level.index < _level.index) return false;
    if (_enabledTags.isEmpty) return true;
    if (tag != null && _enabledTags.contains(tag)) return true;
    return false;
  }

  static void trace(String message, {String? tag}) {
    if (_shouldLog(LogLevel.trace, tag)) {
      debugPrint('[TRACE]${tag != null ? '[$tag]' : ''} $message');
    }
  }

  static void debug(String message, {String? tag}) {
    if (_shouldLog(LogLevel.debug, tag)) {
      debugPrint('[DEBUG]${tag != null ? '[$tag]' : ''} $message');
    }
  }

  static void debugOnly(String message, {String? tag}) {
    if (shouldShowDebug) {
      debug(message, tag: tag);
    }
  }

  static void info(String message, {String? tag}) {
    if (_shouldLog(LogLevel.info, tag)) {
      debugPrint('[INFO]${tag != null ? '[$tag]' : ''} $message');
    }
  }

  static void warn(String message, {String? tag}) {
    if (_shouldLog(LogLevel.warn, tag)) {
      debugPrint('[WARN]${tag != null ? '[$tag]' : ''} $message');
    }
  }

  static void error(String message, {String? tag}) {
    if (_shouldLog(LogLevel.error, tag)) {
      debugPrint('[ERROR]${tag != null ? '[$tag]' : ''} $message');
    }
  }

  /// Create a scoped logger instance
  static ScopedLogger scope(String scope) {
    return ScopedLogger(scope);
  }
}

/// Scoped logger for better organization
class ScopedLogger {
  final String _scope;

  ScopedLogger(this._scope);

  void trace(String message) => Logger.trace(message, tag: _scope);
  void debug(String message) => Logger.debug(message, tag: _scope);
  void info(String message) => Logger.info(message, tag: _scope);
  void warn(String message) => Logger.warn(message, tag: _scope);
  void error(String message, [dynamic error]) {
    final fullMessage = error != null ? '$message: $error' : message;
    Logger.error(fullMessage, tag: _scope);
  }
}

/// Simple stopwatch utility for timing operations
class Stopwatch2 {
  final String _name;
  final ScopedLogger? _logger;
  final Stopwatch _stopwatch = Stopwatch();

  Stopwatch2(this._name, [this._logger]);

  void start() {
    _stopwatch.start();
    _logger?.debug('Started: $_name');
  }

  void stop() {
    _stopwatch.stop();
    _logger?.debug('Stopped: $_name (${_stopwatch.elapsedMilliseconds}ms)');
  }

  Duration get elapsed => _stopwatch.elapsed;
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;
  bool get isRunning => _stopwatch.isRunning;
}
