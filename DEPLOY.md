# Propsure redesign: deploy and verification guide

Nothing in this bundle has been deployed, run on a device, or charged. Every step below is yours to run.

## What was and was not verified

| Part | Verified how | Not verified |
|---|---|---|
| Cloud Functions (`functions/`) | 26 automated tests against an in-memory Firestore fake; `node --check` on every file | Real Firestore, real Paystack, real Cloud Scheduler |
| Media worker (`media_worker/`) | Frame-analysis unit test with ffmpeg; `node --check` | Docker build, Cloud Run, Eventarc/Scheduler wiring |
| Firestore and Storage rules (`config/`) | Read against the app's actual writes (field by field) | **Not run in the Firebase emulator.** Run them before deploying |
| Flutter (`lib/`) | Syntax parse of all 76 Dart files; a cross-reference check (imports exist, constructor named params exist, `Class.member` exists, providers are defined) | **Never compiled, never run.** Expect some analyzer errors or warnings on your first `flutter analyze`; most should be one-line fixes |
| Screens vs mockups | Built from the 45 mockups | Pixel comparison on a device |

## 1. Drop-in

1. Replace your `lib/` with the new `lib/`.
2. Replace `functions/` with the new `functions/` (run `npm install` inside it).
3. Put `config/firestore.rules`, `config/firestore.indexes.json`, `config/storage.rules` where your `firebase.json` expects them (or update the paths in `firebase.json`).
4. Add the new `media_worker/` folder to your repo (it deploys separately to Cloud Run).

### `pubspec.yaml`
New dependencies: `cloud_functions`, `video_player`.
Already used by the app and still required: `cloud_firestore`, `firebase_auth`, `firebase_core`, `firebase_storage`, `flutter_riverpod`, `go_router`, `hive_flutter`, `image_picker`, `url_launcher`, `geolocator`, `google_maps_flutter`, `webview_flutter`, `http`, `uuid`, `csv`, `file_picker`, `cached_network_image`, `google_fonts`, `geocoding`, `geoflutterfire_plus`, `flutter_image_compress`, `logger`.
`webview_flutter` must be 4.x (the checkout uses `WebViewController`). `video_player` needs `INTERNET` on Android (already present for the rest of the app).
`BitmapDescriptor.fromBytes` (price pins on the map) is deprecated in newer `google_maps_flutter` versions but still works.

Android: the camera and location permissions the app already declares are enough. Add nothing else.

## 2. Deploy order

```
# 1. Rules and indexes FIRST (the new app depends on them)
firebase deploy --only firestore:rules,firestore:indexes,storage

# 2. Functions
cd functions && npm install
firebase functions:config:set ...   # or use .env (see below)
firebase deploy --only functions

# 3. Media worker
cd media_worker
gcloud run deploy propsure-media-worker --source . --region us-central1 --no-allow-unauthenticated
# Cloud Scheduler: POST <service-url>/run every 1 minute, authenticated with an OIDC token
# for a service account that has roles/run.invoker on the service.
```
Rules to run in the emulator before step 1: a signed-in user cannot write `status`, `isVerified`, `premiumPlan`, `featuredUntil`, `authority`, `titleReview`, `videoUrl`, `stills` on a listing; a renter cannot read another user's `users/{uid}`; an agent can create a `status: 'draft'` listing but not an `active` one.

### Environment variables (functions)
| Name | Default | Meaning |
|---|---|---|
| `PAYSTACK_SECRET_KEY` | none, required | Paystack secret key |
| `PAYSTACK_CALLBACK_URL` | `https://propsure.africa/payment/callback` | The only callback Paystack receives. The in-app checkout watches for this host |
| `FREE_ACTIVE_LISTINGS` / `PRO_ACTIVE_LISTINGS` | 3 / 20 | **Please confirm these limits** |
| `REFRESH_AFTER_DAYS` / `HIDE_AFTER_DAYS` | 7 / 21 | Freshness windows |
| `BOOST_CATALOG` | pilot | `pilot` = mockup prices (₦3,000 / ₦5,000); `standard` = the old source prices (₦5,000 / ₦10,000 / ₦20,000) |
| `FOUNDER_PROMO_ENABLED` | `false` | Leave off until you have tested the claim path |

