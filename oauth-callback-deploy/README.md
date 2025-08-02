# Cognify OAuth Callback

This is the OAuth callback page for the Cognify Flutter app.

## Quick Deploy to Vercel

1. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

2. **Deploy this folder**:
   ```bash
   cd oauth-callback-deploy
   vercel --prod
   ```

3. **Get your domain**: Vercel will give you a URL like `https://your-project-name.vercel.app`

4. **Update your Flutter app**: Replace `cognify-oauth.vercel.app` with your new domain

## Alternative: Deploy via Vercel Website

1. Go to [vercel.com](https://vercel.com)
2. Sign up/login with GitHub
3. Click "New Project"
4. Upload this folder or connect your GitHub repo
5. Deploy!

## App Links Setup

After deployment, you'll need to:

1. **Update Android Manifest** with your domain
2. **Add domain verification** (`.well-known/assetlinks.json`)
3. **Test on Android device**

## How It Works

1. OpenRouter redirects to your domain: `https://yourdomain.com/callback?code=...&state=...`
2. This page captures the OAuth parameters
3. It redirects back to your app using custom schemes: `cognify://oauth/callback?code=...&state=...`
4. Your Flutter app receives the callback via App Links
5. App exchanges the code for an API key

## Security Features

- HTTPS only
- State parameter validation
- CSRF protection
- Automatic window closing
- Error handling
