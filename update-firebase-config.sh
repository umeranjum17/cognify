#!/bin/bash

# Script to update Firebase configuration (google-services.json) using FlutterFire CLI
# This will ensure the latest configuration is downloaded from Firebase Console

set -e

echo "🔥 Updating Firebase Configuration..."
echo ""

FLUTTER_PATH="/home/umer/flutter/bin/flutter"
DART_PATH="/home/umer/flutter/bin/dart"
PROJECT_DIR="/home/umer/Documents/Github/cognify"

cd "$PROJECT_DIR"

# Check if FlutterFire CLI is installed
if ! $DART_PATH pub global list | grep -q flutterfire_cli; then
    echo "📦 Installing FlutterFire CLI..."
    $DART_PATH pub global activate flutterfire_cli
    echo ""
fi

# Get FlutterFire CLI path
FLUTTERFIRE_CLI="$DART_PATH pub global run flutterfire_cli:flutterfire"

echo "🔍 Getting SHA-1 fingerprint for debug keystore..."
echo ""

# Check if debug keystore exists, if not, create it
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
if [ ! -f "$DEBUG_KEYSTORE" ]; then
    echo "📱 Creating debug keystore..."
    keytool -genkey -v -keystore "$DEBUG_KEYSTORE" \
        -alias androiddebugkey \
        -storepass android \
        -keypass android \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"
    echo "✅ Debug keystore created"
    echo ""
fi

# Get SHA-1 fingerprint
echo "🔑 SHA-1 Fingerprint:"
SHA1=$(keytool -list -v -keystore "$DEBUG_KEYSTORE" \
    -alias androiddebugkey \
    -storepass android \
    -keypass android 2>/dev/null | \
    awk '/SHA1:/{print $2}' | tr -d ':' | tr '[:upper:]' '[:lower:]')

if [ -z "$SHA1" ]; then
    echo "⚠️  Could not extract SHA-1 fingerprint"
    echo "   Please run: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android"
    exit 1
fi

echo "$SHA1"
echo ""

# Check if SHA-1 is already in google-services.json
if grep -q "$SHA1" android/app/google-services.json 2>/dev/null; then
    echo "✅ SHA-1 fingerprint is already in google-services.json"
else
    echo "⚠️  SHA-1 fingerprint NOT found in current google-services.json"
    echo "   You need to add it to Firebase Console:"
    echo "   1. Go to https://console.firebase.google.com/project/cognify-eb0a2/settings/general"
    echo "   2. Select your Android app"
    echo "   3. Click 'Add fingerprint' and paste: $SHA1"
    echo ""
fi

echo "🔄 Using FlutterFire CLI to configure Firebase..."
echo "   This will download the latest google-services.json from Firebase"
echo ""

# Use FlutterFire CLI to configure Firebase
# This will prompt for project selection and download the config
$FLUTTERFIRE_CLI configure \
    --project=cognify-eb0a2 \
    --platforms=android \
    --yes \
    --out=lib/firebase_options.dart \
    --ios-bundle-id=com.umerfarooq1995.cognify-flutter \
    --android-package-name=com.umerfarooq1995.cognify_flutter \
    --android-app-id=1:702035468371:android:1b52df4446f2404791e6a6 || {
    echo ""
    echo "⚠️  FlutterFire CLI configuration failed or requires authentication"
    echo ""
    echo "📋 Alternative: Manual download from Firebase Console"
    echo "   1. Go to: https://console.firebase.google.com/project/cognify-eb0a2/settings/general"
    echo "   2. Click on your Android app"
    echo "   3. Download google-services.json"
    echo "   4. Replace android/app/google-services.json with the downloaded file"
    echo ""
    echo "   Make sure to add SHA-1 fingerprint: $SHA1"
    exit 1
}

# Verify the file was updated
if [ -f "android/app/google-services.json" ]; then
    echo ""
    echo "✅ google-services.json updated successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Make sure SHA-1 fingerprint ($SHA1) is added in Firebase Console"
    echo "   2. Rebuild your app: flutter run --flavor dev"
    echo ""
else
    echo ""
    echo "⚠️  google-services.json not found. Please download it manually from Firebase Console."
    echo ""
fi



