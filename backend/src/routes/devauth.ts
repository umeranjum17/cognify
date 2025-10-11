import express from 'express';
import { getAdminAuth } from '../services/firebase.js';

export const devAuthRouter = express.Router();

// POST /api/devauth/custom-token
// Dev-only endpoint to mint a Firebase custom token for simulator use
devAuthRouter.post('/custom-token', async (req, res) => {
  try {
    const { uid, email, claims } = req.body || {};

    // Gate: Only allow in non-production environments
    const env = (process.env.NODE_ENV || 'development').toLowerCase();
    const allowInProd = process.env.ALLOW_DEVAUTH_IN_PROD === 'true';
    if (env === 'production' && !allowInProd) {
      res.status(403).json({ error: 'Forbidden in production' });
      return;
    }

    const effectiveUid = typeof uid === 'string' && uid.trim().length > 0
      ? uid.trim()
      : `dev_${Date.now().toString(36)}`;

    const sanitizedEmail = typeof email === 'string' && email.includes('@')
      ? email
      : undefined;

    const additionalClaims = (claims && typeof claims === 'object') ? claims : {};

    // Ensure the user exists; if not, create a placeholder via custom claims usage only
    // Firebase custom tokens do not require pre-created users. We'll just mint a token.
    const auth = getAdminAuth();
    const token = await auth.createCustomToken(effectiveUid, {
      env: env,
      dev: env !== 'production',
      ...(sanitizedEmail ? { email: sanitizedEmail } : {}),
      ...additionalClaims,
    });

    res.json({ customToken: token, uid: effectiveUid, email: sanitizedEmail });
  } catch (error: any) {
    console.error('devauth error:', error?.message || error);
    res.status(500).json({ error: 'Failed to mint custom token' });
  }
});


