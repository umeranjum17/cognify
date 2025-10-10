import { Request, Response, NextFunction } from 'express';
import { getAdminAuth } from '../services/firebase.js';

export interface AuthRequest extends Request {
  user?: {
    uid: string;
    email?: string;
    [key: string]: any;
  };
}

export async function requireAuth(
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authStartMs = Date.now();
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      res.status(401).json({ error: 'Missing Authorization header' });
      return;
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      res.status(401).json({ error: 'Invalid Authorization header format' });
      return;
    }

    const idToken = parts[1];
    const auth = getAdminAuth();
    const decodedToken = await auth.verifyIdToken(idToken);
    
    req.user = {
      ...decodedToken,
      uid: decodedToken.uid,
      email: decodedToken.email
    };
    // Attach auth verification duration for downstream profiling
    (req as any)._timing = (req as any)._timing || {};
    (req as any)._timing.authVerifyMs = Date.now() - authStartMs;
    
    next();
  } catch (error: any) {
    console.error('Auth error:', error.message);
    res.status(401).json({ error: 'Unauthorized', message: error.message });
  }
}

export function optionalAuth(
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    next();
    return;
  }

  requireAuth(req, res, next);
}

