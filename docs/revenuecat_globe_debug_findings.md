# RevenueCat Globe Toggle — Debug Findings and Recommendations

Owner: Roo  
Date: 2025-08-07

## Summary
You observed that the Internet “Globe” toggle is enabled in-app without a purchase prompt. This is expected in local debug because the tester whitelist bypasses the paywall. To execute real “sandbox” purchases, the app must be installed from Play Store Internal Testing using a non-whitelisted test account.

## What We Found

1) Tester whitelist grants premium unconditionally
- Code: [AppAccessProvider._evaluate()](lib/providers/app_access_provider.dart:37)
- Behavior:
  - hasPremiumAccess = isTester OR entitlementActive
  - Testers are determined by [TesterWhitelistConfig.testerEmails](lib/config/tester_whitelist.dart:7)
  - If your email is whitelisted, all premium features are ON in debug.

2) Globe gating uses unified access logic
- UI gating call site: [FeatureAccess.isEnabledForUser()](lib/services/premium_feature_gate.dart:24)
- Globe onTap flow: [EditorScreen._buildMainContent()](lib/screens/editor_screen.dart:1148)
  - If hasAccess = true → toggles globe locally.
  - If hasAccess = false → invokes [PaywallCoordinator.showNativePurchaseFlow()](lib/services/paywall_coordinator.dart:86), which:
    - Initializes offerings
    - Enforces Google sign-in
    - Calls [RevenueCatService.identify()](lib/services/revenuecat_service.dart:96)
    - Purchases the first available package

3) Entitlement propagation and gate
- RevenueCat entitlement check: [RevenueCatService.isEntitledToPremium](lib/services/revenuecat_service.dart:151) (entitlements.active['premium'])
- Subscription state updates: [SubscriptionProvider._updateEntitlementFromCache()](lib/providers/subscription_provider.dart:139)
- App-wide access: [AppAccessProvider.hasPremiumAccess](lib/providers/app_access_provider.dart:46)

4) Why you weren’t asked for payment
- Your email is in [TesterWhitelistConfig.testerEmails](lib/config/tester_whitelist.dart:7).
- Local debug build + whitelisted account → hasPremiumAccess = true → paywall code path is skipped.

## How to Perform a Sandbox Purchase Correctly (Android)

1) Play Console prerequisites
- Products: Ensure in-app products are created and Active (not “Draft”).  
- License Testing: Add a Google account in Play Console → Settings → Developer account → License testing. Use the same Gmail on your test device.
- Internal Testing Track: Upload a signed build (Play App Signing) to an Internal testing release and publish. Wait for the Play Store to show the release to testers.

2) Install from Play Store, not Android Studio
- Join the internal test link and install/update from Play Store. Billing test dialogs only appear for store-installed builds.

3) Use a non-whitelisted test account
- Option A: Temporarily remove your email from [TesterWhitelistConfig.testerEmails](lib/config/tester_whitelist.dart:7).
- Option B: Create or use a second Google account that is not on the whitelist and add it to License testing.

4) Purchase flow
- Sign in in-app (Google).  
- Tap the Globe → PaywallCoordinator runs native purchase flow → Google’s “License test” purchase dialog appears → approve.  
- On success, entitlement premium becomes active and Globe toggles on.

Notes
- RevenueCat “Could not check” status for products may appear until Google finishes propagation. This can take hours.

## Recommendations

A) Keep whitelist for developer convenience, but test sandbox via Play Console
- For real billing UX validation, always use a Play Store Internal Testing install and a non-whitelisted tester account.

B) Add a Developer toggle to simulate non-premium without editing code
- Add a debug-only flag in SharedPreferences or a hidden Dev Settings panel that forces AppAccessProvider to ignore tester whitelist. This lets you flip between “tester bypass” and “paywall-required” instantly on local builds.

C) Strengthen entitlement UX logging
- Show entitlement state (tester vs entitlement) somewhere in Settings or a small developer overlay.  
- Log key steps: RC configured, offerings fetched, customerInfo state, entitlement active.

D) Maintain fail-closed gating
- Current implementation already fails closed when RC state is unknown (good). Keep it this way to avoid accidental free access in production.

## Concrete Action Plan

- Short term (today)
  1. Remove your email from [tester whitelist](lib/config/tester_whitelist.dart:7) or use a second test account not listed.
  2. Upload internal testing build and install from Play Store.
  3. Trigger purchase via the Globe; approve the “License test” dialog.

- Optional dev QoL
  1. Implement a Dev Setting “Simulate Non‑Premium” that sets a local override in AppAccessProvider to ignore the whitelist in debug.
  2. Add entitlement status banner in Settings: Tester | Entitled | Locked + last RC update time.

## Troubleshooting Checklist

- App uses the correct RC Public SDK key for Android in [SubscriptionsConfig](lib/config/subscriptions_config.dart:5).
- Offerings exist and contain the products premium_monthly and premium_annual in RC, matching Play Console IDs.
- Firebase sign-in succeeds and [identify()](lib/services/revenuecat_service.dart:96) is called with a non-empty UID.
- Device’s Play account is listed under License testing and matches the account used to install the app from Play Store testing.
- Products are fully propagated (may need a few hours after creation/publish).

## Rationale for Current Design
- Tester bypass in debug accelerates feature work without repeatedly hitting paywalls.
- Production remains fail-closed and relies solely on the entitlement, preventing accidental free access.
