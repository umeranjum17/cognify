# API Security Quick Reference

## ✅ Security Status: All APIs Secured

All Cognify APIs are now protected and require Firebase Authentication.

---

## 🚀 Quick Start

### For New Endpoints

When creating a new API endpoint, use this template:

#### Edge Runtime (streaming, performance-critical):
```typescript
import { verifyAuthForEdge, createUnauthorizedResponse } from '../shared/auth-helpers';

export const config = { runtime: 'edge' };

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default async function handler(req: Request) {
  // Handle OPTIONS
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  // ✅ AUTHENTICATION CHECK - ALWAYS FIRST
  const auth = await verifyAuthForEdge(req);
  if (!auth.success) {
    return createUnauthorizedResponse(auth.error || 'Unauthorized', CORS_HEADERS);
  }

  // Now use auth.uid for user-specific operations
  // ... your business logic
}
```

#### Node.js Runtime (uses Firebase Admin directly):
```typescript
import { verifyFirebaseIdToken } from '../shared/firebase-admin';

export const config = { runtime: 'nodejs18.x' };

export default async function handler(req: Request) {
  try {
    // ✅ AUTHENTICATION CHECK - ALWAYS FIRST
    const authHeader = req.headers.get('authorization') ?? undefined;
    const decoded = await verifyFirebaseIdToken(authHeader);
    const uid = decoded.uid;

    // ... your business logic
  } catch (e: any) {
    return new Response(
      JSON.stringify({ success: false, error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }
}
```

---

## 📱 Client-Side Implementation

### Flutter/Dart

```dart
// Get Firebase ID token
final user = FirebaseAuth.instance.currentUser;
final idToken = await user?.getIdToken();

// Make authenticated request
final response = await http.post(
  Uri.parse('$apiBase/api/chat'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $idToken',
  },
  body: jsonEncode(requestBody),
);

// Handle 401 (token expired)
if (response.statusCode == 401) {
  // Refresh token and retry
  final newToken = await user?.getIdToken(true);
  // Retry request...
}
```

### Create Reusable API Service

```dart
class ApiService {
  static const String baseUrl = 'https://your-api.com/api';

  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    
    // Auto-retry on 401
    if (response.statusCode == 401) {
      final user = FirebaseAuth.instance.currentUser;
      final newToken = await user?.getIdToken(true);
      return await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $newToken',
        },
        body: jsonEncode(body),
      );
    }
    
    return response;
  }
}
```

---

## 🧪 Quick Test

### Test Without Auth (should fail):
```bash
curl -X GET https://your-api.com/api/config/app
# Expected: {"error":"Missing Authorization header"}
# Status: 401
```

### Test With Auth (should work):
```bash
# Get token first (use your Firebase credentials)
curl -X GET https://your-api.com/api/config/app \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
# Expected: Config data
# Status: 200
```

---

## 📋 Environment Variables Checklist

Required in Vercel (or .env.local for local dev):

```bash
✅ FIREBASE_PROJECT_ID=your-project-id
✅ FIREBASE_CLIENT_EMAIL=service-account@project.iam.gserviceaccount.com
✅ FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
✅ OPENROUTER_API_KEY=your-key
✅ BRAVE_API_KEY=your-key
✅ RC_WEBHOOK_SECRET=your-secret
```

---

## 🔒 Secured Endpoints

| Endpoint | Auth Required |
|----------|--------------|
| `/api/chat` | ✅ Yes |
| `/api/mermaid/generate` | ✅ Yes |
| `/api/config/app` | ✅ Yes |
| `/api/config/models` | ✅ Yes |
| `/api/config/modes` | ✅ Yes |
| `/api/config/pricing` | ✅ Yes |
| `/api/config` | ✅ Yes |
| `/api/credits/balance` | ✅ Yes |
| `/api/credits/consume` | ✅ Yes |
| `/api/credits/refund` | ✅ Yes |
| `/api/oauth/callback` | ❌ No (OAuth flow) |
| `/api/rc/webhook` | ⚠️ Webhook Secret |

---

## ⚠️ Common Errors & Fixes

| Error | Cause | Solution |
|-------|-------|----------|
| `Missing Authorization header` | Client not sending token | Add `Authorization: Bearer <token>` header |
| `Invalid Authorization header` | Wrong format | Use `Bearer <token>`, not just `<token>` |
| Token expired | Token > 1 hour old | Call `getIdToken(true)` to force refresh |
| `Missing Firebase Admin credentials` | Env vars not set | Set all 3 Firebase env vars in Vercel |
| CORS error | Missing headers | Ensure CORS_HEADERS includes `Authorization` |

---

## 📚 Full Documentation

- **[API_SECURITY_GUIDE.md](./API_SECURITY_GUIDE.md)** - Complete security documentation (20+ pages)
- **[API_SECURITY_TESTING.md](./API_SECURITY_TESTING.md)** - Testing procedures (15+ pages)
- **[API_SECURITY_IMPLEMENTATION_SUMMARY.md](./API_SECURITY_IMPLEMENTATION_SUMMARY.md)** - What was implemented

---

## 🎯 Security Checklist

Before deploying:
- [ ] Environment variables set in Vercel
- [ ] All new endpoints include auth check
- [ ] Client code updated to send Authorization header
- [ ] Token refresh logic implemented
- [ ] Tested without auth (should return 401)
- [ ] Tested with valid auth (should work)
- [ ] Tested with expired token (should refresh)

---

## 🆘 Getting Help

1. Check error message carefully
2. Review [Common Errors](#️-common-errors--fixes) section above
3. Check the full guides in API_SECURITY_GUIDE.md
4. Verify environment variables are set
5. Test manually with cURL to isolate issue

---

**Last Updated**: October 8, 2025  
**Security Status**: ✅ Production Ready

