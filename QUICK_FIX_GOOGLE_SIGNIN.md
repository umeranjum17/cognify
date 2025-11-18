# Quick Fix: Google Sign-In Error Code 10

## The Problem
You're seeing: `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:)`

**Error Code 10 = DEVELOPER_ERROR** - This means your app's SHA-1 fingerprint doesn't match Firebase configuration.

## The Solution (3 Steps)

### Step 1: Build the app once to create debug keystore
```bash
flutter build apk --debug
```
This will automatically create the debug keystore if it doesn't exist.

### Step 2: Get your SHA-1 fingerprint

**Option A: Use the script**
```bash
./get-sha1.sh
```

**Option B: Use Gradle**
```bash
cd android && ./gradlew printSha1
```

**Option C: Manual command**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

Copy the SHA-1 value (it looks like: `AB:CD:EF:12:34:56:...`)

### Step 3: Add SHA-1 to Firebase Console

1. Go to: https://console.firebase.google.com/project/cognify-eb0a2/settings/general/android:com.umerfarooq1995.cognify_flutter
2. Scroll to **SHA certificate fingerprints**
3. Click **Add fingerprint**
4. Paste your SHA-1 (with or without colons - both work)
5. Click **Save**
6. **Download** the updated `google-services.json`
7. Replace `android/app/google-services.json` with the new file
8. Rebuild: `flutter clean && flutter run`

## That's it! 🎉

After adding the SHA-1 and updating `google-services.json`, Google Sign-In should work.

## Why This Happens

- Each Android app build uses a signing certificate
- Firebase needs to know the SHA-1 fingerprint of that certificate
- If it doesn't match, Google Sign-In fails with error 10
- Debug builds use `~/.android/debug.keystore` (created automatically)
- Release builds use your custom keystore (configured in `android/local.properties`)

## Need Help?

See `GOOGLE_SIGNIN_FIX.md` for detailed troubleshooting.


