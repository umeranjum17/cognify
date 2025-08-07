import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import 'firebase_auth_provider.dart';

// SubscriptionProvider()
// Hardened to fail closed: defaults to gated when state is unknown or RC fails.
// Exposes a tri-state SubscriptionState { unknown, inactive, active } to allow
// UI/providers to treat unknown as locked by default.
class SubscriptionProvider extends ChangeNotifier {
  FirebaseAuthProvider? _auth;
  StreamSubscription? _authStateSub;
  bool _initialized = false;

  // Tri-state for entitlement visibility
  // unknown: RC not initialized or failed; we must gate by default
  // inactive: RC says no entitlement
  // active: RC says entitled
  SubscriptionState _state = SubscriptionState.unknown;

  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _error;
  StreamSubscription<CustomerInfo>? _sub;

  bool get initialized => _initialized;
  SubscriptionState get state => _state;
  bool get isEntitled => _state == SubscriptionState.active; // legacy getter for existing code
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  String? get error => _error;

  Future<void> initialize({String? appUserId}) async {
    if (_initialized) return;

    // Default fail-closed state
    _setState(SubscriptionState.unknown);
    notifyListeners();

    try {
      await RevenueCatService.instance.initialize(appUserId: appUserId);

      // Attempt to hydrate customer info (safe even if RC not configured; service is defensive)
      try {
        _customerInfo = await Purchases.getCustomerInfo();
        _updateEntitlementFromCache();
      } catch (e) {
        // Keep unknown (gated)
        debugPrint('⚠️ [SubscriptionProvider] getCustomerInfo error: $e');
      }

      try {
        _offerings = await RevenueCatService.instance.getOfferings();
      } catch (e) {
        debugPrint('⚠️ [SubscriptionProvider] getOfferings error: $e');
      }

      _sub = RevenueCatService.instance.customerInfoStream.listen((info) {
        _customerInfo = info;
        _updateEntitlementFromCache();
        notifyListeners();
      }, onError: (e) {
        debugPrint('⚠️ [SubscriptionProvider] stream error: $e');
      });

      _initialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      // Stay fail-closed as unknown (gated)
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
      _updateEntitlementFromCache();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Wire FirebaseAuthProvider to sync identity with RevenueCat
  void wireAuth(FirebaseAuthProvider auth) {
    if (_auth == auth) return;
    _auth = auth;

    // React immediately to current state
    _handleAuthChange();

    // Listen for subsequent auth state changes
    _auth!.addListener(_handleAuthChange);
  }

  void _handleAuthChange() {
    final uid = _auth?.uid;
    // When user signs in: identify with RevenueCat
    if (uid != null && uid.isNotEmpty) {
      RevenueCatService.instance.identify(uid).then((_) async {
        try {
          _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
        } catch (_) {}
        try {
          _customerInfo = await Purchases.getCustomerInfo();
        } catch (_) {}
        _updateEntitlementFromCache();
        notifyListeners();
      });
    } else {
      // On sign out: refresh state without logging out (prevents "anonymous logout" errors)
      // Only refresh offerings and customer info; state will remain consistent
      Future(() async {
        try {
          _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
        } catch (_) {}
        try {
          _customerInfo = await Purchases.getCustomerInfo();
        } catch (_) {}
        _updateEntitlementFromCache();
        notifyListeners();
      });
    }
  }

  void _updateEntitlementFromCache() {
    final entitled = RevenueCatService.instance.isEntitledToPremium;
    // If we have no customer info, remain unknown (fail-closed)
    if (_customerInfo == null) {
      _setState(SubscriptionState.unknown);
      return;
    }
    _setState(entitled ? SubscriptionState.active : SubscriptionState.inactive);
  }

  void _setState(SubscriptionState s) {
    if (_state != s) {
      _state = s;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_auth != null) {
      _auth!.removeListener(_handleAuthChange);
    }
    _authStateSub?.cancel();
    super.dispose();
  }
}

enum SubscriptionState { unknown, inactive, active }