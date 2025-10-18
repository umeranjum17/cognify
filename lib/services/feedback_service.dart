import 'package:flutter/foundation.dart';
import '../api/api.dart';
import '../config/app_config.dart';

class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  Future<void> submit({
    required String message,
    String? userId,
    String? userEmail,
    Map<String, dynamic>? extra,
  }) async {
    try {
      // Route feedback through backend API (not client-side Firestore)
      // Enrich with app context + any provided extras
      final context = <String, dynamic>{
        'user': {
          if (userId != null) 'id': userId,
          if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
        },
        'app': {
          'name': AppConfig.appName,
          'version': AppConfig.appVersion,
          'backendBaseUrl': AppConfig.backendBaseUrl,
        },
        if (extra != null) ...extra,
      };

      await API.instance.sendFeedback(
        message: message.trim(),
        contactEmail: userEmail,
        context: context,
      );

      if (kDebugMode) print('✅ Feedback submitted successfully via backend');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Backend feedback submission failed: $e');
      }

      // Re-throw with more context for UI to handle fallback
      throw Exception('Failed to submit feedback to backend: ${e.toString()}');
    }
  }
}

