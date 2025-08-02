# Release Deployment Checklist for Cognify

Use this checklist to ensure a smooth and compliant release to Google Play.

---

## 1. Code & Build
- [x] All features and bug fixes merged to main branch
- [x] Version number and code updated in `pubspec.yaml`
- [x] Advertising ID permission added to `AndroidManifest.xml`
- [x] Target and compile SDK set to 34 (or latest required by Play)
- [x] Release keystore configured in `local.properties`
- [x] Production release bundle built (`.aab` file)

## 2. Documentation
- [x] Keystore setup documented (`KEYSTORE_SETUP.md`)
- [x] Play Console upload guide available (`PLAY_CONSOLE_UPLOAD.md`)
- [x] Account troubleshooting guide available (`PLAY_CONSOLE_ACCOUNT_TROUBLESHOOTING.md`)
- [x] Internal testing instructions ready (`INTERNAL_TESTING_INSTRUCTIONS.md`)

## 3. Play Console
- [x] App bundle uploaded to Play Console
- [x] Release notes and testing instructions provided
- [x] Advertising ID declaration completed (if prompted)
- [x] All warnings/errors resolved in Play Console

## 4. Account & Policy
- [x] Developer account verified and in good standing
- [x] All required business/identity verification completed
- [x] Payment and tax info up to date

## 5. Testing & Rollout
- [x] Internal testers invited and app installed
- [x] All core features tested on Android 13+ devices
- [x] Feedback collected and issues addressed
- [x] Rollout started (internal or production)

---

**Tip:**  
Review all Play Console messages and warnings before rollout.  
Keep this checklist updated for future releases.