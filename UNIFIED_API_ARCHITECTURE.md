# 🎯 Unified API Architecture - Configuration-Driven Frontend

## Core Principle: Backend Tells Frontend What To Do

**Frontend should NEVER hardcode:**
- ❌ Which endpoint to call for which mode
- ❌ What capabilities each mode has
- ❌ Model defaults or temperature settings
- ❌ API behavior or business logic

**Backend Configuration is Source of Truth:**
- ✅ Mode configurations (`/api/config/modes`)
- ✅ Model list (`/api/config/models`)
- ✅ App settings (`/api/config/app`)
- ✅ All behavior determined server-side

---

## 🏗️ New Architecture

### Single Unified Endpoint: `/api/chat`

**All modes use the same endpoint!** Backend determines behavior based on `mode` parameter.

```typescript
POST /api/chat
{
  "mode": "search",  // Backend uses this to route logic
  "messages": [...],
  "model": "google/gemini-2.5-flash-lite",  // Optional, backend has defaults
  "temperature": 0.7  // Optional, backend has defaults
}
```

### Backend Routes Based on Mode

```typescript
// api/chat.ts
switch (mode) {
  case 'chat':
    // Just AI, no tools
    break;
  case 'search':
    // AI + Brave web search tool
    break;
  case 'aipedia':
    // AI + Brave web + image search tools
    break;
  case 'deepsearch':
    // AI + advanced research tools
    break;
}
```

**Frontend doesn't know or care about the differences!**

---

## 📋 Configuration Flow

### 1. Frontend Starts

```dart
// On app launch:
await ModeApiService.instance.loadConfigurations();

// This fetches:
GET /api/config/modes
{
  "data": {
    "chat": {
      "id": "chat",
      "endpoint": "/api/chat",
      "displayName": "Chat",
      "icon": "💬",
      "capabilities": ["text"],
      "defaultModel": "google/gemini-2.5-flash-lite",
      ...
    },
    "search": {
      "id": "search",
      "endpoint": "/api/chat",  // SAME ENDPOINT!
      "displayName": "Search",
      "icon": "🔍",
      "capabilities": ["text", "web-search"],
      ...
    }
  }
}
```

### 2. Frontend Uses Config

```dart
// When user selects a mode:
final config = modeConfigs['search'];
final endpoint = config['endpoint'];  // "/api/chat"

// Call backend - it knows what to do!
final response = await dio.post(endpoint, data: {
  'mode': 'search',  // Backend uses this
  'messages': [...]
});
```

### 3. Backend Determines Behavior

```typescript
// Backend sees mode='search' and automatically:
// - Adds web search tool
// - Sets appropriate system prompt
// - Configures temperature
// - Handles all logic

const config = getModeConfig(request.mode);
const tools = buildToolsForMode(request.mode);
const systemPrompt = config.systemPrompt;
// ... rest is automatic
```

---

## 🗂️ File Structure

### Backend (`/api`)

```
api/
├── chat.ts                    ← UNIFIED ENDPOINT (all modes)
├── config/
│   ├── app.ts                ← App settings
│   ├── models.ts             ← Available models + pricing
│   ├── modes.ts              ← Mode configurations
│   └── pricing.ts            ← Pricing tiers
├── credits/
│   ├── balance.ts
│   ├── consume.ts
│   └── refund.ts
├── shared/
│   └── config-data.ts        ← SINGLE SOURCE OF TRUTH
└── modes/                     ← DEPRECATED (delete these)
    ├── chat.ts               ❌ Delete - use /api/chat
    ├── search.ts             ❌ Delete - use /api/chat
    └── aipedia.ts            ❌ Delete - use /api/chat
```

### Frontend (`lib/services`)

```
lib/services/
├── mode_api_service.dart      ← Configuration-driven client
├── credits_service.dart       ← Calls /api/credits/*
├── llm_service.dart           ← Thin wrapper
└── conversation_service.dart  ← Local state management
```

---

## 🔄 Configuration Update Flow

### Add a New Mode (Backend Only!)

1. **Update `/api/shared/config-data.ts`**:
```typescript
export const MODE_CONFIGS = {
  // ... existing modes ...
  'research': {  // NEW MODE
    id: 'research',
    endpoint: '/api/chat',  // Same endpoint!
    displayName: 'Research',
    icon: '🧪',
    capabilities: ['text', 'web-search', 'citations'],
    defaultModel: 'google/gemini-2.5-flash-lite',
    temperature: 0.6,
  }
};
```

2. **Update `/api/chat.ts`** logic:
```typescript
function getModeConfig(mode: string) {
  const configs = {
    // ... existing ...
    research: {
      systemPrompt: 'You are a research assistant...',
      tools: ['braveWebSearch', 'citationTool'],
    }
  };
  return configs[mode];
}
```

