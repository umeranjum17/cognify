# Globe Tap → Direct RevenueCat Purchase (Android-first)

Objective:
- When the globe icon is tapped:
  - If user has premium access → toggle globe state normally
  - If user does not have premium access → trigger RevenueCat purchase flow directly (no intermediate app modal)
- If we keep the upgrade modal, its Upgrade Now button should call the same RevenueCat flow, not navigate to a placeholder screen.

This plan lists the exact edits, files, and test steps.

---

## 1) Critical prerequisite: use the Android SDK API Key (Client)

- Replace the secret key with the Android SDK API Key (Client, starts with `apx_`) in:
  - [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)

How to find it:
- RevenueCat dashboard → Apps & providers → your Android app → SDK API Keys (Client)

Why: If you use a secret key, RevenueCat blocks offerings/customer info (Backend Code: 7243). Purchases will fail and the paywall/product list won’t load.

After updating the key, perform a full hot-restart.

---

## 2) Wire globe tap to call RC purchase directly

Current behavior:
- The globe onTap checks premium access. If locked, it calls `_showWebSearchUpgrade()` and navigates to `/subscription`:
  - [editor_screen.dart:1147-1211](lib/screens/editor_screen.dart:1147)
  - Modal Upgrade Now handler → `context.push('/subscription')`: [editor_screen.dart:4053-4063](lib/screens/editor_screen.dart:4053)

Required change:
- Replace the “locked” path to call a coordinator that performs the native RC flow.

Proposed orchestrator:
- Use/extend [lib/services/paywall_coordinator.dart](lib/services/paywall_coordinator.dart)

Add method:
```dart
// File: lib/services/paywall_coordinator.dart
// Pseudocode for the new API
class PaywallCoordinator {
  static Future<bool> showNativePurchaseFlow(BuildContext context) async {
    final auth = context.read<FirebaseAuthProvider>();
    final subs = context.read<SubscriptionProvider>();

    // Ensure SubscriptionProvider is initialized (fetches offerings)
    if (!subs.initialized) {
      await subs.initialize(appUserId: auth.uid);
    } else {
      await subs.refreshOfferings();
    }

    // Sign-in gate: enforce sign-in before purchase (as per approved flow)
    if (!auth.isSignedIn) {
      await auth.signInWithGoogle();
    }
    final uid = auth.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Sign-in failed: missing UID');
    }

    // Link RC to UID
    await RevenueCatService.instance.identify(uid);

    // Refresh offerings to ensure eligibility/pricing correctness
    await subs.refreshOfferings();

    // Choose a default package (first available)
    final offerings = subs.offerings;
    final pkg = offerings?.current?.availablePackages.isNotEmpty == true
        ? offerings!.current!.availablePackages.first
        : null;
    if (pkg == null) {
      throw Exception('No packages available');
    }

    // Purchase
    final result = await RevenueCatService.instance.purchasePackage(pkg);
    if (!result.success) {
      throw Exception(result.errorMessage ?? 'Purchase failed');
    }

    // Success
    return true;
  }
}
```

Change the globe tap handler in EditorScreen:
- File: [lib/screens/editor_screen.dart](lib/screens/editor_screen.dart)
- Location of globe check:
  - [editor_screen.dart:1147-1211](lib/screens/editor_screen.dart:1147)

Edit the onTap branch:
```dart
// Existing:
if (hasAccess) {
  setState(() => _isOfflineMode = !_isOfflineMode);
} else {
  // OLD:
  // _showWebSearchUpgrade();

  // NEW:
  () async {
    try {
      final ok = await PaywallCoordinator.showNativePurchaseFlow(context);
      if (ok) {
        // Flip the globe or refresh UI as premium is now active
        setState(() {
          _isOfflineMode = false; // enable online tools
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Premium unlocked')),
        );
      }
    } catch (e) {
      // Optional: show a small toast/snackbar on fail
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    }
  }();
}
```

