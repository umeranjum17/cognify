# Broken Imports - Files to Fix

## Files with Broken Imports (16 files)

### Services (4 files):
1. **lib/services/llm_service.dart**
   - ❌ `import 'cost_service.dart';`
   - ❌ `import 'request_usage_estimator.dart';`
   - ✅ Already updated to use ModeApiService
   - Fix: Remove these imports

2. **lib/services/model_service.dart**
   - ❌ `import 'openrouter_client.dart';`
   - Fix: Call `/api/config/models` instead

3. **lib/services/document_processor.dart**
   - ❌ `import 'openrouter_client.dart';`
   - Check if actually using it

4. **lib/services/user_service.dart**
   - ❌ `import 'openrouter_client.dart';`
   - Check if actually using it

### Screens (3 files):
5. **lib/screens/editor_screen.dart**
   - ❌ `import '../services/openrouter_client.dart';`
   - ❌ `import '../services/mode_engine.dart';`
   - ❌ `import '../services/session_cost_service.dart';`

6. **lib/screens/model_quick_switcher.dart**
   - ❌ `import '../services/request_usage_estimator.dart';`

7. **lib/screens/model_selection_screen.dart**
   - ❌ `import '../services/request_usage_estimator.dart';`

### Widgets (5 files):
8. **lib/widgets/session_cost_bottom_sheet.dart**
   - ❌ `import '../services/session_cost_service.dart';`
   - This widget shows session costs
   - Replace with backend data

9. **lib/widgets/model_capabilities_bottom_sheet.dart**
   - ❌ `import '../services/request_usage_estimator.dart';`
   - Shows cost estimates
   - Get from backend

10. **lib/widgets/follow_up_questions_widget.dart**
    - ❌ `import '../services/session_cost_service.dart';`

11. **lib/widgets/cost_display_widget.dart**
    - ❌ `import '../services/cost_service.dart';`
    - Displays costs
    - Get from backend response

12. **lib/widgets/session_info_widget.dart**
    - ❌ `import '../services/session_cost_service.dart';`
    - ❌ `import 'session_cost_bottom_sheet.dart';`

---

## API Keys to Remove

### lib/config/app_config.dart
```dart
// DELETE THESE:
static const String openRouterApiKey = 'sk-openrouter-hardcoded-placeholder';

Future<String?> get openRouterApiKey async {
  // ... DELETE THIS ENTIRE METHOD
}
```

### lib/config/app_secrets.dart (if exists)
```dart
// DELETE ALL API KEYS:
static const openRouterApiKey = '...';
static const braveApiKey = '...';
```

**The frontend should have ZERO API keys!**

---

## Quick Fix Script

```bash
# 1. Remove all import lines with deleted services
find lib -name "*.dart" -type f -exec sed -i '' '/import.*cost_service/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*request_usage_estimator/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*session_cost_service/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*mode_engine/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*openrouter_client/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*brave_search_service/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*tools\.dart/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*content_extractor/d' {} +

# 2. Then manually fix the logic in each file
```

---

## Replacement Strategy

### For Cost Display Widgets:
**OLD:**
```dart
final cost = CostService.calculateCost(...);
```

**NEW:**
```dart
// Backend returns cost in response
final response = await ModeApiService.instance.chat(...);
final cost = response['usage']?['cost'] ?? 0.0;
```

### For Usage Estimation:
**OLD:**
```dart
final estimate = RequestUsageEstimator.estimate(...);
```

**NEW:**
```dart
// Create new endpoint: /api/estimate
final response = await dio.post('/api/estimate', data: {
  'mode': 'search',
  'model': selectedModel,
});
final estimate = response.data['requestUnits'];
```

### For Model Selection:
**OLD:**
```dart
final models = await _openRouterClient.getModels();
```

**NEW:**
```dart
final response = await dio.get('/api/config/models');
final models = response.data['data']['available'];
```

---

## Backend Changes Needed

### 1. Update Mode API Responses
Add usage data to all mode endpoints:

```typescript
// In api/modes/{chat,search,aipedia}.ts
// After streaming is complete, send:
const usageData = {
  type: 'usage',
  tokens: {
    input: result.usage.promptTokens,
    output: result.usage.completionTokens,
    total: result.usage.totalTokens
  },
  cost: calculateCost(result.usage, pricing),
  requestUnits: calculateRequestUnits(cost),
  model: selectedModel
};

// Send as part of stream before [DONE]
yield `data: ${JSON.stringify(usageData)}\n\n`;
```

### 2. Create Estimate Endpoint
```typescript
// api/estimate.ts
export default async function handler(req: Request) {
  const { mode, model, inputTokens } = await req.json();

  // Get pricing from config
  const pricing = await getModelPricing(model);

  // Estimate based on mode multipliers
  const estimate = calculateEstimate(mode, pricing, inputTokens);

  return new Response(JSON.stringify({
    requestUnits: estimate.units,
    estimatedCost: estimate.cost,
    tokens: estimate.tokens
  }));
}
```

---

## Migration Steps

### Step 1: Remove All Import Statements ✅
Run the sed commands above to remove broken imports

### Step 2: Comment Out Broken Code
For each file with errors, comment out the code that uses deleted services:
```dart
// TODO: Get from backend response instead
// final cost = CostService.calculateCost(...);
```

### Step 3: Update Backend Mode APIs
Add usage data to streaming responses

### Step 4: Update Frontend to Parse Usage
```dart
// In llm_service.dart
await for (final chunk in _modeApi.chatStream(...)) {
  if (chunk['type'] == 'usage') {
    // Store usage data
    _lastRequestCost = chunk['cost'];
    _lastRequestTokens = chunk['tokens'];
  }
}
```

### Step 5: Remove API Keys
Delete all `openRouterApiKey` and `braveApiKey` references from:
- `lib/config/app_config.dart`
- `lib/config/app_secrets.dart`
- Any environment files

### Step 6: Test End-to-End
- Chat mode
- Search mode
- Aipedia mode
- Cost tracking
- Quota consumption

---

## Expected Errors After Import Removal

After removing imports, expect errors like:
```
Undefined name 'CostService'
Undefined name 'RequestUsageEstimator'
Undefined name 'SessionCostService'
Undefined name 'OpenRouterClient'
```

**This is GOOD!** These errors show where we need to:
1. Remove the code entirely (UI-only concern)
2. Replace with backend API call
3. Parse from backend response

---

## Clean Architecture

**Frontend Responsibilities:**
- ✅ Display UI
- ✅ Collect user input
- ✅ Call backend APIs
- ✅ Show responses
- ❌ Calculate costs
- ❌ Estimate usage
- ❌ Select models
- ❌ Call OpenRouter/Brave
- ❌ Store API keys

**Backend Responsibilities:**
- ✅ All AI API calls
- ✅ Cost calculation
- ✅ Usage tracking
- ✅ Model selection
- ✅ Search integration
- ✅ Quota management
- ✅ API key management

---

## Next Action

```bash
# Remove all broken imports
cd /Users/umerfaroq/Documents/GitHub/cognify-flutter

find lib -name "*.dart" -type f -exec sed -i '' '/import.*cost_service/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*request_usage_estimator/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*session_cost_service/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*mode_engine/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*openrouter_client/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*brave_search_service/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*tools\.dart/d' {} +
find lib -name "*.dart" -type f -exec sed -i '' '/import.*content_extractor/d' {} +

# Then check what breaks
flutter analyze
```
