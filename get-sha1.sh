#!/bin/bash

# Script to get SHA-1 fingerprints for Android keystores
# This is needed for Google Sign-In configuration in Firebase

echo "🔍 Getting SHA-1 fingerprints for Google Sign-In..."
echo ""

# Get debug keystore SHA-1
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

if [ -f "$DEBUG_KEYSTORE" ]; then
    echo "📱 Debug Keystore SHA-1:"
    keytool -list -v -keystore "$DEBUG_KEYSTORE" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -A 1 "SHA1:" | grep -o "[0-9A-F:]\{47\}" | tr '[:upper:]' '[:lower:]' | sed 's/://g'
    echo ""
else
    echo "⚠️  Debug keystore not found at $DEBUG_KEYSTORE"
    echo "   It will be created automatically when you build the app."
    echo "   Run this script again after building once."
    echo ""
fi

# Get release keystore SHA-1 if configured
if [ -f "android/local.properties" ]; then
    STORE_FILE=$(grep "^storeFile=" android/local.properties | cut -d'=' -f2)
    if [ -n "$STORE_FILE" ] && [ -f "$STORE_FILE" ]; then
        KEY_ALIAS=$(grep "^keyAlias=" android/local.properties | cut -d'=' -f2)
        STORE_PASS=$(grep "^storePassword=" android/local.properties | cut -d'=' -f2)
        KEY_PASS=$(grep "^keyPassword=" android/local.properties | cut -d'=' -f2)
        
        if [ -n "$KEY_ALIAS" ] && [ -n "$STORE_PASS" ] && [ -n "$KEY_PASS" ]; then
            echo "📦 Release Keystore SHA-1:"
            keytool -list -v -keystore "$STORE_FILE" -alias "$KEY_ALIAS" -storepass "$STORE_PASS" -keypass "$KEY_PASS" 2>/dev/null | grep -A 1 "SHA1:" | grep -o "[0-9A-F:]\{47\}" | tr '[:upper:]' '[:lower:]' | sed 's/://g'
            echo ""
        fi
    fi
fi

echo "📋 Next steps:"
echo "1. Copy the SHA-1 fingerprint(s) above"
echo "2. Go to Firebase Console: https://console.firebase.google.com/"
echo "3. Select your project: cognify-eb0a2"
echo "4. Go to Project Settings > Your apps > Android app"
echo "5. Click 'Add fingerprint' and paste the SHA-1"
echo "6. Download the updated google-services.json"
echo "7. Replace android/app/google-services.json with the new file"
echo "8. Rebuild your app"
echo ""


