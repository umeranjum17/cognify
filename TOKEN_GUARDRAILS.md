# Token Guardrails Implementation

## Problem
A reasoning model (`deepseek-r1:free`) generated **300k tokens** in a single response, costing significant money. This happened because there were no upper bounds on response size.

## Solution: Multi-Layer Protection

### 1. **Global Hard Cap**
- **Location**: `backend/src/config/config-data.ts` line 172
- **Setting**: `globalMaxTokens: 50000`
- **Effect**: NO model can generate more than 50k tokens, regardless of user request
- **Purpose**: Prevents catastrophic cost overruns

### 2. **Mode-Specific Limits**
Each mode has its own safety limit:

| Mode | Max Tokens | Purpose |
|------|------------|---------|
| `chat` | 8,000 | Quick responses |
| `search` | 12,000 | Regular searches |
| `aipedia` | 16,000 | Comprehensive answers |
| `deepsearch` | 20,000 | Deep research |

### 3. **Reasoning Model Protection (10x Cost Penalty)**
- **Location**: `backend/src/routes/chat.ts` line 472-476, `backend/src/routes/credits.ts` line 128-132
- **Detection**: Any model with "r1", "reasoning", or "deepseek-r1" in name
- **Token Limit**: Maximum 15,000 tokens
- **Cost Multiplier**: **10x** (reasons why below)
- **Purpose**: Reasoning models generate hidden internal reasoning tokens that cost money but users don't see

### 4. **Priority Order**
The final token limit is determined by:
1. Reasoning model cap (30k) if applicable
2. Mode-specific cap
3. User-requested cap
4. Global hard cap (50k)

**Smallest value wins** to ensure maximum protection.

## Example Protection Scenario

If a user requests 200k tokens for a reasoning model:
- Requested: 200,000 tokens
- Reasoning model cap: 15,000 tokens ← **Applied**
- Mode cap (deepsearch): 15,000 tokens  
- Global cap: 50,000 tokens

**Result**: Request limited to 15,000 tokens ✅  
**Cost**: Automatically multiplied by 10x to account for hidden reasoning tokens ✅

## Why 10x Cost Multiplier for Reasoning Models?

Reasoning models like `deepseek-r1` generate internal "thinking" tokens that are:
- **Charged to you by OpenAI/OpenRouter** (not visible in output)
- **Can be 2-10x more tokens than the visible output**
- **Exponentially more expensive** at scale

The 10x multiplier ensures you don't lose money when users use reasoning models.

## Logging

All token limit decisions are logged for debugging:
```
[chat] Token limit enforced: 30000 (global: 50000, mode max: 20000, requested: 200000, isReasoningModel: true)
⚠️ [SAFETY] Reasoning model detected (deepseek/deepseek-r1:free), applying extra tight limit
⚠️ [SAFETY] User requested 200000 tokens but limited to 30000 by safety guardrails
```

## Adjusting Limits

Edit `backend/src/config/config-data.ts`:

```typescript
export const QUOTA_CONFIG = {
  globalMaxTokens: 50000, // ← Change this for global max
  // ...
} as const;

export const MODE_CONFIGS = {
  deepsearch: {
    maxTokens: 20000, // ← Change this for mode-specific limits
    // ...
  },
} as const;
```

## Testing

To test the guardrails:
1. Make a request with an absurdly high token count
2. Check logs for warning messages
3. Verify response is capped at the limit

## Cost Estimation

With current limits, worst-case scenarios:
- Regular chat: 8k tokens max
- Search mode: 12k tokens max  
- Reasoning model: 15k tokens max × **10x cost multiplier**
- Global cap: 50k tokens (fallback)

Even at 15k tokens for reasoning models with 10x multiplier, this protects against runaway costs vs. unlimited token generation that could cost $100+ per request.

