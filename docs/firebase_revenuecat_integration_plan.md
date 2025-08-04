# Firebase Auth + RevenueCat Integration Plan (Android first, extensible to iOS)

Status snapshot (from code)
- RevenueCat scaffold present: [`lib/services/revenuecat_service.dart`](lib/services/revenuecat_service.dart), [`lib/providers/subscription_provider.dart`](lib/providers/subscription_provider.dart), [`lib/screens/subscription/paywall_screen.dart`](lib/screens/subscription/paywall_screen.dart), gating via [`lib/providers/app_access_provider.dart`](lib/providers/app_access_provider.dart).
- Firebase auth provider in place with Google/Apple methods: [`lib/providers/firebase_auth_provider.dart`](lib/providers/firebase_auth_provider.dart).
- Placeholder Firebase options to be replaced: [`lib/firebase_options.dart`](lib/firebase_options.dart).
- Android google-services plugin active and json present: [`android/app/build.gradle`](android/app/build.gradle).

Product principle
- Free users: zero friction. No sign-in required. They onboard with OpenRouter key and use free features; we do not incur auth or subscription overhead.
- Premium users: require account linkage at the moment they opt-in. We ask them to sign in with Google (Android) to bind the purchase to their identity, enabling restore and multi-device use.
- Extensibility: The same flow will later support Sign in with Apple on iOS, using identical screens and provider hooks.

User flows

Free flow
1) User installs app and uses free features without auth.
2) If the user never opens premium, Firebase Auth is never invoked.

Premium purchase flow (Android + Google)
1) User opens Paywall.
2) If not signed in:
   - Show rationale: “To secure your subscription and enable restore on any device, we’ll connect your purchase to your Google account.”
   - Show “Continue with Google”.
3) On Google sign-in success:
   - FirebaseAuthProvider now has _user and uid.
   - SubscriptionProvider identifies user in RevenueCat with uid.
   - Fetch offerings and show purchase options.
4) User selects package and taps “Continue”.
5) RevenueCat purchase flow.
6) On success, entitlement premium becomes active; AppAccessProvider.hasPremiumAccess turns true and premium features unlock.

Restore flow
1) User taps “Restore Purchases” (Paywall or Settings).
2) RevenueCat restorePurchases() runs; if entitlement premium is active, premium unlocks.
3) If the user hadn’t signed in yet, prompt sign-in so we can match restored access to their account across devices.

Sign-out flow
- If a signed-in user signs out, call RevenueCat logOut() and re-fetch CustomerInfo to ensure UI reflects current entitlements (usually anonymous/no premium unless tester whitelist).

Architecture decisions

Where identity binding happens
- Centralize RevenueCat initialization and identity changes in SubscriptionProvider:
  - initialize(appUserId) configures Purchases with public key (Android first).
  - After Firebase auth changes (uid became non-null), call RevenueCatService.identify(uid).
  - After sign-out (uid null), call RevenueCatService.logOut().

Gating policy
- AppAccessProvider.hasPremiumAccess = TesterWhitelist OR RevenueCat entitlement 'premium'.
- Premium routes/components must check this flag; if false, route to Paywall.

Single initialization path
- Avoid duplicate RevenueCat initialization. Preferred entry: SubscriptionProvider.initialize() on app start (root route), passing Firebase UID if available. Remove the extra init call in _initializeApp in [`lib/main.dart`](lib/main.dart:604).

Extensibility to iOS/Apple
- Keep Paywall UI logic abstract: “provider sign-in” section supports multiple buttons, currently shows only Google on Android. Later we add Apple button for iOS builds, with platform checks.

Exact work items

Replace placeholders and setup
- RevenueCat:
  - In dashboard, create products in Google Play Console (In-app subscriptions): product IDs:
    - premium_monthly
    - premium_annual
  - Create entitlement: premium.
  - Create offering: default; attach packages mapping to monthly/annual products.
  - Retrieve Android Public SDK Key.
  - Insert values into [`lib/config/subscriptions_config.dart`](lib/config/subscriptions_config.dart:7).
- Firebase Android:
  - Replace placeholder [`lib/firebase_options.dart`](lib/firebase_options.dart) with FlutterFire-generated file by running:
    - flutter pub global activate flutterfire_cli
    - flutterfire configure --project=<your-project> --android-package=com.umerfarooq1995.cognify_flutter
  - Confirm android/app/google-services.json package_name matches applicationId in [`android/app/build.gradle`](android/app/build.gradle:47,74,81).

Code changes (implementation spec)
1) PaywallScreen gating and messaging
   - Behavior:
     - If not signed in: render rationale card and “Continue with Google” button.
     - On click: call FirebaseAuthProvider.signInWithGoogle(). Show spinner and error states.
     - After success: SubscriptionProvider.refreshOfferings(), then show packages and purchase button.
     - Always show “Restore Purchases”.
   - Touchpoints: [`lib/screens/subscription/paywall_screen.dart`](lib/screens/subscription/paywall_screen.dart).
   - Copy suggestions (short and friendly):
     - Title: Unlock Premium
     - Body: Secure your subscription to your account so you can restore it on any device.
     - CTA: Continue with Google
     - Post-sign-in: Continue to purchase

