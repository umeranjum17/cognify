# Debug Logging Guide

## Overview
The app has been configured to reduce excessive logging by default. Only warnings and errors are shown in normal operation.

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