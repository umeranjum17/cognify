# Android Production Build Setup Guide

This folder contains all the information needed to build the Cognify Flutter app for Android production on a new computer.

## Prerequisites

1. **Flutter SDK** - Install Flutter (version >=3.10.0)
2. **Android Studio** - For Android SDK and build tools
3. **Java 21** - Required for Gradle compatibility (see Java Setup section)

## Quick Start

1. Install Java 21 (see `JAVA_SETUP.md`)
2. Configure signing credentials (see `SIGNING_SETUP.md`)
3. Update `android/gradle.properties` with your Java 21 path
4. Run: `flutter build appbundle --release --flavor production`

## Files in This Folder

- `README.md` - This file
- `JAVA_SETUP.md` - Java 21 installation instructions
- `SIGNING_SETUP.md` - Keystore and signing configuration
- `BUILD_COMMANDS.md` - Complete build commands reference
- `CONFIGURATION.md` - All configuration details
- `TROUBLESHOOTING.md` - Common errors and solutions
- `QUICK_START.md` - 5-minute setup guide
- `SETUP_CHECKLIST.md` - Step-by-step verification
- `FILES_INDEX.md` - Complete file index
- `gradle.properties.template` - Template for gradle.properties
- `local.properties.template` - Template for local.properties
- `CREDENTIALS.txt` - Signing credentials (KEEP SECURE!)
- `cognify-release-key.jks` - **Keystore file (included!)**

## Current Build Configuration

- **Gradle Version:** 8.12
- **Java Version:** 21 (OpenJDK 21.0.9+10)
- **Min SDK:** 23
- **Target SDK:** 36
- **Build Type:** Release with ProGuard
- **Flavor:** Production

## Build Output

Production AAB will be generated at:
```
build/app/outputs/bundle/productionRelease/app-production-release.aab
```

## Troubleshooting

See `TROUBLESHOOTING.md` for common issues and solutions.

