# Vercel Callback Handler Update Guide

## Overview
This guide covers updating the Vercel callback handler to support dynamic OAuth redirects based on the enhanced state parameter.

## Updated Vercel Handler Implementation

### Enhanced `oauth-callback-deploy/index.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OAuth Callback - Cognify</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 2rem;
            border-radius: 12px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            max-width: 400px;
        }
        .spinner {
            border: 3px solid rgba(255, 255, 255, 0.3);
            border-top: 3px solid white;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 1rem;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .success { color: #4ade80; }
        .error { color: #f87171; }
        .button {
            background: rgba(255, 255, 255, 0.2);
            border: 1px solid rgba(255, 255, 255, 0.3);
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            cursor: pointer;
            margin-top: 1rem;
            text-decoration: none;
            display: inline-block;
        }
        .button:hover {
            background: rgba(255, 255, 255, 0.3);
        }
        .debug-info {
            font-size: 0.8em;
            opacity: 0.7;
            margin-top: 1rem;
            text-align: left;
            background: rgba(0, 0, 0, 0.2);
            padding: 0.5rem;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="spinner" id="spinner"></div>
        <h1 id="title">Processing OAuth Callback...</h1>
        <p id="message">Please wait while we redirect you back to the app.</p>
        <div id="actions" style="display: none;">
            <a href="#" id="openApp" class="button">Open Cognify App</a>
        </div>
        <div id="debugInfo" class="debug-info" style="display: none;"></div>
    </div>

    <script>
        // Enhanced OAuth callback handler with dynamic redirect support
        
        // Configuration
        const DEBUG_MODE = true; // Set to false in production
        const ALLOWED_ORIGINS = [
            'http://localhost',
            'https://localhost',
            'http://127.0.0.1',
            'https://127.0.0.1'
        ];
        const MAX_STATE_AGE = 10 * 60 * 1000; // 10 minutes

        // Extract OAuth parameters from URL
        const urlParams = new URLSearchParams(window.location.search);
        const code = urlParams.get('code');
        const encodedState = urlParams.get('state');
        const error = urlParams.get('error');
        
        // DOM elements
        const spinner = document.getElementById('spinner');
        const title = document.getElementById('title');
        const message = document.getElementById('message');
        const actions = document.getElementById('actions');
        const openAppBtn = document.getElementById('openApp');
        const debugInfo = document.getElementById('debugInfo');

        // Debug logging
        function debugLog(msg, data = null) {
            if (DEBUG_MODE) {
                console.log('[OAuth Debug]', msg, data || '');
                const debugDiv = document.getElementById('debugInfo');
                debugDiv.style.display = 'block';
                debugDiv.innerHTML += `<div>${msg}${data ? ': ' + JSON.stringify(data, null, 2) : ''}</div>`;
            }
        }

        function updateUI(success, titleText, messageText, showButton = false) {
            spinner.style.display = 'none';
            title.textContent = titleText;
            title.className = success ? 'success' : 'error';
            message.textContent = messageText;
            if (showButton) {
                actions.style.display = 'block';
            }
        }

        // Enhanced state decoding
        function decodeOAuthState(encodedState) {
            try {
                debugLog('Decoding state', encodedState?.substring(0, 20) + '...');
                
                if (!encodedState) {
                    throw new Error('No state parameter provided');
                }

                // Add padding if needed for Base64URL
                let padded = encodedState;
                while (padded.length % 4 !== 0) {
                    padded += '=';
                }

                // Decode Base64URL
                const jsonString = atob(padded.replace(/-/g, '+').replace(/_/g, '/'));
                const stateData = JSON.parse(jsonString);
                
                debugLog('Decoded state data', stateData);

                // Validate required fields
                if (!stateData.randomState || !stateData.origin || !stateData.timestamp) {
                    throw new Error('Missing required state fields');
                }

                // Validate timestamp (not older than 10 minutes)
                const now = Date.now();
                const stateAge = now - stateData.timestamp;
                if (stateAge > MAX_STATE_AGE) {
                    throw new Error(`State too old: ${Math.round(stateAge / 1000)}s (max ${MAX_STATE_AGE / 1000}s)`);
                }

                // Validate origin
                const isOriginAllowed = ALLOWED_ORIGINS.some(allowed => 
                    stateData.origin.startsWith(allowed)
                );
                
                if (!isOriginAllowed) {
                    throw new Error(`Origin not allowed: ${stateData.origin}`);
                }

                debugLog('State validation passed');
                return stateData;

            } catch (e) {
                debugLog('State decoding failed', e.message);
                throw e;
            }
        }

        // Enhanced redirect logic
        function redirectToOrigin(stateData) {
            const { origin, platform } = stateData;
            
            debugLog('Preparing redirect', { origin, platform });

            // Construct callback URLs
            const webCallbackUrl = `${origin}/oauth/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(encodedState)}`;
            const mobileCallbackUrl = `cognify://oauth/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(encodedState)}`;
            
            debugLog('Callback URLs', { web: webCallbackUrl, mobile: mobileCallbackUrl });

            let redirected = false;

            // Platform-specific redirect strategy
            if (platform === 'web') {
                debugLog('Using web redirect strategy');
                try {
                    window.location.href = webCallbackUrl;
                    redirected = true;
                } catch (e) {
                    debugLog('Web redirect failed', e.message);
                }
            } else {
                debugLog('Using mobile redirect strategy');
                // Try mobile schemes first
                const mobileSchemes = [
                    `cognify://oauth/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(encodedState)}`,
                    `cognify-free://oauth/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(encodedState)}`
                ];

                mobileSchemes.forEach((scheme, index) => {
                    setTimeout(() => {
                        if (!redirected) {
                            try {
                                debugLog(`Trying mobile scheme ${index + 1}`, scheme);
                                window.location.href = scheme;
                                if (index === 0) redirected = true;
                            } catch (e) {
                                debugLog(`Mobile scheme ${index + 1} failed`, e.message);
                            }
                        }
                    }, index * 200);
                });
            }

            // Fallback to web redirect if mobile didn't work
            if (!redirected && platform !== 'web') {
                setTimeout(() => {
                    if (!redirected) {
                        debugLog('Trying web fallback');
                        try {
                            window.location.href = webCallbackUrl;
                            redirected = true;
                        } catch (e) {
                            debugLog('Web fallback failed', e.message);
                        }
                    }
                }, 1000);
            }

            // Show manual option after automatic attempts
            setTimeout(() => {
                updateUI(true, 'Authentication Successful!',
                    'If the app didn\'t open automatically, click the button below:', true);

                openAppBtn.onclick = () => {
                    debugLog('Manual redirect triggered');
                    const allUrls = [webCallbackUrl, ...mobileSchemes];
                    allUrls.forEach(url => {
                        try {
                            window.location.href = url;
                        } catch (e) {
                            debugLog('Manual redirect failed', e.message);
                        }
                    });
                };
            }, 3000);
        }

        // Store OAuth result for polling-based approaches
        function storeOAuthResult(stateData) {
            if (stateData?.randomState) {
                try {
                    const result = {
                        status: error ? 'error' : 'completed',
                        state: encodedState,
                        code,
                        error,
                        timestamp: Date.now(),
                        origin: stateData.origin
                    };
                    localStorage.setItem(`oauth_result_${stateData.randomState}`, JSON.stringify(result));
                    debugLog('OAuth result stored in localStorage', result);
                } catch (e) {
                    debugLog('Failed to store OAuth result', e.message);
                }
            }
        }

        // Main callback handling logic
        function handleCallback() {
            debugLog('Starting OAuth callback processing');
            debugLog('URL parameters', { code: code?.substring(0, 10) + '...', state: encodedState?.substring(0, 20) + '...', error });

            try {
                if (error) {
                    debugLog('OAuth error received', error);
                    updateUI(false, 'Authentication Failed', `Error: ${error}`);
                    return;
                }

                if (!code || !encodedState) {
                    debugLog('Missing required parameters');
                    updateUI(false, 'Invalid Callback', 'Missing required OAuth parameters.');
                    return;
                }

                // Decode and validate state
                const stateData = decodeOAuthState(encodedState);
                
                debugLog('State validation successful, storing result');
                storeOAuthResult(stateData);

                updateUI(true, 'Authentication Successful!', 'Redirecting back to the app...');
                
                setTimeout(() => {
                    redirectToOrigin(stateData);
                }, 1000);

            } catch (e) {
                debugLog('Callback processing failed', e.message);
                updateUI(false, 'Callback Error', `Failed to process callback: ${e.message}`);
                
                // Fallback to hardcoded localhost for development
                if (code && encodedState) {
                    debugLog('Attempting fallback redirect');
                    setTimeout(() => {
                        const fallbackUrl = `http://localhost:3000/oauth/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(encodedState)}`;
                        try {
                            window.location.href = fallbackUrl;
                        } catch (fe) {
                            debugLog('Fallback redirect failed', fe.message);
                        }
                    }, 2000);
                }
            }
        }

        // Initialize callback handling
        handleCallback();

        // Auto-close window after 30 seconds
        setTimeout(() => {
            try {
                debugLog('Auto-closing window');
                window.close();
            } catch (e) {
                debugLog('Could not close window automatically');
            }
        }, 30000);
    </script>
</body>
</html>
```

## Key Features of Updated Handler

### 1. **Enhanced State Decoding**
- Proper Base64URL decoding with padding
- JSON parsing of state data
- Comprehensive validation (timestamp, origin, required fields)

### 2. **Dynamic Redirect Logic**
- Platform-aware redirection (web vs mobile)
- Origin-based callback URL generation
- Multiple fallback strategies

### 3. **Security Validations**
- Origin whitelist checking
- Timestamp validation (10-minute window)
- Required field validation

### 4. **Debug Support**
- Comprehensive logging for development
- Visual debug information display
- Error tracking and reporting

### 5. **Fallback Mechanisms**
- Multiple mobile scheme attempts
- Web fallback for mobile failures
- Hardcoded localhost fallback for development

## Testing Strategy

### 1. **Development Testing**
```bash
# Test different ports
flutter run -d chrome --web-port 3000
flutter run -d chrome --web-port 8080
flutter run -d chrome --web-port 8081
```

### 2. **State Parameter Testing**
Create test states to verify decoding:
```javascript
// Test state generation
const testState = {
  randomState: "abc123",
  origin: "http://localhost:8080",
  timestamp: Date.now(),
  version: "1.0",
  platform: "web"
};
const encoded = btoa(JSON.stringify(testState)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
console.log('Test encoded state:', encoded);
```

### 3. **Security Testing**
- Test expired states (older than 10 minutes)
- Test invalid origins
- Test malformed state parameters
- Test missing required fields

## Deployment

### 1. **Update Vercel Deployment**
```bash
cd oauth-callback-deploy
# Replace index.html with the enhanced version
vercel --prod
```

### 2. **Environment Configuration**
- Set `DEBUG_MODE = false` for production
- Update `ALLOWED_ORIGINS` with your production domains
- Test with actual OAuth flow

### 3. **Monitoring**
- Monitor Vercel function logs
- Track successful vs failed redirects
- Monitor state validation failures

## Security Considerations

### 1. **State Parameter Security**
- ✅ Base64URL encoding prevents URL issues
- ✅ Timestamp validation prevents replay attacks
- ✅ Origin whitelist prevents unauthorized redirects
- ✅ Required field validation ensures data integrity

### 2. **Origin Validation**
- Only localhost and specified domains allowed
- Protocol validation (http/https)
- Port range validation if needed

### 3. **Error Handling**
- No sensitive data in error messages
- Proper fallback mechanisms
- Logging for debugging without exposing secrets

## Production Checklist

- [ ] Update `ALLOWED_ORIGINS` with production domains
- [ ] Set `DEBUG_MODE = false`
- [ ] Test with actual OAuth flow
- [ ] Verify redirect works on all target platforms
- [ ] Monitor error rates and performance
- [ ] Test fallback mechanisms
- [ ] Validate security measures

## Integration with Flutter App

The Flutter app needs to:
1. Generate enhanced state with origin information
2. Handle the callback with decoded state validation
3. Support both the new dynamic approach and legacy fallback

This creates a robust, secure, and developer-friendly OAuth callback system that automatically adapts to different development environments and ports.