# Balance Display Fix

## Problem
The app was displaying balance incorrectly:
- **Backend** returns balance in **request units** (x), where 1x = $0.01
- **Frontend** was displaying these units as dollars with `$` prefix
- Example: Backend returns `994` → UI showed "$994.00" (WRONG)

## Root Cause
The backend `/api/credits/balance` endpoint returns:
```json
{
  "balance": 994,
  "lastUpdated": "2025-01-10T..."
}
```

Where `balance` is in **request units** (not dollars). The value `994` means:
- 994x available
- Equivalent to $9.94 worth of API usage (since 1x = $0.01)

But the Flutter UI was treating this as `$994.00` instead of `994x`.

## Solution
Updated two widgets to display balance correctly as request units with "x" suffix:

### 1. `lib/widgets/session_info_widget.dart`
**Before:**
```dart
'Balance: \$${remainingCredits.toStringAsFixed(2)}'
// Showed: "Balance: $994.00" 
```

**After:**
```dart
'Balance: ${_formatCount(remainingUnits)}x'
// Shows: "Balance: 994x"
```

### 2. `lib/widgets/credits_usage_widget.dart`
**Before:**
```dart
'Total Credits': '\$${totalCredits.toStringAsFixed(2)}'
'Used': '\$${totalUsage.toStringAsFixed(2)}'
'Remaining': '\$${remainingCredits.toStringAsFixed(2)}'
```

**After:**
```dart
'Total Credits': '${totalUnits}x'
'Used': '${usedUnits}x'
'Remaining': '${remainingUnits}x'
```

## Pricing Model Recap

### Request Units (x) System
- **1x = $0.01** (dollarsPerRequestUnit in backend config)
- Each model request costs a certain number of x based on token usage
- Example calculations:
  - Model costs $0.03 per typical request → 3x per request
  - Model costs $0.005 per request → 1x per request (minimum is 1x)
  - Free models → 0x per request

### Conversion Examples
| Balance (x) | Dollar Value | Models at 1x/req | Models at 5x/req |
|-------------|--------------|------------------|------------------|
| 1,000x      | $10.00       | ~1,000 requests  | ~200 requests    |
| 994x        | $9.94        | ~994 requests    | ~198 requests    |
| 100x        | $1.00        | ~100 requests    | ~20 requests     |

## Display Logic

### Top Bar (session_info_widget.dart)
Shows two pieces of info:
1. **Left side**: Balance in request units
   - `Balance: 994x` (formatted with K/M for large numbers)
2. **Right side**: Per-request cost and remaining
   - For paid models: `994 left · $0.05/req · x5`
   - For free models: `994 left · Free`

### Credits Usage Widget
Shows detailed breakdown:
- Total Credits: `1000x`
- Used: `6x`
- Remaining: `994x`

## $10 Subscription Plan

For a **$10/month subscription**:
- Users get: **1,000x** ($10.00 ÷ $0.01)
- This allows:
  - ~1,000 requests with models averaging 1x/request (e.g., GPT-3.5-like)
  - ~200 requests with models averaging 5x/request (e.g., GPT-4-like)
  - Unlimited requests with free models (0x)

## Backend Configuration
Located in: `backend/src/config/config-data.ts`

```typescript
export const QUOTA_CONFIG = {
  initialRequestAllocation: 1000,  // New users start with 1000x
  dollarsPerRequestUnit: 0.01,     // 1x = $0.01
};
```

To change the pricing:
- Modify `dollarsPerRequestUnit` to adjust what 1x represents
- Example: `0.005` would make 1x = $0.005 (2x cheaper)

