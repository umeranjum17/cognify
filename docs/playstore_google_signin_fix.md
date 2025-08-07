# Fix Google Sign-In for Play Store Internal Testing

## Problem
When uploading to Play Store for internal testing, you get this error:
```
Purchase failed: PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)
```

## Root Cause
Play Store re-signs your APK with Google's certificate, which has a different SHA fingerprint than your release keystore. Google Sign-In fails because the new SHA fingerprint isn't registered in Firebase.

## Solution Steps

### Step 1: Get Play Store SHA Fingerprint

**Option A: From Play Console (Recommended)**
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: `com.umerfarooq1995.cognify_flutter`
3. Go to **Setup** → **App signing**
4. Look for **"App signing certificate"** section
5. Copy the **SHA-1 fingerprint** (it will look like: `AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:11:22:33:44`)

**Option B: From Uploaded APK**
1. Download your uploaded APK from Play Console
2. Extract the APK and get the certificate:
   ```bash
   # Extract APK
   unzip your-app.apk
   
   # Get certificate info
   keytool -printcert -file META-INF/CERT.RSA
   ```

### Step 2: Add SHA to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `cognify-eb0a2`
3. Click gear icon → **Project settings**
4. Under **"Your apps"**, find the Android app: `com.umerfarooq1995.cognify_flutter`
5. Scroll down to **"SHA certificate fingerprints"**
6. Click **"Add fingerprint"**
7. Paste the Play Store SHA-1 fingerprint (without colons)
8. Click **"Save"**

### Step 3: Download Updated google-services.json

1. Still in Firebase Console → Project settings
2. Under your Android app, click **"Download google-services.json"**
3. Replace the file at: `android/app/google-services.json`

### Step 4: Rebuild and Upload

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Build release APK
flutter build apk --release --flavor production

# Upload to Play Store internal testing
```

### Step 5: Test

1. Install the new APK from Play Store internal testing
2. Try Google Sign-In
3. Should work without the `ApiException: 10` error

## Expected SHA Fingerprints in google-services.json

After the fix, your `google-services.json` should have **3** SHA fingerprints:

```json
"oauth_client": [
  {
    "client_id": "...",
    "client_type": 1,
    "android_info": {
      "package_name": "com.umerfarooq1995.cognify_flutter",
      "certificate_hash": "0b998194bd1394fd5c0d623dbbd7fc46d26a6260"  // Debug
    }
  },
  {
    "client_id": "...", 
    "client_type": 1,
    "android_info": {
      "package_name": "com.umerfarooq1995.cognify_flutter",
      "certificate_hash": "b81ba8e1b9a8f407b2d143a1fe68ea687bbdf967"  // Release
    }
  },
  {
    "client_id": "...",
    "client_type": 1, 
    "android_info": {
      "package_name": "com.umerfarooq1995.cognify_flutter",
      "certificate_hash": "PLAY_STORE_SHA_HERE"  // Play Store (to be added)
    }
  }
]
```

## Troubleshooting

### If you can't find the Play Store SHA:
1. Upload a test APK to Play Console
2. Go to **Release** → **Internal testing**
3. Download the signed APK
4. Extract and check the certificate as shown in Option B above

### If still getting errors:
1. Verify the SHA fingerprint matches exactly (no extra spaces)
2. Wait 5-10 minutes for Firebase to propagate changes
3. Check that you're using the correct `google-services.json` file
4. Ensure the package name matches exactly: `com.umerfarooq1995.cognify_flutter`

## Verification Commands

Check your current SHA fingerprints:
```bash
# Debug builds
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release builds  
keytool -list -v -alias cognify -keystore /Users/umerfarooq/cognify-release-key.jks

# Gradle signing report
cd android && ./gradlew :app:signingReport
``` 