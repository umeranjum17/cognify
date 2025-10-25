# RevenueCat Consumables for Anonymous Users - Complete Guide

## Overview

RevenueCat fully supports anonymous users making purchases, including consumable products (like credit packs). This guide explains how it works in your Cognify app.

---

## How It Works

### 1. **Anonymous User Identification**

When you initialize RevenueCat **without** an `appUserId`:

```dart
// Anonymous initialization (no appUserId)
await RevenueCatService.instance.initialize();
```

RevenueCat automatically:
- Generates a **unique anonymous identifier** for the device
- Stores it in the device's keychain/secure storage
- Associates all purchases with this anonymous ID
- This ID **persists across app restarts** on the same device

### 2. **Anonymous Purchase Flow**

```
Anonymous User Opens App
  ↓
RevenueCat initializes with anonymous ID (auto-generated)
  ↓
User browses credit packages
  ↓
User purchases credits (e.g., "100 Credits - $4.99")
  ↓
RevenueCat processes purchase with anonymous ID
  ↓
Purchase receipt stored in App Store/Google Play
  ↓
RevenueCat webhook fires to your backend
  ↓
Backend receives webhook with:
  - app_user_id: "anonymous_xyz123" (RevenueCat's generated ID)
  - product_id: "100_credits"
  - transaction_id: "1000000123456789"
  ↓
Backend grants 100 credits to the anonymous user
```

### 3. **Account Linking (Anonymous → Authenticated)**

When an anonymous user signs in with Google/Apple, you need to **transfer** their purchases:

```dart
// User was anonymous, now signing in with Google
final firebaseUser = await FirebaseAuth.instance.signInWithGoogle();

// Identify the user in RevenueCat (this transfers purchases)
await RevenueCatService.instance.identify(firebaseUser.uid);
```

**What happens internally:**

```
RevenueCat.logIn(firebaseUser.uid)
  ↓
RevenueCat checks if user has existing account
  ↓
RevenueCat finds anonymous purchases on device
  ↓
RevenueCat TRANSFERS purchases from anonymous → authenticated
  ↓
Backend receives webhook with ALIAS event:
  {
    "event_type": "ALIAS",
    "original_app_user_id": "anonymous_xyz123",
    "new_app_user_id": "firebase_uid_abc789"
  }
  ↓
Backend should:
  - Transfer credits from anonymous user to authenticated user
  - Merge purchase history
  - Optionally delete anonymous user data
```

---

## Critical Implementation Details

### ✅ **What Works Automatically**

1. **Purchase persistence**: Purchases made anonymously are stored in the device's App Store/Google Play receipt
2. **Local tracking**: RevenueCat SDK tracks the anonymous user across app restarts
3. **Receipt validation**: RevenueCat validates all purchases server-side
4. **Webhook delivery**: Your backend receives webhooks for anonymous purchases

### ⚠️ **What You Must Handle**

#### A. Backend Webhook Handling for Anonymous Users

Your backend must support anonymous `app_user_id` values:

```typescript
// backend/src/routes/credits.ts

// Current implementation assumes Firebase UIDs
// PROBLEM: Anonymous users have RevenueCat-generated IDs like "$RCAnonymousID:abc123"

app.post('/webhooks/revenuecat', async (req, res) => {
  const event = req.body;
  const userId = event.app_user_id; // Could be anonymous!

  // ❌ This will FAIL for anonymous users
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(userId) // Firebase UID doesn't exist for anonymous RevenueCat ID
    .get();

  // ✅ Better approach: Map RevenueCat ID → Firebase UID
  const userDoc = await admin.firestore()
    .collection('users')
    .where('revenueCatUserId', '==', userId)
    .limit(1)
    .get();
});
```

#### B. Storing RevenueCat User ID Mapping

You need to store the RevenueCat user ID alongside Firebase UID:

```typescript
// When user signs in (anonymous or authenticated)
await admin.firestore().collection('users').doc(firebaseUid).set({
  revenueCatUserId: currentRevenueCatUserId,
  isAnonymous: user.isAnonymous,
  createdAt: Timestamp.now(),
}, { merge: true });
```

#### C. Handling ALIAS Webhooks

When anonymous users sign in, RevenueCat sends an `ALIAS` event:

```typescript
app.post('/webhooks/revenuecat', async (req, res) => {
  const event = req.body;

  if (event.type === 'ALIAS') {
    const oldUserId = event.original_app_user_id; // Anonymous ID
    const newUserId = event.new_app_user_id;      // Firebase UID

    // Transfer credits from anonymous to authenticated user
    const oldUserRef = admin.firestore()
      .collection('users')
      .where('revenueCatUserId', '==', oldUserId)
      .limit(1);

    const oldUserSnap = await oldUserRef.get();
    if (!oldUserSnap.empty) {
      const oldUserDoc = oldUserSnap.docs[0];
      const oldCredits = oldUserDoc.data().credits?.balance || 0;

      // Add to new user
      await admin.firestore()
        .collection('users')
        .doc(newUserId)
        .set({
          revenueCatUserId: newUserId,
          credits: {
            balance: FieldValue.increment(oldCredits),
          },
        }, { merge: true });

      // Delete old anonymous user (optional)
      await oldUserDoc.ref.delete();
    }
  }
});
```

