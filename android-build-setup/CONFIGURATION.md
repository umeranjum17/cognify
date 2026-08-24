# Complete Configuration Reference

## Project Structure

```
cognify-flutter/
├── android/
│   ├── app/
│   │   ├── build.gradle          # App build configuration
│   │   └── google-services.json   # Firebase configuration
│   ├── build.gradle              # Project build configuration
│   ├── gradle.properties         # Gradle settings
│   ├── gradle/
│   │   └── wrapper/
│   │       └── gradle-wrapper.properties  # Gradle version
│   └── local.properties          # Local config (NOT in git)
└── pubspec.yaml                  # Flutter dependencies
```

## Key Configuration Files

### 1. `android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx4096M -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
android.ndkVersion=27.0.12077973
org.gradle.java.home=/Users/YOUR_USERNAME/jdk/jdk-21.0.9+10/Contents/Home
```

**Important:** Update `org.gradle.java.home` to your Java 21 path.

### 2. `android/gradle/wrapper/gradle-wrapper.properties`

```properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.12-all.zip
```

**Gradle Version:** 8.12 (automatically downloaded on first build)

### 3. `android/app/build.gradle` - Key Settings

```gradle
android {
    namespace "com.umerfarooq1995.cognify_flutter"
    compileSdkVersion 36
    ndkVersion "27.0.12077973"
    
    defaultConfig {
        applicationId "com.umerfarooq1995.cognify_flutter"
        minSdkVersion 23          // Required by firebase_analytics
        targetSdkVersion 36
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
    
    buildTypes {
        release {
            debuggable false
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            signingConfig signingConfigs.release
        }
    }
}
```

### 4. `android/local.properties` (Create this file)

```properties
sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk
flutter.sdk=/path/to/flutter
flutter.buildMode=release
flutter.versionName=1.0.7
flutter.versionCode=33
storeFile=/path/to/cognify-release-key.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=cognify
keyPassword=YOUR_KEY_PASSWORD
```

## Build Flavors

The project uses product flavors:

1. **production**
   - App ID: `com.umerfarooq1995.cognify_flutter`
   - App Name: "Cognify"
   - No version suffix

2. **dev**
   - App ID: `com.umerfarooq1995.cognify_flutter`
   - App Name: "Cognify Dev"
   - Version suffix: "-dev"

3. **umer**
   - App ID: `com.umerfarooq1995.cognify_flutter`
   - App Name: "Cognify Umer"
   - Version suffix: "-umer"

## Dependencies

Key Android dependencies (from `android/app/build.gradle`):
- Google Play Services
- Firebase
- Play In-App Reviews
- Play In-App Updates
- Play Asset Delivery
- Play Feature Delivery

## ProGuard Configuration

Release builds use ProGuard for:
- Code obfuscation
- Code shrinking
- Resource shrinking

Configuration file: `android/app/proguard-rules.pro`

## Native Libraries

Supported ABIs:
- `arm64-v8a` (64-bit ARM)
- `armeabi-v7a` (32-bit ARM)
- `x86_64` (64-bit x86)

## API Configuration

Default API Base URL: `https://cognify-backend.fly.dev`

Can be overridden via:
- Environment variable: `API_BASE_URL`
- Gradle property: `API_BASE_URL`

## Version Management

Version is managed in `android/local.properties`:
- `flutter.versionName` - User-facing version (e.g., "1.0.7")
- `flutter.versionCode` - Internal version number (e.g., 33)

For Play Store:
- Each upload must have a higher `versionCode`
- `versionName` can be any string



