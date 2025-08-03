# Android Build Troubleshooting Guide

## Issue: Gradle build failed to produce an .apk file

### Root Causes and Solutions

#### 1. **Flavor Configuration Issue**
The project uses product flavors (dev, production, umer) but the launch configuration wasn't properly set up for flavor-specific builds.

**Solution**: Updated `.vscode/launch.json` with proper flavor configurations.

#### 2. **Build Directory Structure**
Flutter generates APK files in specific directories based on flavor and build type:
- Debug builds: `build/app/outputs/flutter-apk/app-{flavor}-debug.apk`
- Release builds: `build/app/outputs/flutter-apk/app-{flavor}-release.apk`

#### 3. **Android SDK Configuration**
Ensure proper Android SDK setup:
```bash
# Check Android SDK installation
flutter doctor --android-licenses

# Verify SDK path in local.properties
sdk.dir=/Users/umerfaroq/Library/Android/sdk
```

#### 4. **Gradle Configuration**
The project uses:
- Gradle version: 8.3.0
- Kotlin version: 1.8.10
- Android Gradle Plugin: 8.3.0
- Compile SDK: 35
- Target SDK: 34

### Updated Launch Configurations

The `.vscode/launch.json` now includes:

1. **Flavor-specific debug configurations**:
   - `cognify-flutter (dev flavor)`
   - `cognify-flutter (production flavor)`
   - `cognify-flutter (umer flavor)`

2. **Build configurations**:
   - `Build APK (dev flavor)`
   - `Build APK (production flavor)`

3. **Profile and Release modes** with proper flavor support

### Build Commands

#### Debug Builds
```bash
# Dev flavor
flutter build apk --flavor dev --debug

# Production flavor
flutter build apk --flavor production --debug

# Umer flavor
flutter build apk --flavor umer --debug
```

#### Release Builds
```bash
# Dev flavor
flutter build apk --flavor dev --release

# Production flavor
flutter build apk --flavor production --release
```

### Troubleshooting Steps

1. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --flavor dev --debug
   ```

2. **Check APK output location**:
   ```bash
   ls -la build/app/outputs/flutter-apk/
   ```

3. **Verify Android SDK**:
   ```bash
   flutter doctor -v
   ```

4. **Check Gradle logs**:
   ```bash
   cd android
   ./gradlew assembleDevDebug --info
   ```

### Common Issues and Fixes

#### Issue: "Gradle build failed to produce an .apk file"
**Cause**: VS Code launch configuration not finding the APK file
**Solution**: Use the updated launch.json with proper flavor configurations

#### Issue: "Missing Android SDK components"
**Solution**: Install Android Studio and accept licenses
```bash
flutter doctor --android-licenses
```

#### Issue: "Build directory not found"
**Solution**: Ensure clean build process
```bash
flutter clean
flutter pub get
```

### File Locations

- **APK files**: `build/app/outputs/flutter-apk/`
- **Gradle configuration**: `android/app/build.gradle`
- **Launch configuration**: `.vscode/launch.json`
- **Local properties**: `android/local.properties`

### Verification

After implementing these fixes:

1. The APK files should be generated in the correct location
2. VS Code launch configurations should work properly
3. Flavor-specific builds should function correctly
4. Debug and release builds should be accessible

### Next Steps

1. Test the updated launch configurations in VS Code
2. Verify APK generation for all flavors
3. Test deployment to Android devices/emulators
4. Consider implementing CI/CD for automated builds 