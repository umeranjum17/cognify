export const config = {
  runtime: 'edge',
};

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get('code') ?? '';
  const state = url.searchParams.get('state') ?? '';
  const error = url.searchParams.get('error');

  const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>OAuth Callback</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Oxygen, Ubuntu, Cantarell, Helvetica Neue, Arial, sans-serif; padding: 24px; line-height: 1.5; }
      .ok { color: #0a0; }
      .err { color: #a00; }
      code { background: #f5f5f5; padding: 2px 4px; border-radius: 4px; }
      .small { color: #666; font-size: 0.9em; }
    </style>
  </head>
  <body>
    <h1>${error ? 'Authentication Failed' : 'Authentication Complete'}</h1>
    ${error ? `<p class="err">Error: <code>${escapeHtml(error)}</code></p>` : ''}
    <p class="small">You can close this tab. If it doesn't close automatically, it will try to return to the app.</p>
    <script>
      (function () {
        var payload = { type: 'oauth_callback', code: ${JSON.stringify(code)}, state: ${JSON.stringify(state)}, error: ${JSON.stringify(error)} };
        try {
          if (window.opener && !window.opener.closed) {
            window.opener.postMessage(payload, '*');
            setTimeout(function(){ window.close(); }, 100);
          }
        } catch (e) {}

        // Mobile fallback: try custom scheme
        var schemeUrl = 'cognify://oauth/callback?code=' + encodeURIComponent(${JSON.stringify(code)}) + '&state=' + encodeURIComponent(${JSON.stringify(state)}) + (${JSON.stringify(error)} ? '&error=' + encodeURIComponent(${JSON.stringify(error)}) : '');
        setTimeout(function(){ window.location.href = schemeUrl; }, 300);
      })();
    </script>
  </body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function escapeHtml(s: string) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

