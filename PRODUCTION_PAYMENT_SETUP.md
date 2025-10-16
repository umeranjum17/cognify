# Production Payment Testing Setup

## Step 1: App Store Connect Configuration

### 1.1 Create Products in App Store Connect
1. **Go to App Store Connect**: https://appstoreconnect.apple.com
2. **Select your app**: `com.umerfarooq1995.cognify-flutter`
3. **Go to Features → In-App Purchases**
4. **Create new consumable product**:
   - **Product ID**: `com.cognify.credits.500`
   - **Reference Name**: `500 Credits Pack`
   - **Product Type**: Consumable
   - **Price**: $4.99 (or your desired price)
   - **Description**: `500 AI credits to use for chat and requests in the app.`

### 1.2 Submit for Review
- Submit the in-app purchase for App Store review
- **Status must be "Ready to Submit" or "Approved"** for testing

## Step 2: RevenueCat Production Setup

### 2.1 Configure Products in RevenueCat
1. **Go to RevenueCat Dashboard**: https://app.revenuecat.com
2. **Select your project**
3. **Go to Products tab**
4. **Add/Update product**:
   - **Product ID**: `com.cognify.credits.500`
   - **Store**: App Store
   - **Type**: Consumable

### 2.2 Verify API Keys
- **iOS Public Key**: `appl_YEqixFmxSRzmfBQeDEzEVrdHzfa`
- **Android Public Key**: `goog_bPnaGqdwHbhqoOYLYupZBaPWySp`

## Step 3: TestFlight Setup

### 3.1 Create TestFlight Build
1. **Archive your app in Xcode**:
   - Open `ios/Runner.xcworkspace`
   - Select "Any iOS Device" as target
   - Product → Archive
   - Upload to App Store Connect

2. **Configure TestFlight**:
   - Go to App Store Connect → TestFlight
   - Select your build
   - Add internal/external testers
   - Enable "In-App Purchases" testing

### 3.2 Sandbox Testing
- **Create Sandbox Apple ID**: https://developer.apple.com/account
- **Add sandbox tester**: App Store Connect → Users and Access → Sandbox Testers
- **Use sandbox Apple ID** on test device

## Step 4: Production Build Configuration

### 4.1 Update Flutter Configuration
```dart
// lib/config/purchases_config.dart
class PurchasesConfig {
  static const bool purchasesEnabled = true;
  
  // Production keys (already configured)
  static const String rcPublicKeyIOS = 'appl_YEqixFmxSRzmfBQeDEzEVrdHzfa';
  static const String rcPublicKeyAndroid = 'goog_bPnaGqdwHbhqoOYLYupZBaPWySp';
  
  // Product IDs (must match App Store Connect)
  static const String productCredits500 = 'com.cognify.credits.500';
}
```

### 4.2 Build for Production
```bash
# Clean and build
flutter clean
flutter pub get

# Build for iOS (production)
flutter build ios --release

# Archive in Xcode for TestFlight
```

## Step 5: Testing Process

### 5.1 TestFlight Testing
1. **Install TestFlight** on your device
2. **Install your app** from TestFlight
3. **Sign in with sandbox Apple ID**
4. **Test purchase flow**:
   - Navigate to credits screen
   - Tap "500 Credits Pack"
   - Complete purchase with sandbox Apple ID
   - Verify credits are added

### 5.2 RevenueCat Verification
1. **Check RevenueCat Dashboard**:
   - Go to RevenueCat → Events
   - Look for purchase events
   - Verify customer info updates

### 5.3 Backend Verification
1. **Check your backend logs**:
   - Verify RevenueCat webhooks are received
   - Check credit balance updates
   - Verify purchase validation

## Step 6: Production Deployment

### 6.1 App Store Review
1. **Submit for review** with in-app purchases
2. **Wait for approval** (usually 24-48 hours)
3. **Release to App Store**

### 6.2 Monitor Production
1. **RevenueCat Analytics**:
   - Track purchase events
   - Monitor conversion rates
   - Check for errors

2. **App Store Connect**:
   - Monitor sales reports
   - Check for refunds
   - Review customer feedback

## Important Notes

### Sandbox vs Production
- **Sandbox**: Test environment, no real money
- **Production**: Real App Store, real money
- **TestFlight**: Uses sandbox for testing

### Testing Requirements
- **Sandbox Apple ID**: Required for testing
- **TestFlight**: Required for real App Store testing
- **Approved Products**: Must be approved in App Store Connect

### Security Considerations
- **Never use production API keys** in development
- **Always test in sandbox** before production
- **Validate purchases** on your backend
- **Handle refunds** and cancellations

## Troubleshooting

### Common Issues
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

### Debug Steps
1. **Check logs** in Xcode console
2. **Verify RevenueCat** dashboard
3. **Test with different** sandbox accounts
4. **Check App Store Connect** product status
