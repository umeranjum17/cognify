# Frontend Cleanup Plan - Move Logic to Backend

## Philosophy: "Dumb Frontend, Smart Backend"

The frontend should ONLY:
- Display UI
- Collect user input
- Call backend APIs
- Render responses

The backend should handle:
- All business logic
- Cost calculations
- Usage tracking
- Model selection
- File processing
- Content extraction

---

## Services to DELETE (Move to Backend)

### ❌ Business Logic (Backend should handle)

1. **request_usage_estimator.dart** (122 lines)
   - Estimates request units and costs
   - **MOVE TO**: Backend should return estimated cost with each request
   - Mode APIs should include `{ cost: 0.0042, requestUnits: 3, tokens: {...} }` in response

2. **cost_service.dart** (290 lines)
   - Calculates costs, fetches pricing
   - **MOVE TO**: `/api/credits/estimate` endpoint
   - Backend tracks actual costs per request

3. **session_cost_service.dart** (64 lines)
   - Tracks session-level costs
   - **MOVE TO**: Backend tracks in Firebase per conversation
   - Frontend just displays what backend returns

4. **usage_quota_service.dart** (164 lines)
   - Manages usage quotas and limits
   - **ALREADY ON BACKEND**: `/api/credits/balance`, `/api/credits/consume`
   - Frontend should just call these APIs

5. **model_service.dart** (543 lines)
   - Complex model selection logic
   - **MOVE TO**: Backend chooses best model based on mode
   - Frontend gets model list from `/api/config/models`
   - Mode APIs auto-select best model if not specified

6. **document_processor.dart** (646 lines)
   - Processes documents, extracts text
   - **MOVE TO**: New endpoint `/api/process/document`
   - Backend handles file parsing, extraction, summarization

7. **content_extractor.dart** (38 lines)
   - Extracts content from URLs
   - **MOVE TO**: Backend mode APIs handle URL extraction
   - Search/Aipedia modes already fetch web content

8. **file_attachment_service.dart** (344 lines)
   - Complex file handling logic
   - **MOVE TO**: `/api/upload/attachment` endpoint
   - Backend handles storage, processing, OCR, etc.

9. **mode_engine.dart** (104 lines)
   - Determines which mode to use
   - **SIMPLIFY**: Frontend just lets user pick mode
   - Backend is mode-aware via `/api/modes/{chat,search,aipedia}`

### ✅ Keep (UI/Client Concerns)

1. **mode_api_service.dart** ✅
   - Client for calling backend Mode APIs
   - This is the ONLY service that talks to AI backend

2. **credits_service.dart** ✅
   - Calls `/api/credits/*` endpoints
   - Thin wrapper for credits API

3. **llm_service.dart** ✅
   - Simplified to call mode_api_service
   - Just a thin orchestration layer

4. **conversation_service.dart** ✅
   - Manages local conversation state
   - UI concern, keeps messages in memory

5. **file_upload_service.dart** ✅
   - Handles multipart uploads to backend
   - Pure HTTP client, no business logic

6. **revenuecat_service.dart** ✅
   - RevenueCat SDK integration
   - Client-side only

7. **subscription_credits_service.dart** ✅
   - Syncs RevenueCat → Backend credits
   - Orchestration between RC and your backend

8. **secure_storage.dart** ✅
   - Local secure storage wrapper
   - Client-side only

9. **remote_config_service.dart** ✅
   - Firebase Remote Config
   - Could potentially be replaced by `/api/config/app` but ok to keep

10. **data_deletion_service.dart** ✅
    - GDPR data deletion
    - Calls backend deletion APIs

11. **user_service.dart** ✅
    - User profile management
    - Calls backend user APIs

12. **access_service.dart** ✅
    - Feature access checks
    - Thin client logic

13. **premium_feature_gate.dart** ✅
    - UI gating for premium features
    - Pure UI concern

14. **paywall_coordinator.dart** ✅
    - Shows paywalls
    - Pure UI concern

15. **services_manager.dart** ✅
    - Initializes services
    - Orchestration layer

16. **prompt_service.dart** ✅
    - Manages prompt templates?
    - Check if needed or move to backend

---

## Backend Endpoints to CREATE

### 1. `/api/estimate` (POST)
Replace: `request_usage_estimator.dart`, `cost_service.dart`
```typescript
POST /api/estimate
{
  "mode": "search",
  "model": "google/gemini-2.5-flash-lite",
  "inputTokens": 900  // optional
}

Response:
{
  "requestUnits": 3,
  "estimatedCost": 0.0042,
  "tokens": { "input": 900, "output": 1100 }
}
```