---

## Consumables vs Non-Consumables

### **Consumables (Your Use Case: Credits)**

- **Can be purchased multiple times**
- **Not restored** by `restorePurchases()` (by design)
- **Require backend tracking** (you must store credit balance)
- **Examples**: Credit packs, gems, tokens

**RevenueCat Behavior:**
```dart
// Anonymous user buys 100 credits
purchasePackage(package); // ✅ Works

// User signs in
identify(firebaseUid); // ✅ Transfers subscription info, but NOT consumable balance

// User calls restore
restorePurchases(); // ❌ Does NOT restore consumed credits
```

**Your Responsibility:**
- Store credit balance in Firestore (which you already do via `/api/credits/balance`)
- Transfer balance during ALIAS event
- Sync balance via SSE stream

### **Non-Consumables (Subscriptions, One-Time Unlocks)**

- **Can only be purchased once**
- **Automatically restored** by `restorePurchases()`
- **RevenueCat handles most logic**
- **Examples**: Premium subscription, "Remove Ads" unlock

**RevenueCat Behavior:**
```dart
// User buys premium subscription
purchasePackage(package); // ✅ Works

// User signs in on new device
identify(firebaseUid);
restorePurchases(); // ✅ Automatically restores subscription
```

---

## Recommended Architecture for Your App

### **Option 1: Pure Anonymous (Current)**

**Flow:**
1. User opens app → Auto sign-in anonymously with Firebase
2. Firebase generates anonymous UID → RevenueCat uses Firebase UID
3. User purchases credits → Backend grants credits to Firebase anonymous UID
4. User signs in with Google/Apple → Firebase **links** anonymous account
5. No RevenueCat ALIAS needed (Firebase UID stays the same!)

**Code:**
```dart
// In FirebaseAuthProvider.initialize()
if (FirebaseAuth.instance.currentUser == null) {
  await FirebaseAuth.instance.signInAnonymously();
}

final firebaseUid = FirebaseAuth.instance.currentUser!.uid;

// Initialize RevenueCat with Firebase UID (not anonymous!)
await RevenueCatService.instance.initialize(appUserId: firebaseUid);
```

**Pros:**
- ✅ No ALIAS webhook needed
- ✅ Firebase handles account linking automatically
- ✅ Credits stay attached to same UID after sign-in
- ✅ Simpler backend logic

**Cons:**
- ⚠️ Firebase anonymous accounts can be lost if user clears app data
- ⚠️ Requires Firebase Authentication always

---

### **Option 2: RevenueCat Anonymous ID (Alternative)**

**Flow:**
1. User opens app → RevenueCat generates anonymous ID
2. User purchases credits → Backend uses RevenueCat anonymous ID
3. User signs in → Call `identify(firebaseUid)` to transfer purchases
4. Backend handles ALIAS webhook to transfer credits

**Code:**
```dart
// Initialize RevenueCat without appUserId
await RevenueCatService.instance.initialize(); // Anonymous

// Later when user signs in
await RevenueCatService.instance.identify(firebaseUser.uid);
```

**Pros:**
- ✅ No Firebase dependency for purchases
- ✅ RevenueCat handles device-to-device transfer

**Cons:**
- ❌ Must implement ALIAS webhook handling
- ❌ More complex backend logic
- ❌ Credits might not transfer if webhook fails

---

## Your Current Implementation Analysis

Looking at your code, you're using **Option 1** (Firebase Anonymous):

```dart
// lib/providers/firebase_auth_provider.dart (lines 45-138)
if (user == null && hasCompletedFirstLaunch) {
  await FirebaseAuth.instance.signInAnonymously();
}

// lib/services/revenuecat_service.dart
await RevenueCatService.instance.initialize(appUserId: firebaseUid);
```

**This is GREAT!** Because:
1. ✅ Firebase anonymous accounts persist across app restarts
2. ✅ Firebase UID remains the same after Google/Apple sign-in (via account linking)
3. ✅ Your backend already uses Firebase UID for credits
4. ✅ No need to implement ALIAS webhook

**However, there's a small issue:**

In `firebase_auth_provider.dart`, when a user signs in with Google/Apple, you're **not linking** the accounts:

```dart
// Current code (lines ~200)
Future<void> signInWithGoogle() async {
  if (isAnonymous) {
    await FirebaseAuth.instance.signOut(); // ❌ This loses the anonymous account!
  }
  await FirebaseAuth.instance.signInWithCredential(credential);
}
```

