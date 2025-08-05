import 'dart:convert';

/// JSON normalization utilities for safe type casting
class JsonUtils {
  /// Converts a Map with dynamic keys to a Map with String keys
  /// This prevents runtime type casting errors when dealing with JSON data
  static Map<String, dynamic> deepStringKeyMap(Map<dynamic, dynamic> input) {
    final result = <String, dynamic>{};
    
    for (final entry in input.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      
      if (value is Map<dynamic, dynamic>) {
        result[key] = deepStringKeyMap(value);
      } else if (value is List) {
        result[key] = _normalizeList(value);
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  /// Normalizes a List to ensure all nested maps have string keys
  static List<dynamic> _normalizeList(List input) {
    final result = <dynamic>[];
    
    for (final item in input) {
      if (item is Map<dynamic, dynamic>) {
        result.add(deepStringKeyMap(item));
      } else if (item is List) {
        result.add(_normalizeList(item));
      } else {
        result.add(item);
      }
    }
    
    return result;
  }

  /// Deep normalization that handles both Maps and Lists
  /// This is a more comprehensive version that can handle any JSON structure
  static dynamic deepNormalize(dynamic input) {
    if (input is Map<dynamic, dynamic>) {
      return deepStringKeyMap(input);
    } else if (input is List) {
      return _normalizeList(input);
    } else {
      return input;
    }
  }

  /// Safely converts a dynamic value to Map<String, dynamic>
  /// Returns null if the value cannot be converted
  static Map<String, dynamic>? safeStringKeyMap(dynamic input) {
    if (input == null) return null;
    
    if (input is Map<String, dynamic>) {
      return input;
    }
    
    if (input is Map<dynamic, dynamic>) {
      return deepStringKeyMap(input);
    }
    
    return null;
  }

  /// Safely converts a dynamic value to List<dynamic>
  /// Returns null if the value cannot be converted
  static List<dynamic>? safeList(dynamic input) {
    if (input == null) return null;
    
    if (input is List) {
      return _normalizeList(input);
    }
    
    return null;
  }

  /// Validates if a dynamic value can be safely converted to Map<String, dynamic>
  static bool isValidStringKeyMap(dynamic input) {
    if (input == null) return false;
    return input is Map<String, dynamic> || input is Map<dynamic, dynamic>;
  }

  /// Validates if a dynamic value can be safely converted to List
  static bool isValidList(dynamic input) {
    return input is List;
  }
} 