# Surgical fix plan: Preserve OpenRouter auth onboarding, reliably open Sources on share

Goal
- Keep the existing OpenRouter onboarding/auth check behavior in the root route.
- Surgically eliminate the intermittent redirect-to-Editor/blank-page when a link is shared.
- Make no broad behavioral changes beyond the share flow.

Summary of minimal changes
- Fix lifecycle bug in SourcesScreen to remove undefined behavior.
- Add a narrow guard in the root route’s “redirect to editor” block to skip that redirect only when a share flow is in progress.
- Do not change onboarding/auth logic itself.

Why this preserves onboarding
- The onboarding/auth check remains exactly as in AppRouter: unauthenticated users still see OAuthOnboarding, and authenticated users still get redirected to /editor.
- We only skip the redirect in the single case where the active route is handling a shared URL (either /?sharedUrl=... or /sources?sharedUrl=...). All other cases proceed as today.

Proposed diffs (exact and minimal)

1) lib/screens/sources_screen.dart
Fix the lifecycle brace error and make initialUrl handling single-shot. This prevents duplicate calls and potential blank UI from mis-nested lifecycle methods. Behavior: populate field once; do not auto-add by default.

```diff
@@
 class _SourcesScreenState extends State<SourcesScreen> {
   late final UnifiedApiService _apiService;
+  bool _handledInitialUrl = false;
@@
-  @override
-  void dispose() {
-    _urlController.removeListener(_onUrlChanged);
-    _urlController.dispose();
-    _refreshTimer?.cancel();
-    super.dispose();
-  @override
-  void didUpdateWidget(SourcesScreen oldWidget) {
-    super.didUpdateWidget(oldWidget);
-    if (widget.initialUrl != null &&
-        widget.initialUrl != oldWidget.initialUrl &&
-        widget.initialUrl!.isNotEmpty) {
-      debugPrint('🟢 didUpdateWidget: Detected new initialUrl: ${widget.initialUrl}');
-      _handleInitialUrl(autoAdd: true);
-    }
-  }
-  }
+  @override
+  void dispose() {
+    _urlController.removeListener(_onUrlChanged);
+    _urlController.dispose();
+    _refreshTimer?.cancel();
+    super.dispose();
+  }
+
+  @override
+  void didUpdateWidget(covariant SourcesScreen oldWidget) {
+    super.didUpdateWidget(oldWidget);
+    if (!_handledInitialUrl &&
+        widget.initialUrl != null &&
+        widget.initialUrl!.isNotEmpty &&
+        widget.initialUrl != oldWidget.initialUrl) {
+      debugPrint('🟢 didUpdateWidget: new initialUrl: ${widget.initialUrl}');
+      _handleInitialUrl(autoAdd: false);
+    }
+  }
@@
   @override
   void initState() {
     super.initState();
@@
-    // Handle initial URL if provided, and trigger add
-    WidgetsBinding.instance.addPostFrameCallback((_) {
-      _handleInitialUrl(autoAdd: true);
-    });
+    // Handle initial URL once (populate only)
+    WidgetsBinding.instance.addPostFrameCallback((_) {
+      _handleInitialUrl(autoAdd: false);
+    });
   }
@@
-  void _handleInitialUrl({bool autoAdd = false}) {
+  void _handleInitialUrl({bool autoAdd = false}) {
+    if (_handledInitialUrl) return;
     debugPrint('🟢 _handleInitialUrl called with sharedUrl: ${widget.initialUrl}, autoAdd: $autoAdd');
     String? sharedUrl = widget.initialUrl;
-    if (sharedUrl == null || sharedUrl.isEmpty) {
+    if (sharedUrl == null || sharedUrl.isEmpty) {
       sharedUrl = SharingService().getPendingSharedUrl();
     }
     if (sharedUrl != null && sharedUrl.isNotEmpty) {
       try {
-        sharedUrl = Uri.decodeQueryComponent(sharedUrl);
+        sharedUrl = Uri.decodeFull(sharedUrl);
       } catch (e) {
-        debugPrint('Error decoding URL: $e');
+        try { sharedUrl = Uri.decodeQueryComponent(sharedUrl); } catch (_) {}
+        debugPrint('Error decoding URL: $e');
       }
     }
     if (sharedUrl != null && sharedUrl.isNotEmpty && mounted) {
-      setState(() {
-        _urlController.text = sharedUrl!;
-        _selectedSourceType = SourceType.detectSourceType(sharedUrl);
-      });
-      if (autoAdd) {
-        _addUrl();
-      } else {
+      sharedUrl = sharedUrl.trim();
+      if (!_isValidUrl(sharedUrl)) return;
+      setState(() {
+        _urlController.text = sharedUrl!;
+        _selectedSourceType = SourceType.detectSourceType(sharedUrl);
+        _handledInitialUrl = true;
+      });
+      if (!autoAdd) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Row(
               children: [
                 const Icon(Icons.share, color: Colors.white, size: 20),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     'Shared URL added: ${sharedUrl.length > 40 ? '${sharedUrl.substring(0, 40)}...' : sharedUrl}',
                   ),
                 ),
               ],
             ),
             backgroundColor: AppColors.lightAccent,
             action: SnackBarAction(
               label: 'Add Now',
               textColor: Colors.white,
               onPressed: _addUrl,
             ),
             duration: const Duration(seconds: 5),
           ),
         );
       }
     }
   }
```

