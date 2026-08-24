# Android Build Setup - Files Index

This folder contains everything needed to build the Android app on a new computer.

## 📚 Documentation Files

1. **README.md** - Main overview and quick reference
2. **QUICK_START.md** - 5-minute setup guide
3. **SETUP_CHECKLIST.md** - Step-by-step verification checklist
4. **JAVA_SETUP.md** - Java 21 installation instructions
5. **SIGNING_SETUP.md** - Keystore and signing configuration
6. **BUILD_COMMANDS.md** - All build commands reference
7. **CONFIGURATION.md** - Complete configuration details
8. **TROUBLESHOOTING.md** - Common errors and solutions

## 📋 Template Files

9. **gradle.properties.template** - Template for Gradle configuration
10. **local.properties.template** - Template for local properties

## 🔐 Credentials

11. **CREDENTIALS.txt** - Signing credentials (KEEP SECURE!)

## 🚀 Getting Started

**New to this?** Start with:
1. `QUICK_START.md` - Fast setup
2. `SETUP_CHECKLIST.md` - Verify everything

**Having issues?** Check:
1. `TROUBLESHOOTING.md` - Common problems
2. `CONFIGURATION.md` - All settings

**Need details?** Read:
1. `README.md` - Overview
2. Individual guide files for specific topics

## 📦 What You Need to Transfer

When moving to a new computer, you need:

1. **This entire folder** (`android-build-setup/`)
2. **Keystore file** (`cognify-release-key.jks`) - Copy separately, keep secure
3. **Project code** - The entire `cognify-flutter` repository

## ✅ Verification

After setup, run:
```bash
flutter doctor -v
flutter build appbundle --release --flavor production
```

If both succeed, you're ready to build!
