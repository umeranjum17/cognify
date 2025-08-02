# Google Play Console Upload Guide

Follow these steps to upload your new app bundle for internal testing or production:

## 1. Prepare Your App Bundle
- Ensure you have built the release bundle:
  ```
  flutter build appbundle --release --flavor production
  ```
- The output file will be at:  
  `build/app/outputs/bundle/productionRelease/app-production-release.aab`

## 2. Sign In to Google Play Console
- Go to https://play.google.com/console
- Select your app (Cognify) or create a new app if needed.

## 3. Navigate to Release Management
- Go to **Release** > **Testing** > **Internal testing** (or **Production** for live release).
- Click **Create new release**.

## 4. Upload the App Bundle
- Click **Upload** and select your `.aab` file.
- Wait for the upload and processing to complete.

## 5. Fill in Release Details
- Add release notes (e.g. "Internal test build for Cognify v1.0.0").
- Add testers if using internal testing.

## 6. Address Warnings/Errors
- If prompted, complete the Advertising ID declaration.
- Resolve any account or policy issues flagged by Play Console.

## 7. Review and Rollout
- Click **Review release**.
- If all checks pass, click **Start rollout to testers** (or **Production**).

## 8. Monitor Status
- Track the release status and address any feedback or issues.

---

**Tip:**  
If you see SDK or signing errors, double-check your `build.gradle` and keystore setup.

For more details, see the official docs:  
https://developer.android.com/studio/publish
