// In-memory storage for OAuth states (in production, use Redis or database)
const oauthStates = new Map();

// Clean up old states (older than 10 minutes)
function cleanupOldStates() {
  const tenMinutesAgo = Date.now() - 10 * 60 * 1000;
  for (const [state, data] of oauthStates.entries()) {
    if (data.timestamp < tenMinutesAgo) {
      oauthStates.delete(state);
    }
  }
}

export default function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  cleanupOldStates();

  if (req.method === 'GET') {
    // Check status of OAuth flow
    const { state } = req.query;
    
    if (!state) {
      return res.status(400).json({ error: 'Missing state parameter' });
    }

    const oauthData = oauthStates.get(state);
    
    if (!oauthData) {
      return res.status(200).json({ status: 'pending' });
    }

    return res.status(200).json({
      status: oauthData.status,
      code: oauthData.code,
      state: oauthData.state,
      error: oauthData.error
    });
  }

  if (req.method === 'POST') {
    // Store OAuth result
    const { state, code, error } = req.body;
    
    if (!state) {
      return res.status(400).json({ error: 'Missing state parameter' });
    }

    oauthStates.set(state, {
      status: error ? 'error' : 'completed',
      code,
      state,
      error,
      timestamp: Date.now()
    });

    return res.status(200).json({ success: true });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
