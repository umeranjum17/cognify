# RevenueCat Monthly Credits Architecture

## Overview

This document describes the subscription-based monthly credits system that integrates RevenueCat for subscription management with Firestore for credits tracking and consumption.

## Architecture Principles

1. **RevenueCat as Single Source of Truth**: Subscription status, entitlements, and billing periods are managed by RevenueCat
2. **Minimal Local Configuration**: No local storage (SharedPreferences) for quota - everything syncs via Firestore
3. **Fail-Closed Security**: System defaults to gated access when RevenueCat is unavailable
4. **Period-Based Reset**: Credits reset automatically when billing period expires (no scheduled jobs)

## System Flow

```
┌─────────────────────────────────────────────────────────┐
│                    USER SUBSCRIBES                       │
│                  (RevenueCat Handles)                    │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  REVENUECAT WEBHOOK                      │
│  api/rc/webhook.ts - Vercel Edge Function               │
│                                                          │
│  On INITIAL_PURCHASE/RENEWAL:                           │
│  1. Extract period dates from payload                   │
│  2. Determine tier from product ID                      │
│  3. Write to Firestore atomically:                      │
│     - status: 'active'                                  │
│     - tier: 'premium_monthly' | 'premium_annual'        │
│     - currentPeriodStart/End: from RevenueCat           │
│     - monthlyAllowance: 100 (configurable)              │
│     - consumed: 0 (reset for new period)                │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│              FIRESTORE STRUCTURE                         │
│  users/{uid}/subscription/current:                      │
│    - status: 'active' | 'cancelled' | 'expired'         │
│    - tier: 'premium_monthly' | 'premium_annual' | 'free'│
│    - productId: 'premium_monthly' (from stores)         │
│    - currentPeriodStart: Timestamp                      │
│    - currentPeriodEnd: Timestamp                        │
│    - monthlyAllowance: 100                              │
│    - consumed: 0                                        │
│    - lastSyncedFromRC: Timestamp                        │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│           CLIENT WATCHES FIRESTORE                       │
│  SubscriptionCreditsService.watchCredits(uid)           │
│                                                          │
│  1. Real-time stream of subscription changes            │
│  2. Auto-detects period expiration                      │
│  3. Triggers reset when period expires                  │
│  4. Emits SubscriptionCredits to UI                     │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│              USER CONSUMES CREDITS                       │
│  UsageQuotaProvider.consume(amount: 1)                  │
│                                                          │
│  1. Check if period expired → reset if needed           │
│  2. Check if enough credits remaining                   │
│  3. Atomically increment 'consumed' in Firestore        │
│  4. Update local state and notify listeners             │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Backend Webhook (`api/rc/webhook.ts`)

**Purpose**: Sync RevenueCat subscription events to Firestore

**Handles Events**:
- `INITIAL_PURCHASE` - Grant initial credits for new subscription
- `RENEWAL` - Reset credits for new billing period
- `CANCELLATION` - Mark as cancelled (keep access until period ends)
- `EXPIRATION` - Downgrade to free tier
- `PRODUCT_REFUND` - Immediately revoke access

**Tier Allowances**:
```typescript
const TIER_ALLOWANCES = {
  'premium_monthly': 100,
  'premium_annual': 100,
  'free': 10,
};
```

**Idempotency**: Uses RevenueCat event IDs to prevent duplicate processing

### 2. Client Service (`lib/services/subscription_credits_service.dart`)

**Purpose**: Firestore-backed credits management

**Key Methods**:
- `watchCredits(uid)` - Real-time stream of subscription credits
- `fetchCredits(uid)` - One-time snapshot fetch
- `consume(uid, amount)` - Atomically consume credits with Firestore transaction
- `_resetForNewPeriod(uid, credits)` - Auto-reset when period expires

**Period Detection**:
```dart
if (credits.isPeriodExpired && credits.status == 'active') {
  await _resetForNewPeriod(uid, credits);
}
```

### 3. Provider Layer (`lib/providers/usage_quota_provider.dart`)

**Purpose**: Expose subscription credits to UI with Provider pattern

**Provides**:
- Real-time credits updates via stream
- Consumption API
- Legacy compatibility getters for existing UI

**Example Usage**:
```dart
final quotaProvider = context.watch<UsageQuotaProvider>();
final remaining = quotaProvider.remaining;
final allowance = quotaProvider.limit;

