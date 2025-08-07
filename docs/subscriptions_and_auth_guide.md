# Subscriptions and Auth Guide (High-Level, OpenRouter-Aware)

Goal
Deliver a fast, low‑friction login and subscription experience where premium features are gated by feature flags AND the user’s premium status. OpenRouter remains a mandatory core service available to everyone through their own OpenRouter accounts. Premium initially gates Search Agents and must be extensible to more premium features in the future.

Key Principles
- OpenRouter for all: All models remain available to every user because they bring their own OpenRouter credentials. Core chat and model usage must never be blocked by premium.
- Premium gates features, not models: Premium only gates advanced in‑app capabilities such as Search Agents, automations, special toolchains, or increased in‑app quotas.
- Zero‑friction start: Use Firebase Anonymous Auth by default so users can start immediately. Offer Apple/Google/Email login later for sync across devices.
- Serverless subscriptions: Use RevenueCat for cross‑platform IAP, entitlement validation, restore purchases, and tester grants. No custom backend required.
- One source of truth for premium: A single selector computes isPremium = isTester OR hasEntitlement("premium"). Feature flags + isPremium control access.

Repository Components
- Feature flags: [lib/config/feature_flags.dart](lib/config/feature_flags.dart:1)
- Subscription config: [lib/config/subscriptions_config.dart](lib/config/subscriptions_config.dart:1)
- Tester whitelist: [lib/config/tester_whitelist.dart](lib/config/tester_whitelist.dart:1)
- Auth providers: [lib/providers/auth_provider.dart](lib/providers/auth_provider.dart:1), [lib/providers/firebase_auth_provider.dart](lib/providers/firebase_auth_provider.dart:1)
- Subscription provider (to be wired to RevenueCat): [lib/providers/subscription_provider.dart](lib/providers/subscription_provider.dart:1)
- App access / gating surface: [lib/providers/app_access_provider.dart](lib/providers/app_access_provider.dart:1)
- Paywall UI scaffold: [lib/screens/subscription/paywall_screen.dart](lib/screens/subscription/paywall_screen.dart:1)
- Router: [lib/router/app_router.dart](lib/router/app_router.dart:1)
- OpenRouter usage (reference): LLM/model services and model selection screens, e.g., [lib/services/llm_service.dart](lib/services/llm_service.dart:1), [lib/screens/model_selection_screen.dart](lib/screens/model_selection_screen.dart:1)

Architecture Overview

    OpenRouter (user-provided API access for all models)
                  |
                  v
           Core Chat + LLM Features  [ALWAYS AVAILABLE]
                  |
                  +-------------------------------+
                  |                               |
                  v                               v
    Firebase Auth (Anonymous + Providers)     RevenueCat Purchases
         AuthProvider (uid/email/stream)   (offerings, entitlements, restore)
                  |                               |
                  v                               v
              Tester Allowlist               Entitlement "premium"
                  |                               |
                  +--------------+----------------+
                                 v
                          Premium Selector
                  isPremium = isTester OR hasEntitlement
                                 |
                                 v
      Feature Gate = FeatureFlags.FLAG && isPremium (premium features only)
                                 |
                                 v
                 Premium-Only Features (e.g., Search Agents)

What Is Free vs Premium
- Free for all (via OpenRouter):
  - Connecting user’s OpenRouter account
  - Using any OpenRouter models the user has access to
  - Core chat and basic features powered by OpenRouter
- Premium (gated by feature flags + isPremium):
  - Search Agents (initial premium feature)
  - Future advanced features: autonomous pipelines, knowledge graph tools, advanced exports, bulk operations, etc.
  - Optional: in‑app resource limits (e.g., higher history, larger attachment sizes) can be made premium later

Two‑Tier Feature Flags: Industry Practice (Visibility vs Enablement)
Industry-standard approach in consumer apps (Notion, Slack, Arc, many games) uses two orthogonal controls:

1) Visibility Flag (show/hide)
- Purpose: Control whether a feature is even discoverable in UI (for unreleased, internal, or staged rollout).
- Recommended naming: FEATURE_X_VISIBLE
- Behavior:
  - false: do not render any entry points; feature is invisible
  - true: render entry points (menu item, button, card, teaser)

2) Enablement Gate (paywall/entitlement)
- Purpose: Control whether interactions perform the feature vs route to monetization/upgrade.
- Recommended naming: FEATURE_X_REQUIRES_PREMIUM or simply gate via premium selector
- Behavior when visible == true:
  - if isPremium: perform action normally
  - if !isPremium: intercept tap and show paywall (or a contextual premium explainer sheet)

Why two flags?
- Clean rollout phases: internal only -> visible to all as teaser -> fully enabled for premium -> later enable for all
- Marketing-friendly: you can tease a feature without enabling it
- Analytics-friendly: measure interest (impressions, taps) before enabling

Concrete Policy Matrix

- Visible=false, Premium=n/a
  - Not shown anywhere, for strict beta/internal or kill switch
- Visible=true, Premium=false
  - Shown and usable by all users
- Visible=true, Premium=true
  - Shown to all; usable only by premium/testers; non‑premium taps open paywall
- Visible=false, Premium=true
  - Typically used during internal testing or emergency off; keeps the experience consistent by hiding all entry points even for premium

Recommended Flags for Search Agents
- SEARCH_AGENTS_VISIBLE
- SEARCH_AGENTS_ENABLED (requires premium if enabled)
- Premium logic:
  - canUseSearchAgents = SEARCH_AGENTS_VISIBLE && SEARCH_AGENTS_ENABLED && isPremium
