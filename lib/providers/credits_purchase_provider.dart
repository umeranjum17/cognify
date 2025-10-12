import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import '../config/purchases_config.dart';
import 'firebase_auth_provider.dart';

/// CreditsPurchaseProvider
/// Manages RevenueCat initialization, offerings, and customer info for
/// consumable credit purchases. No entitlement gating semantics.
class CreditsPurchaseProvider extends ChangeNotifier {
  FirebaseAuthProvider? _auth;
  StreamSubscription? _authStateSub;
  bool _initialized = false;

  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _error;
  StreamSubscription<CustomerInfo>? _sub;

  bool get initialized => _initialized;
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  String? get error => _error;

  Future<void> initialize({String? appUserId}) async {
    if (_initialized) return;

    // Only initialize when purchases are enabled (credit-based flow).
    if (!(PurchasesConfig.purchasesEnabled)) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return;
    }

    try {
      await RevenueCatService.instance.initialize(appUserId: appUserId);

      if (RevenueCatService.instance.isConfigured) {
        try {
          _customerInfo = await RevenueCatService.instance.forceRefreshCustomerInfo();
        } catch (e) {
          debugPrint('⚠️ [CreditsPurchaseProvider] getCustomerInfo error: $e');
        }
        try {
          _offerings = await RevenueCatService.instance.getOfferings();
        } catch (e) {
          debugPrint('⚠️ [CreditsPurchaseProvider] getOfferings error: $e');
        }
      } else {
        debugPrint('⚠️ [CreditsPurchaseProvider] RevenueCat not configured, skipping initialization');
      }

      _sub = RevenueCatService.instance.customerInfoStream.listen((info) {
        _customerInfo = info;
        if (_initialized) notifyListeners();
      }, onError: (e) {
        debugPrint('⚠️ [CreditsPurchaseProvider] stream error: $e');
      });

      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> refreshOfferings() async {
    if (!(PurchasesConfig.purchasesEnabled)) {
      return;
    }
    try {
      if (!RevenueCatService.instance.isConfigured) {
        debugPrint('⚠️ [CreditsPurchaseProvider] RevenueCat not configured, skipping offerings refresh');
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
      debugPrint('⚠️ [CreditsPurchaseProvider] refreshOfferings error: $e');
      if (_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    }
  }

  Future<void> restore() async {
    if (!(PurchasesConfig.purchasesEnabled)) {
      return;
    }
    try {
      if (!RevenueCatService.instance.isConfigured) {
        debugPrint('⚠️ [CreditsPurchaseProvider] RevenueCat not configured, skipping restore');
        return;
      }
      _customerInfo = await RevenueCatService.instance.restorePurchases();
      if (_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('⚠️ [CreditsPurchaseProvider] restore error: $e');
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

    if (PurchasesConfig.purchasesEnabled) {
      _handleAuthChange();
    }

    _auth!.addListener(_handleAuthChange);
  }

  String? _lastKnownUid;
  bool _isHandlingAuthChange = false;

  void _handleAuthChange() {
    if (!(PurchasesConfig.purchasesEnabled)) {
      return;
    }
    if (_isHandlingAuthChange) {
      debugPrint('⚠️ [CreditsPurchaseProvider] Auth change already in progress, skipping...');
      return;
    }
    final uid = _auth?.uid;
    final userChanged = _lastKnownUid != uid;

    if (uid != null && uid.isNotEmpty) {
      Future<void> handleUserLogin() async {
        _isHandlingAuthChange = true;
        try {
          if (userChanged && _lastKnownUid != null) {
            await RevenueCatService.instance.reset();
            await Future.delayed(const Duration(milliseconds: 500));
            await RevenueCatService.instance.initialize(appUserId: uid);
          } else {
            // If the SDK isn't configured yet (first login after app start), initialize with UID
            if (!RevenueCatService.instance.isConfigured) {
              await RevenueCatService.instance.initialize(appUserId: uid);
            } else {
              await RevenueCatService.instance.identify(uid);
            }
          }

          if (RevenueCatService.instance.isConfigured) {
            try {
              _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
            } catch (e) {
              debugPrint('⚠️ [CreditsPurchaseProvider] Failed to refresh offerings: $e');
            }
            try {
              _customerInfo = await RevenueCatService.instance.forceRefreshCustomerInfo();
            } catch (e) {
              debugPrint('⚠️ [CreditsPurchaseProvider] Failed to refresh customer info: $e');
            }
          }

          notifyListeners();
        } catch (e) {
          debugPrint('❌ [CreditsPurchaseProvider] Error handling user login: $e');
          notifyListeners();
        } finally {
          _isHandlingAuthChange = false;
        }
      }

      handleUserLogin();
    } else {
      Future<void> handleUserLogout() async {
        _isHandlingAuthChange = true;
        try {
          await RevenueCatService.instance.reset();
          await RevenueCatService.instance.initialize();
          if (RevenueCatService.instance.isConfigured) {
            try {
              _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true);
            } catch (e) {
              debugPrint('⚠️ [CreditsPurchaseProvider] Failed to refresh offerings after logout: $e');
            }
            try {
              _customerInfo = await RevenueCatService.instance.forceRefreshCustomerInfo();
            } catch (e) {
              debugPrint('⚠️ [CreditsPurchaseProvider] Failed to refresh customer info after logout: $e');
            }
          }
          notifyListeners();
        } catch (e) {
          debugPrint('❌ [CreditsPurchaseProvider] Error handling user logout: $e');
          notifyListeners();
        } finally {
          _isHandlingAuthChange = false;
        }
      }

      handleUserLogout();
    }

    _lastKnownUid = uid;
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