// Consume credits
await quotaProvider.consume(amount: 1);
```

### 4. Access Control (`lib/providers/app_access_provider.dart`)

**Purpose**: Determine premium access based on RevenueCat entitlement

**Logic**:
```dart
final hasActiveSubscription = _subs.isEntitled; // From RevenueCat
_hasPremiumAccess = hasActiveSubscription;
```

## Monthly Reset Mechanism

### How It Works

1. **RevenueCat tracks billing periods** - Each subscription has `currentPeriodEnd` timestamp
2. **Client detects expiration** - `SubscriptionCreditsService` checks `isPeriodExpired` on each fetch/update
3. **Auto-reset on detection**:
   ```dart
   if (now > currentPeriodEnd && subscription.isActive) {
     // Calculate new period (1 month from old end)
     final newPeriodStart = oldPeriodEnd;
     final newPeriodEnd = DateTime(
       oldPeriodEnd.year,
       oldPeriodEnd.month + 1,
       oldPeriodEnd.day,
     );
     
     // Update Firestore
     await docRef.update({
       'consumed': 0,
       'currentPeriodStart': newPeriodStart,
       'currentPeriodEnd': newPeriodEnd,
     });
   }
   ```

### When Reset Happens

- **On every Firestore watch event** - Stream listener checks period
- **On manual fetch** - `fetchCredits()` checks and resets if needed
- **Before consumption** - `consume()` validates period before deducting

**No Scheduled Jobs Required!** - Period detection is event-driven

## Data Flow Examples

### Example 1: New Subscription

```
1. User purchases via RevenueCat → INITIAL_PURCHASE event
2. Webhook receives event with period_end: "2025-02-04T00:00:00Z"
3. Webhook writes to Firestore:
   {
     status: 'active',
     tier: 'premium_monthly',
     currentPeriodStart: '2025-01-04T00:00:00Z',
     currentPeriodEnd: '2025-02-04T00:00:00Z',
     monthlyAllowance: 100,
     consumed: 0,
   }
4. Client stream receives update → UI shows 100 credits
```

### Example 2: Monthly Renewal

```
1. RevenueCat auto-renews subscription → RENEWAL event
2. Webhook extracts new period_end: "2025-03-04T00:00:00Z"
3. Webhook updates Firestore:
   {
     consumed: 0,  // Reset!
     currentPeriodStart: '2025-02-04T00:00:00Z',
     currentPeriodEnd: '2025-03-04T00:00:00Z',
   }
4. Client stream receives update → UI shows 100 credits again
```

### Example 3: Period Expiration (Client-Side)

```
1. User opens app on 2025-02-05 (period ended on 2025-02-04)
2. SubscriptionCreditsService detects isPeriodExpired = true
3. Checks subscription status = 'active' (still subscribed via RevenueCat)
4. Triggers _resetForNewPeriod():
   - Sets new period: 2025-02-04 → 2025-03-04
   - Resets consumed to 0
   - Updates Firestore
5. Stream emits new credits → UI updates
```

### Example 4: Credit Consumption

```
1. User makes API request
2. App calls quotaProvider.consume(amount: 1)
3. SubscriptionCreditsService.consume():
   - Checks isPeriodExpired → reset if needed
   - Checks remaining >= 1
   - Firestore transaction:
     - Read current consumed: 5
     - Write consumed: 6
   - Returns updated credits