**Fix:**
```dart
Future<void> signInWithGoogle() async {
  final credential = await _getGoogleCredential();

  if (isAnonymous) {
    // Link anonymous account instead of signing out
    try {
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
    } catch (e) {
      // If linking fails (account already exists), sign out and sign in
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
  } else {
    await FirebaseAuth.instance.signInWithCredential(credential);
  }
}
```

---

## Testing Guide

### Test 1: Anonymous Purchase
1. Open app (auto sign-in anonymously)
2. Check Firestore: `users/{firebase_uid}` should exist
3. Purchase credits
4. Check backend webhook receives `app_user_id: {firebase_uid}`
5. Verify credits appear in app

### Test 2: Account Linking
1. Start as anonymous user
2. Purchase 100 credits (balance = 100)
3. Sign in with Google
4. **Expected**: Firebase UID stays the same, credits remain
5. **Verify**: Check `user.uid` before/after sign-in

### Test 3: New Device
1. User A signs in on Device 1
2. Purchases credits (balance = 100)
3. Sign out
4. Sign in on Device 2 with same Google account
5. **Expected**: Credits restored (via backend SSE stream)

### Test 4: Restore Purchases
1. Anonymous user purchases credits
2. Consumes all credits (balance = 0)
3. Calls `restorePurchases()`
4. **Expected**: Balance stays 0 (consumables not restored)
5. **Actual**: Backend should handle via purchase history

---

## Common Pitfalls

### ❌ Mistake 1: Not Storing RevenueCat User ID
**Problem**: Backend can't map webhook `app_user_id` to Firebase user

**Solution**:
```typescript
// Store in Firestore
users/{firebaseUid}/
  revenueCatUserId: string
  credits: { balance: number }
```

### ❌ Mistake 2: Expecting Consumables to Restore
**Problem**: User thinks credits should restore like subscriptions

**Solution**: Show UI message:
```dart
"Credits are consumable and cannot be restored. Your purchase history is saved."
```

### ❌ Mistake 3: Signing Out Instead of Linking
**Problem**: Anonymous purchases lost when user signs in

**Solution**: Use `linkWithCredential()` instead of `signOut() + signIn()`

### ❌ Mistake 4: Not Handling ALIAS Events (if using Option 2)
**Problem**: Credits don't transfer when user signs in

**Solution**: Implement ALIAS webhook handler (see above)

---

## Recommended Next Steps

1. **Verify Firebase Account Linking**
   - Check if `linkWithCredential()` is used in sign-in flow
   - Add logging to confirm UID stays the same

2. **Add RevenueCat User ID to Firestore**
   - Store `revenueCatUserId` field in user document
   - Update backend webhook to use this field

3. **Test Anonymous Purchase Flow**
   - Use Xcode StoreKit Configuration (iOS)
   - Use Google Play test account (Android)

4. **Monitor ALIAS Events** (if needed)
   - Add ALIAS webhook handler
   - Log all events to understand flow

5. **Add Purchase History Screen**
   - Show all past purchases (from RevenueCat webhook logs)
   - Help users understand consumable vs non-consumable

---

## Example: Complete Anonymous → Authenticated Flow

```dart
// 1. App Launch (Anonymous)
await FirebaseAuth.instance.signInAnonymously();
// Firebase UID: "anon_abc123"

await RevenueCatService.instance.initialize(
  appUserId: "anon_abc123"
);

// 2. Purchase Credits
await RevenueCatService.instance.purchasePackage(package);
// Backend receives webhook:
// { app_user_id: "anon_abc123", product_id: "100_credits" }
// Backend grants 100 credits to users/anon_abc123

// 3. User Signs In with Google
final credential = await GoogleAuthProvider().getCredential();
await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
// Firebase UID: STILL "anon_abc123" ✅

// RevenueCat already knows user as "anon_abc123"
// No need to call identify()!

// 4. Credits Persist
// users/anon_abc123/credits/balance = 100 ✅
```

---

## Summary

| Aspect | Anonymous Users | Authenticated Users |
|--------|----------------|---------------------|
| **RevenueCat ID** | Auto-generated or Firebase UID | Firebase UID |
| **Purchases** | ✅ Fully supported | ✅ Fully supported |
| **Consumables** | ✅ Works, requires backend | ✅ Works, requires backend |
| **Restore** | ❌ Not automatic | ❌ Not automatic |
| **Transfer** | ✅ Via ALIAS or Firebase linking | N/A |
| **Backend Mapping** | ⚠️ Must map RevenueCat ID → Firebase UID | ✅ Direct 1:1 mapping |

**Your current architecture (Firebase Anonymous + RevenueCat) is EXCELLENT** because:
- ✅ Firebase handles account linking automatically
- ✅ No need for complex ALIAS webhook logic
- ✅ Credits persist across sign-in
- ✅ Simple backend implementation

**Just ensure**:
- Use `linkWithCredential()` instead of sign-out + sign-in
- Store `revenueCatUserId` in Firestore for debugging
- Test account linking flow thoroughly
