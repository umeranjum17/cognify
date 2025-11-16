# App Store Review IAP Fix Guide

## Problem Summary

App Store rejected the app with **Guideline 2.1 - Performance - App Completeness**:
> "We found that your in-app purchase products exhibited one or more bugs which create a poor user experience. Specifically, **no credit packs are available to purchase when tapping 'Buy Credits'**."

## Why It Works in Simulator/TestFlight But Not in App Store Review

**This is a critical difference!** Here's why:

### Simulator/TestFlight (Sandbox Environment):
- ✅ Products work even if not fully approved
- ✅ Products work even if "Cleared for Sale" is OFF
- ✅ Works without Paid Apps Agreement signed
- ✅ Uses sandbox App Store servers
- ✅ RevenueCat can show products from sandbox

### App Store Review (Production Environment):
- ❌ Products MUST be approved and "Cleared for Sale"
- ❌ **Paid Apps Agreement MUST be signed** (Apple specifically mentions this!)
- ❌ Uses production App Store servers
- ❌ RevenueCat must have production products configured
- ❌ Products must be included in the app submission

## Root Causes

Based on the codebase analysis, the issue is that **RevenueCat offerings are returning empty** (no packages available) in the production environment. This typically happens when:

1. **App Store Localization Rejected** - ⚠️ **YOUR CURRENT ISSUE!** Your product shows "Rejected" status in App Store Localization section. This prevents products from appearing during review.
2. **Paid Apps Agreement not signed** - This is also critical! Apple specifically mentioned this in the review feedback.
3. **Products not "Cleared for Sale"** - Products must be enabled in App Store Connect for production
4. **Products not approved** - Products must be approved before they appear in production
5. **Products not linked to RevenueCat Offering** - Products exist in App Store Connect but aren't added to a RevenueCat Offering
6. **RevenueCat Offering not configured** - The "default" offering needs to have packages attached
7. **RevenueCat using sandbox products** - Production environment needs production products configured

## Step-by-Step Fix

### 1. **CRITICAL: Sign Paid Apps Agreement** ⚠️

**This is the #1 most common cause!** Apple specifically mentioned this in your review feedback.

Go to **App Store Connect** → **Agreements, Tax, and Banking** → **Paid Apps Agreement**

**Required Actions:**
- ✅ **Sign the Paid Apps Agreement** (if not already signed)
- ✅ Complete all tax and banking information
- ✅ Wait for agreement to be activated (can take 24-48 hours)

**Why This Matters:**
- Without this agreement signed, in-app purchases are **completely disabled** in production
- They will work in sandbox/TestFlight but fail during App Store review
- This is the most common reason for IAP failures in review

### 2. Verify App Store Connect Products

Go to **App Store Connect** → **Your App** → **Features** → **In-App Purchases**

**⚠️ CRITICAL: Check Localization Status**
- **Your product shows "Rejected" status in App Store Localization!**
- This is likely why products aren't available during review
- Go to **App Store Localization** section and check the rejection reason
- Fix the issue and resubmit the localization

**Required Check:**
- ✅ Products are **Consumable** type (not Subscription)
- ✅ **App Store Localization status is "Ready to Submit" or "Approved"** (NOT "Rejected")
- ✅ Products are **"Cleared for Sale"** (toggle ON) - **CRITICAL for production**
- ✅ Products are **Approved** (status should show "Ready to Submit" or "Approved")
- ✅ Products are **included in your app submission** (linked to the app version)
- ✅ Products have **Review Screenshot** uploaded (required for review)
- ✅ Products have **Review Notes** explaining the purchase flow

**Your Current Products:**
- `com.cognify.credits.500` - 500 Credits Pack ($4.99)

**Recommended Additional Products:**
- `com.cognify.credits.1000` - 1000 Credits Pack ($9.99)
- `com.cognify.credits.2000` - 2000 Credits Pack ($19.99)
- `com.cognify.credits.5000` - 5000 Credits Pack ($49.99)

### 3. Configure RevenueCat Dashboard

**Critical Steps:**

1. **Log into RevenueCat Dashboard** → Select your project

