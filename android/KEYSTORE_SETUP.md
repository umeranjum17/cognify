# Android Release Keystore Setup Guide

To sign your app for Google Play, you must configure your keystore credentials in `android/local.properties`.  
**Never commit your actual `local.properties` file or credentials to version control.**

## Steps

1. **Copy the template:**
   ```
   cp android/local.properties.example android/local.properties
   ```

2. **Edit `android/local.properties` and fill in:**
   ```
   storeFile=/Users/umerfaroq/cognify-release-key.jks
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyAlias=YOUR_KEY_ALIAS
   keyPassword=YOUR_KEY_PASSWORD
   ```

3. **Keep your keystore file safe and backed up.**

4. **Do not share your keystore or credentials. Losing your keystore means you cannot update your app on Google Play.**

5. **If you need to change the keystore location, update the `storeFile` path accordingly.**

## Example

```
storeFile=/Users/umerfaroq/cognify-release-key.jks
storePassword=mySecurePassword123
keyAlias=cognify-key
keyPassword=mySecurePassword123
```

**After setup, you can build a signed release bundle for Play Console upload.**