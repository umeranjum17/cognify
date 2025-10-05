# API Migration Status - Frontend to Backend Mode APIs

## ✅ Completed

### Backend Changes
1. **Deleted redundant proxy endpoints** (`/api/proxy/*`)
   - Removed `/api/proxy/openrouter/*`
   - Removed `/api/proxy/brave/*`
   - These were duplicating functionality already in `/api/modes/*`

2. **Fixed package dependencies**
   - Changed `@ai-sdk/openrouter` to `@openrouter/ai-sdk-provider`
   - Updated imports in all mode files
   - Installed correct packages

3. **Verified Mode APIs** (all working)
   - `/api/modes/chat` - Uses OpenRouter directly
   - `/api/modes/search` - Uses OpenRouter + Brave web search
   - `/api/modes/aipedia` - Uses OpenRouter + Brave web + image search
   - `/api/config/models` - Fetches available models from OpenRouter
   - `/api/config/app` - Returns app configuration
   - `/api/credits/*` - Credit management endpoints

### Frontend Changes
1. **Updated LLM Service** ([lib/services/llm_service.dart](lib/services/llm_service.dart))
   - Changed from `OpenRouterClient` to `ModeApiService`
   - Removed `_maybeInjectSearchContext` - backend handles this now
   - Removed Brave search injection logic
   - Simplified `chatCompletion()` and `chatCompletionStream()` methods
   - Backend Mode APIs now handle all AI + search functionality

2. **Deleted obsolete services**
   - ❌ Deleted `lib/services/openrouter_client.dart`
   - ❌ Deleted `lib/services/brave_search_service.dart`
   - ❌ Deleted `lib/services/tools.dart` (contained Brave/OpenRouter tools)

## ⚠️ Remaining Work - Files with Compilation Errors

These files still import the deleted services and will fail to compile:

### 1. [lib/services/model_service.dart](lib/services/model_service.dart)
**Issue**: Imports `openrouter_client.dart` and calls `_openRouterClient.getModels()`
**Solution**: Replace with HTTP call to `/api/config/models`

```dart
// OLD CODE (broken):
import 'openrouter_client.dart';
final modelsResponse = await _openRouterClient.getModels();

// NEW CODE (needed):
import 'package:dio/dio.dart';
import '../config/app_config.dart';

final dio = Dio();
final response = await dio.get('${AppConfig.backendBaseUrl}/api/config/models');
final modelsData = response.data['data'];
```

### 2. [lib/services/document_processor.dart](lib/services/document_processor.dart)
**Issue**: Imports `openrouter_client.dart`
**Check**: See if it actually uses OpenRouter or can be removed

### 3. [lib/services/user_service.dart](lib/services/user_service.dart)
**Issue**: Imports `openrouter_client.dart` or `brave_search_service.dart`
**Check**: See if it actually uses these services

### 4. [lib/screens/editor_screen.dart](lib/screens/editor_screen.dart)
**Issue**: Calls `openRouterClient.getModels()`
**Solution**: Same as model_service.dart - call `/api/config/models`

## Architecture Summary

### Before (Messy ❌)
```
Frontend
  ├─ openRouterClient → OpenRouter API directly
  ├─ BraveSearchService → Brave API directly
  ├─ LLMService → injects search results manually
  └─ ModeApiService → /api/modes/* (NOT USED!)

Backend
  ├─ /api/proxy/openrouter → OpenRouter (proxy)
  ├─ /api/proxy/brave → Brave (proxy)
  └─ /api/modes/* → OpenRouter + Brave (duplicate!)
```

### After (Clean ✅)
```
Frontend
  └─ LLMService → ModeApiService → Backend Mode APIs

Backend
  ├─ /api/modes/chat → OpenRouter
  ├─ /api/modes/search → OpenRouter + Brave web search
  ├─ /api/modes/aipedia → OpenRouter + Brave web + images
  ├─ /api/config/models → OpenRouter models list
  └─ /api/credits/* → Credit management
```

## Benefits

1. **Security**: API keys only on backend, not in frontend
2. **Simplicity**: Frontend just calls one service (`ModeApiService`)
3. **Consistency**: All AI features go through same code path
4. **Maintainability**: Search logic only in one place (backend)
5. **Cost control**: Backend can enforce rate limits and quotas

## Next Steps

1. Fix compilation errors in the 4 files listed above
2. Test the chat/search/aipedia modes end-to-end
3. Remove any other references to OpenRouter/Brave in frontend
4. Deploy and test in production

## Environment Variables Needed

Backend needs these in Vercel:
```
OPENROUTER_API_KEY=<your-key>
BRAVE_API_KEY=<your-key>
FIREBASE_ADMIN_SDK_CONFIG=<your-config-json>
```

Frontend no longer needs API keys! Just needs:
```
BACKEND_BASE_URL=https://your-vercel-app.vercel.app
```
