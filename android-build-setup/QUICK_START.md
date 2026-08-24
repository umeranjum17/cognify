# Quick Start Guide

Get up and running in 5 minutes!

## Step 1: Install Java 21

```bash
mkdir -p ~/jdk && cd ~/jdk
curl -L -o jdk21.tar.gz "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jdk/hotspot/normal/eclipse"
tar -xzf jdk21.tar.gz
```

## Step 2: Configure Gradle

Edit `android/gradle.properties` and add:
```properties
org.gradle.java.home=/Users/YOUR_USERNAME/jdk/jdk-21.0.9+10/Contents/Home
```

## Step 3: Keystore (Already Included!)

The keystore file `cognify-release-key.jks` is already in this folder. Copy it to your preferred location:
```bash
cp android-build-setup/cognify-release-key.jks ~/cognify-release-key.jks
```

## Step 4: Create local.properties

Create `android/local.properties`:
```properties
sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk
flutter.sdk=/path/to/flutter
flutter.buildMode=release
flutter.versionName=1.0.7
flutter.versionCode=33
storeFile=/path/to/cognify-release-key.jks
storePassword=123456
keyAlias=cognify
keyPassword=123456
```

## Step 5: Build!

```bash
flutter clean
flutter pub get
flutter build appbundle --release --flavor production
```

Done! Your AAB is at: `build/app/outputs/bundle/productionRelease/app-production-release.aab`

## Need More Details?

- Full setup: See `README.md`
- Java issues: See `JAVA_SETUP.md`
- Signing issues: See `SIGNING_SETUP.md`
- Build errors: See `TROUBLESHOOTING.md`