Set the Paystack webhook URL to the deployed `paystackWebhook` function.

## 3. Things you must decide or set up

- **Boost and plan prices.** The mockups show Agent Pro ₦10,000 / 30 days and boosts ₦3,000 (7 days) and ₦5,000 (14 days). Your earlier plan listed ₦5,000 / ₦10,000 / ₦20,000. The pilot catalog follows the mockups. Confirm before you take payments. The annual price is hidden in the app until you confirm one.
- **Free 3 / Pro 20 listing limits** (above).
- **Legal text.** `lib/presentation/screens/info/legal_screen.dart` has plain-language drafts of Terms and Privacy. Have a Nigerian lawyer review them (NDPA 2023, consumer-protection wording, refunds) before launch.
- **WhatsApp assist number.** The line is 08107286686, built into the app as `kWhatsAppAssistNumber` in `app_providers.dart`, so nothing needs setting up. To change it later without a new build, add Firestore `public_config/app` with a string field `whatsappAssistNumber`; that value overrides the built-in one. The flow only helps people send details; a person on your side turns messages into drafts.
- **Support email** `support@propsure.africa` (`contact_support_screen.dart`): create the mailbox or change it.
- **propsure.africa hosting.** Share links use `https://propsure.africa/l/{listingId}` and shortlist invites use `/s/{code}`. Both need a web page and app deep-link setup (Android App Links), or the links will open a browser page that does not exist. The payment callback `/payment/callback` must also resolve (a blank page is fine; the app intercepts it).
- **Reviewer access.** Verification and reports are reviewed by people with a `reviewer` or `admin` claim (`setAdminOrReviewerClaim`). There is no reviewer app in this bundle. Until you have one, use the Firebase console or your admin app.
- **Push notifications are not implemented.** Search alerts and support updates appear in the in-app Notifications list. Settings toggles other than Search alerts are saved but do nothing yet, and the app says so.
- **Deleting an account** sends a support request; nothing deletes data automatically.
- **Blocking** is not implemented; Settings says so.

## 4. Data migrations (run once, before or just after deploy)

1. **Old listings with `status: 'active'` but no `availabilityConfirmedAt`.** They will show "Availability not confirmed". Either backfill `availabilityConfirmedAt` to a date you trust, or let agents press Update. Do not backfill dates you cannot stand behind.
2. **`video360Url` / `video360`.** Legacy field, never displayed. You can delete it.
3. **Old `For Rent` category strings.** The app reads both `For Rent` and `for_rent`, but new writes use `for_rent`, `for_sale`, `short_stay`, `commercial`.
4. **Existing user docs** with `premiumPlan` / verification fields are untouched. New writes to those fields come only from the server.
5. **`public_profiles`** is written by the `syncPublicProfile` trigger on user changes. For existing users, touch each user doc once (or run a one-off script) so the mirror exists. The agent profile and listing screens read from it.
6. **Indexes.** `firestore.indexes.json` contains every composite index the new queries need. Wait for them to finish building.

## 5. First-build checklist

1. `flutter pub get`, then `flutter analyze`. Fix what it reports.
2. Run on a device with a test Firebase project, not production.
3. Walk this path: welcome → phone sign-in → add a video listing → review frames → add costs → publish → see it in search with the Sponsored label absent → boost it → see Sponsored → request an inspection from a second account → confirm it.
4. Paystack: use your **test** key first. Confirm that after payment the listing shows Sponsored only once `verifyPaystackTransaction` or the webhook has marked it paid.
5. Try to break it: a renter account trying to publish, an agent over the free limit, an unconfirmed fee in the move-in total.
