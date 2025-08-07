# RevenueCat Paywall Flow (Android-first)

This document explains why the app showed the internal "Unlock Web Search" modal instead of the RevenueCat paywall, and prescribes an Android-first implementation that you approved:
- Show Paywall
- On Continue: Google Sign-In
- Identify user with RevenueCat using Firebase UID
- Purchase package

It also includes exact code change locations as hyperlinks to your source files.

---

## Why paywall didn’t show

From runtime logs and code review:

- Client uses a RevenueCat Secret API key, which RevenueCat rejects in mobile apps:
  - Replace with Android SDK API Key (Client) starting with `apx_` [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
  - Error seen: Backend Code: 7243 - Secret API keys should not be used in your app.

- Provider lookup error during RevenueCat init
  - RC init depends on `FirebaseAuthProvider` and `SubscriptionProvider` in `CognifyApp` [main.dart:359-374](lib/main.dart:359)
  - A hot-reload after changing providers can make the tree stale. Full hot-restart is required.

- Calling `Purchases.logOut` while the RC user is anonymous
  - Unconditional logout path can cause: "Called logOut but the current user is anonymous."
  - See [subscription_provider.dart:124-136](lib/providers/subscription_provider.dart:124)

---

## Correct keys to use

- Retrieve Android SDK API Key (Client) from RevenueCat:
  - RevenueCat → Apps & providers → Select your Android app → SDK API Keys (Client)
  - Copy the Android SDK API Key (starts with `apx_...`)
  - Do NOT use Secret API keys in the app.

- Update here:
  - Set `SubscriptionsConfig.rcPublicKeyAndroid` to the `apx_...` key [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
  - Keep `SubscriptionsConfig.rcPublicKeyIOS` as a placeholder until you add iOS.

---

## Approved user flow (Android)

1) User taps premium-gated action → navigate to PaywallScreen
2) Paywall loads offerings (requires correct `apx_` key)
3) User taps Continue:
   - Google Sign-In (Firebase)
   - On success: `RevenueCatService.identify(uid)`
   - Then `RevenueCatService.purchasePackage(selected)`
4) On purchase success: return to previous screen and show entitlement enabled

Rationale:
- Ensures the RC App User ID is linked to your Firebase UID at purchase time
- Avoids anonymous-only purchases in your chosen flow
- Keeps cross-device restore and account linking sane

---

## Minimal changes to implement

1) Replace key
- Replace secret `sk_...` with Android SDK API Key `apx_...`:
  - [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)

2) Keep RC initialization anonymous-friendly and not dependent on auth
- Already supported by `RevenueCatService.initialize()`:
  - Configures with correct platform key and warms caches [revenuecat_service.dart:33-91](lib/services/revenuecat_service.dart:33)
  - Identifies only if `appUserId` is provided (we’ll pass it after sign-in)

3) Harden logout and identify wiring
- SubscriptionProvider should not call `logOut` when the current RC user is anonymous
- Only call `identify(uid)` when a non-empty UID exists
- Code areas to adjust:
  - Identify on sign-in [subscription_provider.dart:109-123](lib/providers/subscription_provider.dart:109)
  - Avoid logout on anonymous [subscription_provider.dart:124-136](lib/providers/subscription_provider.dart:124)

4) Paywall button flow
- Current `PaywallScreen` loads offerings and purchases with `RevenueCatService` [paywall_screen.dart:31-44](lib/screens/subscription/paywall_screen.dart:31)
- Modify Continue button to:
  - If not signed in, trigger Google Sign-In
  - After sign-in, call `identify(uid)` then `purchasePackage(selected)` [paywall_screen.dart:223-229](lib/screens/subscription/paywall_screen.dart:223)

---

## Concrete step-by-step (what to edit)