2. **Add Products to RevenueCat:**
   - Go to **Products** tab
   - Click **Add Product**
   - For each product ID (`com.cognify.credits.500`, etc.):
     - Enter the exact **Product ID** from App Store Connect
     - Select **iOS** platform
     - Save

3. **Create/Update Offering:**
   - Go to **Offerings** tab
   - Find or create the **"default"** offering (or the one your app uses)
   - Click **Add Package** or **Edit Offering**
   - For each product:
     - Create a **Package** with identifier (e.g., `credits_500`)
     - Attach the corresponding **Product** (e.g., `com.cognify.credits.500`)
   - **Save the offering**

4. **Verify Offering Structure:**
   ```
   Offering: "default"
   ├── Package: "credits_500" → Product: "com.cognify.credits.500"
   ├── Package: "credits_1000" → Product: "com.cognify.credits.1000"
   ├── Package: "credits_2000" → Product: "com.cognify.credits.2000"
   └── Package: "credits_5000" → Product: "com.cognify.credits.5000"
   ```

### 4. Verify Backend Receipt Validation

The review feedback specifically mentions receipt validation. Your backend must handle both production and sandbox receipts.

**Current Implementation:** ✅ Your webhook handler (`backend/src/routes/webhook.ts`) already handles sandbox via `RC_WEBHOOK_CONFIG.allowSandbox: true`

**Ensure these are set in environment variables:**
```bash
RC_WEBHOOK_SECRET=your_webhook_secret
RC_SIGNATURE_SECRET=your_signature_secret  # Optional but recommended
RC_REQUIRE_SIGNATURE=false  # Set to true in production for security
```

**Verify Webhook URL in RevenueCat:**
- Go to RevenueCat Dashboard → **Project Settings** → **Webhooks**
- Ensure webhook URL is: `https://your-backend.com/api/rc/webhook`
- Test webhook delivery

### 5. Test Before Resubmission

**Important:** You cannot fully test production environment before submission, but you can verify:

**Sandbox Testing (Required):**