### 2. `/api/modes/{mode}` - Enhanced Response
Update existing mode endpoints to include cost/usage in response:
```typescript
Response (streaming):
data: {"type":"usage","data":{"tokens":{"input":234,"output":567},"cost":0.0023,"requestUnits":2}}
data: {"type":"chunk","data":"Hello..."}
data: [DONE]
```

### 3. `/api/process/document` (POST)
Replace: `document_processor.dart`, `content_extractor.dart`
```typescript
POST /api/process/document
multipart/form-data: { file, extractText, summarize }

Response:
{
  "text": "...",
  "summary": "...",
  "metadata": { ... }
}
```

### 4. `/api/upload/attachment` (POST)
Replace: `file_attachment_service.dart`
```typescript
POST /api/upload/attachment
multipart/form-data: { file, conversationId }

Response:
{
  "attachmentId": "...",
  "url": "...",
  "processedText": "..."
}
```

### 5. `/api/conversation/{id}/cost` (GET)
Replace: `session_cost_service.dart`
```typescript
GET /api/conversation/{conversationId}/cost

Response:
{
  "totalCost": 0.042,
  "requestUnits": 12,
  "breakdown": [
    { "timestamp": "...", "cost": 0.003, "requestUnits": 1 }
  ]
}
```

---

## Implementation Steps

### Phase 1: Delete Obvious Redundancies ✅
- [x] Delete `openrouter_client.dart`
- [x] Delete `brave_search_service.dart`
- [x] Delete `tools.dart`

### Phase 2: Delete Business Logic Services
- [ ] Delete `request_usage_estimator.dart`
- [ ] Delete `cost_service.dart`
- [ ] Delete `session_cost_service.dart`
- [ ] Delete `content_extractor.dart`
- [ ] Delete `document_processor.dart`
- [ ] Delete `file_attachment_service.dart`
- [ ] Delete `mode_engine.dart`

### Phase 3: Simplify Model Service
- [ ] Replace `model_service.dart` with simple API client
- [ ] Call `/api/config/models` instead of OpenRouter directly

### Phase 4: Update LLM Service
- [ ] Remove all cost calculation logic
- [ ] Remove model selection logic
- [ ] Backend mode APIs handle model selection
- [ ] Parse usage data from streaming responses

### Phase 5: Create Backend Endpoints
- [ ] Create `/api/estimate` endpoint
- [ ] Update mode endpoints to include usage data
- [ ] Create `/api/process/document` endpoint (if file upload needed)
- [ ] Create `/api/upload/attachment` endpoint (if file upload needed)

### Phase 6: Update usage_quota_service
- [ ] Remove local calculation logic
- [ ] Just call `/api/credits/balance` and `/api/credits/consume`
- [ ] Backend handles all quota logic

---

## File Count Reduction

**Before:**
- 25 service files
- ~3,500 lines of business logic

**After:**
- 15 service files (10 deleted)
- ~1,500 lines (mostly UI orchestration)
- **60% reduction in frontend complexity!**

---

## Benefits

1. **Security**: No pricing data or business logic exposed
2. **Consistency**: One source of truth (backend)
3. **Performance**: Backend can cache/optimize calculations
4. **Maintainability**: Change logic once, all clients benefit
5. **Testing**: Easier to test backend logic
6. **Mobile App Size**: Smaller APK/IPA
7. **Bug Fixes**: Fix in backend, no app update needed

---

## Migration Priority

**HIGH (Do First):**
1. ❌ Delete `request_usage_estimator.dart`
2. ❌ Delete `cost_service.dart`
3. ❌ Delete `session_cost_service.dart`
4. ✅ Update `usage_quota_service.dart` to use backend APIs only

**MEDIUM (Do Next):**
5. ❌ Simplify `model_service.dart` → call `/api/config/models`
6. ❌ Delete `content_extractor.dart`
7. ❌ Delete `mode_engine.dart`

**LOW (Nice to Have):**
8. ❌ Delete `document_processor.dart` (create `/api/process/document`)
9. ❌ Delete `file_attachment_service.dart` (create `/api/upload/attachment`)

---

## Next Action

Run: `rm lib/services/{request_usage_estimator,cost_service,session_cost_service,content_extractor,document_processor,file_attachment_service,mode_engine}.dart`

Then update code that imports these to call backend APIs instead.