- Tap handling:
  - If SEARCH_AGENTS_VISIBLE && !isPremium && SEARCH_AGENTS_ENABLED: show paywall
  - If SEARCH_AGENTS_VISIBLE && (!SEARCH_AGENTS_ENABLED): either hide actions behind “Coming soon” teaser or disable with tooltip; do not show paywall because it’s not available yet

UX Patterns (Industry‑Standard)
- Disabled-but-visible control:
  - Use secondary text or badge “Premium” beside the feature name
  - On tap (if premium-gated and enabled): show paywall sheet
  - On tap (if not yet enabled overall): show a brief “Coming soon” sheet, optional join‑waitlist link
- Paywall entry consistency:
  - All premium-gated entry points should route to the same PaywallScreen with contextual copy
- Reduce friction:
  - Prefer bottom sheet paywalls over full-screen unless needed for legal copy
  - Preload offerings so pricing is instant
- Clear recoverability:
  - “Restore purchases” always available
- Teaser analytics:
  - Track impressions (feature visible) and intent taps (on disabled state) to inform rollout

OpenRouter Positioning (Explicit)
- OpenRouter connectivity and all models are available to everyone at all times
- The user supplies their own OpenRouter access; the app does not charge for model usage
- Premium never blocks model selection or chat; it only unlocks advanced, app‑level capabilities (e.g., Search Agents)
- Model Quick Switcher and any OpenRouter-dependent screens continue to function regardless of premium state

Operational Setup (No Code)

A) Firebase Console
- Enable Authentication providers:
  - Anonymous (required for zero friction)
  - Apple (iOS), Google, Email/Password (optional but recommended)
- Ensure [lib/firebase_options.dart](lib/firebase_options.dart:1) matches your project

B) RevenueCat Dashboard
- Create project; get Dev/Prod API keys
- Create “premium” entitlement
- Create products and an offering (e.g., default)
- Assign tester premium grants via dashboard for test accounts

C) App Stores
- Configure in‑app products in App Store Connect / Play Console matching RevenueCat
- Use test users for sandbox/internal testing

Implementation Guide (Code Pass Preview)
- Initialization:
  - Ensure Firebase initialized and anonymous sign‑in on startup
  - Initialize RevenueCat Purchases with the proper API key and identify with Firebase uid
- SubscriptionProvider:
  - Fetch offerings
  - Purchase a selected package
  - Observe entitlements (premium)
  - Restore purchases on demand and at startup
- Premium Selector:
  - Compute isTester from [lib/config/tester_whitelist.dart](lib/config/tester_whitelist.dart:1)
  - Compute hasEntitlement("premium") from SubscriptionProvider
  - Expose isPremium = isTester OR hasEntitlement
- Feature Flags:
  - Define SEARCH_AGENTS_VISIBLE and SEARCH_AGENTS_ENABLED in [lib/config/feature_flags.dart](lib/config/feature_flags.dart:1)
  - Apply gating:
    - showEntry = SEARCH_AGENTS_VISIBLE
    - canUse = SEARCH_AGENTS_VISIBLE && SEARCH_AGENTS_ENABLED && isPremium
- Tap Handling:
  - if (!SEARCH_AGENTS_VISIBLE): return; no UI
  - if (SEARCH_AGENTS_VISIBLE && !SEARCH_AGENTS_ENABLED): show “Coming soon” teaser (no paywall)
  - if (SEARCH_AGENTS_VISIBLE && SEARCH_AGENTS_ENABLED && !isPremium): show paywall
  - if (SEARCH_AGENTS_VISIBLE && SEARCH_AGENTS_ENABLED && isPremium): proceed to feature
- Paywall:
  - Present as a bottom sheet
  - Show offering, price, CTA, and restore button
  - Handle loading and common errors gracefully
- Settings:
  - Account section: show auth state, offer Apple/Google/Email sign‑in
  - Subscription section: show Manage Subscription and Restore Purchases

Scalability and Extensibility
- Add new premium features by:
  1) Defining FEATURE_VISIBLE and FEATURE_ENABLED flags in [lib/config/feature_flags.dart](lib/config/feature_flags.dart:1)
  2) Wrapping entry points with showEntry and canUse checks
  3) Showing either paywall (if enabled but not premium) or “Coming soon” (if not enabled)
- Optionally add Firebase Remote Config later for dynamic control over flags without shipping updates

Reliability and Edge Cases
- Cache last entitlements state and refresh on app resume
- Make restore idempotent and safe to retry
- Ensure anonymous→Apple/Google/Email re‑identifies RevenueCat correctly
- Prefer dashboard grants for testers in production; keep local whitelist minimal for dev

Next Steps (When we do the code pass)
- Wire RevenueCat in [lib/providers/subscription_provider.dart](lib/providers/subscription_provider.dart:1)
- Implement Premium selector (isTester OR entitlement)
- Add SEARCH_AGENTS_VISIBLE and SEARCH_AGENTS_ENABLED
- Apply the visibility/enablement tap handling across UI entry points
- Connect PaywallScreen to offerings/purchase/restore
- Ensure anonymous sign‑in on launch; add Settings entries for Restore and Manage Subscription

Defaults and Naming
- Entitlement: premium
- Offering: default (current)
- Auth: Anonymous + Apple/Google/Email enabled
- Flags: FEATURE_VISIBLE, FEATURE_ENABLED per feature (e.g., SEARCH_AGENTS_VISIBLE, SEARCH_AGENTS_ENABLED)

This document now follows industry practice: two-tier flags for discoverability and monetization, a single premium selector, and OpenRouter always available to all users.