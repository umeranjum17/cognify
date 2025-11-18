# Google Sign-In Error Fix Guide

## Error: `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:)`

**Error Code 10 = DEVELOPER_ERROR**

This error occurs when the SHA-1 fingerprint of your app's signing certificate doesn't match what's configured in Firebase Console.

## Quick Fix Steps

### 1. Get Your SHA-1 Fingerprint

Run the provided script:
```bash
./get-sha1.sh
```

Or manually:
```bash
# For debug keystore (default)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

**Note:** If the debug keystore doesn't exist, build your app once and it will be created automatically, then run the command again.

### 2. Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **cognify-eb0a2**
3. Click the gear icon ⚙️ → **Project Settings**
4. Scroll down to **Your apps** section
5. Find your Android app: `com.umerfarooq1995.cognify_flutter`
6. Click **Add fingerprint** button
7. Paste your SHA-1 fingerprint (without colons, or with colons - both work)
8. Click **Save**

### 3. Download Updated google-services.json

1. In the same Firebase Console page, click **Download google-services.json**
2. Replace `android/app/google-services.json` with the downloaded file

### 4. Rebuild Your App

```bash
flutter clean
flutter pub get
flutter run
```

## Why This Happens

- **Debug builds** use a default debug keystore (`~/.android/debug.keystore`)
- **Release builds** use your custom keystore (configured in `android/local.properties`)
- Firebase needs to know the SHA-1 fingerprint of **each keystore** you use
- If the fingerprint doesn't match, Google Sign-In will fail with error code 10

## Current Configuration

Your `google-services.json` currently has these SHA-1 fingerprints configured:
- `0b998194bd1394fd5c0d623dbbd7fc46d26a6260`
- `b81ba8e1b9a8f407b2d143a1fe68ea687bbdf967`

If your current debug keystore's SHA-1 doesn't match either of these, you'll get the error.

## Troubleshooting

### If debug keystore doesn't exist:
1. Build your app once: `flutter build apk --debug`
2. The keystore will be created automatically
3. Run `./get-sha1.sh` again

### If you're using a different machine:
- Each machine has its own debug keystore
- You need to add the SHA-1 from each machine to Firebase

### For release builds:
- Make sure to add the release keystore's SHA-1 fingerprint as well
- Use the same process but with your release keystore

## Alternative: Using Gradle to Get SHA-1

You can also add this to `android/app/build.gradle` to automatically print SHA-1:

```gradle
android {
    // ... existing config ...
    
    tasks.register('printSha1') {
        doLast {
            def keystoreFile = file("${System.getProperty('user.home')}/.android/debug.keystore")
            if (keystoreFile.exists()) {
                exec {
                    commandLine 'keytool', '-list', '-v', '-keystore', keystoreFile.absolutePath,
                            '-alias', 'androiddebugkey', '-storepass', 'android', '-keypass', 'android'
                }
            } else {
                println "Debug keystore not found. Build the app once to create it."
            }
        }
    }
}
```

Then run: `./gradlew printSha1`


