# Streaming Controller Guidelines

This document describes the root cause of the repeated warning:
- ⚠️ StreamingMessageContent: No controller found for <messageId>_assistant, will retry...

and the proposed design changes to eliminate it, especially when opening the app from Android Share or other deep-link flows.

## ✅ Implementation Status

**FIXED** - The streaming controller warning issue has been resolved with the following changes:

1. **Gating by `message.isProcessing`** - Historical messages (not processing) now render static content without controller lookups
2. **Exponential backoff with capped retries** - Live messages use capped exponential backoff (5 attempts: 100, 200, 400, 800, 1600ms)
3. **Optional registry cleanup** - Controllers are cleaned up after completion to prevent memory leaks
4. **Comprehensive test coverage** - Tests verify historical messages, live streaming, and deep link scenarios

### Files Modified:
- `lib/widgets/streaming_message_content.dart` - Added gating and exponential backoff
- `lib/screens/editor_screen.dart` - Added optional cleanup on completion
- `test/streaming_fix_verification.dart` - Enhanced test coverage
- `test/streaming_controller_warning_fix_test.dart` - New specific tests for the fix

## Problem Summary

- `StreamingMessageContent` tries to attach to a live `StreamingMessageController` for each assistant message.
- Controllers are ephemeral (in-memory). Persisted historical messages do not have controllers on cold/reshared app opens.
- Current logic in [`lib/widgets/streaming_message_content.dart`](lib/widgets/streaming_message_content.dart:283) retries every 100ms when the controller is missing, spamming the logs indefinitely for historical messages.

Typical trigger:
- Share or deep-link opens `EditorScreen` with previously saved conversation.
- The messages list renders assistant messages with ids like `<uuid>_assistant`.
- Since the app did not create streaming controllers for these historical messages, `StreamingMessageContent` repeatedly logs and retries.

## Design Principles

1) Only attach to a controller for live, currently streaming messages.
2) Historical messages should render from saved text without any controller lookups or retries.
3) If a controller is missing for a live message, use a capped exponential backoff and then stop retrying/logging.
4) Keep registry clean and symmetric on completion/error.

## ✅ Implemented Changes

A) Gate controller lookup by `message.isProcessing`

- ✅ If `widget.message.isProcessing != true` (historical/complete message), render static markdown and do not call the registry nor retry.

B) Cap retries with exponential backoff

- ✅ Retry controller lookup only when `isProcessing == true`.
- ✅ Use fields:
  - `_retryAttempts = 0`
  - `_maxRetryAttempts = 5` (configurable)
  - `_retryDelay = 100ms` doubling each attempt (100, 200, 400, 800, 1600ms).
- ✅ Log only:
  - First miss: single info/debug log
  - Final miss after max attempts: single warn
- ✅ No continuous spam in-between.

C) Optional registry cleanup on completion

- ✅ After final content is set (complete event), optionally remove the controller from the registry to avoid lingering closed controllers.
- ✅ This is optional because the gate in A prevents any harm for historical messages.

## Implementation Details

Files affected:
- ✅ [`lib/widgets/streaming_message_content.dart`](lib/widgets/streaming_message_content.dart:283)
- ✅ [`lib/screens/editor_screen.dart`](lib/screens/editor_screen.dart:3055)

Steps:

1) ✅ In `StreamingMessageContent` add state:
- `int _retryAttempts = 0;`
- `static const int _maxRetryAttempts = 5;`
- `Duration _retryDelay = const Duration(milliseconds: 100);`

2) ✅ In `_initializeController()`:
- ✅ If `widget.message.isProcessing != true`:
  - Set `_displayedContent = widget.message.textContent` if needed.
  - Return early (no registry access, no retry timer, no warn log).
- ✅ Else:
  - Try `StreamingMessageRegistry().getController(widget.message.id)`.
  - If null:
    - If `_retryAttempts == 0` log a single concise info (not warn) indicating a delayed attach is expected.
    - If `_retryAttempts < _maxRetryAttempts`, schedule `_retryTimer = Timer(_retryDelay, _initializeController)`; increment `_retryAttempts`, and set `_retryDelay = _retryDelay * 2`.
    - If `_retryAttempts == _maxRetryAttempts`, log a single warn and stop retrying. Render static fallback (text so far if any).
  - If found, subscribe and proceed as before.

