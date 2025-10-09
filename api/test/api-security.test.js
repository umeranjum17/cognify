/* API Security End-to-End Test
 * Requires Node 18+ (global fetch).
 * Env vars: API_BASE, FIREBASE_API_KEY, TEST_EMAIL, TEST_PASSWORD, (optional) RC_WEBHOOK_SECRET
 */

const API_BASE = process.env.API_BASE;
const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY;
const TEST_EMAIL = process.env.TEST_EMAIL;
const TEST_PASSWORD = process.env.TEST_PASSWORD;
const RC_WEBHOOK_SECRET = process.env.RC_WEBHOOK_SECRET;

if (!API_BASE || !FIREBASE_API_KEY || !TEST_EMAIL || !TEST_PASSWORD) {
  console.error('Missing env: API_BASE, FIREBASE_API_KEY, TEST_EMAIL, TEST_PASSWORD');
  process.exit(1);
}

async function getIdToken() {
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD, returnSecureToken: true }),
  });
  const json = await res.json();
  if (!res.ok || !json.idToken) throw new Error(`Login failed: ${JSON.stringify(json)}`);
  return json.idToken;
}

async function request(method, path, { headers = {}, body } = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const ct = res.headers.get('content-type') || '';
  const isJson = ct.includes('application/json');
  const data = isJson ? await res.json().catch(() => ({})) : await res.text();
  return { status: res.status, ok: res.ok, data, headers: res.headers, isJson };
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function run() {
  let failures = 0;
  const fail = (m) => { console.error('FAIL:', m); failures++; };
  const pass = (m) => console.log('PASS:', m);

  console.log('=== Unauthenticated checks (expect 401) ===');
  const unauthTests = [
    ['POST', '/api/chat', { body: { messages: [{ role: 'user', content: 'hi' }], mode: 'chat' } }],
    ['POST', '/api/mermaid/generate', { body: { code: 'graph TD; A-->B' } }],
    ['GET', '/api/config/app'],
    ['GET', '/api/config/models'],
    ['GET', '/api/config/modes'],
    ['GET', '/api/config/pricing'],
    ['GET', '/api/config'],
    ['GET', '/api/credits/balance'],
    ['POST', '/api/credits/consume', { body: { amount: 1, requestId: `test-${Date.now()}` } }],
    ['POST', '/api/credits/refund', { body: { requestId: `missing-${Date.now()}` } }],
  ];

  for (const [method, path, options] of unauthTests) {
    try {
      const r = await request(method, path, { ...(options || {}), headers: { 'Content-Type': 'application/json' } });
      assert(r.status === 401, `${method} ${path} expected 401, got ${r.status}`);
      pass(`${method} ${path} blocked (401)`);
    } catch (e) {
      fail(`${method} ${path}: ${e.message}`);
    }
  }

  console.log('\n=== Special cases ===');
  try {
    const r = await request('GET', '/api/oauth/callback?code=abc&state=xyz');
    assert(r.status === 200, `GET /api/oauth/callback expected 200, got ${r.status}`);
    pass('GET /api/oauth/callback (200)');
  } catch (e) {
    fail(`GET /api/oauth/callback: ${e.message}`);
  }

  try {
    const r1 = await request('POST', '/api/rc/webhook', {
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer wrong' },
      body: { foo: 'bar' },
    });
    assert(r1.status === 401, `/api/rc/webhook wrong secret expected 401, got ${r1.status}`);
    pass('POST /api/rc/webhook wrong secret blocked (401)');

    if (RC_WEBHOOK_SECRET) {
      const r2 = await request('POST', '/api/rc/webhook', {
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${RC_WEBHOOK_SECRET}` },
        body: {},
      });
      assert([200, 400].includes(r2.status), `/api/rc/webhook valid secret expected 200/400, got ${r2.status}`);
      pass('POST /api/rc/webhook valid secret (200/400)');
    } else {
      console.log('SKIP /api/rc/webhook with valid secret: RC_WEBHOOK_SECRET not set');
    }
  } catch (e) {
    fail(`/api/rc/webhook: ${e.message}`);
  }

  console.log('\n=== Authenticated checks ===');
  let token;
  try {
    token = await getIdToken();
    pass('Obtained Firebase ID token');
  } catch (e) {
    fail(`getIdToken: ${e.message}`);
    process.exit(1);
  }

  const authHeaders = { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` };

  for (const path of ['/api/config/app', '/api/config/models', '/api/config/modes', '/api/config/pricing', '/api/config']) {
    try {
      const r = await request('GET', path, { headers: authHeaders });
      assert(r.status === 200, `${path} expected 200, got ${r.status}`);
      assert(r.isJson, `${path} expected JSON`);
      pass(`GET ${path} (200)`);
    } catch (e) {
      fail(`GET ${path}: ${e.message}`);
    }
  }

  try {
    const r = await request('GET', '/api/credits/balance', { headers: authHeaders });
    assert(r.status === 200, `/api/credits/balance expected 200, got ${r.status}`);
    assert(r.isJson, `/api/credits/balance expected JSON`);
    pass('GET /api/credits/balance (200)');
  } catch (e) {
    fail(`/api/credits/balance: ${e.message}`);
  }

  try {
    const r = await request('POST', '/api/chat', {
      headers: authHeaders,
      body: { messages: [{ role: 'user', content: 'Say hello' }], mode: 'chat' },
    });
    assert([200, 409].includes(r.status), `/api/chat expected 200/409, got ${r.status}`);
    pass(`POST /api/chat (${r.status})`);
  } catch (e) {
    fail(`/api/chat: ${e.message}`);
  }

  try {
    const r = await request('POST', '/api/mermaid/generate', {
      headers: authHeaders,
      body: { code: 'graph TD; A-->B', format: 'png' },
    });
    assert(r.status === 200, `/api/mermaid/generate expected 200, got ${r.status}`);
    const ct = r.headers.get('content-type') || '';
    assert(ct.includes('image/'), `expected image content-type, got ${ct}`);
    pass('POST /api/mermaid/generate (200 image)');
  } catch (e) {
    fail(`/api/mermaid/generate: ${e.message}`);
  }

  if (failures > 0) {
    console.error(`\n${failures} test(s) failed`);
    process.exit(1);
  } else {
    console.log('\nAll tests passed');
  }
}

run().catch((e) => {
  console.error('Unhandled error:', e);
  process.exit(1);
});


