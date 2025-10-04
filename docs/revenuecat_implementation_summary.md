# RevenueCat Monthly Credits Implementation Summary

## What Was Done

Implemented a complete RevenueCat + Firestore subscription system with monthly credit allowances that reset automatically each billing period.

## Key Changes

### 1. Backend Webhook (`api/rc/webhook.ts`) ✅
- **Before**: Simple credits grant/deduct, no period tracking
- **After**: Full subscription lifecycle management
  - Extracts period dates from RevenueCat payload
  - Determines tier from product ID
  - Stores in Firestore: `users/{uid}/subscription/current`
  - Handles: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, REFUND
  - Resets consumed credits on renewal

### 2. New Service: `SubscriptionCreditsService` ✅
- **Purpose**: Firestore-backed credits with RevenueCat sync
- **Features**:
  - Real-time streaming from Firestore
  - Auto-detects period expiration
  - Auto-resets credits when period expires
  - Atomic consumption via Firestore transactions
  - No local storage (SharedPreferences removed)

### 3. Updated `UsageQuotaProvider` ✅
- **Before**: Used local SharedPreferences `UsageQuotaService`
- **After**: Uses Firestore `SubscriptionCreditsService`
- **Maintains**: Legacy API compatibility for existing UI code

### 4. Updated `AppAccessProvider` ✅
- **Before**: Hardcoded `hasPremiumAccess = true`
- **After**: Uses actual RevenueCat entitlement status
- Now properly gates features based on subscription

### 5. Documentation ✅
- Created comprehensive architecture guide
- Included data flow examples
- Testing scenarios
- Troubleshooting guide
- Migration notes

## How It Works

```
USER SUBSCRIBES → REVENUECAT WEBHOOK → FIRESTORE UPDATE → CLIENT STREAM → UI UPDATE
                                               ↓
                                  Monthly reset on period expiration
                                               ↓
                                    Consumption tracked in Firestore
```

## Monthly Reset Logic

**Event-Driven (No Scheduled Jobs!)**

1. RevenueCat tracks billing period end date
2. Client detects when current time > period end
3. Auto-resets consumed to 0, updates period dates
4. Happens on:
   - Every Firestore watch event
   - Manual fetch
   - Before consumption

## Architecture Benefits

✅ **RevenueCat as authority** - Subscription truth lives in RevenueCat  
✅ **Minimal local state** - Client only caches, doesn't own data  
✅ **Auto-sync on events** - Webhook keeps Firestore in sync  
✅ **Period-based reset** - No scheduled jobs needed  
✅ **Offline resilience** - Firestore cache works offline  
✅ **Fail-closed security** - Defaults to gated when unavailable  

## Firestore Structure

```
users/{uid}/
  └── subscription/
      └── current/
          ├── status: 'active' | 'cancelled' | 'expired' | 'free'
          ├── tier: 'premium_monthly' | 'premium_annual' | 'free'
          ├── productId: 'premium_monthly'
          ├── currentPeriodStart: Timestamp
          ├── currentPeriodEnd: Timestamp
          ├── monthlyAllowance: 100
          ├── consumed: 0
          └── lastSyncedFromRC: Timestamp
```

## Configuration

**Tier Allowances (Backend)**:
```typescript
const TIER_ALLOWANCES = {
  'premium_monthly': 100,
  'premium_annual': 100,
  'free': 10,
};
```

**Product IDs**:
- `premium_monthly` - 100 credits/month
- `premium_annual` - 100 credits/month
- `free` - 10 credits/month (fallback)

## Testing Checklist

- [ ] Configure RevenueCat webhook URL in dashboard
- [ ] Set `RC_WEBHOOK_SECRET` environment variable
- [ ] Test purchase in RevenueCat sandbox
- [ ] Verify Firestore `users/{uid}/subscription/current` created
- [ ] Check client receives credits
- [ ] Manually set `currentPeriodEnd` to past date
- [ ] Verify auto-reset on app open
- [ ] Test consumption and quota exceeded
- [ ] Test cancellation flow

## Next Steps

1. **Deploy webhook** - Ensure Vercel function is deployed with env vars
2. **Configure RevenueCat** - Add webhook URL to RevenueCat dashboard
3. **Test in sandbox** - Use RevenueCat test environment
4. **Monitor logs** - Check Vercel and RevenueCat for errors
5. **Production rollout** - Enable for real users

## Breaking Changes

⚠️ **Important for existing users**:

- `UsageQuotaProvider.quota` now returns `SubscriptionCredits` (not `UsageQuota`)
- `consumeRequests()` method removed - use `consume()` instead
- `refund()` no longer supported (managed by RevenueCat lifecycle)
- Legacy getters maintained for UI compatibility

## Files Modified

✅ `api/rc/webhook.ts` - Enhanced webhook with period tracking  
✅ `lib/services/subscription_credits_service.dart` - New Firestore service  
✅ `lib/providers/usage_quota_provider.dart` - Updated to use new service  
✅ `lib/providers/app_access_provider.dart` - Uses real subscription status  
✅ `docs/revenuecat_monthly_credits_architecture.md` - Full documentation  

## Monitoring

**Check webhook health**:
- Vercel logs: `/api/rc/webhook` function
- RevenueCat events: Firestore `revenuecat_events` collection
- User subscriptions: Firestore `users/{uid}/subscription/current`

**Debug commands**:
```dart
// Force refresh credits
await quotaProvider.refresh();

// Check current state
print('Remaining: ${quotaProvider.remaining}');
print('Allowance: ${quotaProvider.limit}');
print('Status: ${quotaProvider.credits?.status}');
```

## Support

See full documentation: `docs/revenuecat_monthly_credits_architecture.md`

For troubleshooting, check:
1. RevenueCat dashboard → Events
2. Vercel logs → `/api/rc/webhook`
3. Firestore → `revenuecat_events` collection
4. Firestore → `users/{uid}/subscription/current` document
