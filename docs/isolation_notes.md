# Fix: Hive initialization errors when running tools in Dart isolates

Problem summary
When executing tools in background isolates, code paths indirectly touched Hive (via AppConfig/DatabaseService). Hive is not initialized in worker isolates, so any attempt to access it throws a HiveError (e.g., "Hive not initialized" or box access errors).

This happened because:
- Tools were spawned in an isolate and then invoked using a new ToolsManager instance in the isolate entrypoint: [`_toolExecutionIsolate()`](lib/services/agents/executor_engine.dart:12).
- Brave search tools called BraveSearchService which fetched the API key via AppConfig (which uses DatabaseService, backed by Hive).
- AppConfig/DatabaseService access in the isolate triggered Hive usage without re-init.

Design decision
Avoid Hive (and AppConfig/DatabaseService) access inside worker isolates. Instead, inject all required runtime values from the main isolate into the isolate's tool input. This keeps isolates pure and avoids having to initialize Hive or open boxes in each isolate.

Changes implemented

1) BraveSearchService: added optional apiKey parameters and prefer them over AppConfig
- Methods updated to accept apiKey and use it instead of hitting AppConfig when provided:
  - [`BraveSearchService.isAvailable()`](lib/services/brave_search_service.dart:55-63)
  - [`BraveSearchService.search()`](lib/services/brave_search_service.dart:67-97)
  - [`BraveSearchService.searchImages()`](lib/services/brave_search_service.dart:140-169)
  - [`BraveSearchService.searchWeb()`](lib/services/brave_search_service.dart:219-248)
- Behavior: If an apiKey is passed, no AppConfig (Hive) access occurs; otherwise, fallback to AppConfig for main-isolate usage.

2) ExecutorEngine: inject Brave API key into messages before isolate spawn for search tools
- When building ToolExecutionMessage for search tools, inject the Brave key (from main isolate) so isolates don't call AppConfig:
  - [`executeTools()` search message construction](lib/services/agents/executor_engine.dart:232-238) now adds:
    - 'braveApiKey': await AppConfig().braveSearchApiKey ?? 'BSA6Crcr3bFuvfEOIgHdL-y7IO_YPqr'
  - Import added:
    - [`import '../../config/app_config.dart';`](lib/services/agents/executor_engine.dart:10-13)

3) Tools: pass the apiKey through to BraveSearchService
- BraveSearch and image tools now pass the injected key down to the service:
  - [`BraveSearchEnhancedTool.invoke()`](lib/services/tools.dart:25-58) calls `search(query, count: count, apiKey: input['apiKey'] ?? input['braveApiKey'])`
  - [`BraveSearchTool.invoke()`](lib/services/tools.dart:77-107) calls `search(..., apiKey: ...)`
  - [`ImageSearchTool.invoke()`](lib/services/tools.dart:184-216) calls `searchImages(..., apiKey: ...)`

Why this resolves the error
- AppConfig and DatabaseService (Hive-backed) are only used on the main isolate.
- Worker isolates receive the needed apiKey as plain input and use it directly.
- No Hive initialization is required inside isolates, preventing HiveError crashes.

Validation checklist
1) Run a plan that uses brave_search or brave_search_enhanced:
   - Expect isolates to start and complete without Hive errors.
   - Logs should show ToolExecutionMessage includes &#34;braveApiKey&#34;, and BraveSearchService uses the provided key.

2) Run image_search:
   - Similar expectations as above; verify `searchImages` receives apiKey and completes.

3) Ensure other isolate-executed tools don't call AppConfig/DatabaseService directly:
   - If a tool needs config, inject it from main isolate into the tool input (same pattern).

Extending the pattern
- Any isolate-executed tool must avoid accessing AppConfig/DatabaseService/Hive.
- If a value is needed (API keys, feature flags, settings), resolve on main isolate and inject into ToolSpec.input before spawning.
- In services that may be used in isolates, add optional parameters to accept injected values and prefer them over reading from configuration layers.

Notes
- A default sample key was already present as a fallback. The code maintains that default but prefers injected values. For production, ensure the real key is set in AppConfig in the main isolate or injected explicitly into ToolSpec when queuing.
- If you later need read/write local persistence inside isolates, you would need to initialize Hive per isolate and carefully manage adapters/boxes. This is not recommended here due to complexity and overhead.

Summary
The fix ensures isolate-safe execution by avoiding Hive access from isolates: we inject configuration (Brave API key) from the main isolate and adjust BraveSearchService and tools to use the injected value, resolving the Hive initialization error without requiring per-isolate Hive setup.