1. **Create Sandbox Test Account:**
   - App Store Connect → **Users and Access** → **Sandbox Testers**
   - Create a test account (use a real email, but it's isolated)

2. **Test on Device:**
   - Sign out of App Store on test device
   - Open your app
   - When prompted to buy, use the sandbox test account
   - Verify products load correctly
   - Complete a test purchase
   - Verify credits are added to account

3. **Check Logs:**
   - Verify RevenueCat SDK logs show offerings loaded
   - Verify backend webhook receives purchase events
   - Verify credits are added to Firestore

**Expected Behavior:**
- ✅ "Buy Credits" opens sheet with available packs
- ✅ All configured credit packs are visible
- ✅ Purchase flow completes successfully
- ✅ Credits are added to user balance
- ✅ No "No credit packs available" error

### 6. Additional Checklist

**Before Resubmission - Production Requirements:**

- [ ] **Paid Apps Agreement is signed and active** (MOST IMPORTANT!)
- [ ] All products are "Cleared for Sale" in App Store Connect
- [ ] All products are approved (not just "Waiting for Review")
- [ ] All products are included in your app submission
- [ ] All products have review screenshots uploaded
- [ ] All products have review notes explaining the purchase
- [ ] Products are added to RevenueCat dashboard
- [ ] Products are linked to an Offering in RevenueCat
- [ ] RevenueCat offering is marked as "current"
- [ ] RevenueCat webhook URL is configured and working
- [ ] Backend webhook handler accepts sandbox events
- [ ] Tested sandbox purchase flow end-to-end
- [ ] Verified credits are added correctly after purchase
- [ ] Offering identifier matches app code (`"default"` or configured value)

### 7. Common Issues & Solutions

**Issue: "Works in TestFlight but not in App Store review"**

**Most Likely Causes (in order of likelihood):**
1. **App Store Localization Rejected** - ⚠️ **YOUR ISSUE!** Check the App Store Localization section - if status is "Rejected", fix and resubmit
2. **Paid Apps Agreement not signed** - Check Agreements, Tax, and Banking section
3. **Products not "Cleared for Sale"** - Toggle must be ON for production
4. **Products not approved** - Status must be "Approved" not just "Waiting for Review"
5. **Products not included in app submission** - Must link products to app version
6. **RevenueCat using sandbox products** - Verify production products in RevenueCat dashboard

**How to Fix Localization Rejection:**
1. Go to your in-app purchase → **App Store Localization** section
2. Click on the rejected localization (English (U.S.))
3. Review the rejection reason/message
4. Common fixes:
   - Update display name to be more descriptive
   - Ensure description clearly explains the purchase
   - Remove any prohibited content
   - Match the description to what's in your review notes
5. Save and resubmit the localization
6. Wait for approval (usually 24-48 hours)

**Issue: "No credit packs available" still appears**

**Solutions:**
1. **Check RevenueCat API Key:**
   - Verify `PurchasesConfig.rcPublicKeyIOS` is correct
   - Ensure it's the **public SDK key** (not secret key)
   - Key should start with `appl_`

2. **Check Offering Identifier:**
   - App uses `"default"` offering (see `PurchasesConfig.offeringDefault`)
   - Ensure RevenueCat has an offering with identifier `"default"`
   - Or update app code to match your RevenueCat offering ID

3. **Check Product IDs Match Exactly:**
   - App Store Connect Product ID: `com.cognify.credits.500`
   - RevenueCat Product ID: `com.cognify.credits.500` (must match exactly)
   - Package identifier can be different (e.g., `credits_500`)

4. **Check Network Connectivity:**
   - RevenueCat SDK needs internet to fetch offerings
   - Check if device/emulator has network access
   - Check RevenueCat service status

**Issue: Products load in sandbox but not in production**

**Solution:**
- Products must be "Cleared for Sale" in App Store Connect
- Products must be approved (even consumables need review)
- Wait 24-48 hours after enabling products for App Store to sync

**Issue: Purchase fails during review**

**Solution:**
- Ensure backend webhook accepts sandbox environment
- Check `RC_WEBHOOK_CONFIG.allowSandbox: true` in config
- Verify webhook URL is accessible from internet (not localhost)

## Code Verification

Your app code structure is correct:

✅ **RevenueCat Service** (`lib/services/revenuecat_service.dart`):
- Properly initializes with iOS key
- Fetches offerings with error handling
- Handles timeouts gracefully

✅ **Credits Purchase Provider** (`lib/providers/credits_purchase_provider.dart`):
- Initializes RevenueCat on app start
- Refreshes offerings when user logs in
- Handles authentication state changes

✅ **Purchase Sheet** (`lib/widgets/quick_credit_purchase_sheet.dart`):
- Shows loading state while fetching offerings
- Displays error message if no packages available
- Handles purchase flow correctly

## Next Steps

1. **Fix RevenueCat Configuration** (Steps 1-2 above) - This is the most likely issue
2. **Test Thoroughly** (Step 4) - Use sandbox test account
3. **Resubmit to App Store** with a note explaining the fix
4. **Monitor Review** - Apple should be able to complete test purchases now

## Resubmission Notes

When resubmitting, include this note in the review notes:

> "We have resolved the in-app purchase issue. The Paid Apps Agreement has been signed and all credit pack products are now properly configured:
> - All products are 'Cleared for Sale' and approved in App Store Connect
> - All products are properly configured in RevenueCat and linked to the default offering
> - Backend webhook is configured to handle both sandbox and production receipts
> - We have tested the purchase flow in sandbox environment and verified that all products load correctly and purchases complete successfully
> 
> Please test the 'Buy Credits' feature to verify the fix. The products should now be available for purchase during review."

**Key Points to Mention:**
- Paid Apps Agreement is signed
- Products are "Cleared for Sale"
- Products are approved and included in submission
- RevenueCat is properly configured
- Tested in sandbox (you can't fully test production, but this shows effort)

## References

- [Apple In-App Purchase Guide](https://developer.apple.com/in-app-purchase/)
- [RevenueCat iOS Setup](https://www.revenuecat.com/docs/ios)
- [RevenueCat Offerings](https://www.revenuecat.com/docs/offerings)
- [App Store Review Guidelines 2.1](https://developer.apple.com/app-store/review/guidelines/#performance)

