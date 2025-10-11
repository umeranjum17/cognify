# Credit-Based IAP Setup Guide

## Overview
You need to create **consumable** (one-time purchase) credit packs instead of auto-renewing subscriptions in both app stores and RevenueCat.

---

## Part 1: App Store Connect (iOS)

### 1. Sign in to App Store Connect
- Go to https://appstoreconnect.apple.com
- Sign in with your Apple Developer account
- Select your app (Cognify)

### 2. Navigate to In-App Purchases
- Click on your app
- Go to **Features** tab
- Click **In-App Purchases**

### 3. Create New Consumable Products

Click **Create** and select **Consumable** (not Subscription!)

#### Credit Pack 1: 500 Credits ($5)
- **Reference Name**: `500 Credits Pack`
- **Product ID**: `com.cognify.credits.500` (or your bundle ID format)
- **Price**: $4.99 USD (Tier 5)
- **Display Name**: `500 Credits`
- **Description**: `500 AI credits for Cognify. Use across all models and features. Credits never expire.`
- **Review Screenshot**: Upload a screenshot showing the purchase flow
- **Review Notes**: Optional explanation

#### Credit Pack 2: 1000 Credits ($10)
- **Reference Name**: `1000 Credits Pack`
- **Product ID**: `com.cognify.credits.1000`
- **Price**: $9.99 USD (Tier 10)
- **Display Name**: `1,000 Credits`
- **Description**: `1,000 AI credits for Cognify. Best value! Credits never expire.`

#### Credit Pack 3: 2000 Credits ($20)
- **Reference Name**: `2000 Credits Pack`
- **Product ID**: `com.cognify.credits.2000`
- **Price**: $19.99 USD (Tier 20)
- **Display Name**: `2,000 Credits`
- **Description**: `2,000 AI credits for Cognify. Popular choice! Credits never expire.`

#### Credit Pack 4: 5000 Credits ($50) [Optional]
- **Reference Name**: `5000 Credits Pack`
- **Product ID**: `com.cognify.credits.5000`
- **Price**: $49.99 USD (Tier 50)
- **Display Name**: `5,000 Credits`
- **Description**: `5,000 AI credits for Cognify. Maximum value! Credits never expire.`

### 4. Important Settings
- **Type**: Must be **Consumable** (allows repeat purchases)
- **Cleared for Sale**: Toggle ON after setup
- **Localization**: Add languages as needed

### 5. Submit for Review
- Each product needs approval before use
- Usually takes 24-48 hours

---

## Part 2: Google Play Console (Android)

### 1. Sign in to Google Play Console
- Go to https://play.google.com/console
- Select your app (Cognify)

### 2. Navigate to In-app products
- Go to **Monetize** → **Products** → **In-app products**

### 3. Create New Products

Click **Create product** for each credit pack:

#### Credit Pack 1: 500 Credits ($5)
- **Product ID**: `credits_500` (must match iOS for RevenueCat)
- **Name**: `500 Credits`
- **Description**: `500 AI credits for Cognify. Use across all models and features. Credits never expire.`
- **Status**: Active
- **Price**: $4.99 USD
  - Set default price
  - Google will convert to local currencies automatically

#### Credit Pack 2: 1000 Credits ($10)
- **Product ID**: `credits_1000`
- **Name**: `1,000 Credits`
- **Description**: `1,000 AI credits for Cognify. Best value! Credits never expire.`
- **Price**: $9.99 USD

#### Credit Pack 3: 2000 Credits ($20)
- **Product ID**: `credits_2000`
- **Name**: `2,000 Credits`
- **Description**: `2,000 AI credits for Cognify. Popular choice! Credits never expire.`
- **Price**: $19.99 USD

#### Credit Pack 4: 5000 Credits ($50) [Optional]
- **Product ID**: `credits_5000`
- **Name**: `5,000 Credits`
- **Description**: `5,000 AI credits for Cognify. Maximum value! Credits never expire.`
- **Price**: $49.99 USD

### 4. Important Notes
- **Type**: One-time products (not subscriptions)
- **Managed**: Yes (Google tracks purchase state)
- Products are immediately available (no review needed)

---

## Part 3: RevenueCat Dashboard Setup

### 1. Sign in to RevenueCat
- Go to https://app.revenuecat.com
- Select your Cognify project

### 2. Create Products

Navigate to **Products** in the left sidebar:

#### For Each Credit Pack:
1. Click **New** 
2. **Product Identifier (iOS)**: Use App Store Product ID
   - `com.cognify.credits.500`
   - `com.cognify.credits.1000`
   - `com.cognify.credits.2000`
   - `com.cognify.credits.5000`
3. **Product Identifier (Android)**: Use Play Store Product ID
   - `credits_500`
   - `credits_1000`
   - `credits_2000`
   - `credits_5000`
4. **Display Name**: `500 Credits`, `1000 Credits`, etc.
5. **Product Type**: **Consumable** (NOT subscription!)

### 3. Create an Offering

Navigate to **Offerings** → **Create new offering**:

1. **Offering Identifier**: `credit_packs` (or `default`)
2. **Display Name**: `Credit Packs`
3. **Description**: `Purchase AI credits for Cognify`

#### Add Packages to Offering:
1. Click **Add Package**
2. For each credit pack:
   - **Package Identifier**: `credits_500`, `credits_1000`, etc.
   - **Product**: Select the product you created
   - **Package Type**: Custom
3. Click **Save**

### 4. Set as Current Offering
- Toggle **Current** to ON for your offering
- This makes it the default offering fetched by the app

### 5. Configure Entitlements (Optional)
If you want to track "premium" access after credits purchase:
- Go to **Entitlements**
- Create entitlement: `credits_purchased`
- Attach to all credit pack products

---

