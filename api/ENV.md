## Environment variables

Create a file called `.env.local` in this `api` directory and set:

```
# Required for all chat modes via OpenRouter
OPENROUTER_API_KEY=sk-or-your-key-here

# Required for search/aipedia modes (web/image search tools)
# Get from https://brave.com/search/api/
BRAVE_API_KEY=brave-your-key-here

# Firebase Admin (only needed if using credits/billing endpoints)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-service-account@your-project-id.iam.gserviceaccount.com
# Paste the private key as a single line; newlines will be restored at runtime
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\\nABC...\\n-----END PRIVATE KEY-----\\n"
```

Local dev:

```bash
cd api
export $(grep -v '^#' .env.local | xargs) # or use a shell export manually
npm run dev
```

The Flutter app points to `http://10.0.2.2:3000` (Android emulator) by default.