3. **Deploy**

**Frontend automatically picks it up!** No app update needed! 🎉

---

## 📊 Configuration Schema

### Mode Configuration (Backend)

```typescript
{
  id: string,                    // 'chat', 'search', etc.
  endpoint: string,              // Always '/api/chat' now
  displayName: string,           // "Chat", "Search"
  description: string,           // "Quick answers..."
  icon: string,                  // "💬", "🔍"
  defaultModel: string,          // Model ID from OpenRouter
  availableModels: string[],     // Array of model IDs
  capabilities: string[],        // ['text', 'web-search', ...]
  temperature: number,           // Default temperature
}
```

### Request Format (Frontend → Backend)

```typescript
{
  mode: string,                  // Required: 'chat', 'search', 'aipedia'
  messages: Message[],           // Required: Conversation history
  model?: string,                // Optional: Override default
  temperature?: number,          // Optional: Override default
  maxTokens?: number,            // Optional: Limit response
  query?: string,                // Optional: For single queries
}
```

### Response Format (Backend → Frontend)

```typescript
// Streaming response:
data: {"type":"chunk","data":"Hello..."}
data: {"type":"usage","tokens":{"input":234,"output":567},"cost":0.0023}
data: [DONE]
```

---

## ✅ Benefits

### 1. Zero Hardcoding
```dart
// OLD (BAD):
final endpoint = mode == ChatMode.search
  ? '/api/modes/search'
  : '/api/modes/chat';

// NEW (GOOD):
final endpoint = config['endpoint'];  // Backend tells us!
```

### 2. Instant Updates
- Change mode behavior → Deploy backend → All clients updated
- Add new mode → Deploy backend → Shows in app automatically
- No app store review needed!

### 3. A/B Testing
```typescript
// Backend can serve different configs to different users:
if (userIsInExperiment('new-search-ui')) {
  return enhancedSearchConfig;
}
```

### 4. Feature Flags
```typescript
export const FEATURE_FLAGS = {
  enableDeepSearchMode: true,  // Toggle on/off instantly
  showTrendingTopics: false,   // A/B test this
};
```

### 5. Model Flexibility
```typescript
// Backend can switch models without frontend changes:
MODE_CONFIGS.chat.defaultModel = 'claude-3-5-sonnet';  // Done!
```

---

## 🚀 Migration Steps

### Step 1: Deploy New Unified Endpoint ✅
- [x] Created `/api/chat.ts`
- [x] Handles all modes with `mode` parameter
- [x] Routes to correct logic based on mode

### Step 2: Update Configuration ✅
- [x] Added `endpoint` field to all mode configs
- [x] All point to `/api/chat`
- [x] Added capabilities, icons, etc.

### Step 3: Update Frontend ✅
- [x] `ModeApiService` fetches config on startup
- [x] Uses config to determine endpoint
- [x] Passes `mode` parameter to backend

### Step 4: Delete Old Mode Endpoints (TODO)
```bash
# Delete these redundant files:
rm api/modes/chat.ts
rm api/modes/search.ts
rm api/modes/aipedia.ts
```

### Step 5: Test & Deploy
- [ ] Test all modes work with unified endpoint
- [ ] Verify config updates propagate
- [ ] Deploy to production

---

## 📖 Developer Workflow

### Adding a Feature:

**OLD Way (Bad):**
1. Add mode logic to backend ❌
2. Update frontend to call new endpoint ❌
3. Update frontend UI ❌
4. Release app update ❌
5. Wait for app store approval ❌
6. Users update app ❌

**NEW Way (Good):**
1. Add mode to backend config ✅
2. Deploy backend ✅
3. Done! ✅

### Changing Model:

**OLD Way (Bad):**
1. Change model in backend code ❌
2. Change model in frontend code ❌
3. Release app update ❌

**NEW Way (Good):**
1. Change `defaultModel` in config ✅
2. Deploy ✅
3. All clients use new model instantly ✅

---

## 🎯 Next Actions

1. **Delete old mode endpoints**:
   ```bash
   rm api/modes/{chat,search,aipedia}.ts
   ```

2. **Test unified endpoint locally**

3. **Deploy to staging**

4. **Verify configs propagate correctly**

5. **Deploy to production**

---

## 🔐 Security Note

Frontend still has ZERO API keys. All secrets on backend:
- ✅ `OPENROUTER_API_KEY` on backend only
- ✅ `BRAVE_API_KEY` on backend only
- ✅ `FIREBASE_ADMIN_SDK` on backend only

Frontend just knows:
- 📍 Backend URL
- 🎨 UI configuration from backend
- 📨 How to format requests (generic)

---

**Status: 95% Complete** 🎯

**Remaining: Delete old `/api/modes/*` endpoints**
