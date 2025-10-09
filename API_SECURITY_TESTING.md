# API Security Testing Guide

## Overview

This guide provides comprehensive testing procedures to verify that all Cognify API endpoints are properly secured and scoped to logged-in users only.

## Table of Contents

1. [Quick Security Verification](#quick-security-verification)
2. [Detailed Endpoint Testing](#detailed-endpoint-testing)
3. [Automated Testing Scripts](#automated-testing-scripts)
4. [Security Regression Testing](#security-regression-testing)
5. [Performance Impact Testing](#performance-impact-testing)

---

## Quick Security Verification

### Prerequisites

1. Have a test Firebase account ready
2. Install `curl` or `httpie` for command-line testing
3. Have your API base URL (e.g., `https://your-project.vercel.app`)

### Step 1: Verify Unauthenticated Access is Blocked

Test all secured endpoints WITHOUT authentication:

```bash
# Set your API base URL
export API_BASE="https://your-project.vercel.app"

# Test chat endpoint
curl -X POST $API_BASE/api/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}],"mode":"chat"}' \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 401
# Expected body: {"error":"Missing Authorization header"}

# Test mermaid endpoint
curl -X POST $API_BASE/api/mermaid/generate \
  -H "Content-Type: application/json" \
  -d '{"code":"graph TD; A-->B"}' \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 401

# Test config endpoints
curl -X GET $API_BASE/api/config/app -w "\nStatus: %{http_code}\n"
# Expected: Status: 401

curl -X GET $API_BASE/api/config/models -w "\nStatus: %{http_code}\n"
# Expected: Status: 401

curl -X GET $API_BASE/api/config/modes -w "\nStatus: %{http_code}\n"
# Expected: Status: 401

curl -X GET $API_BASE/api/config/pricing -w "\nStatus: %{http_code}\n"
# Expected: Status: 401

curl -X GET $API_BASE/api/config -w "\nStatus: %{http_code}\n"
# Expected: Status: 401

# Test credits endpoints
curl -X GET $API_BASE/api/credits/balance \
  -H "Content-Type: application/json" \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 401

curl -X POST $API_BASE/api/credits/consume \
  -H "Content-Type: application/json" \
  -d '{"amount":10,"requestId":"test"}' \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 401

curl -X POST $API_BASE/api/credits/refund \
  -H "Content-Type: application/json" \
  -d '{"requestId":"test"}' \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 401
```

**✅ PASS Criteria**: All endpoints return HTTP 401 with authentication error message

**❌ FAIL Criteria**: Any endpoint returns 200 or processes the request without auth

### Step 2: Get Firebase ID Token

```bash
# Replace with your Firebase Web API Key
export FIREBASE_API_KEY="YOUR_FIREBASE_WEB_API_KEY"
export TEST_EMAIL="test@example.com"
export TEST_PASSWORD="testpassword"

# Sign in and get ID token
RESPONSE=$(curl -s 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key='$FIREBASE_API_KEY \
  -H 'Content-Type: application/json' \
  --data-binary '{
    "email":"'$TEST_EMAIL'",
    "password":"'$TEST_PASSWORD'",
    "returnSecureToken":true
  }')

# Extract ID token
export ID_TOKEN=$(echo $RESPONSE | jq -r '.idToken')

# Verify token was obtained
echo "ID Token: ${ID_TOKEN:0:50}..."
```

### Step 3: Verify Authenticated Access Works

Test all secured endpoints WITH authentication:

```bash
# Test chat endpoint
curl -X POST $API_BASE/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{"messages":[{"role":"user","content":"Hello"}],"mode":"chat"}' \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 200 or 409 (insufficient credits)
# Should NOT be 401

# Test config endpoints
curl -X GET $API_BASE/api/config/app \
  -H "Authorization: Bearer $ID_TOKEN" \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 200
# Should return config data

curl -X GET $API_BASE/api/config/models \
  -H "Authorization: Bearer $ID_TOKEN" \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 200

curl -X GET $API_BASE/api/credits/balance \
  -H "Authorization: Bearer $ID_TOKEN" \
  -w "\nStatus: %{http_code}\n"

# Expected: Status: 200
# Should return balance data
```

**✅ PASS Criteria**: All endpoints return appropriate success responses (200, or business logic errors like 409)

**❌ FAIL Criteria**: Any endpoint still returns 401 with valid token

---

## Detailed Endpoint Testing

### Test Script Template

Create a file `test-api-security.sh`:

```bash
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
API_BASE="${API_BASE:-https://your-project.vercel.app}"
FIREBASE_API_KEY="${FIREBASE_API_KEY:-}"
TEST_EMAIL="${TEST_EMAIL:-test@example.com}"
TEST_PASSWORD="${TEST_PASSWORD:-testpassword}"

echo "================================"
echo "API Security Test Suite"
echo "================================"
echo "API Base: $API_BASE"
echo ""

# Function to test unauthenticated endpoint
test_unauth() {
  local endpoint=$1
  local method=${2:-GET}
  local data=$3
  
  echo -n "Testing $method $endpoint (unauth)... "
  
  if [ "$method" = "GET" ]; then
    status=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE$endpoint")
  else
    status=$(curl -s -o /dev/null -w "%{http_code}" -X $method "$API_BASE$endpoint" \
      -H "Content-Type: application/json" \
      -d "$data")
  fi
  
  if [ "$status" = "401" ]; then
    echo -e "${GREEN}PASS${NC} (401)"
  else
    echo -e "${RED}FAIL${NC} (got $status, expected 401)"
    return 1
  fi
  return 0
}

# Function to test authenticated endpoint
test_auth() {
  local endpoint=$1
  local method=${2:-GET}
  local data=$3
  
  echo -n "Testing $method $endpoint (auth)... "
  
  if [ "$method" = "GET" ]; then
    status=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE$endpoint" \
      -H "Authorization: Bearer $ID_TOKEN")
  else
    status=$(curl -s -o /dev/null -w "%{http_code}" -X $method "$API_BASE$endpoint" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ID_TOKEN" \
      -d "$data")
  fi
  
  if [ "$status" != "401" ]; then
    echo -e "${GREEN}PASS${NC} ($status)"
  else
    echo -e "${RED}FAIL${NC} (got 401, should be authenticated)"
    return 1
  fi
  return 0
}

# Get Firebase ID token
echo "Getting Firebase ID token..."
RESPONSE=$(curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FIREBASE_API_KEY" \
  -H 'Content-Type: application/json' \
  --data-binary "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"returnSecureToken\":true}")

ID_TOKEN=$(echo $RESPONSE | jq -r '.idToken')

if [ "$ID_TOKEN" = "null" ] || [ -z "$ID_TOKEN" ]; then
  echo -e "${RED}Failed to get ID token. Check credentials.${NC}"
  exit 1
fi

echo -e "${GREEN}ID token obtained${NC}"
echo ""

# Test suite
echo "Testing Unauthenticated Access (should all be 401):"
echo "------------------------------------------------"

FAIL_COUNT=0

test_unauth "/api/chat" "POST" '{"messages":[],"mode":"chat"}' || ((FAIL_COUNT++))
test_unauth "/api/mermaid/generate" "POST" '{"code":"graph TD; A-->B"}' || ((FAIL_COUNT++))
test_unauth "/api/config/app" "GET" || ((FAIL_COUNT++))
test_unauth "/api/config/models" "GET" || ((FAIL_COUNT++))
test_unauth "/api/config/modes" "GET" || ((FAIL_COUNT++))
test_unauth "/api/config/pricing" "GET" || ((FAIL_COUNT++))
test_unauth "/api/config" "GET" || ((FAIL_COUNT++))
test_unauth "/api/credits/balance" "GET" || ((FAIL_COUNT++))
test_unauth "/api/credits/consume" "POST" '{"amount":10,"requestId":"test"}' || ((FAIL_COUNT++))
test_unauth "/api/credits/refund" "POST" '{"requestId":"test"}' || ((FAIL_COUNT++))

echo ""
echo "Testing Authenticated Access (should NOT be 401):"
echo "-----------------------------------------------"

test_auth "/api/config/app" "GET" || ((FAIL_COUNT++))
test_auth "/api/config/models" "GET" || ((FAIL_COUNT++))
test_auth "/api/config/modes" "GET" || ((FAIL_COUNT++))
test_auth "/api/config/pricing" "GET" || ((FAIL_COUNT++))
test_auth "/api/config" "GET" || ((FAIL_COUNT++))
test_auth "/api/credits/balance" "GET" || ((FAIL_COUNT++))

echo ""
echo "================================"
if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}$FAIL_COUNT test(s) failed${NC}"
  exit 1
fi
```

Make it executable and run:

```bash
chmod +x test-api-security.sh

# Set required environment variables
export API_BASE="https://your-project.vercel.app"
export FIREBASE_API_KEY="your-firebase-web-api-key"
export TEST_EMAIL="test@example.com"
export TEST_PASSWORD="testpassword"

# Run the tests
./test-api-security.sh
```

---

## Automated Testing Scripts

### Node.js Test Suite

Create `test-security.js`:

```javascript
const fetch = require('node-fetch');

const API_BASE = process.env.API_BASE || 'https://your-project.vercel.app';
const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY;
const TEST_EMAIL = process.env.TEST_EMAIL || 'test@example.com';
const TEST_PASSWORD = process.env.TEST_PASSWORD || 'testpassword';

async function getIdToken() {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
        returnSecureToken: true,
      }),
    }
  );
  
  const data = await response.json();
  return data.idToken;
}

async function testEndpoint(endpoint, options = {}) {
  const { method = 'GET', body, auth = false, token } = options;
  
  const headers = {
    'Content-Type': 'application/json',
  };
  
  if (auth && token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  const response = await fetch(`${API_BASE}${endpoint}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  
  return {
    status: response.status,
    ok: response.ok,
  };
}

async function runTests() {
  console.log('API Security Test Suite');
  console.log('======================\n');
  
  // Get auth token
  console.log('Getting Firebase ID token...');
  const idToken = await getIdToken();
  console.log('✓ Token obtained\n');
  
  let passed = 0;
  let failed = 0;
  
  // Test unauthenticated access (should all be 401)
  console.log('Testing Unauthenticated Access:');
  console.log('-------------------------------');
  
  const unauthTests = [
    { endpoint: '/api/chat', method: 'POST', body: { messages: [], mode: 'chat' } },
    { endpoint: '/api/mermaid/generate', method: 'POST', body: { code: 'graph TD; A-->B' } },
    { endpoint: '/api/config/app', method: 'GET' },
    { endpoint: '/api/config/models', method: 'GET' },
    { endpoint: '/api/config/modes', method: 'GET' },
    { endpoint: '/api/config/pricing', method: 'GET' },
    { endpoint: '/api/config', method: 'GET' },
    { endpoint: '/api/credits/balance', method: 'GET' },
    { endpoint: '/api/credits/consume', method: 'POST', body: { amount: 10, requestId: 'test' } },
    { endpoint: '/api/credits/refund', method: 'POST', body: { requestId: 'test' } },
  ];
  
  for (const test of unauthTests) {
    const result = await testEndpoint(test.endpoint, {
      method: test.method,
      body: test.body,
      auth: false,
    });
    
    if (result.status === 401) {
      console.log(`✓ ${test.method} ${test.endpoint} - correctly blocked (401)`);
      passed++;
    } else {
      console.log(`✗ ${test.method} ${test.endpoint} - SECURITY ISSUE (got ${result.status}, expected 401)`);
      failed++;
    }
  }
  
  console.log('\nTesting Authenticated Access:');
  console.log('----------------------------');
  
  const authTests = [
    { endpoint: '/api/config/app', method: 'GET' },
    { endpoint: '/api/config/models', method: 'GET' },
    { endpoint: '/api/config/modes', method: 'GET' },
    { endpoint: '/api/config/pricing', method: 'GET' },
    { endpoint: '/api/config', method: 'GET' },
    { endpoint: '/api/credits/balance', method: 'GET' },
  ];
  
  for (const test of authTests) {
    const result = await testEndpoint(test.endpoint, {
      method: test.method,
      auth: true,
      token: idToken,
    });
    
    if (result.status !== 401) {
      console.log(`✓ ${test.method} ${test.endpoint} - authenticated (${result.status})`);
      passed++;
    } else {
      console.log(`✗ ${test.method} ${test.endpoint} - auth not working (got 401)`);
      failed++;
    }
  }
  
  console.log('\n======================');
  console.log(`Results: ${passed} passed, ${failed} failed`);
  
  if (failed > 0) {
    console.log('\n⚠️  SECURITY ISSUES DETECTED ⚠️');
    process.exit(1);
  } else {
    console.log('\n✓ All security tests passed');
    process.exit(0);
  }
}

runTests().catch(error => {
  console.error('Test suite error:', error);
  process.exit(1);
});
```

Run with:

```bash
npm install node-fetch
node test-security.js
```

---

## Security Regression Testing

### Add to CI/CD Pipeline

Create `.github/workflows/security-test.yml`:

```yaml
name: API Security Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  security-tests:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm install node-fetch
      
      - name: Run security tests
        env:
          API_BASE: ${{ secrets.API_BASE }}
          FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}
          TEST_EMAIL: ${{ secrets.TEST_EMAIL }}
          TEST_PASSWORD: ${{ secrets.TEST_PASSWORD }}
        run: node test-security.js
```

### Pre-deployment Verification

Add to `package.json`:

```json
{
  "scripts": {
    "test:security": "node test-security.js",
    "predeploy": "npm run test:security"
  }
}
```

---

## Performance Impact Testing

### Measure Auth Overhead

```bash
#!/bin/bash

echo "Performance Impact Test"
echo "======================"
echo ""

# Test without auth verification (baseline - should fail but measure time)
echo "Baseline (no auth - will fail):"
time curl -s -o /dev/null "$API_BASE/api/config/app"

echo ""
echo "With authentication:"
time curl -s -o /dev/null -H "Authorization: Bearer $ID_TOKEN" "$API_BASE/api/config/app"

echo ""
echo "Expected overhead: ~10-20ms for Edge runtime endpoints"
```

### Load Testing

Using `ab` (Apache Bench):

```bash
# Install ab
# Ubuntu/Debian: sudo apt-get install apache2-utils
# macOS: already installed

# Test with authentication
ab -n 100 -c 10 \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  "$API_BASE/api/config/app"

# Expected: All requests should succeed (non-401 status)
```

---

## Security Checklist

Before deploying to production, verify:

- [ ] All secured endpoints return 401 without authentication
- [ ] All secured endpoints accept valid Firebase ID tokens
- [ ] Config endpoints require authentication (unless intentionally public)
- [ ] Credits endpoints require authentication
- [ ] Chat endpoint requires authentication
- [ ] Mermaid endpoint requires authentication
- [ ] OAuth callback remains public (special case)
- [ ] RevenueCat webhook uses secret authentication
- [ ] CORS headers include `Authorization` in allowed headers
- [ ] Error messages don't leak sensitive information
- [ ] Performance overhead is acceptable (<50ms)
- [ ] Token expiration is handled gracefully
- [ ] Refresh token logic works correctly

---

## Troubleshooting Test Failures

### Test fails with "Failed to get ID token"

**Cause**: Invalid Firebase credentials or API key

**Solution**:
1. Verify `FIREBASE_API_KEY` is correct (from Firebase Console > Project Settings > Web API Key)
2. Verify test user exists in Firebase Authentication
3. Check Firebase Authentication is enabled in Firebase Console

### Test fails with "connection refused"

**Cause**: API not deployed or wrong base URL

**Solution**:
1. Verify `API_BASE` URL is correct
2. Check deployment status on Vercel
3. Test API is accessible: `curl $API_BASE/api/health` (if you have a health endpoint)

### Some endpoints return 401 even with valid token

**Cause**: Auth verification not properly implemented

**Solution**:
1. Check endpoint code has `verifyAuthForEdge` or `verifyFirebaseIdToken` call
2. Verify imports are correct
3. Check logs for specific error messages
4. Ensure Firebase Admin environment variables are set in Vercel

### All tests pass locally but fail in CI

**Cause**: Environment variables not set in CI

**Solution**:
1. Add secrets to GitHub Actions:
   - `API_BASE`
   - `FIREBASE_API_KEY`
   - `TEST_EMAIL`
   - `TEST_PASSWORD`
2. Verify secrets are correctly referenced in workflow file

---

## Next Steps

After verifying security:

1. ✅ Deploy to production
2. ✅ Update client applications to send Authorization headers
3. ✅ Monitor logs for authentication failures
4. ✅ Set up alerts for suspicious activity (many 401s)
5. ✅ Implement rate limiting if needed
6. ✅ Add audit logging for compliance
7. ✅ Regular security audits (monthly)

---

## Support

If tests fail or you discover security issues:

1. **DO NOT** deploy until fixed
2. Review the [API Security Guide](./API_SECURITY_GUIDE.md)
3. Check endpoint code for proper auth implementation
4. Verify environment variables are set
5. Test manually with cURL to isolate the issue

