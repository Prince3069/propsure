# Propsure — Environment Variables & Security Setup

## ══════════════════════════════════════════════
## WHERE YOUR SECRETS LIVE — IMPORTANT TO READ
## ══════════════════════════════════════════════

### ❌ NEVER put secrets in:
- Flutter code (anyone can decompile your app)
- pubspec.yaml
- .env files committed to git
- Firebase Remote Config (visible to app)
- Firestore (readable if rules have a bug)

### ✅ WHERE secrets MUST live:
- Firebase Secret Manager (for Cloud Functions)
- Your CI/CD environment variables (for builds)

---

## STEP 1: Paystack Keys

### Get your keys from:
https://dashboard.paystack.com/#/settings/developer

You have two sets:
- Test keys (pk_test_..., sk_test_...) — for development
- Live keys (pk_live_..., sk_live_...) — for production

### Public Key (safe in Flutter app)
Open: `lib/services/paystack_service.dart`

```dart
// Line ~20
static const String publicKey = 'pk_live_YOUR_KEY_HERE';
```

Replace `pk_live_YOUR_KEY_HERE` with your actual public key.
This is the ONLY Paystack key that goes in your Flutter code.

### Secret Key (MUST stay in Cloud Functions)

```bash
# Run this in your terminal (not in code!)
firebase functions:secrets:set PAYSTACK_SECRET_KEY
# When prompted, paste: sk_live_YOUR_SECRET_KEY_HERE
```

### Webhook Secret (MUST stay in Cloud Functions)

```bash
firebase functions:secrets:set PAYSTACK_WEBHOOK_SECRET
# When prompted, paste: your_webhook_secret_from_paystack_dashboard
```

To get webhook secret:
1. Paystack Dashboard → Settings → API Keys & Webhooks
2. Add webhook URL: https://us-central1-YOUR_PROJECT.cloudfunctions.net/paystackWebhook
3. Copy the webhook secret shown

---

## STEP 2: Cloud Functions URL

Open: `lib/services/paystack_service.dart`

```dart
// Line ~26
static const String _functionsBaseUrl =
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net';
```

Replace `YOUR_PROJECT_ID` with your Firebase project ID.
Find it in: Firebase Console → Project Settings → General → Project ID

---

## STEP 3: Google Maps API Key

### Get from:
https://console.cloud.google.com → APIs & Services → Credentials → Create API Key

### Enable these APIs:
- Maps SDK for Android
- Maps SDK for iOS
- Places API
- Geocoding API

### Restrict the key (important for security!):
- Application restrictions → Android apps + iOS apps
- API restrictions → Only the 4 APIs above

### Android (NOT in code — in AndroidManifest):
File: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest>
  <application>
    <!-- ADD THIS INSIDE <application> -->
    <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_ANDROID_MAPS_KEY"/>
  </application>
</manifest>
```

### iOS (NOT in code — in AppDelegate):
File: `ios/Runner/AppDelegate.swift`

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(...) -> Bool {
    GMSServices.provideAPIKey("YOUR_IOS_MAPS_KEY")
    // rest of your code
  }
}
```

### Web (in index.html):
File: `web/index.html`

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_WEB_MAPS_KEY"></script>
```

Use SEPARATE keys for Android, iOS, Web — each restricted to its platform.

---

## STEP 4: Firebase Setup

### google-services.json (Android)
1. Firebase Console → Your project → Project Settings
2. Add Android app → Package name: `com.propsure.app`
3. Download `google-services.json`
4. Place at: `android/app/google-services.json`

### GoogleService-Info.plist (iOS)
1. Add iOS app → Bundle ID: `com.propsure.app`  
2. Download `GoogleService-Info.plist`
3. Place at: `ios/Runner/GoogleService-Info.plist`

---

## STEP 5: Deploy Cloud Functions

```bash
# First time setup
npm install -g firebase-tools
firebase login
firebase init functions

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:initiatePayment,functions:verifyPayment,functions:paystackWebhook
```

---

## STEP 6: Firestore Security Rules

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

---

## STEP 7: Add .gitignore (CRITICAL)

Make sure these are in your `.gitignore`:
```
# Firebase
google-services.json
GoogleService-Info.plist
*.keystore
*.jks

# Secrets
.env
.env.*
secrets/
*_secret*
*_private*

# Firebase config backup
.firebaserc
firebase-debug.log
```

---

## SECURITY CHECKLIST

Before going live, verify ALL of these:

- [ ] No Paystack secret key in Flutter code
- [ ] `google-services.json` in `.gitignore`
- [ ] `GoogleService-Info.plist` in `.gitignore`
- [ ] Firestore rules deployed (not test mode)
- [ ] Firebase auth phone numbers restricted to Nigeria (+234)
- [ ] Cloud Functions deployed with secrets
- [ ] Webhook URL added to Paystack dashboard
- [ ] Maps API key restricted by platform
- [ ] Admin users created with `role: 'admin'` in Firestore manually
- [ ] CORS restricted to `propsure.africa` in Cloud Functions
- [ ] Rate limiting active in Cloud Functions

---

## ADMIN ACCOUNT SETUP

Admin users are NOT created through the app.
Create them manually in Firestore:

1. Let the person sign in via phone OTP (creates their user doc)
2. Go to Firestore Console → users → find their document
3. Manually set: `role: "admin"`
4. They can now access propsure_admin at your admin URL

---

## PRODUCTION DEPLOYMENT COMMANDS

```bash
# Build Flutter app for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Build Admin Web
cd propsure_admin
flutter build web --release

# Deploy Admin to Firebase Hosting
firebase deploy --only hosting:admin
```

---

## PAYSTACK CALLBACK URL

In Paystack Dashboard → Settings → API Keys:
Set webhook URL to:
```
https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/paystackWebhook
```

Set success redirect to:
```
https://propsure.africa/payment/callback
```
