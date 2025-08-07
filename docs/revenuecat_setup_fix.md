# RevenueCat Setup Fix - Resolving Configuration Errors

## Current Issue
The app is showing "Purchase failed: Exception: No packages available" because:
1. Invalid RevenueCat API key format
2. Products not properly configured in RevenueCat dashboard
3. Products not created in Google Play Console

## Step-by-Step Fix

### 1. RevenueCat Dashboard Setup

#### A. Get the Correct API Key
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Navigate to **Apps & providers**
3. Select your Android app
4. Go to **SDK API Keys (Client)**
5. Copy the **Android SDK API Key** (starts with `apx_`)

#### B. Create Products in RevenueCat
1. Go to **Products** in RevenueCat dashboard
2. Create two products:
   - Product ID: `premium_monthly`
   - Product ID: `premium_annual`
3. Set up the Google Play Console integration for each product

#### C. Create Entitlement
1. Go to **Entitlements** in RevenueCat dashboard
2. Create entitlement with ID: `premium`
3. Configure the entitlement to grant access to premium features

#### D. Create Offering
1. Go to **Offerings** in RevenueCat dashboard
2. Create offering with ID: `default`
3. Add packages for both `premium_monthly` and `premium_annual` products

### 2. Google Play Console Setup

#### A. Create In-App Products
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to **Monetize** → **Products** → **Subscriptions**
4. Create two subscriptions:
   - Product ID: `premium_monthly`
   - Product ID: `premium_annual`
5. Set pricing and subscription details
6. **Important**: Make sure the product IDs exactly match what's in RevenueCat

#### B. Link to RevenueCat
1. In Google Play Console, go to **Setup** → **API access**
2. Ensure RevenueCat has access to your app's billing data

### 3. Update App Configuration

#### A. Replace API Key
1. Open `lib/config/subscriptions_config.dart`
2. Replace the placeholder with your real API key:
   ```dart
   static const String rcPublicKeyAndroid = 'apx_your_actual_key_here';
   ```

#### B. Verify Product IDs
Ensure these match exactly in all three places:
- `lib/config/subscriptions_config.dart` (lines 15-16)
- RevenueCat dashboard products
- Google Play Console subscriptions

### 4. Test the Fix

#### A. Clean and Rebuild
```bash
flutter clean
flutter pub get
flutter run
```

#### B. Test Flow
1. Open the app
2. Navigate to a premium feature
3. Verify the paywall loads without errors
4. Test the purchase flow

## Expected Results

After completing these steps:
- ✅ No more "ConfigurationError" in logs
- ✅ Offerings load successfully
- ✅ Products show with correct pricing
- ✅ Purchase flow works end-to-end

## Troubleshooting

### Still Getting Configuration Errors?
1. **Verify API Key**: Ensure it starts with `apx_` and is the Client key, not Secret key
2. **Check Product IDs**: Must match exactly across RevenueCat, Google Play, and app config
3. **Wait for Sync**: Google Play changes can take up to 24 hours to sync
4. **Test Account**: Use a test account in Google Play Console for testing

### Common Mistakes
- ❌ Using Secret API key instead of Client API key
- ❌ Mismatched product IDs between platforms
- ❌ Not waiting for Google Play changes to propagate
- ❌ Using production products for testing

## Next Steps

Once the basic setup works:
1. Test with real purchases (use test accounts)
2. Set up iOS configuration
3. Configure analytics and webhooks
4. Set up tester grants for development

## Support Resources

- [RevenueCat Configuration Guide](https://docs.revenuecat.com/docs/configuration)
- [Google Play Billing Setup](https://developer.android.com/google/play/billing)
- [RevenueCat Error Codes](https://docs.revenuecat.com/docs/errors) 