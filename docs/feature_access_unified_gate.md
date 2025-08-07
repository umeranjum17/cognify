# Unified Feature Access Gate

Objective
- Eliminate confusion between frontend and backend gating by introducing a single, consistent helper API that combines:
  - Kill switch (feature discoverability and execution off)
  - Conditional rendering with teasers
  - Entitlement-based enablement for execution
- Make this reusable across both UI widgets and service/agent code.

Core Concepts
- Kill switch: If off, the feature is completely hidden and disabled across UI and backend.
- Conditional rendering: If discoverable, UI may show entry points (icons, buttons). Teaser states appear when the feature is visible but not enabled for the user (non-entitled).
- Entitlement-based enablement: If the user has entitlement and the feature is discoverable, execution is enabled. Otherwise: basic mode or upgrade prompt.

Proposed API Surface

1) FeatureAccess (single authority)
- Location: [dart.lib/services/premium_feature_gate.dart](lib/services/premium_feature_gate.dart:1)
- Responsibilities:
  - Centralized logic to answer “can show?” and “can execute?” for a feature name
  - Optional action guard for UI interactions
  - Context-aware variant for UI (uses providers) and context-free variant for backend (accepts entitlement boolean)

- Methods:
  - bool FeatureAccess.canShow(String featureName)
    - Uses FeatureFlags to determine kill switch (discoverability)
  - bool FeatureAccess.isEnabledForUser(BuildContext context, String featureName)
    - Returns true if canShow(featureName) is true AND the user is entitled via AppAccessProvider.hasPremiumAccess
  - bool FeatureAccess.isEnabled(bool isEntitled, String featureName)
    - Context-free backend use: same as above but accepts entitlement boolean (from SubscriptionProvider or auth layer)
  - Future<bool> FeatureAccess.guardAction(BuildContext context, String featureName, VoidCallback action)
    - Executes action if isEnabledForUser is true
    - Otherwise triggers paywall flow, returns false

2) Deprecate duplicate guard widget surface
- Keep [dart.lib/widgets/premium_guard.dart](lib/widgets/premium_guard.dart:20) as a thin wrapper that delegates to FeatureAccess:
  - PremiumGuard(featureName, child, fallback)
    - if !FeatureAccess.canShow(featureName): render SizedBox.shrink()
    - if FeatureAccess.isEnabledForUser(context, featureName): render child
    - else: render fallback teaser or a premium gate prompt

Behavior Matrix

- canShow = FeatureAccess.canShow('search_agents') based on kill switch:
  - Backed by FeatureFlags: SEARCH_AGENTS_VISIBLE for this feature
- isEnabledForUser (UI): canShow && user.isEntitled
- isEnabled (Backend): canShow && isEntitled (passed in)

States:
- Kill switch OFF:
  - UI: no icon/button rendered; no teaser
  - Backend: always basic plan (no advanced tools)
- Kill switch ON, user NOT entitled:
  - UI: render entry point + lock/upgrade behavior; teaser allowed
  - Backend: basic plan
- Kill switch ON, user entitled:
  - UI: render entry point; feature enabled
  - Backend: full plan (advanced tools allowed)

Where to apply

1) Editor Screen (globe icon)
- File: [dart._buildMainContent](lib/screens/editor_screen.dart:1113)
- Rendering:
  - Replace condition FeatureFlags.SEARCH_AGENTS_ENABLED with FeatureAccess.canShow('search_agents')
- Behavior:
  - On tap:
    - If FeatureAccess.isEnabledForUser(context, 'search_agents'): toggle online/offline
    - Else: open upgrade dialog [_showWebSearchUpgrade](lib/screens/editor_screen.dart:3876)
- Visuals:
  - Keep lock badge and tooltip for non-entitled state

2) SearchAgent backend planning
- File: [dart.SearchAgent.createExecutionPlan](lib/services/agents/search_agent.dart:27)
- Replace static flag check at [dart.search_agent.dart:37-39](lib/services/agents/search_agent.dart:37) with:
  - if (!FeatureAccess.isEnabled(isEntitled, 'search_agents')) return _createBasicPlan(...)
  - isEntitled is sourced from SubscriptionProvider/Auth layer and passed to SearchAgent or injected into the service that calls it

3) Premium widgets
- File: [dart.lib/widgets/premium_guard.dart](lib/widgets/premium_guard.dart:20)
- Modify to delegate to FeatureAccess:
  - Use FeatureAccess.canShow(featureName) for visibility
  - Use FeatureAccess.isEnabledForUser(context, featureName) for gating
  - Keep fallback/teaser and paywall behavior as is

FeatureFlags contract

- Keep FeatureFlags minimal and front-end oriented:
  - SEARCH_AGENTS_VISIBLE: true/false kill switch controlling discoverability in UI and participation in backend (through FeatureAccess.canShow)
  - SEARCH_AGENTS_ENABLED: deprecated as a static global. Runtime enablement now derives from entitlement via FeatureAccess.

Rationale

- One source of truth:
  - FeatureAccess encapsulates rules for both UI and backend
  - FeatureFlags remain a thin config for killswitches and discoverability
- No confusion over ENABLED semantics:
  - Remove static ENABLED dependency in backend planning
  - Runtime enablement uses entitlement consistently

Migration Plan

- Step 1: Implement FeatureAccess helpers in premium_feature_gate.dart
  - canShow(featureName) -> reads FeatureFlags
  - isEnabledForUser(context, featureName) -> uses AppAccessProvider
  - isEnabled(isEntitled, featureName) -> for backend
  - guardAction(context, featureName, action) -> for UI events

- Step 2: Update PremiumGuard widget to delegate to FeatureAccess
  - Keeps API stable for existing UI code

- Step 3: Update EditorScreen globe logic
  - Render when FeatureAccess.canShow('search_agents')
  - Tap uses FeatureAccess.isEnabledForUser(context, 'search_agents')

- Step 4: Update SearchAgent
  - Replace static FeatureFlags.SEARCH_AGENTS_ENABLED check with FeatureAccess.isEnabled(isEntitled, 'search_agents')
  - Accept isEntitled parameter in createExecutionPlan call chain or inject via service

Test Plan

- Kill switch OFF:
  - Set SEARCH_AGENTS_VISIBLE=false
  - Globe icon hidden, backend returns basic plan regardless of entitlement

- Kill switch ON, non-entitled:
  - Globe visible with lock badge; tapping opens upgrade dialog
  - Backend returns basic plan

- Kill switch ON, entitled:
  - Globe visible; tap toggles online/offline visuals
  - Backend produces full plan with search tools enabled

- Regression checks:
  - Other premium features that still use PremiumGuard continue to work since it delegates to FeatureAccess
  - No runtime errors if providers are unavailable in backend paths (backend uses isEnabled(bool, featureName))

Mermaid overview

flowchart TD
  A[FeatureFlags.SEARCH_AGENTS_VISIBLE] -->|false| Z[Hide UI and force basic backend]
  A -->|true| B{User Entitled?}
  B -->|No| C[UI: Teaser/Lock, Upgrade Prompt]
  C --> D[Backend: Basic Plan]
  B -->|Yes| E[UI: Enabled; Toggle Online/Offline]
  E --> F[Backend: Full Plan]

Next steps request
- Approve this unified helper approach. After approval, I will:
  1) Add FeatureAccess helpers to [dart.lib/services/premium_feature_gate.dart](lib/services/premium_feature_gate.dart:1)
  2) Update [dart.lib/widgets/premium_guard.dart](lib/widgets/premium_guard.dart:20) to delegate
  3) Change EditorScreen globe render/tap logic
  4) Change SearchAgent to use the backend helper