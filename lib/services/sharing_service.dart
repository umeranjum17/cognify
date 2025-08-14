import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SharingService {
  static final SharingService _instance = SharingService._internal();
  static const MethodChannel _channel =
      MethodChannel('com.userfaroq1995.cognify_flutter/sharing');
  String? _pendingSharedUrl;

  bool _initialized = false;
  
  factory SharingService() => _instance;
  SharingService._internal();

  /// Check for new shared content (call this when app resumes)
  Future<void> checkForSharedContent() async {
    try {
      // Skip platform channel calls on web
      if (kIsWeb) {
        debugPrint('📱 Web platform - skipping shared content check');
        return;
      }
      
      final sharedText = await _channel.invokeMethod<String?>('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        final extractedUrl = extractUrl(sharedText);
        if (extractedUrl != null) {
          _pendingSharedUrl = extractedUrl;
          debugPrint('📱 New shared content detected: $extractedUrl');
        }
      }
    } catch (e) {
      // Handle MissingPluginException gracefully on web
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('📱 Platform channel not available (web platform)');
      } else {
        debugPrint('📱 Error checking for shared content: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _pendingSharedUrl = null;
    _initialized = false;
    debugPrint('📱 Sharing service disposed');
  }

  /// Extract URL from text content
  String? extractUrl(String content) {
    // Common URL patterns
    final urlPatterns = [
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      RegExp(r'www\.[^\s]+', caseSensitive: false),
    ];

    for (final pattern in urlPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        String url = match.group(0)!;

        // Add https:// if missing
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }

        return url;
      }
    }

    // If content looks like a URL without protocol
    if (content.contains('.') && !content.contains(' ')) {
      return 'https://$content';
    }

    return null;
  }

  /// Get pending shared URL and clear it
  String? getPendingSharedUrl() {
    final url = _pendingSharedUrl;
    _pendingSharedUrl = null;
    return url;
  }

  /// Check if there's a pending shared URL
  bool hasPendingSharedUrl() {
    return _pendingSharedUrl != null;
  }

  /// Initialize sharing service with platform channel
  Future<void> initialize(BuildContext context) async {
    if (_initialized) return;
    
    debugPrint('📱 Sharing service initializing...');
    
    try {
      // Skip platform channel calls on web or if platform doesn't support it
      if (kIsWeb) {
        debugPrint('📱 Web platform - skipping sharing service initialization');
        _initialized = true;
        return;
      }

      // For iOS, check if sharing is supported
      if (!kIsWeb && Platform.isIOS) {
        debugPrint('📱 iOS platform - checking for sharing support...');
      }
      
      // Check for shared content from platform channel
      final sharedText = await _channel.invokeMethod<String?>('getSharedText');
      
      if (sharedText != null && sharedText.isNotEmpty) {
        debugPrint('📱 Received shared text: $sharedText');
        
        // Extract URL from shared text
        final extractedUrl = extractUrl(sharedText);
        if (extractedUrl != null) {
          _pendingSharedUrl = extractedUrl;
          debugPrint('📱 Set pending shared URL: $extractedUrl');
        } else {
          debugPrint('📱 No URL found in shared text');
        }
      } else {
        debugPrint('📱 No shared text received from platform');
      }
    } catch (e) {
      // Handle MissingPluginException and other errors gracefully
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('📱 Sharing plugin not implemented for this platform - continuing without sharing features');
      } else {
        debugPrint('📱 Error initializing sharing service: $e');
      }
    }
    
    _initialized = true;
  }

  /// Validate if URL is properly formatted
  bool isValidUrl(String text) {
    try {
      final uri = Uri.parse(text);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      // Try to detect URL patterns even without proper scheme
      return RegExp(r'(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}', caseSensitive: false)
          .hasMatch(text);
    }
  }

  /// Set a pending shared URL (for manual testing or future integration)
  void setPendingSharedUrl(String url) {
    _pendingSharedUrl = url;
    debugPrint('📱 Manually set pending shared URL: $url');
  }
}