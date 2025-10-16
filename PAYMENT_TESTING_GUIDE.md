# Payment Testing Guide - iOS Production Build

## Quick Setup for Payment Testing

### 1. Xcode Configuration (Already Done)
- ✅ StoreKit configuration file: `ios/storekit.storekit`
- ✅ Product ID configured: `com.cognify.credits.500`
- ✅ Development team set: `FKBTSU84AY`
- ✅ Bundle ID: `com.umerfarooq1995.cognify-flutter`

### 2. Testing on iOS Simulator

#### Option A: Using Xcode (Recommended)
1. **Open Xcode** (already opened): `ios/Runner.xcworkspace`
2. **Select Simulator**: Choose iPhone 16 Plus or iPad simulator
3. **Configure StoreKit Testing**:
   - Go to `Product` → `Scheme` → `Edit Scheme`
   - Select `Run` → `Options` tab
   - Set `StoreKit Configuration` to `storekit.storekit`
4. **Run the app**: Press `Cmd+R` or click the play button

#### Option B: Using Flutter CLI
```bash
# Run on iPhone simulator
flutter run -d "iPhone 16 Plus" --release

# Run on iPad (when connected)
flutter run -d "iPad" --release
```

### 3. Testing on Physical iPad

#### Prerequisites:
- iPad must be unlocked
- iPad must be in Developer Mode
- iPad must be connected via cable or same WiFi network

#### Steps:
1. **Enable Developer Mode on iPad**:
   - Go to Settings → Privacy & Security → Developer Mode
   - Turn on Developer Mode
   - Restart iPad when prompted

2. **Connect iPad**:
   ```bash
   # Check if iPad is detected
   flutter devices
   
   # Run on iPad
   flutter run -d "iPad" --release
   ```

### 4. Payment Testing Process

#### In the App:
1. **Navigate to Credits/Purchase Screen**
2. **Test the 500 Credits Pack**:
   - Product ID: `com.cognify.credits.500`
   - Price: $4.99
   - Type: Consumable

#### StoreKit Testing Features:
- **No real money charged** - StoreKit testing uses sandbox
- **Instant purchases** - No waiting for App Store processing
- **Test different scenarios**:
  - Successful purchases
  - Failed purchases
  - Cancelled purchases
  - Network errors

### 5. RevenueCat Configuration

Your app is configured with:
- **iOS API Key**: `appl_YEqixFmxSRzmfBQeDEzEVrdHzfa`
- **Product ID**: `com.cognify.credits.500`
- **Testing Mode**: Enabled

### 6. Troubleshooting

#### If payments don't work:
1. **Check StoreKit Configuration**:
   - Ensure `storekit.storekit` is selected in Xcode scheme
   - Verify product ID matches exactly

2. **Check RevenueCat**:
   - Verify API key is correct
   - Check product ID in RevenueCat dashboard

3. **Check Device/Simulator**:
   - Ensure device is signed in with Apple ID
   - For simulator: Use test Apple ID
   - For device: Use sandbox Apple ID

#### Common Issues:
- **"Product not found"**: Check product ID spelling
- **"Purchase failed"**: Check StoreKit configuration
- **"Network error"**: Check internet connection

### 7. Testing Scenarios

#### Test These Flows:
1. **Happy Path**:
   - Open app → Go to credits → Purchase 500 credits → Success

2. **Error Handling**:
   - Cancel purchase mid-flow
   - Test with no internet
   - Test with invalid product

3. **Edge Cases**:
   - Multiple rapid purchases
   - Purchase while offline
   - App backgrounding during purchase

### 8. Production vs Testing

#### Current Setup (Testing):
- ✅ StoreKit testing enabled
- ✅ Sandbox environment
- ✅ No real charges
- ✅ Instant processing

#### For Real Production:
- Update RevenueCat API keys to production
- Remove StoreKit testing configuration
- Test with real App Store Connect

## Quick Commands

```bash
# Clean and rebuild
flutter clean && flutter pub get

# Build for iOS
flutter build ios --release --no-codesign

# Run on simulator
flutter run -d "iPhone 16 Plus" --release

# Run on iPad
flutter run -d "iPad" --release

# Check devices
flutter devices
```

## Next Steps

1. **Test on Simulator**: Use Xcode with StoreKit configuration
2. **Test on iPad**: Enable Developer Mode and run Flutter app
3. **Verify Payments**: Test the complete purchase flow
4. **Check RevenueCat**: Verify purchases appear in RevenueCat dashboard

---

**Note**: This setup uses StoreKit testing, so no real money will be charged during testing.
