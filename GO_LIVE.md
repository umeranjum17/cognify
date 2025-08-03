# Go Live Checklist: Firebase Auth + RevenueCat

Objective
Ship iOS and Android with working Firebase Authentication and RevenueCat subscriptions. Tester email(s) get full access without paywall.

Code Status Summary
- Firebase Auth provider present and initialized ([lib/providers/firebase_auth_provider.dart](lib/providers/firebase_auth_provider.dart:1)).
- RevenueCat SDK wrapped ([lib/services/revenuecat_service.dart](lib/services/revenuecat_service.dart:1)) and consumed by SubscriptionProvider ([lib/providers/subscription_provider.dart](lib/providers/subscription_provider.dart:1)).
- Paywall flow implemented and now bypasses for testers or entitled users ([lib/services/paywall_coordinator.dart](lib/services/paywall_coordinator.dart:1)).
- Tester whitelist implemented ([lib/config/tester_whitelist.dart](lib/config/tester_whitelist.dart:1)) and unified via AppAccessProvider ([lib/providers/app_access_provider.dart](lib/providers/app_access_provider.dart:1)).
- App wires providers in main ([lib/main.dart](lib/main.dart:1)).

Required Console Work

1) Firebase (Both iOS and Android)
- Create/Select Firebase project.
- Add iOS app
  - Bundle ID must match ios/Runner project.
  - Download GoogleService-Info.plist and add to ios/Runner (ensure it is included in the target).
- Add Android app
  - Package name (applicationId) must match android/app/build.gradle.
  - Add SHA-1 and SHA-256 for debug and release keystores in Firebase Console (required for Google Sign-In).
  - Download google-services.json and place at android/app/google-services.json.
- Enable Auth Providers
  - Google (required for current flows).
  - Apple (optional; only if you intend to use Sign in with Apple on iOS).
- Android Gradle integration
  - Project-level build.gradle: add classpath 'com.google.gms:google-services:X.Y.Z'.
  - App-level build.gradle: apply plugin 'com.google.gms.google-services'.

2) RevenueCat
- In RevenueCat Project
  - Create Entitlement: premium.
  - Create Offering: default.
  - Add Products/Packages to offering (monthly/annual).
- Create Store Products
  - App Store Connect: create subscriptions matching your identifiers.
  - Google Play Console: create subscriptions matching identifiers.
  - Ensure product IDs exactly match the app code.
- API Keys
  - Copy iOS and Android Public SDK Keys (not secret keys).
  - Paste into code at [lib/config/subscriptions_config.dart](lib/config/subscriptions_config.dart:1):
    - rcPublicKeyIOS
    - rcPublicKeyAndroid
  - Confirm identifiers:
    - offeringDefault = 'default'
    - entitlementPremium = 'premium'
    - productMonthly = 'premium_monthly'
    - productAnnual = 'premium_annual'

App-side Actions You Must Complete

- Paste Firebase config files
  - ios/Runner/GoogleService-Info.plist
  - android/app/google-services.json

- Replace RevenueCat placeholders
  - [lib/config/subscriptions_config.dart](lib/config/subscriptions_config.dart:1) with your real SDK keys and product IDs.

- Ensure identify/logout calls happen
  - After successful Firebase sign-in: RevenueCatService.instance.identify(uid).
  - On sign-out: RevenueCatService.instance.logOut().
  - Current flows cover app start and paywall flow; ensure your sign-in UI triggers identify(uid).

Tester Whitelisting

- Your email is already whitelisted:
  - [lib/config/tester_whitelist.dart](lib/config/tester_whitelist.dart:1) → 'umeranjum17@gmail.com'
- Add more testers by editing testerEmails list and redeploying.
- Access rule:
  - hasPremiumAccess = isTester OR RevenueCat entitlement.
  - Managed by AppAccessProvider → PaywallCoordinator bypasses for testers.

Smoke Test Plan

iOS (Sandbox)
1. Build to a device with GoogleService-Info.plist included.
2. Sign in with your whitelisted email.
3. Open a premium feature → Paywall should be bypassed (tester).
4. Sign out, sign in with a non-whitelisted account → Paywall should appear.
5. Using a Sandbox Apple ID, complete a purchase → entitlement should be active, bypass thereafter.
6. Test restore purchases → entitlement remains.

Android (Internal Testing / License Testing)
1. Upload an internal test build (or use license testing).
2. Install on a tester device with google-services.json baked in.
3. Whitelisted email → bypass paywall.
4. Non-whitelisted → paywall appears, purchase in Play → entitlement active → bypass.
5. Test restore.

Operational Notes

- Production safety
  - Keep testerEmails minimal in prod.
  - No domain-wide dev wildcards used by default.
- Auditing
  - Consider adding an analytics event on tester bypass for auditing.
- Troubleshooting
  - If Google sign-in fails on Android, verify SHA-1/SHA-256 in Firebase and re-download google-services.json.
  - If offerings are empty, verify RevenueCat offering and product mapping exist and your public SDK keys are correct.

Owner Checklist (Copy/Paste)
- [ ] Firebase: iOS app added; GoogleService-Info.plist in ios/Runner
- [ ] Firebase: Android app added; SHA-1/SHA-256 set; google-services.json in android/app
- [ ] Firebase: Auth providers enabled (Google, optionally Apple)
- [ ] RevenueCat: Entitlement 'premium' created
- [ ] RevenueCat: Offering 'default' with packages mapped to store products
- [ ] App Store Connect / Play Console: subscriptions created with IDs matching code
- [ ] Code: [lib/config/subscriptions_config.dart](lib/config/subscriptions_config.dart:1) keys and IDs replaced
- [ ] Sign-in UI triggers RevenueCat identify(uid); sign-out triggers logOut()
- [ ] Tester email(s) set in [lib/config/tester_whitelist.dart](lib/config/tester_whitelist.dart:1)

Appendix: Key File References
- Firebase Auth Provider: [lib/providers/firebase_auth_provider.dart](lib/providers/firebase_auth_provider.dart:1)
- RevenueCat Service: [lib/services/revenuecat_service.dart](lib/services/revenuecat_service.dart:1)
- Subscription Provider: [lib/providers/subscription_provider.dart](lib/providers/subscription_provider.dart:1)
- Paywall Flow: [lib/services/paywall_coordinator.dart](lib/services/paywall_coordinator.dart:1), [lib/screens/subscription/paywall_screen.dart](lib/screens/subscription/paywall_screen.dart:1)
- Tester Whitelist: [lib/config/tester_whitelist.dart](lib/config/tester_whitelist.dart:1)
- Access Provider: [lib/providers/app_access_provider.dart](lib/providers/app_access_provider.dart:1)
- App Wiring: [lib/main.dart](lib/main.dart:1)