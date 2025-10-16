# Real Production Payment Testing Guide

## 🎯 **What You Need for REAL Production Testing**

### **Current Status:**
- ✅ RevenueCat configured with production keys
- ✅ Product ID: `com.cognify.credits.500` 
- ✅ Bundle ID: `com.umerfarooq1995.cognify-flutter`
- ❌ **Missing**: App Store Connect product setup
- ❌ **Missing**: TestFlight build

---

## **Step 1: App Store Connect Setup (REQUIRED)**

### 1.1 Create In-App Purchase Product
1. **Go to**: https://appstoreconnect.apple.com
2. **Select your app**: `com.umerfarooq1995.cognify-flutter`
3. **Navigate to**: Features → In-App Purchases
4. **Click**: "+" to create new product
5. **Configure**:
   ```
   Product ID: com.cognify.credits.500
   Reference Name: 500 Credits Pack
   Product Type: Consumable
   Price: $4.99 (or your desired price)
   Description: 500 AI credits to use for chat and requests in the app.
   ```

### 1.2 Submit for Review
- **Status**: Must be "Ready to Submit" or "Approved"
- **Review time**: Usually 24-48 hours
- **Required for**: Real App Store testing

---

## **Step 2: RevenueCat Production Setup**

### 2.1 Configure Product in RevenueCat
1. **Go to**: https://app.revenuecat.com
2. **Select your project**
3. **Navigate to**: Products tab
4. **Add/Update product**:
   ```
   Product ID: com.cognify.credits.500
   Store: App Store
   Type: Consumable
   ```

### 2.2 Verify Configuration
- **iOS Public Key**: `appl_YEqixFmxSRzmfBQeDEzEVrdHzfa` ✅
- **Android Public Key**: `goog_bPnaGqdwHbhqoOYLYupZBaPWySp` ✅

---

## **Step 3: Create TestFlight Build**

### 3.1 Build for TestFlight
```bash
# Clean and prepare
cd /Users/umerfaroq/Documents/GitHub/cognify-flutter
flutter clean
flutter pub get

# Build iOS release
flutter build ios --release
```

### 3.2 Archive in Xcode
1. **Open Xcode**: `ios/Runner.xcworkspace`
2. **Select**: "Any iOS Device" as target
3. **Product** → **Archive**
4. **Upload to App Store Connect**

### 3.3 Configure TestFlight
1. **Go to**: App Store Connect → TestFlight
2. **Select your build**
3. **Add testers**:
   - Internal testers (your team)
   - External testers (up to 10,000)
4. **Enable**: "In-App Purchases" testing

---

## **Step 4: Sandbox Testing Setup**

### 4.1 Create Sandbox Apple ID
1. **Go to**: https://developer.apple.com/account
2. **Navigate to**: Users and Access → Sandbox Testers
3. **Create sandbox tester**:
   ```
   Email: your-test-email@example.com
   Password: (create secure password)
   First Name: Test
   Last Name: User
   Country: United States
   ```

### 4.2 Configure Test Device
1. **Sign out** of App Store on test device
2. **Install TestFlight** from App Store
3. **Install your app** from TestFlight
4. **When prompted for purchase**: Use sandbox Apple ID

---

## **Step 5: Real Production Testing**

### 5.1 TestFlight Testing Process
1. **Open TestFlight** on your device
2. **Install your app**
3. **Open app** and sign in
4. **Navigate to credits/purchase screen**
5. **Tap "500 Credits Pack"**
6. **Complete purchase** with sandbox Apple ID
7. **Verify**: Credits are added to account

### 5.2 What Happens During Testing
- ✅ **Real App Store environment**
- ✅ **Real RevenueCat integration**
- ✅ **Real purchase flow**
- ✅ **No real money charged** (sandbox)
- ✅ **Real webhooks to your backend**

---

## **Step 6: Verification & Monitoring**

### 6.1 RevenueCat Dashboard
1. **Go to**: RevenueCat → Events
2. **Look for**: Purchase events
3. **Verify**: Customer info updates
4. **Check**: Webhook deliveries

### 6.2 Backend Verification
1. **Check logs**: RevenueCat webhooks received
2. **Verify**: Credit balance updates
3. **Confirm**: Purchase validation working

### 6.3 App Store Connect
1. **Go to**: Sales and Trends
2. **Check**: Sandbox sales reports
3. **Monitor**: TestFlight feedback

---

## **Step 7: Production Deployment**

### 7.1 Final App Store Submission
1. **Submit app** for App Store review
2. **Include**: In-app purchase in submission
3. **Wait for approval**: Usually 24-48 hours
4. **Release**: To App Store

### 7.2 Monitor Production
1. **RevenueCat Analytics**: Track real purchases
2. **App Store Connect**: Monitor sales
3. **Backend Logs**: Verify webhook processing

---

## **Quick Commands**

```bash
# Build for production
flutter clean && flutter pub get
flutter build ios --release

# Archive in Xcode
open ios/Runner.xcworkspace
# Then: Product → Archive

# Check devices
flutter devices

# Run on device (if needed)
flutter run -d "Your Device Name" --release
```

---

## **Important Notes**

### **Sandbox vs Production**
- **Sandbox**: Test environment, no real money
- **Production**: Real App Store, real money
- **TestFlight**: Uses sandbox for testing

### **Testing Requirements**
- **Sandbox Apple ID**: Required for testing
- **TestFlight**: Required for real App Store testing
- **Approved Products**: Must be approved in App Store Connect

### **Security**
- **Never use production API keys** in development
- **Always test in sandbox** before production
- **Validate purchases** on your backend
- **Handle refunds** and cancellations

---

## **Troubleshooting**

### **Common Issues**
1. **"Product not found"**:
   - Check product ID spelling
   - Verify product is approved in App Store Connect
   - Check RevenueCat configuration

2. **"Purchase failed"**:
   - Use sandbox Apple ID
   - Check internet connection
   - Verify App Store Connect status

3. **"RevenueCat error"**:
   - Check API keys
   - Verify product configuration
   - Check network connectivity

### **Debug Steps**
1. **Check logs** in Xcode console
2. **Verify RevenueCat** dashboard
3. **Test with different** sandbox accounts
4. **Check App Store Connect** product status

---

## **Next Steps**

1. **Create product** in App Store Connect
2. **Submit for review** (wait for approval)
3. **Create TestFlight build**
4. **Set up sandbox testing**
5. **Test real purchase flow**
6. **Deploy to production**

**This is the ONLY way to test real production payments!** 🚀
