# iOS Deployment Configuration

This directory contains the iOS configuration for the Cognify Flutter app with support for multiple build flavors.

## Build Flavors

The app supports three build flavors:

### 1. Production
- **Bundle ID**: `com.umerfarooq1995.cognify-flutter`
- **Display Name**: `Cognify`
- **Configuration**: `Production.xcconfig`
- **Use**: App Store release

### 2. Dev
- **Bundle ID**: `com.umerfarooq1995.cognify-flutter.dev`
- **Display Name**: `Cognify Dev`
- **Configuration**: `Dev.xcconfig`
- **Use**: Development and testing with premium features enabled

### 3. Umer
- **Bundle ID**: `com.umerfarooq1995.cognify-flutter.umer`
- **Display Name**: `Cognify Umer`
- **Configuration**: `Umer.xcconfig`
- **Use**: Personal build with premium features enabled

## Building for Different Flavors

### Command Line
```bash
# Production build
flutter build ios --flavor production --target lib/main.dart

# Dev build
flutter build ios --flavor dev --target lib/main.dart

# Umer build
flutter build ios --flavor umer --target lib/main.dart
```

### Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the appropriate scheme (Production, Dev, or Umer)
3. Build and run

## Code Signing

For release builds, you'll need to:

1. Set up your Apple Developer account
2. Create App IDs for each flavor in the Apple Developer Console
3. Generate provisioning profiles for each bundle identifier
4. Configure code signing in Xcode for each target

## URL Schemes

The app supports the following URL schemes for OAuth callbacks:
- `cognify://` - Custom scheme
- `https://` - Universal links

## Notes

- The production flavor should be used for App Store submissions
- Dev and Umer flavors include premium features for testing
- Make sure to use different bundle identifiers to avoid conflicts
- Test each flavor thoroughly before deployment
