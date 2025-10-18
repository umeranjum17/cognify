import express from 'express';
import { optionalAuth, AuthRequest } from '../middleware/auth.js';
import { getAdminDb } from '../services/firebase.js';

export const feedbackRouter = express.Router();

// POST /api/feedback - Ingest user feedback
// Accepts: { message: string, contactEmail?: string, meta?: object }
// - Auth optional: will enrich with verified uid/email when Authorization header is present
// - Persists to Firestore collection 'feedback'
feedbackRouter.post('/', optionalAuth, async (req: AuthRequest, res) => {
  try {
    const { message, contactEmail, meta, context } = req.body || {};
    if (!message || typeof message !== 'string' || !message.trim()) {
      res.status(400).json({ error: 'Missing required field: message' });
      return;
    }

    const db = getAdminDb();
    const nowIso = new Date().toISOString();

    // Collect request metadata
    const ipHeader = (req.headers['x-forwarded-for'] as string) || '';
    const ip = ipHeader.split(',').map(s => s.trim()).filter(Boolean)[0] || req.ip;
    const userAgent = req.get('user-agent') || null;
    const referer = req.get('referer') || null;

    // Build document
    const doc: any = {
      message: String(message).trim(),
      contactEmail: (typeof contactEmail === 'string' && contactEmail.trim().length > 0)
        ? contactEmail.trim()
        : null,
      createdAt: nowIso,
      user: req.user ? {
        uid: req.user.uid,
        email: req.user.email || null,
      } : { isAuthenticated: false },
      request: {
        ip,
        userAgent,
        referer,
        authVerifyMs: (req as any)._timing?.authVerifyMs ?? null,
      },
      meta: {},
      source: 'app',
      version: 1,
    };

    // Accept meta/context from client for richer diagnostics
    const incomingMeta = (meta && typeof meta === 'object') ? meta :
                         (context && typeof context === 'object') ? context : null;
    if (incomingMeta) {
      doc.meta = incomingMeta;
    }

    const ref = await db.collection('feedback').add(doc);
    res.status(201).json({ success: true, id: ref.id });
  } catch (error: any) {
    console.error('Error saving feedback:', error?.message || error);
    res.status(500).json({ success: false, error: 'Failed to save feedback' });
  }
});

