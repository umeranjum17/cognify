# RevenueCat Paywall Implementation (Android-first, sign-in → identify → purchase)

This is the concrete, code-level implementation guide. It references exact files/lines in your repo to make edits straightforward and safe.

Goal flow:
1) Navigate to PaywallScreen when a premium feature is tapped
2) Load offerings (requires Android SDK API Key, apx_…)
3) On Continue:
   - Sign in with Google (Firebase)
   - Identify user in RevenueCat with Firebase UID
   - Purchase selected package
4) On success: entitlement active, pop paywall, UI reflects premium

---

## 0) Prerequisites checklist

- Replace secret key with Android SDK API Key (Client):
  - Edit [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
  - Set `rcPublicKeyAndroid = 'apx_...your_android_sdk_client_key...'`
  - Keep iOS placeholder for later

- Ensure Google Play Billing and product IDs exist and match RC offering in:
  - [subscriptions_config.dart:11-17](lib/config/subscriptions_config.dart:11)

- Perform a full hot-restart after changing providers/keys to avoid context errors.

---

## 1) RevenueCat initialization (already suitable)

- RC service configuration:
  - [revenuecat_service.dart:33-91](lib/services/revenuecat_service.dart:33)
  - `initialize()` configures Purchases with platform key and warms caches
  - It identifies only if `appUserId` provided (we will identify post sign-in)

No changes required here unless you want extra logging.

---

## 2) Guard logout and identity wiring in SubscriptionProvider

Why: Logs showed "Called logOut but the current user is anonymous". We will avoid calling logOut when user is anonymous or no UID.

Edit: [subscription_provider.dart:109-136](lib/providers/subscription_provider.dart:109)

Replace the sign-out branch to skip `logOut()` by default. Instead, just refresh current state.

Pseudo-diff (illustrative; make the same semantic changes in code):
- When uid is present: keep identify(uid) and refresh offerings + customer info (already present)
- When uid is null/empty: do NOT call `RevenueCatService.instance.logOut()`, just refresh:

```dart
void _handleAuthChange() {
  final uid = _auth?.uid;

  if (uid != null && uid.isNotEmpty) {
    RevenueCatService.instance.identify(uid).then((_) async {
      try { _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true); } catch (_) {}
      try { _customerInfo = await Purchases.getCustomerInfo(); } catch (_) {}
      _updateEntitlementFromCache();
      notifyListeners();
    });
  } else {
    // Skip Purchases.logOut() to avoid anonymous logout error.
    // Just refresh to reflect current anonymous RC state (or lack of config).
    () async {
      try { _offerings = await RevenueCatService.instance.getOfferings(forceRefresh: true); } catch (_) {}
      try { _customerInfo = await Purchases.getCustomerInfo(); } catch (_) {}
      _updateEntitlementFromCache();
      notifyListeners();
    }();
  }
}
```

Note: This keeps state consistent without triggering logout error.

---

## 3) PaywallScreen: enforce sign-in → identify → purchase

File: [paywall_screen.dart](lib/screens/subscription/paywall_screen.dart)

Key locations:
- Offerings load: [paywall_screen.dart:31-44](lib/screens/subscription/paywall_screen.dart:31)
- Purchase method: [paywall_screen.dart:46-68](lib/screens/subscription/paywall_screen.dart:46)
- Existing sign-in button (for not-signed-in users): [paywall_screen.dart:169-200](lib/screens/subscription/paywall_screen.dart:169)

Implementation edits:
- Ensure Continue button always performs the sequence when user is not signed in:
  1) Google Sign-In
  2) Identify with RC using uid
  3) Purchase selected package

Use this robust Continue handler (replace current handler in [paywall_screen.dart:225-229](lib/screens/subscription/paywall_screen.dart:225)):

```dart
onPressed: _busy ? null : () async {
  final selected = _selected;
  if (selected == null) return;

  setState(() { _busy = true; _error = null; });

  try {
    final auth = context.read<FirebaseAuthProvider>();
    // Step 1: Ensure signed in
    if (!auth.isSignedIn) {
      await auth.signInWithGoogle();
    }
    final uid = auth.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Sign-in failed: missing UID');
    }

    // Step 2: Identify in RevenueCat with UID (links RC user to your account)
    await RevenueCatService.instance.identify(uid);

    // Optional: refresh offerings to ensure correct eligibility/pricing
    await context.read<SubscriptionProvider>().refreshOfferings();

    // Step 3: Purchase
    final result = await RevenueCatService.instance.purchasePackage(selected);

    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).maybePop(); // Close paywall on success
    } else {
      setState(() {
        _error = result.errorMessage ?? 'Purchase failed';
      });
    }
  } catch (e) {
    if (!mounted) return;
    setState(() { _error = e.toString(); });
  } finally {
    if (!mounted) return;
    setState(() { _busy = false; });
  }
}
```

Additionally:
- Keep the top-of-screen "sign-in first" UI for clarity (already present). The Continue button will handle it either way.

---

## 4) Router and initial wiring

- Providers and app initialization are correctly ordered:
  - [main.dart:221-239](lib/main.dart:221)
- RC init is triggered post-frame:
  - [main.dart:348-374](lib/main.dart:348)
- After replacing the key and hot-restarting, the Provider-not-found error from hot-reloads should resolve.

---

## 5) Firebase anonymous sign-in

- Your flow no longer needs anonymous auth.
- In [firebase_auth_provider.dart:53-63](lib/providers/firebase_auth_provider.dart:53), anonymous sign-in is attempted. You can keep it as a fallback; the main paywall path explicitly signs in with Google. If you prefer to disable anonymous sign-in entirely, remove or guard those lines. If you keep it, ensure Firebase console has Anonymous Sign-in enabled to avoid CONFIGURATION_NOT_FOUND warnings in logs.

---

## 6) Testing script (Android)

1) Replace key:
   - [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7) → apx_ key
2) Full hot-restart
3) Open a premium-gated feature → navigate to Paywall
4) Verify offerings show products with pricing
5) Tap Continue:
   - Google Sign-In flow → back to app with UID
   - RC identify(uid)
   - Purchase completes
6) App pops paywall → premium features unlocked (SubscriptionProvider.state should be active after CustomerInfo update)

If offerings do not load:
- Re-check key is apx_ and matches the Android app in RevenueCat
- Confirm product IDs in Play Console match RC products and offering
- Watch for RC warnings in logs

---

## 7) iOS parity (for later)

- Add iOS SDK API Key (Client) to:
  - [subscriptions_config.dart:8](lib/config/subscriptions_config.dart:8)
- Same flow and handlers will work (PurchasesFlutter abstracts platform differences)

---

## Summary of edit points

- Replace secret key → [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
- Guard logout on anonymous and keep identity wiring → [subscription_provider.dart:109-136](lib/providers/subscription_provider.dart:109)
- Continue button: sign-in → identify → purchase → [paywall_screen.dart:223-229](lib/screens/subscription/paywall_screen.dart:223)
- Optional: tweak anonymous sign-in handling → [firebase_auth_provider.dart:53-63](lib/providers/firebase_auth_provider.dart:53)

This document should be all you need to make the code changes quickly and verify the end-to-end flow on Android.