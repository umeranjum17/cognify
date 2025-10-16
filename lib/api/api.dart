import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

/// Single centralized API file for ALL data access
///
/// This is the ONLY file the UI should call for:
/// - Backend API calls
/// - Firebase/Firestore operations
/// - RevenueCat subscriptions
/// - Local storage (SharedPreferences)
///
/// No service layers - just call API.instance methods directly from your UI.
class API {
  static final API instance = API._internal();
  factory API() => instance;
  API._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.backendBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    // Log all requests/responses to help diagnose baseUrl/RC issues
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        try {
          Logger.debug(
            '➡️ API Request: ${options.method} ${options.uri}',
            tag: 'API',
          );
          Logger.debug('   baseUrl=${_dio.options.baseUrl}', tag: 'API');
        } catch (_) {}
        handler.next(options);
      },
      onResponse: (response, handler) {
        try {
          Logger.debug(
            '✅ API Response: ${response.statusCode} ${response.requestOptions.uri}',
            tag: 'API',
          );
        } catch (_) {}
        handler.next(response);
      },
      onError: (e, handler) {
        try {
          Logger.warn(
            '❌ API Error: ${e.message} ${e.requestOptions.uri}',
            tag: 'API',
          );
        } catch (_) {}
        handler.next(e);
      },
    ));
  }

  late final Dio _dio;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== AUTH HELPER ==========

  /// Get Firebase Auth token for authenticated requests
  Future<String?> _getAuthToken() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Get auth headers for requests
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  // ========== CHAT / MODE ENDPOINTS ==========

  /// Fetch available chat mode configurations
  ///
  /// Returns: List of mode configurations
  /// ```dart
  /// final modes = await API.instance.getModes();
  /// ```
  Future<List<dynamic>> getModes() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        '/api/config/modes',
        options: Options(headers: headers),
      );
      return response.data as List<dynamic>;
    } catch (e) {
      print('❌ API Error [getModes]: $e');
      return [];
    }
  }

  /// Send chat message (non-streaming)
  ///
  /// Parameters:
  /// - `mode`: Chat mode (e.g., 'chat', 'deepsearch')
  /// - `messages`: List of message objects with role and content
  /// - `model`: Model ID (e.g., 'google/gemini-2.5-flash-lite')
  /// - `temperature`: Optional temperature (0.0-1.0)
  /// - `maxTokens`: Optional max tokens
  ///
  /// Returns: Map with response data
  /// ```dart
  /// final result = await API.instance.chat(
  ///   mode: 'chat',
  ///   messages: [{'role': 'user', 'content': 'Hello'}],
  ///   model: 'google/gemini-2.5-flash-lite',
  /// );
  /// ```
  Future<Map<String, dynamic>> chat({
    required String mode,
    required List<Map<String, dynamic>> messages,
    required String model,
    double? temperature,
    int? maxTokens,
    String? query,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.post(
        '/api/chat',
        data: {
          'mode': mode,
          'messages': messages,
          if (query != null) 'query': query,
          'model': model,
          if (temperature != null) 'temperature': temperature,
          if (maxTokens != null) 'maxTokens': maxTokens,
        },
        options: Options(headers: headers),
      );

      return {
        'response': response.data,
        'streaming': false,
      };
    } catch (e) {
      print('❌ API Error [chat]: $e');
      rethrow;
    }
  }

  // ========== DEV AUTH (CUSTOM TOKEN) ==========

  /// Request a Firebase custom token from backend and sign in on device.
  /// Dev-only. Returns the signed-in Firebase user UID.
  Future<String?> devSignIn({String? uid, String? email, Map<String, dynamic>? claims}) async {
    try {
      final response = await _dio.post(
        '/api/devauth/custom-token',
        data: {
          if (uid != null) 'uid': uid,
          if (email != null) 'email': email,
          if (claims != null) 'claims': claims,
        },
      );

      final String customToken = response.data['customToken'] as String;
      final cred = await fb.FirebaseAuth.instance.signInWithCustomToken(customToken);
      return cred.user?.uid;
    } catch (e) {
      print('❌ API Error [devSignIn]: $e');
      rethrow;
    }
  }

  /// Send chat message (streaming)
  ///
  /// Parameters: Same as `chat()` method
  ///
  /// Returns: Stream of response chunks
  /// ```dart
  /// final stream = API.instance.chatStream(
  ///   mode: 'chat',
  ///   messages: [{'role': 'user', 'content': 'Hello'}],
  ///   model: 'google/gemini-2.5-flash-lite',
  /// );
  ///
  /// await for (final chunk in stream) {
  ///   print(chunk);
  /// }
  /// ```
  Stream<Map<String, dynamic>> chatStream({
    required String mode,
    required List<Map<String, dynamic>> messages,
    required String model,
    double? temperature,
    int? maxTokens,
    String? query,
  }) async* {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.post(
        '/api/chat',
        data: {
          'mode': mode,
          'messages': messages,
          if (query != null) 'query': query,
          'model': model,
          if (temperature != null) 'temperature': temperature,
          if (maxTokens != null) 'maxTokens': maxTokens,
        },
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data.stream;
      final decoder = utf8.decoder;
      final lineDecoder = const LineSplitter();

      await for (final chunk in stream.transform(decoder).transform(lineDecoder)) {
        if (chunk.trim().isEmpty) continue;
        if (chunk.trim() == '[DONE]') break;

        if (chunk.startsWith('data: ')) {
          final jsonStr = chunk.substring(6);
          try {
            final data = jsonDecode(jsonStr);
            yield data as Map<String, dynamic>;
          } catch (e) {
            print('❌ Failed to parse chunk: $jsonStr');
          }
        }
      }
    } catch (e) {
      print('❌ API Error [chatStream]: $e');
      rethrow;
    }
  }

  // ========== CREDITS ENDPOINTS ==========

  /// Fetch current credits balance
  ///
  /// Returns: Credits balance as double
  /// ```dart
  /// final balance = await API.instance.getCreditsBalance();
  /// print('Balance: $balance credits');
  /// ```
  Future<double> getCreditsBalance() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get(
        '/api/credits/balance',
        options: Options(headers: headers),
      );

      // Accept both { balance, lastUpdated } and legacy { data: { balance } }
      final data = response.data;
      if (data is Map && data['balance'] != null) {
        return (data['balance'] as num).toDouble();
      }
      if (data is Map && data['data'] is Map && data['data']['balance'] != null) {
        return (data['data']['balance'] as num).toDouble();
      }
      throw Exception('Invalid balance response');
    } catch (e) {
      print('❌ API Error [getCreditsBalance]: $e');
      return 0.0;
    }
  }

  /// Consume credits
  ///
  /// Parameters:
  /// - `amount`: Amount of credits to consume
  /// - `reason`: Reason for consumption (e.g., 'chat_request')
  /// - `requestId`: Unique request ID for idempotency
  ///
  /// Returns: Remaining balance after consumption
  ///
  /// Throws: Exception if insufficient credits (HTTP 409)
  /// ```dart
  /// try {
  ///   final newBalance = await API.instance.consumeCredits(
  ///     amount: 10,
  ///     reason: 'chat_request',
  ///     requestId: 'unique-id-123',
  ///   );
  ///   print('Remaining: $newBalance');
  /// } catch (e) {
  ///   print('Insufficient credits!');
  /// }
  /// ```
  Future<double> consumeCredits({
    required double amount,
    required String reason,
    required String requestId,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.post(
        '/api/credits/consume',
        data: {
          'amount': amount,
          'reason': reason,
          'requestId': requestId,
        },
        options: Options(headers: headers),
      );

      return (response.data['data']['balance'] as num).toDouble();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        throw Exception('INSUFFICIENT_CREDITS');
      }
      print('❌ API Error [consumeCredits]: $e');
      rethrow;
    }
  }

  // ========== CONFIG / MODELS ENDPOINTS ==========

  /// Fetch available AI models
  ///
  /// Returns: List of model IDs
  /// ```dart
  /// final models = await API.instance.getModels();
  /// print('Available models: $models');
  /// ```
  Future<List<String>> getModels() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        '/api/config/models',
        options: Options(headers: headers),
      );
      return (response.data as List).cast<String>();
    } catch (e) {
      print('❌ API Error [getModels]: $e');
      // Return fallback models
      return [
        'google/gemini-2.5-flash-lite',
        'mistralai/mistral-7b-instruct:free',
        'meta-llama/llama-3.2-3b-instruct:free',
      ];
    }
  }

  // ========== FILE UPLOAD ENDPOINTS ==========

  /// Upload file to backend
  ///
  /// Parameters:
  /// - `fileName`: Name of the file
  /// - `fileBytes`: File content as bytes
  /// - `mimeType`: MIME type (e.g., 'image/png', 'application/pdf')
  ///
  /// Returns: Map with upload response (fileId, url, etc.)
  /// ```dart
  /// final result = await API.instance.uploadFile(
  ///   fileName: 'document.pdf',
  ///   fileBytes: pdfBytes,
  ///   mimeType: 'application/pdf',
  /// );
  /// print('Uploaded: ${result['fileId']}');
  /// ```
  Future<Map<String, dynamic>> uploadFile({
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final response = await _dio.post(
        '/api/upload',
        data: formData,
        options: Options(headers: headers),
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('❌ API Error [uploadFile]: $e');
      rethrow;
    }
  }

  /// Get all uploaded sources/files
  ///
  /// Returns: List of uploaded file objects
  /// ```dart
  /// final sources = await API.instance.getSources();
  /// for (var source in sources) {
  ///   print('${source['fileName']}: ${source['url']}');
  /// }
  /// ```
  Future<List<dynamic>> getSources() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get(
        '/api/sources',
        options: Options(headers: headers),
      );

      return response.data as List<dynamic>;
    } catch (e) {
      print('❌ API Error [getSources]: $e');
      return [];
    }
  }

  // ========== REVENUECAT / SUBSCRIPTIONS ==========

  bool _revenueCatConfigured = false;

  /// Initialize RevenueCat
  ///
  /// Call this once at app startup
  /// ```dart
  /// await API.instance.initializeRevenueCat(userId: firebaseUser.uid);
  /// ```
  Future<bool> initializeRevenueCat({String? userId}) async {
    if (_revenueCatConfigured) return true;

    try {
      final apiKey = 'YOUR_RC_API_KEY'; // TODO: Move to config
      final configuration = PurchasesConfiguration(apiKey);
      if (userId != null) configuration.appUserID = userId;

      await Purchases.configure(configuration);
      _revenueCatConfigured = true;
      print('✅ RevenueCat initialized');
      return true;
    } catch (e) {
      print('❌ RevenueCat init failed: $e');
      return false;
    }
  }

  /// Get subscription offerings (packages to purchase)
  ///
  /// Returns: Offerings object with available packages
  /// ```dart
  /// final offerings = await API.instance.getOfferings();
  /// final monthly = offerings?.current?.monthly;
  /// ```
  Future<Offerings?> getOfferings() async {
    if (!_revenueCatConfigured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('❌ API Error [getOfferings]: $e');
      return null;
    }
  }

  /// Purchase a subscription package
  ///
  /// Returns: True if purchase successful and premium unlocked
  /// ```dart
  /// final success = await API.instance.purchasePackage(monthlyPackage);
  /// if (success) {
  ///   // Show success message
  /// }
  /// ```
  Future<bool> purchasePackage(Package package) async {
    if (!_revenueCatConfigured) return false;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      print('❌ API Error [purchasePackage]: $e');
      return false;
    }
  }

  /// Check if user has premium subscription
  ///
  /// Returns: True if user has active premium entitlement
  /// ```dart
  /// final isPremium = await API.instance.isPremiumUser();
  /// ```
  Future<bool> isPremiumUser() async {
    if (!_revenueCatConfigured) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      print('❌ API Error [isPremiumUser]: $e');
      return false;
    }
  }

  /// Restore previous purchases
  ///
  /// Returns: True if premium restored
  /// ```dart
  /// final restored = await API.instance.restorePurchases();
  /// ```
  Future<bool> restorePurchases() async {
    if (!_revenueCatConfigured) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      print('❌ API Error [restorePurchases]: $e');
      return false;
    }
  }

  // ========== FIRESTORE / SUBSCRIPTION CREDITS ==========

  /// Watch user's subscription credits (real-time stream)
  ///
  /// Returns: Stream of credit balance updates
  /// ```dart
  /// final stream = API.instance.watchSubscriptionCredits(userId);
  /// await for (final credits in stream) {
  ///   print('Remaining: ${credits['remaining']}');
  /// }
  /// ```
  Stream<Map<String, dynamic>> watchSubscriptionCredits(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('current')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return {
          'monthlyAllowance': 0,
          'consumed': 0,
          'remaining': 0,
          'tier': 'free',
          'status': 'free',
        };
      }

      final data = snapshot.data()!;
      final allowance = data['monthlyAllowance'] as int? ?? 0;
      final consumed = data['consumed'] as int? ?? 0;

      return {
        'monthlyAllowance': allowance,
        'consumed': consumed,
        'remaining': (allowance - consumed).clamp(0, allowance),
        'tier': data['tier'] ?? 'free',
        'status': data['status'] ?? 'free',
        'currentPeriodEnd': (data['currentPeriodEnd'] as Timestamp?)?.toDate(),
      };
    });
  }

  /// Fetch subscription credits (one-time)
  ///
  /// Returns: Current credit balance
  /// ```dart
  /// final credits = await API.instance.fetchSubscriptionCredits(userId);
  /// print('You have ${credits['remaining']} credits');
  /// ```
  Future<Map<String, dynamic>> fetchSubscriptionCredits(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscription')
          .doc('current')
          .get();

      if (!snapshot.exists) {
        return {
          'monthlyAllowance': 0,
          'consumed': 0,
          'remaining': 0,
          'tier': 'free',
          'status': 'free',
        };
      }

      final data = snapshot.data()!;
      final allowance = data['monthlyAllowance'] as int? ?? 0;
      final consumed = data['consumed'] as int? ?? 0;

      return {
        'monthlyAllowance': allowance,
        'consumed': consumed,
        'remaining': (allowance - consumed).clamp(0, allowance),
        'tier': data['tier'] ?? 'free',
        'status': data['status'] ?? 'free',
        'currentPeriodEnd': (data['currentPeriodEnd'] as Timestamp?)?.toDate(),
      };
    } catch (e) {
      print('❌ API Error [fetchSubscriptionCredits]: $e');
      return {
        'monthlyAllowance': 0,
        'consumed': 0,
        'remaining': 0,
        'tier': 'free',
        'status': 'free',
      };
    }
  }

  /// Consume subscription credits (atomic transaction)
  ///
  /// Throws: Exception if insufficient credits
  /// ```dart
  /// try {
  ///   await API.instance.consumeSubscriptionCredits(
  ///     userId: userId,
  ///     amount: 1,
  ///   );
  /// } catch (e) {
  ///   // Show "out of credits" message
  /// }
  /// ```
  Future<void> consumeSubscriptionCredits({
    required String uid,
    int amount = 1,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('subscription')
          .doc('current');

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception('No subscription found');
        }

        final data = snapshot.data()!;
        final allowance = data['monthlyAllowance'] as int? ?? 10;
        final consumed = data['consumed'] as int? ?? 0;
        final remaining = (allowance - consumed).clamp(0, allowance);

        if (remaining < amount) {
          throw Exception('INSUFFICIENT_CREDITS');
        }

        transaction.update(docRef, {
          'consumed': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('❌ API Error [consumeSubscriptionCredits]: $e');
      rethrow;
    }
  }

  // ========== LOCAL STORAGE (SharedPreferences) ==========

  /// Save data to local storage
  ///
  /// ```dart
  /// await API.instance.saveLocal('user_name', 'John');
  /// await API.instance.saveLocal('settings', {'theme': 'dark'});
  /// ```
  Future<void> saveLocal(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else {
        // Serialize complex objects to JSON
        await prefs.setString(key, jsonEncode(value));
      }
    } catch (e) {
      print('❌ API Error [saveLocal]: $e');
    }
  }

  /// Load data from local storage
  ///
  /// ```dart
  /// final name = await API.instance.loadLocal('user_name');
  /// final settings = await API.instance.loadLocal('settings');
  /// ```
  Future<dynamic> loadLocal(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.get(key);

      // Try to decode JSON if it's a string
      if (value is String && (value.startsWith('{') || value.startsWith('['))) {
        try {
          return jsonDecode(value);
        } catch (_) {
          return value;
        }
      }

      return value;
    } catch (e) {
      print('❌ API Error [loadLocal]: $e');
      return null;
    }
  }

  /// Delete data from local storage
  ///
  /// ```dart
  /// await API.instance.deleteLocal('user_name');
  /// ```
  Future<void> deleteLocal(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      print('❌ API Error [deleteLocal]: $e');
    }
  }

  /// Clear all local storage
  ///
  /// ```dart
  /// await API.instance.clearLocal();
  /// ```
  Future<void> clearLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('❌ API Error [clearLocal]: $e');
    }
  }

  // ========== CONVERSATIONS (Local Storage) ==========

  /// Save conversation to local storage
  ///
  /// ```dart
  /// await API.instance.saveConversation(
  ///   id: 'conv_123',
  ///   title: 'My Chat',
  ///   messages: [...],
  /// );
  /// ```
  Future<void> saveConversation({
    required String id,
    required String title,
    required List<Map<String, dynamic>> messages,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString('conversations') ?? '[]';
      final conversations = jsonDecode(conversationsJson) as List;

      final conversationData = {
        'id': id,
        'title': title.isNotEmpty ? title : 'Untitled',
        'messages': messages,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messageCount': messages.length,
        'metadata': metadata,
      };

      final existingIndex = conversations.indexWhere((c) => c['id'] == id);
      if (existingIndex >= 0) {
        final existing = conversations[existingIndex];
        conversationData['createdAt'] = existing['createdAt'];
        conversations[existingIndex] = conversationData;
      } else {
        conversations.insert(0, conversationData);
      }

      // Keep only last 100
      if (conversations.length > 100) {
        conversations.removeRange(100, conversations.length);
      }

      await prefs.setString('conversations', jsonEncode(conversations));
    } catch (e) {
      print('❌ API Error [saveConversation]: $e');
    }
  }

  /// Load all conversations
  ///
  /// ```dart
  /// final conversations = await API.instance.loadConversations();
  /// ```
  Future<List<Map<String, dynamic>>> loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString('conversations') ?? '[]';
      final conversations = jsonDecode(conversationsJson) as List;
      return conversations.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ API Error [loadConversations]: $e');
      return [];
    }
  }

  /// Load specific conversation by ID
  ///
  /// ```dart
  /// final conv = await API.instance.loadConversation('conv_123');
  /// ```
  Future<Map<String, dynamic>?> loadConversation(String id) async {
    try {
      final conversations = await loadConversations();
      return conversations.firstWhere(
        (c) => c['id'] == id,
        orElse: () => {},
      );
    } catch (e) {
      print('❌ API Error [loadConversation]: $e');
      return null;
    }
  }

  /// Delete conversation
  ///
  /// ```dart
  /// await API.instance.deleteConversation('conv_123');
  /// ```
  Future<void> deleteConversation(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString('conversations') ?? '[]';
      final conversations = jsonDecode(conversationsJson) as List;

      conversations.removeWhere((c) => c['id'] == id);

      await prefs.setString('conversations', jsonEncode(conversations));
    } catch (e) {
      print('❌ API Error [deleteConversation]: $e');
    }
  }

  // ========== UTILITY METHODS ==========

  /// Clear any cached data
  void clearCache() {
    // Can add caching logic here if needed
  }

  /// Update base URL (useful for switching environments)
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    Logger.info('🔄 API baseUrl updated -> $newBaseUrl', tag: 'API');
  }

  /// Link anonymous account to persistent account and restore credits
  Future<void> linkAccountAndRestoreCredits({
    required String anonymousUserId,
    required String persistentUserId,
  }) async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final token = await user.getIdToken();
      final response = await _dio.post(
        '/api/account/link',
        data: {
          'anonymousUserId': anonymousUserId,
          'persistentUserId': persistentUserId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to link account: ${response.statusCode}');
      }

      Logger.info('✅ Account linked successfully', tag: 'API');
    } catch (e) {
      Logger.error('❌ Failed to link account: $e', tag: 'API');
      rethrow;
    }
  }
}
