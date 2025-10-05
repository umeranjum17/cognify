# Frontend Isolation Summary

## Overview
The frontend has been refactored to only connect to approved services: your API, Firebase, and RevenueCat. All external API calls have been moved to the backend.

## Changes Made

### ✅ Mermaid Diagram Generation
**Before:** Frontend directly called `https://mermaid.ink/` API
**After:** Frontend calls backend API at `/api/mermaid/generate`

**Files Changed:**
- `lib/widgets/mermaid_image_widget.dart` - Updated to use backend endpoint
- `api/mermaid/generate.ts` - New backend proxy endpoint

**Benefits:**
- Centralized control over Mermaid rendering
- Can add caching, rate limiting, and monitoring on the backend
- Reduces frontend dependencies on external services

### ✅ OAuth Provider (Deprecated - No Changes Needed)
The OAuth provider is deprecated and no longer actively used. The following references remain but are not called:
- `lib/providers/oauth_auth_provider.dart` - Contains references to OpenRouter OAuth URLs
- `lib/config/app_config.dart` - Contains OpenRouter base URL constants

**Note:** These can be safely removed in a future cleanup if the OAuth provider is completely removed.

## Current Frontend External Connections

### Allowed Services ✅
1. **Your Backend API** - `https://cognify-flutter.vercel.app/api/*`
   - Config endpoints (`/api/config/*`)
   - Credits endpoints (`/api/credits/*`)
   - Mode endpoints (`/api/modes/*`)
   - Mermaid generation (`/api/mermaid/generate`)
   - RevenueCat webhook (`/api/rc/webhook`)

2. **Firebase** - Authentication and database
3. **RevenueCat** - Subscription management

### Static/UI References Only (Not Network Calls) 📝
- `lib/models/source_type.dart` - Contains URL placeholders for UI (YouTube, Medium, etc.)
- `lib/services/src/web_location_stub.dart` - Contains localhost URL for development
- `lib/services/remote_config_service.dart` - Hardcoded backend URL (same as #1 above)
- `lib/providers/oauth_auth_provider.dart` - OAuth callback URLs (deprecated functionality)
- `lib/config/app_config.dart` - API base URL constants (not used for direct calls)

## Backend API Endpoints Created

### `/api/mermaid/generate` (POST)
**Purpose:** Generate Mermaid diagrams by proxying to mermaid.ink

**Request:**
```json
{
  "code": "graph TD\n  A-->B",
  "theme": "dark" | "default",
  "format": "png" | "svg",
  "bgColor": "1b1b1f" (optional)
}
```

**Response:** Binary image data (PNG or SVG)

## Verification

All frontend HTTP calls now go through:
1. **Backend API** - `/api/*` endpoints
2. **Firebase SDK** - Authentication and Firestore
3. **RevenueCat SDK** - Subscription management

No direct calls to OpenRouter, Mermaid.ink, or other external APIs.

## Future Cleanup Recommendations

1. **Remove deprecated OAuth provider** - If no longer needed, delete `lib/providers/oauth_auth_provider.dart`
2. **Remove unused constants** - Clean up `openRouterBaseUrl` and `openAiBaseUrl` from `app_config.dart` if not needed
3. **Add backend caching** - Consider caching Mermaid diagrams on the backend for better performance
4. **Add rate limiting** - Protect the Mermaid endpoint from abuse

## Testing Checklist

- [ ] Test Mermaid diagram generation in light mode
- [ ] Test Mermaid diagram generation in dark mode
- [ ] Test Mermaid diagram generation with different diagram types
- [ ] Verify no direct external API calls in production (use network monitoring)
- [ ] Test offline behavior (cached configs should work)
