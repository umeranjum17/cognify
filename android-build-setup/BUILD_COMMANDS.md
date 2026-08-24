# Android Build Commands Reference

## Production Build (App Bundle for Play Store)

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build production AAB
flutter build appbundle --release --flavor production
```

**Output:** `build/app/outputs/bundle/productionRelease/app-production-release.aab`

## Production Build (APK for Direct Distribution)

```bash
flutter build apk --release --flavor production
```

**Output:** `build/app/outputs/apk/production/release/app-production-release.apk`

## Debug Build

```bash
flutter build apk --debug --flavor production
# or
flutter run --flavor production
```

## Other Flavors

The project has multiple flavors:
- `production` - Production release
- `dev` - Development build
- `umer` - Umer's test build

Build with different flavors:
```bash
flutter build appbundle --release --flavor dev
flutter build appbundle --release --flavor umer
```

## Build with Specific Version

```bash
# Update version in android/local.properties first
flutter build appbundle --release --flavor production --build-number=34 --build-name=1.0.8
```

## Verify Build

```bash
# Check AAB file
file build/app/outputs/bundle/productionRelease/app-production-release.aab

# Verify signature
jarsigner -verify -verbose -certs build/app/outputs/bundle/productionRelease/app-production-release.aab

# Check file size
ls -lh build/app/outputs/bundle/productionRelease/app-production-release.aab
```

## Common Build Issues

### Java Version Error
```
Unsupported class file major version 68
```
**Solution:** Install Java 21 and configure `gradle.properties`

### Signing Error
```
keystore password was incorrect
```
**Solution:** Check `local.properties` has correct passwords

### Min SDK Error
```
minSdkVersion 21 cannot be smaller than version 23
```
**Solution:** Already fixed - minSdkVersion is set to 23 in `build.gradle`

## Build Time

Typical build time: 1-3 minutes depending on:
- First build: ~3-5 minutes (downloads dependencies)
- Subsequent builds: ~1-2 minutes
- Clean builds: ~2-3 minutes



