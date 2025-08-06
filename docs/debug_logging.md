# Debug Logging Guide

## Overview
The app has been optimized to reduce excessive logging by default. Only warnings and errors are shown in normal operation to improve performance.

## Performance Improvements
- **Default behavior**: Only errors and warnings are logged
- **Verbose mode**: Must be explicitly enabled for detailed debugging
- **Reduced log noise**: Eliminated most debug print statements
- **Better performance**: Less logging overhead during normal operation

## Enabling Verbose Logging

### Method 1: Settings Toggle
1. Open the app settings
2. Go to the "Debug" section
3. Toggle "Verbose Logging" to enable detailed logging

### Method 2: Code Console (for developers)
In the debug console, you can run:
```dart
Logger.enableVerboseDebugging()
```

To disable:
```dart
Logger.disableVerboseDebugging()
```

To toggle:
```dart
Logger.toggleVerboseDebugging()
```

### Method 3: Programmatic Control
```dart
// Enable verbose mode
Logger.setVerboseMode(true);

// Disable verbose mode
Logger.setVerboseMode(false);
```

## What Verbose Logging Shows
When enabled, verbose logging will show:
- Tool execution timing and completion messages
- Streaming message content updates
- Detailed source processing information
- Web fetch operations and content extraction
- Image processing and deduplication
- Prompt breakdown analysis
- Cost calculation details

## Default Behavior
By default, the app shows:
- ❌ Error messages (always shown)
- ⚠️ Warning messages
- ℹ️ Important informational messages

## Performance Impact
Verbose logging can impact performance and create log noise. Only enable when debugging specific issues.

## Log Levels
- `error`: Always shown
- `warn`: Shown by default
- `info`: Shown by default
- `debug`: Only shown in verbose mode
- `trace`: Only shown in verbose mode
- `debugOnly`: Only shown in debug builds with verbose mode

## Recent Changes
- Reduced default logging verbosity for better performance
- Replaced direct `print()` statements with proper Logger calls
- Added `debugOnly()` method for debug-specific output

## Share-to-Sources Flow Debugging

The Share-to-Sources feature allows users to share URLs from other apps directly to Cognify's Sources screen.

### Flow Overview
1. **Android Intent**: Shared text/URLs are captured via `android.intent.action.SEND`
2. **MainActivity**: Native Android code extracts shared text via MethodChannel
3. **SharingService**: Processes and validates URLs, stores temporarily
4. **Router Navigation**: Navigates to `/sources?sharedUrl=<encoded_url>`
5. **SourcesScreen**: Populates URL field and shows "Add Now" snackbar

### Debug Log Tags
When troubleshooting share flow issues, look for these log tags:
- `📱` SharingService operations (URL extraction, validation)
- `🏠` Router root route handling (share detection, redirection)
- `🧯` Router redirect logic (custom scheme handling)
- `🔍` Router initialization and URL normalization

### Common Issues & Solutions

**Problem**: Shared URLs open Editor instead of Sources
- **Cause**: Router redirect race condition 
- **Solution**: Implemented surgical guard in root route (lines 102-110 in app_router.dart)
- **Debug**: Check for `isShareFlow` detection in router logs

**Problem**: Blank screen after sharing
- **Cause**: SourcesScreen lifecycle issues or double URL handling
- **Solution**: Fixed lifecycle method nesting and added `_handledInitialUrl` guard
- **Debug**: Enable verbose logging to see SourcesScreen initialization

**Problem**: URL not appearing in Sources text field
- **Cause**: URL encoding/decoding issues or SharingService not consuming
- **Debug**: Check SharingService logs for URL extraction and SourcesScreen for field population

### Test Scenarios
1. **Cold start**: Share URL when app is closed → Should open Sources with URL populated
2. **Warm app**: Share URL when app is in background → Should navigate to Sources
3. **Repeat shares**: Multiple shares should work reliably without duplicates
4. **Invalid URLs**: Malformed URLs should be handled gracefully

### Troubleshooting Steps
1. Enable verbose logging: `Logger.setVerboseMode(true)`
2. Share a URL and monitor logs for the tags above
3. Verify Android intent-filter in `android/app/src/main/AndroidManifest.xml`
4. Check MainActivity.kt MethodChannel implementation
5. Confirm SharingService URL extraction and single-use consumption
- Improved log filtering and control mechanisms 