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

  String? _lastKnownUid;

  void _handleAuthChange() {
    final uid = _auth?.uid;
    
    // Check if the user has changed (different UID)
    final userChanged = _lastKnownUid != uid;
    
    debugPrint('🔄 [SubscriptionProvider] Auth change detected - Old: $_lastKnownUid, New: $uid, Changed: $userChanged');
    
    // When user signs in: identify with RevenueCat
    if (uid != null && uid.isNotEmpty) {
      Future<void> handleUserLogin() async {
        try {
          // If user changed, reset RevenueCat completely and reinitialize
          if (userChanged && _lastKnownUid != null) {
            debugPrint('🔄 [SubscriptionProvider] User changed - resetting RevenueCat...');
            await RevenueCatService.instance.reset();
            
            // Add a small delay to ensure proper cleanup
            await Future.delayed(const Duration(milliseconds: 500));
            
            await RevenueCatService.instance.initialize(appUserId: uid);
            
            // Force refresh customer info to ensure we get fresh data
            await RevenueCatService.instance.forceRefreshCustomerInfo();
          } else {
            debugPrint('🔄 [SubscriptionProvider] Same user - identifying with RevenueCat...');
            await RevenueCatService.instance.identify(uid);
          }
          
          // Refresh offerings and customer info
          debugPrint('🔄 [SubscriptionProvider] Refreshing RevenueCat data...');
          try {
            _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
            debugPrint('✅ [SubscriptionProvider] Offerings refreshed');
          } catch (e) {
            debugPrint('⚠️ [SubscriptionProvider] Failed to refresh offerings: $e');
          }
          
          try {
            _customerInfo = await Purchases.getCustomerInfo();
            debugPrint('✅ [SubscriptionProvider] Customer info refreshed for user: $uid');
          } catch (e) {
            debugPrint('⚠️ [SubscriptionProvider] Failed to refresh customer info: $e');
          }
          
          _updateEntitlementFromCache();
          notifyListeners();
          debugPrint('✅ [SubscriptionProvider] User login handling completed');
        } catch (e) {
          debugPrint('❌ [SubscriptionProvider] Error handling user login: $e');
          _setState(SubscriptionState.unknown);
          notifyListeners();
        }
      }
      
      handleUserLogin();
    } else {
      // On sign out: reset RevenueCat completely
      debugPrint('🔄 [SubscriptionProvider] User signed out - resetting RevenueCat...');
      Future<void> handleUserLogout() async {
        try {
          await RevenueCatService.instance.reset();
          await RevenueCatService.instance.initialize(); // Initialize without user ID (anonymous)
          
          try {
            _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
          } catch (e) {
            debugPrint('⚠️ [SubscriptionProvider] Failed to refresh offerings after logout: $e');
          }
          
          try {
            _customerInfo = await Purchases.getCustomerInfo();
          } catch (e) {
            debugPrint('⚠️ [SubscriptionProvider] Failed to refresh customer info after logout: $e');
          }
          
          _updateEntitlementFromCache();
          notifyListeners();
          debugPrint('✅ [SubscriptionProvider] User logout handling completed');
        } catch (e) {
          debugPrint('❌ [SubscriptionProvider] Error handling user logout: $e');
          _setState(SubscriptionState.unknown);
          notifyListeners();
        }
      }
      
      handleUserLogout();
    }
    
    _lastKnownUid = uid;
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