A) SubscriptionsConfig
- Replace key:
  - [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
  - Set `rcPublicKeyAndroid` to your `apx_...` Android SDK API Key (Client)
- Keep iOS placeholder on line 8 as-is for now

B) SubscriptionProvider guards
- File: [subscription_provider.dart](lib/providers/subscription_provider.dart)
- In `_handleAuthChange()` [subscription_provider.dart:109-136](lib/providers/subscription_provider.dart:109)
  - When `uid != null && uid.isNotEmpty`:
    - Call `RevenueCatService.instance.identify(uid)` (already present)
    - Then refresh offerings and customer info (already present)
  - When `uid == null || uid.isEmpty`:
    - Do NOT call `RevenueCatService.instance.logOut()` (this is the source of "anonymous logout" errors)
    - Option: Just refresh offerings and customer info; state will remain consistent

C) PaywallScreen Continue button
- File: [paywall_screen.dart](lib/screens/subscription/paywall_screen.dart)
- Flow:
  - If user not signed in: run `FirebaseAuthProvider.signInWithGoogle()` first [paywall_screen.dart:169-200](lib/screens/subscription/paywall_screen.dart:169)
  - After sign-in, call `RevenueCatService.instance.identify(uid)` (uid from `FirebaseAuthProvider.uid`)
  - Then call `RevenueCatService.instance.purchasePackage(_selected!)` [paywall_screen.dart:56](lib/screens/subscription/paywall_screen.dart:56)
- Ensure you refresh offerings post-sign-in to display correct packages:
  - Already present via `refreshOfferings()` [paywall_screen.dart:182-185](lib/screens/subscription/paywall_screen.dart:182)

D) Initialization order and hot-restart
- Providers are correctly mounted above the app [main.dart:221-239](lib/main.dart:221)
- Do a full hot-restart after adding/changing providers, otherwise you can hit:
  - "Could not find the correct Provider<FirebaseAuthProvider> above this CognifyApp Widget"

---

## FAQ

- Can RC App User ID just be the Google Play account ID?
  - Not directly. RC’s `appUserID` is your logical user ID. Google Play account is represented via purchase receipts. Best practice:
    - Start anonymous or unauthenticated RC user
    - On successful sign-in, call `Purchases.logIn(uid)` to merge into your UID
    - RC automatically validates purchases with Play Billing

- Anonymous sign-in errors in Firebase
  - Your chosen flow does not require anonymous auth. You can keep anonymous disabled and only sign in when the user taps Continue on the paywall.

- Why offerings are empty?
  - If the client uses a secret key, RevenueCat blocks calls (7243).
  - Use the Android SDK API Key (Client) from Apps & providers → Android App → SDK API Keys (Client).

---

## Test checklist (Android)

- Pre-requisites:
  - Google Play products created and synced to RevenueCat Offering IDs
  - Android SDK API Key (Client) set in [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
  - App package name matches in Play Console and RC app

- Scenarios:
  - Open paywall → offerings load with prices
  - Tap Continue → Google Sign-In → app returns with UID
  - RC identifies to UID → purchase completes
  - Entitlement premium is active in `CustomerInfo` → gated premium toggles on
  - Restore purchases flow works from PaywallScreen

---

## iOS readiness

- Keep the same flow on iOS; use `SubscriptionsConfig.rcPublicKeyIOS` with your iOS SDK API Key (Client) later.
- The rest of the service/provider/paywall code stays the same due to platform abstraction in `PurchasesFlutter`.

---

## Summary of exact code hotspots

- Replace secret key: [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
- Providers properly mounted: [main.dart:221-239](lib/main.dart:221)
- RC init with defensive design: [revenuecat_service.dart:33-91](lib/services/revenuecat_service.dart:33)
- Identify/login and logout paths to guard: [subscription_provider.dart:109-136](lib/providers/subscription_provider.dart:109)
- Paywall flow and buttons: [paywall_screen.dart:31-44](lib/screens/subscription/paywall_screen.dart:31), [paywall_screen.dart:223-229](lib/screens/subscription/paywall_screen.dart:223), [paywall_screen.dart:169-200](lib/screens/subscription/paywall_screen.dart:169)

---

## Action you need to take now

- Get the Android SDK API Key (Client) starting with `apx_` from:
  - Apps & providers → Your Android app → SDK API Keys (Client)
- Paste it into [subscriptions_config.dart:7](lib/config/subscriptions_config.dart:7)
- Do a full hot-restart
- Test the paywall flow with the checklist above