2) SubscriptionProvider identity sync
   - Add a method wireAuth(FirebaseAuthProvider auth) or accept a listener from main.dart to observe uid changes.
   - On uid changes:
     - If uid != null: RevenueCatService.identify(uid); update _customerInfo and _isEntitled; notifyListeners().
     - If uid == null: RevenueCatService.logOut(); update state; notify.
   - Ensure initialize() only configures Purchases once, and uses appUserId if provided.
   - Touchpoints: [`lib/providers/subscription_provider.dart`](lib/providers/subscription_provider.dart), [`lib/services/revenuecat_service.dart`](lib/services/revenuecat_service.dart:57,68).

3) Main initialization cleanup
   - Keep SubscriptionProvider.initialize(appUserId: firebaseAuth.uid) in the root route.
   - Remove the additional initialize from _initializeApp to avoid duplicate calls: [`lib/main.dart`](lib/main.dart:604-614).
   - Ensure AppAccessProvider is created after both FirebaseAuthProvider and SubscriptionProvider to listen to updates.

4) AppAccess gating usages
   - Audit premium features/screens (e.g., Trending Topics route).
   - Before entering premium routes, if not hasPremiumAccess, navigate to /paywall.
   - Touchpoints: routing in [`lib/main.dart`](lib/main.dart) and any feature-level checks.

5) Web guards (deferred if web not targeted for purchase)
   - If kIsWeb, hide purchase UI and show info message: “Purchases are available on mobile. You can still sign in to retain access when you move to mobile.”
   - Allow optional Google sign-in on web only when starting premium, if needed later.

Testing plan (Android)
- Free anonymous flow:
  - Launch app; ensure no auth prompts.
- Premium first-time purchase:
  - Tap premium; see rationale copy and Google sign-in CTA.
  - Complete Google sign-in; offerings show; purchase monthly; entitlement active; UI unlocks.
- Restore:
  - Reinstall app or clear data; go to Paywall; tap Restore Purchases; entitlement restored after sign-in.
- Sign-out and re-login:
  - Sign out; verify entitlement reflects state; sign in; entitlement reappears.
- Tester whitelist:
  - Whitelisted email should unlock premium without purchase.
- Error cases:
  - Sign-in cancel; purchase cancel; network errors; ensure clear messages.

Release readiness tasks
- GO_LIVE additions:
  - Sign-in rationale privacy text and how it’s used.
  - Screenshots of Paywall, sign-in prompt, and purchase flow.
  - Play Console checklist:
    - App content and data safety
    - In-app products status active
    - Subscription base plan and pricing configured
    - Testers added to license testers list
    - Internal testing track
- Post-launch monitoring:
  - RevenueCat dashboard checks
  - Firebase Auth sign-in error rates

Copy blocks for reuse (short)
- Rationale headline: Keep your access safe
- Rationale body: We’ll link your purchase to your Google account so you can restore it on any device.
- CTA: Continue with Google
- Restore: Restore Purchases
- Error generic: Something went wrong. Please try again.

File-by-file change checklist (Android phase)
- [`lib/config/subscriptions_config.dart`](lib/config/subscriptions_config.dart): fill rcPublicKeyAndroid, confirm entitlementPremium = premium, offeringDefault = default, product IDs.
- [`lib/firebase_options.dart`](lib/firebase_options.dart): replace with FlutterFire output.
- [`lib/providers/subscription_provider.dart`](lib/providers/subscription_provider.dart): add identity sync with Firebase and centralize init.
- [`lib/services/revenuecat_service.dart`](lib/services/revenuecat_service.dart): ensure identify/logOut update caches and stream subscribers.
- [`lib/screens/subscription/paywall_screen.dart`](lib/screens/subscription/paywall_screen.dart): add sign-in rationale and Google sign-in gate before purchase, loading/error handling, restore.
- [`lib/main.dart`](lib/main.dart): remove duplicate RevenueCat initialize in _initializeApp; confirm initialization via SubscriptionProvider on root; keep AppAccessProvider wiring.
- Premium feature routes: guard using AppAccessProvider.hasPremiumAccess and navigate to /paywall when locked.

Future iOS extension (outline)
- Add Apple Sign-In button gated by Platform.isIOS; call FirebaseAuthProvider.signInWithApple().
- Insert rcPublicKeyIOS in SubscriptionsConfig and configure iOS products in App Store Connect; replicate offering in RevenueCat.
- Add GoogleService-Info.plist and run flutterfire configure for iOS; update bundle id matches.

Owner checklist to unblock dev
- Provide:
  - RevenueCat Android Public SDK Key
  - Confirm entitlement key: premium
  - Product IDs: premium_monthly, premium_annual
  - Confirm offering name: default
  - Firebase project and run flutterfire configure to generate lib/firebase_options.dart

Timeline (suggested)
- Day 1: Configure stores/RevenueCat, replace placeholders, code gating on Paywall, identity sync in provider, remove duplicate init.
- Day 2: End-to-end Android tests, fix edge cases, update GO_LIVE.md.
- Day 3: Prepare iOS scaffolding notes (no code changes needed now), finalize release checklist.

Requested approvals
- Confirm product identifiers and entitlement key, and share the RevenueCat Android Public SDK Key.
- Approval to remove the extra RevenueCat initialization from _initializeApp in [`lib/main.dart`](lib/main.dart:604-614) to prevent double setup.
- Approval of rationale copy above (or send revised wording).

Once approved, implementation steps will be applied exactly as specified above.