## Part 4: Update Your App Code

### 1. Update Product IDs in Code

Edit `lib/config/subscriptions_config.dart`:

```dart
class SubscriptionsConfig {
  // RevenueCat public SDK keys
  static const String rcPublicKeyAndroid = 'goog_YOUR_KEY_HERE';
  static const String rcPublicKeyIOS = 'appl_YOUR_KEY_HERE';

  // Offering identifier
  static const String offeringDefault = 'credit_packs'; // or 'default'
  
  // Entitlement (optional)
  static const String entitlementPremium = 'premium';

  // Credit pack product IDs
  static const String credits500 = 'credits_500';    // Android
  static const String credits1000 = 'credits_1000';  // Android
  static const String credits2000 = 'credits_2000';  // Android
  static const String credits5000 = 'credits_5000';  // Android
  
  static const String credits500iOS = 'com.cognify.credits.500';    // iOS
  static const String credits1000iOS = 'com.cognify.credits.1000';  // iOS
  static const String credits2000iOS = 'com.cognify.credits.2000';  // iOS
  static const String credits5000iOS = 'com.cognify.credits.5000';  // iOS
}
```

### 2. Handle Purchase in Backend

When RevenueCat webhook fires after purchase, add credits to user account:

**Backend endpoint to implement** (`/api/revenuecat-webhook`):

```typescript
// Pseudo-code
app.post('/api/revenuecat-webhook', async (req, res) => {
  const event = req.body;
  
  if (event.type === 'NON_RENEWING_PURCHASE') {
    const userId = event.app_user_id;
    const productId = event.product_id;
    
    // Map product to credits
    const creditMap = {
      'credits_500': 500,
      'credits_1000': 1000,
      'credits_2000': 2000,
      'credits_5000': 5000,
      'com.cognify.credits.500': 500,
      'com.cognify.credits.1000': 1000,
      'com.cognify.credits.2000': 2000,
      'com.cognify.credits.5000': 5000,
    };
    
    const creditsToAdd = creditMap[productId] || 0;
    
    // Add credits to user's Firestore account
    await addCreditsToUser(userId, creditsToAdd);
    
    res.status(200).send('OK');
  }
});
```

---

## Part 5: Testing

### iOS Testing (Sandbox)
1. Add test account in App Store Connect → Users and Access → Sandbox Testers
2. Sign out of real Apple ID on device
3. When prompted during purchase, sign in with sandbox account
4. Purchase is free in sandbox mode

### Android Testing
1. Add test account email to Google Play Console → Setup → License Testing
2. Select "License Testing" response: **RESPOND_NORMALLY**
3. Test purchases are free
4. Use test cards for payment testing

### RevenueCat Testing
1. Use sandbox mode automatically when app is in debug
2. Check RevenueCat dashboard → Customers to see test purchases
3. Verify webhook is receiving events

---

## Part 6: Credit to Dollar Mapping

Based on your setup ($1 = 100 credits):

| Pack | Credits | Price | Value |
|------|---------|-------|-------|
| Starter | 500 | $4.99 | ~$5 |
| Popular | 1,000 | $9.99 | ~$10 |
| Best Value | 2,000 | $19.99 | ~$20 |
| Maximum | 5,000 | $49.99 | ~$50 |

---

## Part 7: Migration Notes

### Current Issues
- Your app is showing old subscription products (Premium Monthly/Annual)
- These need to be **deprecated** or **hidden** in RevenueCat

### Steps to Hide Old Products
1. Go to RevenueCat Dashboard → Offerings
2. Find the old subscription offering
3. Toggle **Current** to OFF
4. Set your new `credit_packs` offering as **Current**

### Clean Up Old Products (Optional)
- You can leave old subscriptions in stores (existing users keep access)
- Just don't include them in new offerings
- RevenueCat will only show current offerings to new users

---

## Part 8: Checklist

### App Store Connect ✓
- [ ] Created 4 consumable products
- [ ] Set prices for all products
- [ ] Added descriptions
- [ ] Submitted for review
- [ ] Products approved and live

### Google Play Console ✓
- [ ] Created 4 in-app products
- [ ] Set prices for all products
- [ ] Products set to Active

### RevenueCat ✓
- [ ] Created 4 products (iOS + Android mappings)
- [ ] Created credit_packs offering
- [ ] Added all 4 packages to offering
- [ ] Set offering as Current
- [ ] Old subscription offerings hidden

### Code ✓
- [ ] Updated SubscriptionsConfig.dart with new product IDs
- [ ] Theme fixed in QuickCreditPurchaseSheet
- [ ] Backend webhook handles credit additions
- [ ] Tested purchase flow

### Testing ✓
- [ ] iOS sandbox purchase tested
- [ ] Android test purchase tested
- [ ] Credits added to account after purchase
- [ ] RevenueCat webhook firing correctly

---

## Need Help?

**RevenueCat Documentation:**
- https://www.revenuecat.com/docs/getting-started
- https://www.revenuecat.com/docs/offerings
- https://www.revenuecat.com/docs/webhooks

**Contact:**
- RevenueCat Support: support@revenuecat.com
- Apple Developer: https://developer.apple.com/contact/
- Google Play Support: https://support.google.com/googleplay/android-developer/

---

## Summary

1. **Delete or hide** old subscription offerings in RevenueCat
2. **Create** 4 new consumable products in App Store Connect
3. **Create** 4 matching products in Google Play Console  
4. **Link** all products in RevenueCat dashboard
5. **Create** new offering with credit packs
6. **Set** new offering as current
7. **Update** app code with new product IDs
8. **Implement** backend webhook to add credits after purchase
9. **Test** with sandbox/test accounts
10. **Deploy** updated app

Your app will now show credit packs instead of subscriptions! 🎉

