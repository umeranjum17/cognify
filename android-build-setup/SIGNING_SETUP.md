# Android Signing Configuration

## Keystore Information

**Keystore File Location:**
```
cognify-release-key.jks (included in this folder)
```

**IMPORTANT:** The keystore file is included in this setup folder. Copy it to a secure location on the new computer.

## Keystore Details

- **Key Alias:** `cognify`
- **Store Password:** See `CREDENTIALS.txt` (keep this file secure!)
- **Key Password:** See `CREDENTIALS.txt` (keep this file secure!)
- **Certificate CN:** Umer Farooq
- **Valid Until:** December 18, 2052

## Setup on New Computer

1. **Extract this folder** to your new computer

2. **Copy the keystore file to a secure location:**
   ```bash
   # The keystore is in this folder - copy it to your preferred location
   cp android-build-setup/cognify-release-key.jks ~/cognify-release-key.jks
   # Or keep it in the project: cp android-build-setup/cognify-release-key.jks android/app/
   ```

3. **Create `android/local.properties`:**
   ```properties
   sdk.dir=/path/to/your/android/sdk
   flutter.sdk=/path/to/your/flutter
   flutter.buildMode=release
   flutter.versionName=1.0.7
   flutter.versionCode=33
   storeFile=/path/to/cognify-release-key.jks
   storePassword=YOUR_STORE_PASSWORD
   keyAlias=cognify
   keyPassword=YOUR_KEY_PASSWORD
   ```

3. **Verify keystore:**
   ```bash
   keytool -list -v -keystore ~/cognify-release-key.jks -alias cognify
   ```

## Security Notes

- **NEVER commit `local.properties` to git** - it's already in `.gitignore`
- **NEVER commit the keystore file** to version control
- Store credentials securely (password manager, encrypted file, etc.)
- Keep backups of the keystore file in a secure location
- If the keystore is lost, you cannot update your app on Google Play Store

## Verifying Signed Build

After building, verify the signature:

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/productionRelease/app-production-release.aab
```

You should see:
- Signer: CN=Umer Farooq
- Signature algorithm: SHA384withRSA
- Certificate valid dates

