import express from 'express';

export const oauthRouter = express.Router();

// GET /api/oauth/callback - OAuth callback handler
oauthRouter.get('/callback', (req, res) => {
  const { code, state, error } = req.query;
  
  if (error) {
    res.status(400).send(`
      <!DOCTYPE html>
      <html>
        <head><title>OAuth Error</title></head>
        <body>
          <h1>Authentication Error</h1>
          <p>${error}</p>
          <script>
            setTimeout(() => window.close(), 3000);
          </script>
        </body>
      </html>
    `);
    return;
  }
  
  res.send(`
    <!DOCTYPE html>
    <html>
      <head><title>Authentication Successful</title></head>
      <body>
        <h1>Authentication Successful</h1>
        <p>You can close this window now.</p>
        <script>
          if (window.opener) {
            window.opener.postMessage({ type: 'oauth_success', code: '${code}', state: '${state}' }, '*');
          }
          setTimeout(() => window.close(), 2000);
        </script>
      </body>
    </html>
  `);
});

