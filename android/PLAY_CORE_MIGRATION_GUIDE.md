# Play Core Library Migration Guide

## Issue
Your app uses `com.google.android.play:core:1.10.3` which is incompatible with targetSdkVersion 34 (Android 14). Google has deprecated this library and requires migration to new focused libraries.

## Migration Steps

### 1. Remove Deprecated Library
Remove this line from `android/app/build.gradle`:
```gradle
implementation 'com.google.android.play:core:1.10.3'
```

### 2. Add Replacement Libraries
Add these Android 14 compatible libraries based on your needs:

```gradle
dependencies {
    // Play In-App Reviews (if you use review functionality)
    implementation 'com.google.android.play:review:2.0.1'
    implementation 'com.google.android.play:review-ktx:2.0.1'
    
    // Play In-App Updates (if you use app update functionality)
    implementation 'com.google.android.play:app-update:2.1.0'
    implementation 'com.google.android.play:app-update-ktx:2.1.0'
    
    // Play Asset Delivery (if you use asset packs)
    implementation 'com.google.android.play:asset-delivery:2.2.2'
    implementation 'com.google.android.play:asset-delivery-ktx:2.2.2'
    
    // Play Feature Delivery (if you use dynamic features)
    implementation 'com.google.android.play:feature-delivery:2.1.0'
    implementation 'com.google.android.play:feature-delivery-ktx:2.1.0'
}
```

### 3. Update Code Usage
If your app uses any Play Core APIs, update the imports:

**Old imports:**
```kotlin
import com.google.android.play.core.review.ReviewManagerFactory
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
```

**New imports:**
```kotlin
import com.google.android.play.core.review.ReviewManagerFactory
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
```

### 4. Rebuild and Test
```bash
flutter clean
flutter build appbundle --release --flavor production
```

## Common Migration Scenarios

### For Basic Apps (No Play Core Features)
If you don't use any Play Core features, simply remove the dependency:
```gradle
// Remove this line completely
// implementation 'com.google.android.play:core:1.10.3'
```

### For Apps Using In-App Reviews
```gradle
implementation 'com.google.android.play:review:2.0.1'
implementation 'com.google.android.play:review-ktx:2.0.1'
```

### For Apps Using In-App Updates
```gradle
implementation 'com.google.android.play:app-update:2.1.0'
implementation 'com.google.android.play:app-update-ktx:2.1.0'
```

## Verification
After migration:
1. Build succeeds without errors
2. Upload to Play Console shows no Play Core compatibility warnings
3. App functions correctly on Android 14 devices

## References
- [Official Google Play Core Migration Guide](https://developer.android.com/guide/playcore)
- [Play In-App Reviews Documentation](https://developer.android.com/guide/playcore/in-app-review)
- [Play In-App Updates Documentation](https://developer.android.com/guide/playcore/in-app-updates)