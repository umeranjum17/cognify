# Fix Google Sign-In ApiException 10 on Android

## Step 1: Extract SHA-1 and SHA-256 from Your Custom Keystore

### Find your keystore alias first:
```bash
keytool -list -keystore /Users/umerfarooq/cognify-release-key.jks
```
This will show output like:
```
Keystore type: PKCS12
Keystore provider: SUN

Your keystore contains 1 entry

cognify, Dec 15, 2023, PrivateKeyEntry,
Certificate fingerprint (SHA-256): AA:BB:CC:...
```

Note the alias name (e.g., "cognify")

### Extract SHA-1 and SHA-256:
Replace `YOUR_ALIAS` with the actual alias from step above:
```bash
keytool -list -v -alias YOUR_ALIAS -keystore /Users/umerfarooq/cognify-release-key.jks
```

When prompted:
- Enter keystore password
- Enter key password (may be same as keystore password)

Look for these lines in the output:
```
Certificate fingerprints:
         SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:11:22:33:44
         SHA256: 11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00
```

Copy both the SHA1 and SHA256 values.

## Step 2: Add to Firebase Console

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select project: cognify-eb0a2
3. Click gear icon → Project settings
4. Under "Your apps", find the Android app with package: `com.umerfarooq1995.cognify_flutter`
5. Scroll down to "SHA certificate fingerprints"
6. Click "Add fingerprint"
7. Paste the SHA1 value (without "SHA1:" prefix)
8. Click "Add fingerprint" again
9. Paste the SHA256 value (without "SHA256:" prefix)
10. Click "Save" at the bottom

## Step 3: Download Updated google-services.json

1. Still in Firebase Console → Project settings
2. Under your Android app, click "Download google-services.json"
3. Replace the file at: `android/app/google-services.json` with the downloaded file

The new file should now contain an `oauth_client` section (unlike your current one which has `"oauth_client": []`)

## Step 4: Rebuild and Test

Run these commands in your project root:

```bash
# Clean everything
flutter clean
flutter pub get

# Uninstall old app (choose one method):
adb uninstall com.umerfarooq1995.cognify_flutter
# OR uninstall via emulator UI

# Build and run (choose your flavor):
flutter run --flavor dev -t lib/main.dart
# OR
flutter run --flavor umer -t lib/main.dart
# OR for production debug:
flutter run -t lib/main.dart
```

## Step 5: Test Google Sign-In

1. Launch the app
2. Go to sign-in screen or paywall
3. Tap "Sign in with Google"
4. Should no longer see `ApiException: 10` error
5. Check logs for success message: `✅ [FirebaseAuth] Google sign-in successful`

## Troubleshooting: If Still Getting ApiException 10

Run this command to see which keystore actually signs your build:
```bash
cd android
./gradlew :app:signingReport
```

Look for the debug variant you're running and verify the SHA1 matches what you added to Firebase. If different, add that SHA1/SHA256 to Firebase instead.

## Expected Log Messages

**Success:**
```
I/flutter: ✅ [FirebaseAuth] Google sign-in successful
```

**Before fix:**
```
I/flutter: ❌ [FirebaseAuth] Google sign-in error: PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)
```

### 3. Complete Implementation Steps

Here's the step-by-step process to fix both issues:

#### For Google Sign-in Fix:

1. **Get your SHA fingerprints**:
   ```bash
   # For debug builds (if using debug keystore)
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # For your custom keystore
   keytool -list -v -alias cognify -keystore /Users/umerfarooq/cognify-release-key.jks
   ```

2. **Add fingerprints to Firebase Console**:
   - Go to Firebase Console → Project Settings → Your Apps → Android app
   - Add both SHA-1 and SHA-256 fingerprints
   - Download updated `google-services.json`

3. **Replace your google-services.json**:
   - Replace `android/app/google-services.json` with the downloaded file

#### For RevenueCat Fix:

1. **Set up RevenueCat dashboard** (as described above)
2. **Update your SDK key** in `lib/config/subscriptions_config.dart`
3. **Create Google Play Console products** with IDs: `premium_monthly` and `premium_annual`

#### Final Steps:

1. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Test both fixes**:
   - Test Google sign-in (should work without ApiException: 10)
   - Test RevenueCat offerings (should load without configuration errors)

### 4. Additional Recommendations

1. **Proper Firebase Configuration**: Consider replacing the placeholder `firebase_options.dart` with the real one:
   ```bash
   flutterfire configure --project=cognify-eb0a2
   ```

2. **Error Handling**: Your current error handling in the auth provider is good, but you might want to add more specific error messages for users.

3. **Testing**: Test both the debug and release builds to ensure SHA fingerprints are correct for both.

The key issues are:
- **Google Sign-in**: SHA certificate fingerprint mismatch (ApiException: 10)
- **RevenueCat**: Missing products in dashboard configuration

Once you complete these steps, both errors should be resolved. The Google sign-in will work properly, and RevenueCat will be able to fetch offerings without configuration errors.