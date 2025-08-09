// RevenueCat service - hardened for graceful degradation and fail-closed gating.
// Ensures that any SDK errors/timeouts never crash the app. When RC is unavailable,
// premium stays locked unless user is in tester whitelist via AppAccessProvider.
//
// Key guarantees:
// - Idempotent initialize() with guarded _configured flag
// - Timeouts on all RC calls to avoid hangs
// - All methods swallow exceptions and log via debugPrint
// - Purchase operations return explicit failure if RC unavailable
// - Streams never throw; listener is wrapped defensively

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/subscriptions_config.dart';

class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  Offerings? _offeringsCache;
  CustomerInfo? _customerInfoCache;

  final StreamController<CustomerInfo> _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  bool _configured = false;
  
  // Public getter to check if RevenueCat is configured
  bool get isConfigured => _configured;

  /// Reset RevenueCat configuration to allow reinitialization with a different user
  Future<void> reset({Duration timeout = const Duration(seconds: 6)}) async {
    debugPrint('🔄 [RevenueCat] Resetting configuration...');
    
    // First, try to logout from RevenueCat if configured
    if (_configured) {
      try {
        await _withTimeout(() => Purchases.logOut(), timeout);
        debugPrint('✅ [RevenueCat] Logged out from previous user');
      } catch (e) {
        debugPrint('⚠️ [RevenueCat] Error logging out during reset: $e');
      }
    }
    
    // Clear cached data
    _offeringsCache = null;
    _customerInfoCache = null;
    
    // Reset configured flag to allow reinitialization
    _configured = false;
    
    debugPrint('✅ [RevenueCat] Reset completed');
  }

  Future<void> initialize({
    String? appUserId,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_configured) return; // idempotent

    try {
      // Configure SDK with platform-specific public SDK key
      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? SubscriptionsConfig.rcPublicKeyIOS
          : SubscriptionsConfig.rcPublicKeyAndroid;

      
      debugPrint('🔧 [RevenueCat] Configuring with key: ${apiKey.substring(0, 10)}...');
      
      final configuration = PurchasesConfiguration(apiKey);
      await _withTimeout(() => Purchases.configure(configuration), timeout);
      _configured = true;
      debugPrint('✅ [RevenueCat] Configuration successful');
    } catch (e, st) {
      debugPrint('❌ [RevenueCat] configure failed, continuing without RC: $e');
      debugPrint('$st');
      // Do not rethrow; fail closed and allow app to continue.
      _configured = false;
      return;
    }

    // Identify user after configure if we have an ID (anonymous if null)
    if (appUserId != null && appUserId.isNotEmpty) {
      try {
        await _withTimeout(() => Purchases.logIn(appUserId), timeout);
      } catch (e) {
        debugPrint('⚠️ [RevenueCat] logIn error: $e');
      }
    }

    // Warm caches and set up listener
    try {
      _customerInfoCache =
          await _withTimeout(() => Purchases.getCustomerInfo(), timeout);
      if (_customerInfoCache != null) {
        _customerInfoController.add(_customerInfoCache!);
      }
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] getCustomerInfo error: $e');
    }

    // Add listener defensively
    try {
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _customerInfoCache = customerInfo;
        // Never throw from stream add
        try {
          _customerInfoController.add(customerInfo);
        } catch (e) {
          debugPrint('⚠️ [RevenueCat] stream add error: $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] addCustomerInfoUpdateListener failed: $e');
    }
  }

  Future<void> identify(String appUserId,
      {Duration timeout = const Duration(seconds: 6)}) async {
    if (!_configured) return; // silently no-op if RC unavailable
    try {
      debugPrint('🔄 [RevenueCat] Identifying user: $appUserId');
      await _withTimeout(() => Purchases.logIn(appUserId), timeout);
      
      // Force refresh customer info to ensure we get the latest data
      final info = await _withTimeout(() => Purchases.getCustomerInfo(), timeout);
      _customerInfoCache = info;
      _customerInfoController.add(info);
      
      debugPrint('✅ [RevenueCat] User identified successfully: $appUserId');
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] identify error: $e');
    }
  }

  /// Force refresh customer info from RevenueCat servers (bypassing cache)
  Future<CustomerInfo?> forceRefreshCustomerInfo({Duration timeout = const Duration(seconds: 6)}) async {
    if (!_configured) return _customerInfoCache;
    try {
      debugPrint('🔄 [RevenueCat] Force refreshing customer info...');
      final info = await _withTimeout(() => Purchases.getCustomerInfo(), timeout);
      _customerInfoCache = info;
      _customerInfoController.add(info);
      debugPrint('✅ [RevenueCat] Customer info force refreshed');
      return info;
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] force refresh error: $e');
      return _customerInfoCache;
    }
  }

  Future<void> logOut({Duration timeout = const Duration(seconds: 6)}) async {
    if (!_configured) return;
    try {
      await _withTimeout(() => Purchases.logOut(), timeout);
      final info =
          await _withTimeout(() => Purchases.getCustomerInfo(), timeout);
      _customerInfoCache = info;
      _customerInfoController.add(info);
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] logout error: $e');
    }
  }

  Future<Offerings?> getOfferings({
    bool forceRefresh = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!_configured) {
      debugPrint('⚠️ [RevenueCat] getOfferings: RC not configured');
      return null;
    }
    if (!forceRefresh && _offeringsCache != null) return _offeringsCache;
    try {
      _offeringsCache =
          await _withTimeout(() => Purchases.getOfferings(), timeout);
      if (_offeringsCache == null) {
        debugPrint('⚠️ [RevenueCat] getOfferings: No offerings returned');
      } else {
        debugPrint('✅ [RevenueCat] getOfferings: Found ${_offeringsCache!.all.length} offerings');
        
        // Debug: List all available products
        _offeringsCache!.all.forEach((key, offering) {
          debugPrint('📦 [RevenueCat] Offering "$key": ${offering.availablePackages.length} packages');
          offering.availablePackages.forEach((package) {
            debugPrint('  📦 Package: ${package.identifier} - Product: ${package.storeProduct.identifier}');
          });
        });
      }
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] getOfferings error: $e');
      // Keep previous cache or null
    }
    return _offeringsCache;
  }

  Future<CustomerInfo?> restorePurchases(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (!_configured) return _customerInfoCache; // no-op if RC down
    try {
      final info =
          await _withTimeout(() => Purchases.restorePurchases(), timeout);
      _customerInfoCache = info;
      _customerInfoController.add(info);
      return info;
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] restorePurchases error: $e');
      return _customerInfoCache;
    }
  }

  bool get isEntitledToPremium {
    final entitlements = _customerInfoCache?.entitlements.active;
    return entitlements
            ?.containsKey(SubscriptionsConfig.entitlementPremium) ==
        true;
  }

  Future<PurchaseResult> purchasePackage(
    Package pkg, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!_configured) {
      return PurchaseResult(
        success: false,
        errorMessage: 'Purchasing unavailable',
      );
    }
    debugPrint('🛒 [RevenueCat] Attempting purchase:');
    debugPrint('  Package ID: ${pkg.identifier}');
    debugPrint('  Product ID: ${pkg.storeProduct.identifier}');
    debugPrint('  Price: ${pkg.storeProduct.priceString}');
    debugPrint('  Product type: ${pkg.packageType}');
    
    try {
      final customerInfo =
          await _withTimeout(() => Purchases.purchasePackage(pkg), timeout);
      _customerInfoCache = customerInfo;
      _customerInfoController.add(customerInfo);
      final entitled = customerInfo.entitlements.active.containsKey(
        SubscriptionsConfig.entitlementPremium,
      );
      
      debugPrint('✅ [RevenueCat] Purchase successful - Entitled: $entitled');
      return PurchaseResult(success: entitled, customerInfo: customerInfo);
    } on PurchasesErrorCode catch (e) {
      debugPrint('❌ [RevenueCat] PurchasesErrorCode: ${e.toString()}');
      return PurchaseResult(
        success: false,
        errorMessage: 'Purchases error: $e',
      );
    } catch (e) {
      debugPrint('❌ [RevenueCat] General purchase error: ${e.toString()}');
      return PurchaseResult(success: false, errorMessage: e.toString());
    }
  }

  void dispose() {
    try {
      _customerInfoController.close();
    } catch (_) {}
  }

  // Helper to enforce timeouts and prevent hangs
  Future<T> _withTimeout<T>(Future<T> Function() op, Duration timeout) {
    return op().timeout(timeout, onTimeout: () {
      throw TimeoutException(
          'RevenueCat operation timed out after ${timeout.inSeconds}s');
    });
  }
}

class PurchaseResult {
  final bool success;
  final CustomerInfo? customerInfo;
  final String? errorMessage;
  PurchaseResult({required this.success, this.customerInfo, this.errorMessage});
}