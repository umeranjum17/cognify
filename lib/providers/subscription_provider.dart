import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import '../config/subscriptions_config.dart';
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

    // When subscriptions are disabled, mark initialized and set inactive state
    if (!SubscriptionsConfig.subscriptionsEnabled) {
      _initialized = true;
      _setState(SubscriptionState.active); // credit-based: treat as active/unlocked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return;
    }

    // Default fail-closed state
    _setState(SubscriptionState.unknown);
    // Don't call notifyListeners() here to avoid setState during build

    try {
      await RevenueCatService.instance.initialize(appUserId: appUserId);

      // Attempt to hydrate customer info only if RevenueCat is configured
      if (RevenueCatService.instance.isConfigured) {
        try {
          _customerInfo = await RevenueCatService.instance.forceRefreshCustomerInfo();
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
      } else {
        debugPrint('⚠️ [SubscriptionProvider] RevenueCat not configured, skipping initialization');
      }

      _sub = RevenueCatService.instance.customerInfoStream.listen((info) {
        _customerInfo = info;
        _updateEntitlementFromCache();
        if (_initialized) notifyListeners(); // Only notify after initialization complete
      }, onError: (e) {
        debugPrint('⚠️ [SubscriptionProvider] stream error: $e');
      });

      _initialized = true;
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      // Stay fail-closed as unknown (gated)
      _initialized = true; // Mark as initialized even with error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> refreshOfferings() async {
    if (!SubscriptionsConfig.subscriptionsEnabled) {
      // No-op in credit mode
      return;
    }
    try {
      // Only attempt to get offerings if RevenueCat is properly configured
      if (!RevenueCatService.instance.isConfigured) {
        debugPrint('⚠️ [SubscriptionProvider] RevenueCat not configured, skipping offerings refresh');
        return;
      }
      _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
      if (_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('⚠️ [SubscriptionProvider] refreshOfferings error: $e');
      if (_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    }
  }

  Future<void> restore() async {
    if (!SubscriptionsConfig.subscriptionsEnabled) {
      // No-op in credit mode
      return;
    }
    try {
      // Only attempt to restore if RevenueCat is properly configured
      if (!RevenueCatService.instance.isConfigured) {
        debugPrint('⚠️ [SubscriptionProvider] RevenueCat not configured, skipping restore');
        return;
      }
      _customerInfo = await RevenueCatService.instance.restorePurchases();
      _updateEntitlementFromCache();
      if (_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('⚠️ [SubscriptionProvider] restore error: $e');
      if (_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    }
  }

  // Wire FirebaseAuthProvider to sync identity with RevenueCat
  void wireAuth(FirebaseAuthProvider auth) {
    if (_auth == auth) return;
    _auth = auth;

    // React immediately to current state
    if (SubscriptionsConfig.subscriptionsEnabled) {
      _handleAuthChange();
    }

    // Listen for subsequent auth state changes
    _auth!.addListener(_handleAuthChange);
  }

  String? _lastKnownUid;
  bool _isHandlingAuthChange = false; // Prevent duplicate auth handling

  void _handleAuthChange() {
    if (!SubscriptionsConfig.subscriptionsEnabled) {
      return;
    }
    // Prevent duplicate/concurrent auth change handling
    if (_isHandlingAuthChange) {
      debugPrint('⚠️ [SubscriptionProvider] Auth change already in progress, skipping...');
      return;
    }
    final uid = _auth?.uid;
    
    // Check if the user has changed (different UID)
    final userChanged = _lastKnownUid != uid;
    
    debugPrint('🔄 [SubscriptionProvider] Auth change detected - Old: $_lastKnownUid, New: $uid, Changed: $userChanged');
    
    // When user signs in: identify with RevenueCat
    if (uid != null && uid.isNotEmpty) {
      Future<void> handleUserLogin() async {
        _isHandlingAuthChange = true;
        try {
          // If user changed, reset RevenueCat completely and reinitialize
          if (userChanged && _lastKnownUid != null) {
            debugPrint('🔄 [SubscriptionProvider] User changed - resetting RevenueCat...');
            await RevenueCatService.instance.reset();
            
            // Add a small delay to ensure proper cleanup
            await Future.delayed(const Duration(milliseconds: 500));
            
            await RevenueCatService.instance.initialize(appUserId: uid);
          } else {
            debugPrint('🔄 [SubscriptionProvider] Same user - identifying with RevenueCat...');
            await RevenueCatService.instance.identify(uid);
          }
          
          // Refresh offerings and customer info only if RevenueCat is configured
          debugPrint('🔄 [SubscriptionProvider] Refreshing RevenueCat data...');
          if (RevenueCatService.instance.isConfigured) {
            try {
              _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
              debugPrint('✅ [SubscriptionProvider] Offerings refreshed');
            } catch (e) {
              debugPrint('⚠️ [SubscriptionProvider] Failed to refresh offerings: $e');
            }
          } else {
            debugPrint('⚠️ [SubscriptionProvider] RevenueCat not configured, skipping offerings refresh');
          }
          
          if (RevenueCatService.instance.isConfigured) {
            try {
              _customerInfo = await RevenueCatService.instance.forceRefreshCustomerInfo();
              debugPrint('✅ [SubscriptionProvider] Customer info refreshed for user: $uid');
            } catch (e) {
              debugPrint('⚠️ [SubscriptionProvider] Failed to refresh customer info: $e');
            }
          }
          
          _updateEntitlementFromCache();
          notifyListeners();
          debugPrint('✅ [SubscriptionProvider] User login handling completed');
        } catch (e) {
          debugPrint('❌ [SubscriptionProvider] Error handling user login: $e');
          _setState(SubscriptionState.unknown);
          notifyListeners();
        } finally {
          _isHandlingAuthChange = false;
        }
      }
      
      handleUserLogin();
    } else {
      // On sign out: reset RevenueCat completely
      debugPrint('🔄 [SubscriptionProvider] User signed out - resetting RevenueCat...');
      Future<void> handleUserLogout() async {
        _isHandlingAuthChange = true;
        try {
          await RevenueCatService.instance.reset();
          await RevenueCatService.instance.initialize(); // Initialize without user ID (anonymous)
          
          if (RevenueCatService.instance.isConfigured) {
            try {
              _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
            } catch (e) {
              debugPrint('⚠️ [SubscriptionProvider] Failed to refresh offerings after logout: $e');
            }
            
            try {
              _customerInfo = await RevenueCatService.instance.forceRefreshCustomerInfo();
            } catch (e) {
              debugPrint('⚠️ [SubscriptionProvider] Failed to refresh customer info after logout: $e');
            }
          }
          
          _updateEntitlementFromCache();
          notifyListeners();
          debugPrint('✅ [SubscriptionProvider] User logout handling completed');
        } catch (e) {
          debugPrint('❌ [SubscriptionProvider] Error handling user logout: $e');
          _setState(SubscriptionState.unknown);
          notifyListeners();
        } finally {
          _isHandlingAuthChange = false;
        }
      }
      
      handleUserLogout();
    }
    
    _lastKnownUid = uid;
  }

  void _updateEntitlementFromCache() {
    final entitled = RevenueCatService.instance.isEntitledToPremium;
    debugPrint('🔄 [SubscriptionProvider] Updating entitlement state:');
    debugPrint('  - Has customer info: ${_customerInfo != null}');
    debugPrint('  - RevenueCat says entitled: $entitled');
    debugPrint('  - Current state: $_state');
    
    // If we have no customer info, remain unknown (fail-closed)
    if (_customerInfo == null) {
      debugPrint('  - No customer info, setting to unknown');
      _setState(SubscriptionState.unknown);
      return;
    }
    
    final newState = entitled ? SubscriptionState.active : SubscriptionState.inactive;
    debugPrint('  - Setting state to: $newState');
    _setState(newState);
  }

  void _setState(SubscriptionState s) {
    if (_state != s) {
      debugPrint('📝 [SubscriptionProvider] State changed: $_state → $s');
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