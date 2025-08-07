# Offline Mode Parity with SearchAgent Basic Plan and Default Globe Off

Clickable references:
- SearchAgent class: [`dart.class SearchAgent`](lib/services/agents/search_agent.dart:10)
- _createBasicPlan: [`dart.method _createBasicPlan()`](lib/services/agents/search_agent.dart:442)
- _isSearchTool: [`dart.method _isSearchTool()`](lib/services/agents/search_agent.dart:460)
- EditorScreen class: [`dart.class EditorScreen`](lib/screens/editor_screen.dart:56)
- _sendMessage: [`dart.method _sendMessage()`](lib/screens/editor_screen.dart:2756)

## Objective
- When the globe is OFF (isOfflineMode = true), behavior must mirror SearchAgent’s basic plan: no search-related tools and no networked planning. Return a basic plan identical to [`dart.method _createBasicPlan()`](lib/services/agents/search_agent.dart:442).
- Default the globe to OFF in [`dart.class EditorScreen`](lib/screens/editor_screen.dart:56).

## Current Behavior Summary
- [`dart.class EditorScreen`](lib/screens/editor_screen.dart:56) maintains `bool _isOfflineMode = false;` by default and toggles via globe icon in the input controls. It forwards `isOfflineMode` into `UnifiedApiService.streamChat` and `UnifiedApiService.sourceGroundedChatStream` within [`dart.method _sendMessage()`](lib/screens/editor_screen.dart:2756).
- [`dart.class SearchAgent`](lib/services/agents/search_agent.dart:10) returns a "basic plan" when the feature flag `search_agents` is disabled in [`dart.method createExecutionPlan()`](lib/services/agents/search_agent.dart:27):
  - [`dart.method _createBasicPlan()`](lib/services/agents/search_agent.dart:442) returns:
    - `toolSpecs: []`
    - `basicMode: true`
    - no search tools executed
  - Search tools are defined by [`dart.method _isSearchTool()`](lib/services/agents/search_agent.dart:460):
    - brave_search, brave_search_enhanced, web_fetch, image_search, youtube_processor, sequential_thinking

## Requirements Mapping
- Offline mode parity: When `_isOfflineMode == true`, we must force the planner path to behave like [`dart.method _createBasicPlan()`](lib/services/agents/search_agent.dart:442), regardless of subscription or mode (Chat or DeepSearch).
- Default globe OFF: Initialize `_isOfflineMode = true` in [`dart.class EditorScreen`](lib/screens/editor_screen.dart:56).

## Design Decisions
1) Single Source of Truth for Search Tool Set
- Keep the canonical search-tool predicate in [`dart.method _isSearchTool()`](lib/services/agents/search_agent.dart:460).
- Avoid drift by either:
  - referencing SearchAgent’s predicate; or
  - extracting the set into a shared utility later (optional).

2) Forcing Basic Plan When Offline
- Introduce a soft control from callers: pass `options: { forceBasicPlan: true }` when offline into [`dart.method createExecutionPlan()`](lib/services/agents/search_agent.dart:27).
- Update [`dart.method createExecutionPlan()`](lib/services/agents/search_agent.dart:27) to short-circuit at the top if `options?.['forceBasicPlan'] == true`, returning [`dart.method _createBasicPlan()`](lib/services/agents/search_agent.dart:442).
- Additionally, filter `enabledTools` upstream (e.g., in UnifiedApiService) to remove search tools when offline. This provides redundancy and prevents accidental tool use outside planner scope.

3) Default Globe OFF
- Change initial state to `_isOfflineMode = true` in [`dart.class EditorScreen`](lib/screens/editor_screen.dart:56). The UI tooltip already reflects offline state: Offline Mode (No Internet Tools).

## Implementation Steps
1) EditorScreen default OFF
- In [`dart.class EditorScreen`](lib/screens/editor_screen.dart:56), change:
  - `bool _isOfflineMode = false;` ➜ `bool _isOfflineMode = true;`

2) SearchAgent: forceBasicPlan option
- In [`dart.method createExecutionPlan()`](lib/services/agents/search_agent.dart:27), add at the top after try begins:
  - If `options != null && options['forceBasicPlan'] == true`, return [`dart.method _createBasicPlan()`](lib/services/agents/search_agent.dart:442) with current args.

3) Upstream filtering (UnifiedApiService)
- Before calling [`dart.method createExecutionPlan()`](lib/services/agents/search_agent.dart:27), if `isOfflineMode == true`:
  - Remove search tools from `enabledTools` using the same set as [`dart.method _isSearchTool()`](lib/services/agents/search_agent.dart:460).
  - Pass `options: { 'forceBasicPlan': true }` into SearchAgent.
- Note: UnifiedApiService is not shown here; implement where the agent pipeline constructs planning calls.

## Edge Cases
- DeepSearch + Offline: Even in DeepSearch, planner must produce basic plan (no sequential_thinking, no search). The forceBasicPlan and tool filtering ensures this.
- Non-premium users: Default OFF is accessible. Turning ON follows existing premium gating logic.
- Source-grounded chats: With offline, no `web_fetch` should be used; ensure upstream filtering applies across source-grounded calls too.

## Testing Checklist
- With app freshly launched:
  - Globe shows OFF visual state; `_isOfflineMode` true in [`dart.class EditorScreen`](lib/screens/editor_screen.dart:56).
- Send a prompt with globe OFF:
  - Planner returns `{ toolSpecs: [], basicMode: true, ... }`.
  - No search tool calls made; no web sources/images appear due to search.
- Toggle globe ON (with access):
  - Planner behaves as before, including search tools if enabled and applicable.
- DeepSearch with globe OFF:
  - Still returns basic plan (no `sequential_thinking`, no `brave_search*`, `web_fetch`, `image_search`, `youtube_processor`).

## Mermaid Overview
flowchart TD
  A[EditorScreen: _isOfflineMode = true (default)] --> B[User sends message]
  B --> C[UnifiedApiService prepares enabledTools]
  C -->|offline| D[Filter out search tools]
  D --> E[SearchAgent.createExecutionPlan options.forceBasicPlan = true]
  E --> F[_createBasicPlan(): toolSpecs [], basicMode true]
  F --> G[Executor runs no search tools]
  G --> H[Assistant response without web/search integrations]

## Acceptance Criteria
- Globe OFF by default.
- When offline:
  - Plans short-circuit to basic plan consistently.
  - No search-related tools appear in `toolSpecs`.
  - `basicMode: true` present in the plan response payload.
- Globe ON preserves existing behavior.

## Notes for Future Refactor
- Consider moving the `search tools` constant set from [`dart.method _isSearchTool()`](lib/services/agents/search_agent.dart:460) to a shared constants/utility to avoid duplication across services.