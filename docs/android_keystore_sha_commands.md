# Extract SHA-1 and SHA-256 from your custom keystore

Use these exact commands with your keystore path: `./cognify-release-key.jks`

## 1) Show alias name(s) in the keystore
```bash
keytool -list -keystore ./cognify-release-key.jks
```
- Enter the keystore password when prompted.
- Note the alias printed on the line that looks like:
  ```
  your_alias, Jan 01, 2024, PrivateKeyEntry
  ```

## 2) Print SHA-1 and SHA-256 for that alias (replace YOUR_ALIAS)
```bash
keytool -list -v -alias YOUR_ALIAS -keystore ./cognify-release-key.jks
```
- Enter keystore password and key password if prompted.
- Copy both lines:
  - `SHA1: AA:BB:...`
  - `SHA256: 11:22:...`

If your alias is `cognify`, run exactly:
```bash
keytool -list -v -alias cognify -keystore ./cognify-release-key.jks
```

## 3) Add fingerprints in Firebase
- Firebase Console → Project settings → Your apps → Android app `com.umerfarooq1995.cognify_flutter`
- Section: SHA certificate fingerprints
  - Add SHA-1 (paste value without the "SHA1:" prefix)
  - Add SHA-256 (paste value without the "SHA256:" prefix)
- Save
- Download the updated `google-services.json`

## 4) Replace file and rebuild
- Replace: `android/app/google-services.json` with the one you downloaded
- Then run:
```bash
flutter clean
flutter pub get
adb uninstall com.umerfarooq1995.cognify_flutter   # or uninstall via emulator UI
flutter run --flavor dev -t lib/main.dart          # or your chosen flavor
```

## 5) Verify
- Open `android/app/google-services.json` and confirm it now includes an `oauth_client` block.
- In the app, trigger Google Sign-In. Expect success (no `ApiException: 10`).

## Troubleshooting
- If sign-in still fails with code 10:
  1. Verify which keystore signed your running build:
     ```bash
     cd android
     ./gradlew :app:signingReport
     ```
  2. Ensure the SHA-1 for the active variant (e.g., `devDebug` or `umerDebug`) is added to Firebase.
  3. Re-download `google-services.json`, replace it, and rebuild as above.