---

## 3) If you keep the modal, call RC directly from “Upgrade Now”

- File: [lib/screens/editor_screen.dart](lib/screens/editor_screen.dart)
- Location: modal Upgrade Now action:
  - [editor_screen.dart:4053-4063](lib/screens/editor_screen.dart:4053)

Change handler:
```dart
// OLD:
Navigator.of(context).pop();
context.push('/subscription');

// NEW:
Navigator.of(context).pop();
try {
  final ok = await PaywallCoordinator.showNativePurchaseFlow(context);
  if (ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Premium unlocked')),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Purchase failed: $e')),
  );
}
```

Note: This reuses the same direct RC flow, preserving consistency.

---

## 4) Provider and logout guards

- Avoid calling `Purchases.logOut` when the RC user is anonymous
  - Adjust sign-out branch logic in:
    - [subscription_provider.dart:109-136](lib/providers/subscription_provider.dart:109)
  - On uid == null/empty: skip logout; optionally just refresh offerings/info
- Identify on sign-in: keep the call to `RevenueCatService.instance.identify(uid)` (already present)

This reduces “Called logOut but the current user is anonymous” errors in logs.

---

## 5) Optional: skip anonymous Firebase auth

- Your approved flow enforces sign-in on purchase. Anonymous sign-in is not required.
- If you keep anonymous sign-in lines in:
  - [firebase_auth_provider.dart:53-63](lib/providers/firebase_auth_provider.dart:53)
- Either enable Anonymous in Firebase console or ignore its failure; it won’t block the paywall flow since we explicitly sign in on purchase.

---

## 6) Router note

- With this plan you don’t need to route to PaywallScreen to purchase; the coordinator buys directly.
- You can keep PaywallScreen as a manual path if you ever want a full screen listing of packages:
  - [lib/screens/subscription/paywall_screen.dart](lib/screens/subscription/paywall_screen.dart)

---

## 7) Test checklist

Pre-requisites:
- Android public SDK API Key (Client) in [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
- Matching product IDs configured in Google Play + RevenueCat offering
- Full hot-restart

Scenarios:
- Tap globe when locked:
  - Google sign-in flow appears, returns with UID
  - RC identify(uid) succeeds
  - Offerings fetched (no 7243 errors)
  - Purchase completes
  - Premium toggles on (FeatureAccess.isEnabledForUser returns true via entitlement)
- Open modal and tap Upgrade Now (if modal retained):
  - Same direct RC flow executes
- If purchase canceled:
  - Show snackbar “Purchase cancelled” or similar
- If purchase succeeds:
  - Entitlement “premium” active in `CustomerInfo`
  - Globe toggles, online tools allowed

---

## 8) Failure modes and diagnostics

- Offerings null / empty:
  - Verify `apx_` key used in [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
  - Check RC logs for “7243 Secret API keys …”
  - Ensure products are approved in Play Console and synced to RC offering

- Provider not found error:
  - Do a full hot-restart after changes to providers in [main.dart:221-239](lib/main.dart:221)

- Logout errors in logs:
  - Confirm sign-out branch in SubscriptionProvider no longer calls logOut for anonymous users

---

## 9) Future iOS parity

- Add the iOS SDK API Key (Client) at:
  - [subscriptions_config.dart:8](lib/config/subscriptions_config.dart:8)
- Same coordinator method will work because PurchasesFlutter is cross-platform.

---

## Summary

- Replace secret with Android SDK Client key (apx_…) in config.
- Globe tap on “locked” path should call `PaywallCoordinator.showNativePurchaseFlow(context)` directly.
- If you keep the modal, wire its Upgrade Now to the same coordinator, not to `/subscription`.
- Guard logout-on-anonymous in SubscriptionProvider.
- Hot-restart and test with the checklist.

This yields the exact behavior requested: globe tap triggers a native RevenueCat purchase flow without detours.