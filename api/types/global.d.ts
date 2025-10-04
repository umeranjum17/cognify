declare module 'firebase-admin/app' {
  export type App = any;
  export function initializeApp(options?: any): App;
  export function getApps(): any[];
  export function cert(credentials: any): any;
}

declare module 'firebase-admin/auth' {
  export function getAuth(app?: any): any;
}

declare module 'firebase-admin/firestore' {
  export function getFirestore(app?: any): any;
}


