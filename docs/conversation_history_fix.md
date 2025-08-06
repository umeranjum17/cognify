# Conversation History: Selected Chat Not Repopulating

Issue
- Tapping a conversation in ConversationHistoryScreen navigates to EditorScreen but does not repopulate that conversation. It appears as a new chat.

Root cause
- Router correctly passes the conversationId via query params into EditorScreen(conversationId: ...). See [lib/router/app_router.dart](lib/router/app_router.dart:181).
- EditorScreen sets _currentConversationId in initState but does not call _loadConversation() when the id comes from the route. It only loads when SharedPreferences key editorInitialData exists. Therefore, navigating from history does not trigger load.

Fix overview
- Trigger _loadConversation() in EditorScreen when a route-provided conversationId is present.
- Add didUpdateWidget to handle route changes while the screen is mounted (e.g., pushReplacement/go to another conversation id).
- Guard _loadInitialData to avoid overriding or double-loading if both route and prefs provide the same id.
- No change required in ConversationHistoryScreen or AppRouter.

Implementation details

1) EditorScreen: load on route-provided conversationId in initState
- After assigning _currentConversationId from widget.conversationId, schedule _loadConversation() using a post-frame callback to ensure context and services are ready.

[lib/screens/editor_screen.dart:254]
if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _loadConversation();
  });
}

2) EditorScreen: handle conversationId changes on the same widget
- If /editor is re-used with a different conversationId (via go/pushReplacement), reload the conversation.

[lib/screens/editor_screen.dart:216]
@override
void didUpdateWidget(covariant EditorScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  final newId = widget.conversationId;
  if (newId != null && newId.isNotEmpty && newId != oldWidget.conversationId) {
    setState(() {
      _currentConversationId = newId;
    });
    _loadConversation();
  }
}

3) EditorScreen: prevent double-load or override from _loadInitialData
- When editorInitialData contains conversationId, only load if it is different from the current _currentConversationId (set from route). This preserves route-driven behavior and avoids duplicate loads.

[lib/screens/editor_screen.dart:2390]
if (initialData['conversationId'] != null) {
  final prefsConvId = initialData['conversationId'] as String;
  // If a route provided the same id, skip duplicate load
  if (_currentConversationId != null && _currentConversationId == prefsConvId) {
    // No-op
  } else {
    _currentConversationId = prefsConvId;
    await _loadConversation();
  }
}

No changes needed elsewhere
- ConversationHistoryScreen already navigates with the correct query param:
  - [lib/screens/conversation_history_screen.dart:382] context.push('/editor?conversationId=${conversation.id}');
- Router already maps the query param into EditorScreen:
  - [lib/router/app_router.dart:181] conversationId = state.uri.queryParameters['conversationId'];

Test plan

A) History navigation
- Precondition: Saved conversations exist.
- Action: Go to /history, tap any conversation.
- Expect: EditorScreen shows that conversation’s messages, title, and costs. No "New Conversation" state.

B) New chat
- Action: Start a new chat from EditorScreen’s New Chat.
- Expect: Fresh _currentConversationId generated; no messages carried over.

C) Deep link
- Action: Navigate directly to /editor?conversationId=existing-id.
- Expect: Conversation is loaded on first frame.

D) Route replacement (robustness)
- Action: While on EditorScreen, navigate to /editor?conversationId=another-id via go/pushReplacement.
- Expect: didUpdateWidget reloads new conversation.

Notes
- The post-frame callback avoids race conditions with service initialization.
- The guard in _loadInitialData prevents duplicate loads if both route and prefs supply the same id.
- The changes are minimal and keep current navigation flow intact.
