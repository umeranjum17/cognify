# API Security Guide

## Overview

This document outlines the authentication and security architecture for all Cognify API endpoints. All APIs requiring user data or business logic are now secured with Firebase Authentication.

## Table of Contents

1. [Security Architecture](#security-architecture)
2. [Authentication Flow](#authentication-flow)
3. [Endpoint Security Status](#endpoint-security-status)
4. [Implementation Details](#implementation-details)
5. [Testing Authentication](#testing-authentication)
6. [Common Issues & Solutions](#common-issues--solutions)
7. [Security Best Practices](#security-best-practices)

---

## Security Architecture

### Components

1. **Firebase Admin SDK** (`/api/shared/firebase-admin.ts`)
   - Runs in Node.js runtime
   - Verifies Firebase ID tokens
   - Manages user authentication state

2. **Auth Verification Endpoint** (`/api/auth/verify.ts`)
   - Node.js runtime endpoint
   - Provides authentication verification for Edge runtime functions
   - Returns user ID and email on successful verification

3. **Auth Helper Utilities** (`/api/shared/auth-helpers.ts`)
   - Reusable helpers for Edge runtime endpoints
   - Standardized error responses
   - Token extraction and validation

### Runtime Considerations

- **Node.js Runtime**: Can use Firebase Admin SDK directly
- **Edge Runtime**: Must call `/api/auth/verify` for authentication
- **Trade-off**: Slight latency (~10-20ms) for improved security and code maintainability

---

## Authentication Flow

### For Edge Runtime Endpoints

```typescript
import { verifyAuthForEdge, createUnauthorizedResponse } from '../shared/auth-helpers';

export default async function handler(req: Request) {
  // 1. Verify authentication
  const auth = await verifyAuthForEdge(req);
  
  // 2. Check if authentication succeeded
  if (!auth.success) {
    return createUnauthorizedResponse(auth.error || 'Unauthorized', CORS_HEADERS);
  }
  
  // 3. Use authenticated user ID
  const userId = auth.uid;
  
  // 4. Proceed with business logic
  // ...
}
```

### For Node.js Runtime Endpoints

```typescript
import { verifyFirebaseIdToken } from '../shared/firebase-admin';

export default async function handler(req: Request) {
  try {
    // 1. Verify token directly
    const authHeader = req.headers.get('authorization') ?? undefined;
    const decoded = await verifyFirebaseIdToken(authHeader);
    
    // 2. Use authenticated user ID
    const userId = decoded.uid;
    
    // 3. Proceed with business logic
    // ...
  } catch (e: any) {
    return new Response(
      JSON.stringify({ success: false, error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }
}
```

### Client-Side Request Format

All authenticated requests must include the Firebase ID token in the Authorization header:

```dart
// Flutter/Dart example
final user = FirebaseAuth.instance.currentUser;
final idToken = await user?.getIdToken();

final response = await http.post(
  Uri.parse('https://your-api.com/api/chat'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $idToken',
  },
  body: jsonEncode({
    'messages': [/* ... */],
    'mode': 'chat',
  }),
);
```

---

## Endpoint Security Status

### ✅ Secured Endpoints (Require Authentication)

| Endpoint | Runtime | Authentication Method | Purpose |
|----------|---------|----------------------|---------|
| `/api/chat` | Edge | `verifyAuthForEdge` | Main chat/AI interface |
| `/api/mermaid/generate` | Edge | `verifyAuthForEdge` | Diagram generation |
| `/api/config/app` | Edge | `verifyAuthForEdge` | App configuration |
| `/api/config/models` | Edge | `verifyAuthForEdge` | Model list & capabilities |
| `/api/config/modes` | Edge | `verifyAuthForEdge` | Chat mode configs |
| `/api/config/pricing` | Edge | `verifyAuthForEdge` | Pricing information |
| `/api/config` (index) | Edge | `verifyAuthForEdge` | Unified config |
| `/api/credits/balance` | Node.js | `verifyFirebaseIdToken` | User credit balance |
| `/api/credits/consume` | Node.js | `verifyFirebaseIdToken` | Credit consumption |
| `/api/credits/refund` | Node.js | `verifyFirebaseIdToken` | Credit refunds |

### ⚠️ Special Case Endpoints (No User Auth)

| Endpoint | Authentication | Reason |
|----------|---------------|---------|
| `/api/oauth/callback` | None | OAuth flow callback - auth happens after |
| `/api/rc/webhook` | Webhook Secret | RevenueCat webhook - uses Bearer token secret |

### 📝 Notes on Config Endpoints

Config endpoints (`/api/config/*`) are now **authenticated by default** to prevent:
- Exposing business logic to competitors
- Revealing pricing strategies
- Unauthorized access to feature flags

**If you need public config** (e.g., for pre-authentication screens):
1. Create a separate `/api/config/public` endpoint
2. Include only non-sensitive configuration
3. Document why it's public

---

## Implementation Details

### Firebase Admin Initialization

Location: `/api/shared/firebase-admin.ts`

```typescript
export function getFirebaseAdminApp(): App {
  if (!app) {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

    if (!projectId || !clientEmail || !privateKey) {
      throw new Error('Missing Firebase Admin credentials');
    }

    app = getApps()[0] || initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
    });
  }
  return app;
}
```

### Required Environment Variables

```bash
# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-service-account@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# API Keys
OPENROUTER_API_KEY=your-openrouter-key
BRAVE_API_KEY=your-brave-key

# Webhook Secret
RC_WEBHOOK_SECRET=your-revenuecat-webhook-secret
```

### CORS Configuration

All secured endpoints include proper CORS headers:

```typescript
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS', // or 'GET, OPTIONS'
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
```

---

## Testing Authentication

### Manual Testing with cURL

#### 1. Get Firebase ID Token

```bash
# Use Firebase Auth REST API
curl 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=YOUR_API_KEY' \
  -H 'Content-Type: application/json' \
  --data-binary '{"email":"test@example.com","password":"testpassword","returnSecureToken":true}'
```

Extract `idToken` from the response.

#### 2. Test Authenticated Endpoint

```bash
curl -X POST https://your-api.com/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}],
    "mode": "chat"
  }'
```

#### 3. Test Without Authentication (Should Fail)

```bash
curl -X POST https://your-api.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}],
    "mode": "chat"
  }'

# Expected response:
# {"error":"Missing Authorization header"}
# Status: 401 Unauthorized
```

### Automated Testing

Create test scripts in `/api/__tests__/`:

```typescript
// Example test
describe('Chat API Authentication', () => {
  it('should reject requests without auth token', async () => {
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ messages: [], mode: 'chat' }),
    });
    
    expect(response.status).toBe(401);
    const data = await response.json();
    expect(data.error).toContain('Authorization');
  });
  
  it('should accept requests with valid token', async () => {
    const token = await getTestFirebaseToken();
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({ messages: [], mode: 'chat' }),
    });
    
    expect(response.status).not.toBe(401);
  });
});
```

---

## Common Issues & Solutions

### Issue 1: "Missing Authorization header"

**Cause**: Client not sending Authorization header

**Solution**:
```dart
// Ensure Authorization header is included
final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
headers['Authorization'] = 'Bearer $idToken';
```

### Issue 2: "Invalid Authorization header"

**Cause**: Incorrect header format (not "Bearer <token>")

**Solution**:
```typescript
// Correct format
Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6...

// Incorrect formats
Authorization: eyJhbGciOiJSUzI1NiIsImtpZCI6...  // Missing "Bearer"
Authorization: Bearer: eyJhbGciOiJSUzI1NiIsImtpZCI6...  // Colon after Bearer
```

### Issue 3: Token Expired

**Cause**: Firebase ID tokens expire after 1 hour

**Solution**:
```dart
// Force token refresh
final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

### Issue 4: "Server misconfigured: FIREBASE_*"

**Cause**: Missing environment variables

**Solution**:
1. Check Vercel environment variables
2. Ensure all three Firebase Admin variables are set:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_CLIENT_EMAIL`
   - `FIREBASE_PRIVATE_KEY`
3. For `FIREBASE_PRIVATE_KEY`, ensure newlines are properly escaped

### Issue 5: CORS Errors

**Cause**: OPTIONS preflight request not handled

**Solution**:
```typescript
// Always handle OPTIONS
if (req.method === 'OPTIONS') {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}
```

### Issue 6: 401 During Credit Consumption

**Cause**: Authorization header not forwarded to internal API calls

**Solution**:
```typescript
// Forward auth header to internal endpoints
const consumeRes = await fetch(`${baseUrl}/api/credits/consume`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': req.headers.get('authorization') || '',
  },
  body: JSON.stringify({ /* ... */ }),
});
```

---

## Security Best Practices

### 1. Token Handling

✅ **DO:**
- Store tokens securely (Flutter Secure Storage, Keychain)
- Refresh tokens before they expire
- Clear tokens on logout

❌ **DON'T:**
- Store tokens in SharedPreferences (Android) or UserDefaults (iOS)
- Log tokens in production
- Send tokens over unencrypted connections

### 2. Error Handling

✅ **DO:**
```typescript
// Return specific error for authentication failures
if (!auth.success) {
  return createUnauthorizedResponse(auth.error, CORS_HEADERS);
}

// Log authentication failures
console.error('Authentication failed:', auth.error);
```

❌ **DON'T:**
```typescript
// Return generic errors that hide auth issues
catch (e) {
  return new Response('Internal Server Error', { status: 500 });
}
```

### 3. Authorization vs Authentication

- **Authentication**: Verifying WHO the user is (covered in this guide)
- **Authorization**: Verifying WHAT the user can do

**Example Authorization Check:**
```typescript
// After authentication
const auth = await verifyAuthForEdge(req);
if (!auth.success) return unauthorized();

// Check if user has permission for this resource
const resource = await getResource(resourceId);
if (resource.ownerId !== auth.uid) {
  return new Response(
    JSON.stringify({ error: 'Forbidden' }),
    { status: 403 }
  );
}
```

### 4. Rate Limiting

Consider adding rate limiting to prevent abuse:

```typescript
// Example: Rate limit per user
const rateLimit = await checkRateLimit(auth.uid, endpoint);
if (rateLimit.exceeded) {
  return new Response(
    JSON.stringify({ error: 'Rate limit exceeded' }),
    { status: 429 }
  );
}
```

### 5. Audit Logging

Log authenticated requests for security auditing:

```typescript
console.log({
  timestamp: new Date().toISOString(),
  userId: auth.uid,
  endpoint: req.url,
  method: req.method,
  ip: req.headers.get('x-forwarded-for'),
});
```

### 6. Token Revocation

Implement token revocation for security incidents:

```typescript
// Check if user token has been revoked
const auth = getAdminAuth();
const user = await auth.getUser(decoded.uid);
if (decoded.iat < user.tokensValidAfterTime.getTime() / 1000) {
  throw new Error('Token revoked');
}
```

---

## Migration Guide

If you have existing client code calling these APIs without authentication:

### Step 1: Update Client to Send Auth Tokens

```dart
// Before (insecure)
final response = await http.post(
  Uri.parse('https://your-api.com/api/chat'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({/* ... */}),
);

// After (secure)
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // Handle unauthenticated state
  throw Exception('User must be logged in');
}

final idToken = await user.getIdToken();
final response = await http.post(
  Uri.parse('https://your-api.com/api/chat'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $idToken',
  },
  body: jsonEncode({/* ... */}),
);
```

### Step 2: Handle 401 Errors

```dart
if (response.statusCode == 401) {
  // Token expired or invalid - try refreshing
  final newToken = await user.getIdToken(true);
  
  // Retry request with new token
  final retryResponse = await http.post(
    Uri.parse('https://your-api.com/api/chat'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $newToken',
    },
    body: jsonEncode({/* ... */}),
  );
  
  if (retryResponse.statusCode == 401) {
    // Still failing - sign out user
    await FirebaseAuth.instance.signOut();
    // Navigate to login screen
  }
}
```

### Step 3: Update API Service Classes

```dart
class ApiService {
  static const String baseUrl = 'https://your-api.com/api';
  
  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    final idToken = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }
  
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getAuthHeaders();
    return await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }
}
```

---

## Summary

### Key Takeaways

1. ✅ All user-facing APIs now require Firebase Authentication
2. ✅ OAuth callback and webhook endpoints use appropriate authentication methods
3. ✅ Edge runtime endpoints use helper function for authentication
4. ✅ Consistent error responses (401 for auth failures)
5. ✅ Proper CORS handling with Authorization header support

### Security Checklist

- [ ] All environment variables are set (Firebase Admin credentials)
- [ ] Client code sends Authorization header with Bearer token
- [ ] Client handles 401 responses (token refresh/re-login)
- [ ] Token refresh logic implemented before 1-hour expiration
- [ ] Error logging in place for authentication failures
- [ ] Rate limiting considered for production
- [ ] Audit logging implemented for compliance

---

## Support & Questions

For security-related questions or concerns:
1. Review this document thoroughly
2. Check the [Common Issues](#common-issues--solutions) section
3. Review endpoint-specific comments in the code
4. Test authentication flow using the testing guide

**Remember**: Never commit Firebase private keys or API keys to version control!

