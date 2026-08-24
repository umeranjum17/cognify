# Troubleshooting Guide

## Common Build Errors and Solutions

### 1. Java Version Incompatibility

**Error:**
```
Unsupported class file major version 68
BUG! exception in phase 'semantic analysis'
```

**Solution:**
1. Install Java 21 (see `JAVA_SETUP.md`)
2. Update `android/gradle.properties`:
   ```properties
   org.gradle.java.home=/path/to/java/21
   ```
3. Verify: `flutter doctor -v` should show Java 21

### 2. Keystore Not Found

**Error:**
```
Failed to read key cognify from store: keystore was tampered with, or password was incorrect
```

**Solutions:**
1. Verify keystore file exists at the path in `local.properties`
2. Check `storePassword` and `keyPassword` are correct
3. Verify `keyAlias` is "cognify"
4. Test keystore manually:
   ```bash
   keytool -list -v -keystore /path/to/cognify-release-key.jks -alias cognify
   ```

### 3. Min SDK Version Error

**Error:**
```
minSdkVersion 21 cannot be smaller than version 23
```

**Solution:**
Already fixed in `android/app/build.gradle` - `minSdkVersion` is set to 23.

### 4. Gradle Download Failed

**Error:**
```
Could not resolve all files for configuration
```

**Solutions:**
1. Check internet connection
2. Clear Gradle cache:
   ```bash
   rm -rf ~/.gradle/caches
   ```
3. Retry build

### 5. Flutter SDK Not Found

**Error:**
```
Flutter SDK not found
```

**Solution:**
1. Install Flutter SDK
2. Update `android/local.properties`:
   ```properties
   flutter.sdk=/path/to/flutter
   ```

### 6. Android SDK Not Found

**Error:**
```
SDK location not found
```

**Solution:**
1. Install Android Studio
2. Update `android/local.properties`:
   ```properties
   sdk.dir=/path/to/Android/sdk
   ```

### 7. Build Fails with "NullPointerException" in Signing

**Error:**
```
Execution failed for task ':app:signProductionReleaseBundle'
java.lang.NullPointerException
```

**Solution:**
1. Ensure `local.properties` has all signing properties:
   - `storeFile`
   - `storePassword`
   - `keyAlias`
   - `keyPassword`
2. Verify keystore file exists at `storeFile` path

### 8. ProGuard Errors

**Error:**
```
Warning: can't find referenced class
```

**Solution:**
Add rules to `android/app/proguard-rules.pro`:
```proguard
-keep class com.example.** { *; }
-dontwarn com.example.**
```

### 9. Build Takes Too Long

**Solutions:**
1. Enable Gradle daemon (already enabled by default)
2. Increase memory in `gradle.properties`:
   ```properties
   org.gradle.jvmargs=-Xmx6144M
   ```
3. Use build cache:
   ```bash
   flutter build appbundle --release --flavor production --build-cache
   ```

### 10. "Gradle sync failed" in Android Studio

**Solutions:**
1. File → Invalidate Caches / Restart
2. Sync Project with Gradle Files
3. Check `gradle.properties` for correct Java path
4. Ensure internet connection for dependency downloads

## Verification Steps

After setup, verify everything works:

1. **Check Flutter:**
   ```bash
   flutter doctor -v
   ```

2. **Check Java:**
   ```bash
   java -version  # Should show 21
   ```

3. **Check Gradle:**
   ```bash
   cd android
   ./gradlew --version
   ```

4. **Test Build:**
   ```bash
   flutter build appbundle --release --flavor production
   ```

## Getting Help

If issues persist:
1. Check Flutter logs: `flutter build appbundle --verbose`
2. Check Gradle logs: `cd android && ./gradlew build --stacktrace`
3. Review `CONFIGURATION.md` for all settings
4. Ensure all prerequisites are installed