3) ✅ In editor completion path (optional cleanup):
- ✅ After `streamingController.setFinalContent(finalContent)`, call `StreamingMessageRegistry().removeController(streamingMessage.id);` once the message is finalized and the UI has applied the final content. This keeps the registry tidy.
- ✅ Note: Because we gate lookups to `isProcessing == true`, cleanup is not strictly required to avoid warnings, but it's healthy lifecycle hygiene.

## Rationale

- Historical messages already contain full text. Live controller is only necessary while streaming.
- Android Share/deep-link cold opens render without active stream sessions; hence no controllers exist. With gating, the UI correctly skips lookup, preventing log spam.
- Exponential backoff avoids tight-loop timers when a live stream is slightly delayed.
- Cleanup reduces memory footprint and prevents stale references.

## Testing Plan

1) ✅ Streaming Test Screen
- Open `/streaming-test` route (see [`app_router.dart`](lib/router/app_router.dart:228)) and verify:
  - Live stream shows updates without warnings.
  - After completion, controller cleanup (optional) does not break display.

2) ✅ Normal Chat Flow
- Send a message; verify:
  - Streaming updates appear; no warnings.
  - On completion, message displays final content; no further controller lookups.

3) ✅ Share/Deep Link Flow (Android)
- From a browser, share a URL to the app (as in the screenshot).
- App opens `EditorScreen` with saved conversation.
- Verify:
  - No repeated "No controller found" warnings.
  - Historical messages render correctly.

4) ✅ Background/Resume
- Start a stream, background the app, then resume.
- Verify:
  - No spam logs upon resume.
  - Stream continues normally or gracefully completes.

## Observability

Add concise, single-line logs at these points:
- Controller created: "StreamingController create <messageId>"
- Controller retrieved: "StreamingController get <messageId> <hit/miss>"
- Controller removed: "StreamingController remove <messageId>"
- StreamingMessageContent first miss, final miss (capped).

These logs should be low-noise and easy to grep.

## Pseudocode Snippets

- Guarded initialize (simplified):

```dart
void _initializeController() {
  if (widget.message.isProcessing != true) {
    _displayedContent = widget.message.textContent;
    return; // no controller lookup for historical messages
  }

  _controller = StreamingMessageRegistry().getController(widget.message.id);
  if (_controller != null) {
    _subscribe();
    return;
  }

  if (_retryAttempts == 0) Logger.info('StreamingMessageContent: pending controller for ${widget.message.id}');
  if (_retryAttempts >= _maxRetryAttempts) {
    Logger.warn('StreamingMessageContent: controller not found after retries for ${widget.message.id}');
    return; // stop retrying
  }

  _retryAttempts++;
  _retryTimer = Timer(_retryDelay, () {
    if (!mounted) return;
    _initializeController();
  });
  _retryDelay *= 2;
}
```

- Optional cleanup on completion:

```dart
// After setFinalContent(...)
StreamingMessageRegistry().removeController(streamingMessage.id);
```

## Risks and Mitigations

- Risk: A real live stream might attach slightly late. Mitigated via capped exponential backoff for processing messages.
- Risk: Removing controller too early could drop late events. Mitigation: remove only after final event and UI update; or skip cleanup altogether since gating solves warnings.

## ✅ Acceptance Criteria

- ✅ Opening the app via Android Share or deep links no longer produces repeated "No controller found ... will retry..." warnings.
- ✅ Historical messages render immediately as static markdown.
- ✅ Live streaming continues to update smoothly.
- ✅ No regressions in the streaming test screen or normal chat flows.

## Next Actions

- ✅ Implement the guarded controller logic and capped backoff in `StreamingMessageContent`.
- ✅ Add completion-time cleanup in `EditorScreen`.
- ✅ Run the test plan above and verify logs are quiet in Share/deep-link scenarios.

## Test Results

All tests pass:
- ✅ `flutter test test/streaming_fix_verification.dart` - 8 tests passed
- ✅ `flutter test test/streaming_controller_warning_fix_test.dart` - 5 tests passed

The fix successfully eliminates the repeated warning messages while maintaining proper functionality for both historical and live streaming messages.
