import { initializeApp, getApps, cert, App, applicationDefault } from 'firebase-admin/app';
import { getAuth, Auth } from 'firebase-admin/auth';
import { getFirestore, Firestore } from 'firebase-admin/firestore';

let app: App | undefined;

export function getFirebaseAdminApp(): App {
  if (!app) {
    const usingEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;
    const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT;

    if (usingEmulator) {
      // Emulator path: no credentials required; Admin SDK picks up FIRESTORE_EMULATOR_HOST
      // IMPORTANT: We must use the real Firebase projectId here so Auth token audience matches
      if (!projectId) {
        throw new Error('FIREBASE_PROJECT_ID is required when using the emulator to verify Auth tokens');
      }
      app = getApps()[0] || initializeApp({
        projectId,
      } as any);
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      // Prefer Google Application Default Credentials when available
      app = getApps()[0] || initializeApp({
        credential: applicationDefault(),
        ...(projectId ? { projectId } : {}),
      });
    } else {
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
      let privateKey = process.env.FIREBASE_PRIVATE_KEY || '';
      // Handle common env formatting issues: quoted JSON-style keys and escaped newlines
      if (privateKey.startsWith('"') && privateKey.endsWith('"')) {
        privateKey = privateKey.slice(1, -1);
      }
      privateKey = privateKey.replace(/\\n/g, '\n');

      if (!projectId || !clientEmail || !privateKey) {
        throw new Error('Missing Firebase Admin credentials in environment variables');
      }

      app = getApps()[0] || initializeApp({
        credential: cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
    }
  }
  return app;
}

export function getAdminAuth(): Auth {
  return getAuth(getFirebaseAdminApp());
}

export function getAdminDb(): Firestore {
  return getFirestore(getFirebaseAdminApp());
}

