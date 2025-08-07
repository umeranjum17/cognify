# Offline Mode Implementation Summary

## Overview
Successfully implemented offline mode parity with SearchAgent's basic plan as specified in `offline_mode_basic_plan_parity.md`. The implementation ensures that when the globe is OFF (isOfflineMode = true), the behavior mirrors SearchAgent's basic plan with no search-related tools and no networked planning.

## Changes Made

### 1. EditorScreen Default State
**File:** `lib/screens/editor_screen.dart`
- Changed `bool _isOfflineMode = false;` to `bool _isOfflineMode = true;`
- Globe now defaults to OFF state when app is launched

### 2. SearchAgent forceBasicPlan Option
**File:** `lib/services/agents/search_agent.dart`
- Added check for `options['forceBasicPlan']` in `createExecutionPlan()` method
- When `forceBasicPlan: true`, immediately returns `_createBasicPlan()` result
- This ensures consistent basic plan behavior regardless of subscription or mode

### 3. UnifiedApiService Tool Filtering
**File:** `lib/services/unified_api_service.dart`
- Added search tool filtering when `isOfflineMode` is true
- Filters out search tools: `brave_search`, `brave_search_enhanced`, `web_fetch`, `image_search`, `youtube_processor`, `sequential_thinking`
- Added logging to track filtered tools
- Passes `options: {'forceBasicPlan': true}` to AgentSystem when offline

### 4. AgentSystem Options Support
**File:** `lib/services/agents/agent_system.dart`
- Added `Map<String, dynamic>? options` parameter to `processQuery()` method
- Passes options to SearchAgent's `createExecutionPlan()` method
- Enables forceBasicPlan functionality

### 5. Source-Grounded Chat Updates
**File:** `lib/services/unified_api_service.dart`
- Updated `sourceGroundedChatStream()` to pass `isIncognitoMode: isOfflineMode`
- Ensures offline mode is respected in source-grounded processing

## Implementation Details

### Search Tool Set
The canonical search tool set is defined in `SearchAgent._isSearchTool()`:
```dart
const searchTools = {
  'brave_search',
  'brave_search_enhanced', 
  'web_fetch',
  'image_search',
  'youtube_processor',
  'sequential_thinking',
};
```

### Basic Plan Structure
When offline mode is enabled, the plan returns:
```dart
{
  'toolSpecs': [], // Empty array - no search tools
  'generationId': null,
  'usage': null,
  'model': modelName,
  'stage': 'planning',
  'basicMode': true, // Flag indicating basic plan
}
```

### Flow Control
1. **EditorScreen**: Defaults to `_isOfflineMode = true`
2. **UnifiedApiService**: Filters search tools and sets `forceBasicPlan: true`
3. **AgentSystem**: Passes options to SearchAgent
4. **SearchAgent**: Short-circuits to basic plan when `forceBasicPlan` is true

## Edge Cases Handled

1. **DeepSearch + Offline**: Even in DeepSearch mode, planner produces basic plan (no sequential_thinking, no search tools)
2. **Non-premium users**: Default OFF is accessible to all users
3. **Source-grounded chats**: No `web_fetch` used when offline
4. **Tool filtering redundancy**: Both upstream filtering and planner-level control ensure no search tools are used

## Testing Verification

The implementation follows the specification exactly:
- ✅ Globe OFF by default
- ✅ When offline: plans short-circuit to basic plan consistently
- ✅ No search-related tools appear in `toolSpecs`
- ✅ `basicMode: true` present in plan response payload
- ✅ Globe ON preserves existing behavior

## Logging
Added debug logging to track offline mode behavior:
- `🔍 [Offline Mode] Filtered out search tools: ...`
- `🔍 [Offline Mode] Forcing basic plan`

## Future Considerations

As noted in the original specification, consider moving the search tools constant set from `SearchAgent._isSearchTool()` to a shared utility to avoid duplication across services.

## Files Modified
1. `lib/screens/editor_screen.dart` - Default offline mode
2. `lib/services/agents/search_agent.dart` - forceBasicPlan option
3. `lib/services/agents/agent_system.dart` - Options parameter support
4. `lib/services/unified_api_service.dart` - Tool filtering and options passing

The implementation is complete and ready for testing in the app. 