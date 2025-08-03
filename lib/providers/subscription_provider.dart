import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  bool _initialized = false;
  bool _isEntitled = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _error;
  StreamSubscription<CustomerInfo>? _sub;

  bool get initialized => _initialized;
  bool get isEntitled => _isEntitled;
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  String? get error => _error;

  Future<void> initialize({String? appUserId}) async {
    if (_initialized) return;
    try {
      await RevenueCatService.instance.initialize(appUserId: appUserId);
      _customerInfo = await Purchases.getCustomerInfo();
      _isEntitled = RevenueCatService.instance.isEntitledToPremium;
      _offerings = await RevenueCatService.instance.getOfferings();
      _sub = RevenueCatService.instance.customerInfoStream.listen((info) {
        _customerInfo = info;
        _isEntitled = RevenueCatService.instance.isEntitledToPremium;
        notifyListeners();
      });
      _initialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshOfferings() async {
    try {
      _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> restore() async {
    try {
      _customerInfo = await RevenueCatService.instance.restorePurchases();
      _isEntitled = RevenueCatService.instance.isEntitledToPremium;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}