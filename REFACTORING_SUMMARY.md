# Frontend Logic to Backend APIs - Refactoring Summary

## ✅ Completed Changes

### 1. **Cost Estimation Moved to Backend**

**New Backend Endpoint:** `/api/usage/estimate`
- **File:** `api/usage/estimate.ts`
- **Purpose:** Calculates request units and dollar costs server-side
- **Input:** `{ model, mode, inputTokens?, outputTokens? }`
- **Output:** `{ requestUnits, dollarCost, inputTokens, outputTokens, isFree }`
- **Logic Moved:** Mode multipliers, token estimation, pricing calculations

**Flutter Changes:**
- **File:** `lib/services/request_usage_estimator.dart`
- **Change:** Now calls `/api/usage/estimate` instead of local calculation
- **Removed:** All local pricing formulas, mode multipliers, token pair resolution

### 2. **Accurate Cost Calculation Moved to Backend**

**New Backend Endpoint:** `/api/usage/calculate`
- **File:** `api/usage/calculate.ts`
- **Purpose:** Fetches actual costs from OpenRouter generation IDs
- **Input:** `{ generationIds: [{id, stage, model}] }`
- **Output:** `{ totalCost, breakdown{}, hasAccurateCosts, accuracy }`
- **Logic Moved:** OpenRouter API calls, cost aggregation, breakdown generation

**Flutter Changes:**
- **File:** `lib/services/cost_service.dart`
- **Method:** `calculateAccurateCosts()`
- **Change:** Now calls `/api/usage/calculate` instead of local OpenRouter calls
- **Removed:** Direct OpenRouter API integration, cost calculation logic

### 3. **LLM Service Updated**

**File:** `lib/services/llm_service.dart`
- **Method:** `_estimateUsageForModel()`
- **Change:** Uses backend-based `RequestUsageEstimator.estimate()`
- **Removed:** Local pricing lookup and calculation

---

## 📋 Remaining Tasks (Recommended Order)

### Phase 1: Quota Management (HIGH PRIORITY)

**Task:** Make `/api/credits/consume` calculate request units server-side

**Current Issue:**
- Flutter calculates request units before calling consume API
- `UsageQuotaService.consumeRequests()` does local estimation

**Solution:**
1. Update `/api/credits/consume.ts`:
   ```typescript
   // Accept: { modelId, mode, conversationId }
   // Calculate units internally using pricing API
   // Consume calculated units
   ```

2. Update `lib/services/usage_quota_service.dart`:
   ```dart
   // Remove local calculation
   // Just pass modelId and mode to API
   // Backend returns consumed units
   ```

### Phase 2: Model Configuration Cleanup (MEDIUM PRIORITY)

**Task:** Remove hardcoded configs from Flutter

**Files to Clean:**
- `lib/models/mode_config.dart` - Remove `_defaultConfigs` (keep minimal fallback)
- `lib/config/model_registry.dart` - Remove `fallbackModelInfo` (keep minimal fallback)

**Ensure:**
- All mode configs come from `/api/config/modes`
- All model data comes from `/api/config/models`
- Only keep 1 free model as emergency fallback

### Phase 3: Model Filtering (LOW PRIORITY)

**Task:** Create `/api/models/filter` endpoint

**Endpoint:**
```
GET /api/models/filter?isFree=true&supportsImages=true&provider=google
```

**Flutter Changes:**
- Remove `ModelRegistry.filterModels()` logic
- Call API endpoint instead

### Phase 4: File Validation (SECURITY)

**Task:** Create `/api/files/validate` endpoint

**Endpoint:**
```
POST /api/files/validate
{ modelId, fileType, fileSize }
```

**Flutter Changes:**
- Keep file picker UI
- Validate via API before upload

---

## 🎯 Architecture Achieved

### Backend (APIs) Now Owns:
✅ Cost calculations (estimate & actual)
✅ Pricing data from OpenRouter
✅ Mode configurations
✅ Model capabilities
⏳ Quota consumption calculations (pending)
⏳ Model filtering (pending)
⏳ File validation (pending)

### Frontend (Flutter) Responsibilities:
✅ Display UI
✅ Call backend APIs
✅ Cache API responses (with TTL)
✅ Format data for display
✅ Handle user input
✅ File picker UI

---

## 📊 Impact Summary

### Logic Removed from Frontend:
- ❌ Token estimation formulas
- ❌ Mode multipliers (chat: 1x, search: 1.3x, aipedia: 1.5x, deepsearch: 8x)
- ❌ Cost calculation from pricing
- ❌ OpenRouter generation ID lookups
- ❌ Request unit calculations

### Logic Added to Backend:
- ✅ `/api/usage/estimate` - Complete estimation logic
- ✅ `/api/usage/calculate` - Accurate cost tracking
- ✅ Centralized pricing from OpenRouter
- ✅ Mode-aware token multipliers

### Benefits:
1. **Single Source of Truth:** Backend owns all business logic
2. **Easy Updates:** Change multipliers or formulas without app releases
3. **Security:** Pricing logic not exposed to clients
4. **Consistency:** All platforms get same calculations
5. **Testing:** Business logic testable on server

---

## 🚀 Next Steps

1. **Test the new endpoints:**
   ```bash
   # Test estimate
   curl -X POST https://your-api.vercel.app/api/usage/estimate \
     -H "Content-Type: application/json" \
     -d '{"model":"google/gemini-2.5-flash-lite","mode":"chat"}'

   # Test calculate
   curl -X POST https://your-api.vercel.app/api/usage/calculate \
     -H "Content-Type: application/json" \
     -d '{"generationIds":[{"id":"gen_123","stage":"main"}]}'
   ```

2. **Deploy to Vercel:**
   ```bash
   vercel --prod
   ```

3. **Test Flutter integration:**
   - Verify `RequestUsageEstimator.estimate()` calls backend
   - Verify `CostService.calculateAccurateCosts()` calls backend
   - Check logs for "via backend" messages

4. **Complete remaining phases (quota, cleanup, filtering, validation)**

---

## 📝 Notes

- All backend endpoints use CORS headers for cross-origin requests
- Error handling includes fallback to free estimates on failures
- Backend fetches live pricing from OpenRouter API
- Flutter caches responses to minimize API calls
- Emergency fallbacks ensure app works if backend is down
