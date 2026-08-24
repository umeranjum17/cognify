# Android Build Setup Checklist

Use this checklist when setting up the build environment on a new computer.

## Prerequisites

- [ ] Flutter SDK installed (>=3.10.0)
- [ ] Android Studio installed
- [ ] Android SDK installed (via Android Studio)
- [ ] Java 21 installed (see `JAVA_SETUP.md`)

## Configuration Steps

- [ ] Java 21 installed and verified
- [ ] `android/gradle.properties` updated with Java 21 path
- [ ] Keystore file (`cognify-release-key.jks`) copied to secure location
- [ ] `android/local.properties` created with:
  - [ ] Android SDK path
  - [ ] Flutter SDK path
  - [ ] Keystore file path
  - [ ] Store password
  - [ ] Key alias ("cognify")
  - [ ] Key password
- [ ] Credentials stored securely (password manager, etc.)

## Verification

- [ ] Run `flutter doctor -v` - all checks should pass
- [ ] Java version shows 21: `java -version`
- [ ] Gradle version shows 8.12: `cd android && ./gradlew --version`
- [ ] Keystore verifies: `keytool -list -v -keystore /path/to/cognify-release-key.jks -alias cognify`
- [ ] Test build succeeds: `flutter build appbundle --release --flavor production`
- [ ] AAB file is generated and signed correctly

## Build Test

```bash
# Clean
flutter clean

# Get dependencies
flutter pub get

# Build
flutter build appbundle --release --flavor production

# Verify
ls -lh build/app/outputs/bundle/productionRelease/app-production-release.aab
jarsigner -verify -verbose -certs build/app/outputs/bundle/productionRelease/app-production-release.aab
```

## Expected Results

- Build completes without errors
- AAB file size: ~50-55 MB
- Signature shows: CN=Umer Farooq
- Certificate valid until 2052

## If Something Fails

1. Check `TROUBLESHOOTING.md`
2. Verify all checklist items are completed
3. Check `CONFIGURATION.md` for all settings
4. Review build logs for specific errors

## Security Reminders

- [ ] `local.properties` is in `.gitignore` (verify)
- [ ] Keystore file is NOT in git (verify)
- [ ] `CREDENTIALS.txt` is stored securely
- [ ] Credentials are not shared publicly



