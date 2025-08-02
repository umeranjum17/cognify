import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/feature_flags.dart';

/// Subscription status model
class SubscriptionStatus {
  final bool isActive;
  final bool isPremium;
  final DateTime? expiryDate;
  final List<String> features;
  final String plan;

  const SubscriptionStatus({
    required this.isActive,
    required this.isPremium,
    this.expiryDate,
    required this.features,
    this.plan = 'free',
  });

  factory SubscriptionStatus.free() {
    return const SubscriptionStatus(
      isActive: false,
      isPremium: false,
      features: FeatureFlags.FREE_FEATURES,
      plan: 'free',
    );
  }

  factory SubscriptionStatus.premium({DateTime? expiryDate}) {
    return SubscriptionStatus(
      isActive: true,
      isPremium: true,
      expiryDate: expiryDate,
      features: [...FeatureFlags.FREE_FEATURES, ...FeatureFlags.PREMIUM_FEATURES],
      plan: 'premium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'isPremium': isPremium,
      'expiryDate': expiryDate?.toIso8601String(),
      'features': features,
      'plan': plan,
    };
  }

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['isActive'] ?? false,
      isPremium: json['isPremium'] ?? false,
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate']) 
          : null,
      features: List<String>.from(json['features'] ?? FeatureFlags.FREE_FEATURES),
      plan: json['plan'] ?? 'free',
    );
  }
}

/// Service for managing user subscription status and feature access
class SubscriptionManager {
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  static const String _subscriptionKey = 'user_subscription_status';
  static const String _lastCheckKey = 'subscription_last_check';
  
  SubscriptionStatus? _cachedStatus;
  DateTime? _lastCheck;

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    final status = await getSubscriptionStatus();
    return status.isActive && _isSubscriptionValid(status);
  }

  /// Get current subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    // Return cached status if recent
    if (_cachedStatus != null && _lastCheck != null) {
      final timeSinceCheck = DateTime.now().difference(_lastCheck!);
      if (timeSinceCheck.inMinutes < 5) {
        return _cachedStatus!;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final subscriptionData = prefs.getString(_subscriptionKey);
    
    if (subscriptionData == null) {
      _cachedStatus = SubscriptionStatus.free();
    } else {
      try {
        final data = jsonDecode(subscriptionData);
        _cachedStatus = SubscriptionStatus.fromJson(data);
      } catch (e) {
        print('Error parsing subscription data: $e');
        _cachedStatus = SubscriptionStatus.free();
      }
    }

    _lastCheck = DateTime.now();
    await _saveLastCheck();
    
    return _cachedStatus!;
  }

  /// Check if specific feature is available
  Future<bool> canAccessFeature(String featureName) async {
    // Free features are always available
    if (FeatureFlags.FREE_FEATURES.contains(featureName)) {
      return true;
    }

    // Premium features require active subscription
    if (FeatureFlags.PREMIUM_FEATURES.contains(featureName)) {
      return await hasActiveSubscription();
    }

    // Unknown feature defaults to free
    return true;
  }

  /// Update subscription status (for when user purchases/cancels)
  Future<void> updateSubscriptionStatus(SubscriptionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionKey, jsonEncode(status.toJson()));
    
    _cachedStatus = status;
    _lastCheck = DateTime.now();
    await _saveLastCheck();
  }

  /// Activate premium subscription
  Future<void> activatePremiumSubscription({
    required DateTime expiryDate,
  }) async {
    final status = SubscriptionStatus.premium(expiryDate: expiryDate);
    await updateSubscriptionStatus(status);
  }

  /// Cancel subscription (revert to free)
  Future<void> cancelSubscription() async {
    final status = SubscriptionStatus.free();
    await updateSubscriptionStatus(status);
  }

  /// Get features available to current user
  Future<List<String>> getAvailableFeatures() async {
    final status = await getSubscriptionStatus();
    return status.features;
  }

  /// Get locked features for current user
  Future<List<String>> getLockedFeatures() async {
    final hasSubscription = await hasActiveSubscription();
    if (hasSubscription) {
      return [];
    }
    return FeatureFlags.PREMIUM_FEATURES;
  }

  /// Check if subscription is still valid (not expired)
  bool _isSubscriptionValid(SubscriptionStatus status) {
    if (!status.isActive) return false;
    if (status.expiryDate == null) return true; // Lifetime subscription
    return DateTime.now().isBefore(status.expiryDate!);
  }

  /// Save last check timestamp
  Future<void> _saveLastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
  }

  /// Clear cached subscription data (for testing/debugging)
  Future<void> clearSubscriptionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subscriptionKey);
    await prefs.remove(_lastCheckKey);
    _cachedStatus = null;
    _lastCheck = null;
  }

  /// Get subscription info for UI display
  Future<Map<String, dynamic>> getSubscriptionInfo() async {
    final status = await getSubscriptionStatus();
    final lockedFeatures = await getLockedFeatures();
    
    return {
      'status': status.toJson(),
      'hasActiveSubscription': await hasActiveSubscription(),
      'lockedFeatures': lockedFeatures,
      'availableFeatures': status.features,
      'isFreeTrial': !status.isPremium,
      'subscriptionPrice': FeatureFlags.MONTHLY_SUBSCRIPTION_PRICE,
      'benefits': FeatureFlags.SUBSCRIPTION_BENEFITS,
    };
  }
}
