// RevenueCat service scaffold
// Handles SDK init, offerings fetch, purchase, restore, and entitlement checks.

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

  Future<void> initialize({String? appUserId}) async {
    // Configure SDK with platform-specific public SDK key
    final configuration = PurchasesConfiguration(
      defaultTargetPlatform == TargetPlatform.iOS
          ? SubscriptionsConfig.rcPublicKeyIOS
          : SubscriptionsConfig.rcPublicKeyAndroid,
    );

    await Purchases.configure(configuration);

    // Identify user after configure if we have an ID (anonymous if null)
    if (appUserId != null && appUserId.isNotEmpty) {
      try {
        await Purchases.logIn(appUserId);
      } catch (e) {
        debugPrint('RevenueCat logIn error: $e');
      }
    }

    // Warm caches and set up listener
    try {
      _customerInfoCache = await Purchases.getCustomerInfo();
      if (_customerInfoCache != null) {
        _customerInfoController.add(_customerInfoCache!);
      }
    } catch (e) {
      debugPrint('RevenueCat getCustomerInfo error: $e');
    }

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _customerInfoCache = customerInfo;
      _customerInfoController.add(customerInfo);
    });
  }

  Future<void> identify(String appUserId) async {
    try {
      await Purchases.logIn(appUserId);
      final info = await Purchases.getCustomerInfo();
      _customerInfoCache = info;
      _customerInfoController.add(info);
    } catch (e) {
      debugPrint('RevenueCat identify error: $e');
    }
  }

  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      final info = await Purchases.getCustomerInfo();
      _customerInfoCache = info;
      _customerInfoController.add(info);
    } catch (e) {
      debugPrint('RevenueCat logout error: $e');
    }
  }

  Future<Offerings?> getOfferings({bool forceRefresh = false}) async {
    if (!forceRefresh && _offeringsCache != null) return _offeringsCache;
    _offeringsCache = await Purchases.getOfferings();
    return _offeringsCache;
  }

  Future<CustomerInfo> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    _customerInfoCache = info;
    _customerInfoController.add(info);
    return info;
  }

  bool get isEntitledToPremium {
    final entitlements = _customerInfoCache?.entitlements.active;
    return entitlements?.containsKey(SubscriptionsConfig.entitlementPremium) == true;
  }

  Future<PurchaseResult> purchasePackage(Package pkg) async {
    try {
      final customerInfo = await Purchases.purchasePackage(pkg);
      _customerInfoCache = customerInfo;
      _customerInfoController.add(customerInfo);
      final entitled = customerInfo.entitlements.active.containsKey(
        SubscriptionsConfig.entitlementPremium,
      );
      return PurchaseResult(success: entitled, customerInfo: customerInfo);
    } on PurchasesErrorCode catch (e) {
      return PurchaseResult(
        success: false,
        errorMessage: 'Purchases error: $e',
      );
    } catch (e) {
      return PurchaseResult(success: false, errorMessage: e.toString());
    }
  }

  void dispose() {
    _customerInfoController.close();
  }
}

class PurchaseResult {
  final bool success;
  final CustomerInfo? customerInfo;
  final String? errorMessage;
  PurchaseResult({required this.success, this.customerInfo, this.errorMessage});
}