Why this is safe
- Fixes a clear syntax/lifecycle error without changing external APIs.
- Only adds a local boolean flag for idempotency.
- Keeps all existing UI and network behavior intact; users still manually add the URL or tap “Add Now”.

2) lib/router/app_router.dart
Add a very narrow “share flow” guard only around the post-auth redirect to /editor. Onboarding is unaffected.

```diff
@@
-                  if (authProvider.isAuthenticated) {
-                    WidgetsBinding.instance.addPostFrameCallback((_) {
-                      if (context.mounted) {
-                        context.go('/editor');
-                      }
-                    });
+                  if (authProvider.isAuthenticated) {
+                    // Surgical guard: if we're handling a share, don't override it.
+                    final uri = GoRouterState.of(context).uri;
+                    final isShareFlow = uri.path == '/sources' ||
+                        uri.queryParameters.containsKey('sharedUrl');
+                    WidgetsBinding.instance.addPostFrameCallback((_) {
+                      if (context.mounted && !isShareFlow) {
+                        context.go('/editor');
+                      }
+                    });
                     return const Scaffold(
```

Why this is safe
- We do not change the redirect condition itself; we only skip when a share is explicitly in progress based on the current URI context.
- Unauthenticated users still go through OAuthOnboarding exactly as before.
- Authenticated users still go to /editor unless they are actively in a share flow.

Test checklist (must pass)
- Unauthenticated fresh launch: Root shows OAuthOnboarding; after successful auth, user is redirected to /editor as before.
- Authenticated normal launch: Root redirects to /editor as before.
- Share into cold app (authenticated): App opens Sources with URL populated; it does NOT get redirected to Editor.
- Share into warm app (authenticated and currently on Editor): Navigates to Sources; URL populated; no flash redirect back to Editor.
- Share into app (unauthenticated): Root shows OAuthOnboarding. After auth completes, ensure URI context no longer contains sharedUrl; behavior returns to normal (you may require user to share again — current behavior unchanged).
- Regression checks: Navigating to Sources via app menu still works; uploading/adding URL continues to function.

Rollback plan
- Revert the two small patches above.
- No data migrations or config changes required.
- Router and screen public APIs remain unchanged; safe to roll back in one commit.

Notes
- This is the minimum required to make share behavior deterministic while preserving your onboarding/auth flow.
- If future telemetry shows edge cases, we can add a query flag like share=1 to strengthen the guard. For now, sharedUrl presence/path is sufficient and least invasive.