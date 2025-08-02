import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

/// Utility functions for common operations
class Helpers {
  static final Map<String, Timer> _debounceTimers = {};

  static final Map<String, DateTime> _throttleTimestamps = {};

  /// Clean up text by removing extra whitespace and normalizing
  static String cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple whitespace with single space
        .trim(); // Remove leading/trailing whitespace
  }

  /// Debounce function calls
  static void debounce(String key, Duration delay, void Function() action) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, action);
  }

  /// Extract domain from URL
  static String? extractDomain(String? url) {
    if (url == null || url.isEmpty) return null;
    
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }

  /// Extract keywords from text (simple implementation)
  static List<String> extractKeywords(String text, {int maxKeywords = 10}) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3) // Filter short words
        .toList();
    
    // Count word frequency
    final wordCount = <String, int>{};
    for (final word in words) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }
    
    // Sort by frequency and return top keywords
    final sortedWords = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedWords
        .take(maxKeywords)
        .map((entry) => entry.key)
        .toList();
  }

  /// Format duration in human-readable format
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Format file size in human-readable format
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor();
    final size = bytes / math.pow(1024, i);
    
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  /// Format timestamp in relative format (e.g., "2 hours ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Generate a hash from a string
  static String generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a unique ID with optional prefix
  static String generateId({String prefix = ''}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(999999);
    return '$prefix${prefix.isNotEmpty ? '_' : ''}${timestamp}_$random';
  }

  /// Check if a string is a valid email
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Check if a string is a valid URL
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Normalize boolean values from various sources
  /// Handles both boolean and string representations
  static bool normalizeBooleanFlag(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  /// Retry a function with exponential backoff
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() function, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (attempt < maxRetries) {
      try {
        return await function();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * backoffMultiplier).round());
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  /// Safely encode JSON for streaming and storage
  /// Removes problematic control characters while preserving formatting
  static String safeJSONStringify(dynamic obj) {
    try {
      return jsonEncode(obj, toEncodable: (dynamic value) {
        if (value is String) {
          // Remove problematic control characters but preserve newlines, carriage returns, and tabs
          return value.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]'), '');
        }
        return value;
      });
    } catch (error) {
      return jsonEncode({'error': 'Encoding error: ${error.toString()}'});
    }
  }

  /// Throttle function calls
  static void throttle(String key, Duration interval, void Function() action) {
    final lastCall = _throttleTimestamps[key];
    final now = DateTime.now();
    
    if (lastCall == null || now.difference(lastCall) >= interval) {
      _throttleTimestamps[key] = now;
      action();
    }
  }

  /// Truncate text to a specified length with ellipsis
  static String truncateText(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}