4. UI updates to show 94 remaining
```

## Error Handling

### RevenueCat Unavailable
- Service returns free tier (10 credits/month)
- App continues with degraded functionality
- No crashes or errors

### Firestore Unavailable
- Local state preserved
- Operations fail gracefully
- Error logged for debugging

### Quota Exceeded
```dart
try {
  await quotaProvider.consume(amount: 1);
} on QuotaExceededException catch (e) {
  // Show paywall or upgrade prompt
  print('Limit: ${e.limit}, Used: ${e.used}, Remaining: ${e.remaining}');
}
```

### Period Expired (Active Subscription)
- Automatically resets on next fetch/consume
- User sees credits restored
- No manual intervention needed

## Configuration

### Product IDs (`lib/config/subscriptions_config.dart`)
```dart
static const String productMonthly = 'premium_monthly';
static const String productAnnual = 'premium_annual';
static const String entitlementPremium = 'premium';
```

### Tier Allowances (Backend)
```typescript
// api/rc/webhook.ts
const TIER_ALLOWANCES = {
  'premium_monthly': 100,
  'premium_annual': 100,
  'free': 10,
};
```

### Free Tier Fallback
```dart
// lib/services/subscription_credits_service.dart
factory SubscriptionCredits.free(String uid) {
  return SubscriptionCredits(
    uid: uid,
    status: 'free',
    tier: 'free',
    monthlyAllowance: 10,
    consumed: 0,
    // ... period dates
  );
}
```

## Testing

### Test Scenarios

1. **New Subscription**
   - Use RevenueCat sandbox
   - Purchase test subscription
   - Verify Firestore update
   - Check client receives 100 credits

2. **Period Reset**
   - Manually update `currentPeriodEnd` to past date in Firestore
   - Open app / make request
   - Verify auto-reset to new period
   - Check consumed = 0

3. **Consumption**
   - Call `quotaProvider.consume(amount: 1)` multiple times
   - Verify Firestore `consumed` increments
   - Check UI updates correctly

4. **Quota Exceeded**
   - Consume all credits
   - Try to consume more
   - Verify `QuotaExceededException` thrown
   - Check paywall appears

5. **Subscription Cancellation**
   - Cancel subscription in RevenueCat
   - Verify webhook sets status = 'cancelled'
   - User keeps access until period ends
   - After period ends, downgrades to free tier

## Migration from Old System

### Old System (Deprecated)
- `UsageQuotaService` with SharedPreferences
- Local storage only
- No sync with subscriptions
- Request-based quota (not monthly)

### New System
- `SubscriptionCreditsService` with Firestore
- Cloud sync via RevenueCat webhook
- Monthly allowance per billing period
- Period-based auto-reset

### Breaking Changes
- `UsageQuotaProvider.quota` now returns `SubscriptionCredits` instead of `UsageQuota`
- `consumeRequests()` removed - use `consume()` instead
- `refund()` no longer supported (managed by RevenueCat)

### Compatibility Layer
```dart
// Legacy getters still work
int get remainingTokens => _credits?.remaining ?? 0;
int get remaining => _credits?.remaining ?? 0;
bool get hasQuota => remaining > 0;
```

## Best Practices

1. **Always check period expiration before consumption** - Handled automatically by `SubscriptionCreditsService`

2. **Use Firestore as cache, RevenueCat as source** - Firestore can be stale; RevenueCat SDK is authoritative

3. **Handle quota exceeded gracefully** - Show upgrade prompt, not error screen

4. **Log all subscription events** - Webhook logs to `revenuecat_events` collection for debugging

5. **Test with RevenueCat sandbox** - Use test product IDs before production

6. **Monitor webhook health** - Check Vercel logs for webhook errors

## Troubleshooting

### Credits not resetting monthly
- Check `currentPeriodEnd` timestamp in Firestore
- Verify webhook received RENEWAL event
- Check Vercel logs for webhook errors
- Manually trigger reset by setting `currentPeriodEnd` to past date

### Subscription active but no credits
- Check RevenueCat entitlement in CustomerInfo
- Verify webhook fired (check `revenuecat_events` collection)
- Force refresh: `await quotaProvider.refresh()`
- Check Firestore `users/{uid}/subscription/current` document

### Webhook not firing
- Verify webhook URL configured in RevenueCat dashboard
- Check `RC_WEBHOOK_SECRET` environment variable
- Test webhook with RevenueCat "Send Test" button
- Check Vercel function logs

### Period not resetting automatically
- Client only resets when app is opened or request made
- Check `isPeriodExpired` logic in `SubscriptionCreditsService`
- Verify subscription status = 'active' (must be subscribed to reset)

## Security Considerations

- **Webhook authentication**: Uses Bearer token to verify RevenueCat origin
- **Firestore rules**: Should restrict write access to webhook service account only
- **Client transactions**: Atomic Firestore transactions prevent race conditions
- **Fail-closed**: Defaults to no access when services unavailable

## Future Enhancements

1. **Usage analytics** - Track consumption patterns per user
2. **Variable pricing** - Different allowances per tier
3. **Rollover credits** - Carry unused credits to next month (capped)
4. **Add-on packs** - One-time credit purchases
5. **Team subscriptions** - Shared pool for organization
