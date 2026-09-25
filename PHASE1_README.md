# Propsure — Phase 1 (P0 Correctness & Trust)

This covers everything from "Correctness and Trust" in the code review that
touches actual code, plus the drawer/UI fixes you asked about directly.
Everything here was written against your real files — every bug described
below was confirmed by reading the actual line, not assumed from the review.

## What changed, and why

### 1. Category normalization
- **New:** `lib/core/constants/listing_category.dart` — canonical
  `ListingCategory` enum (`rent/sale/shortStay/commercial`) with `.value`
  (DB), `.label` (UI), `.routeSlug`, and `fromAny()` which safely parses
  old `"For Rent"`-style documents.
- `listing_model.dart`, `listing_repository.dart`, `upload_listing_screen.dart`,
  `edit_listing_screen.dart`, `search_screen.dart` all now read/write only
  the canonical value. The dropdown still *shows* "For Rent" — it just no
  longer *stores* it.
- The edit screen's category dropdown was actually **broken** — it stored
  the DB value but compared against label items, so it silently showed
  blank every time you opened an existing listing to edit it. Fixed.
- **Run once after deploying:** `migrations/normalize_categories.js` —
  rewrites any already-stored `"For Rent"` etc. to the canonical value. The
  app works even if you don't run it (normalizes on read), but anything
  that reads Firestore directly — exports, BigQuery, admin tools — won't
  see clean data until you do.

### 2. Search / filter state model
- `ListingFilter` no longer has both `query` and `searchQuery` (the
  duplicate that made `copyWith()` silently drop your search text when you
  changed another filter). One field: `query`. Also dropped the dead
  `state` field that was accepted but never actually applied to the query.
- `activeFilterCount` now counts category/featured/query — it was
  undercounting before.
- Fixed the `?category=short-stay` vs `short_stay` mismatch from the
  drawer's browse links, which meant that link returned zero results.
- **Bonus find while verifying this:** `home_screen.dart`'s category chips
  ("All / For Rent / For Sale / Short Stay") had the exact same bug in
  three separate places — `_FeaturedSection`, `_VerifiedSection`, and
  `_RecentSection` all compared the raw chip label directly against
  `listing.category` (canonical). It never matched, so tapping a category
  chip on the home screen silently did nothing — `_FeaturedSection`/
  `_VerifiedSection` quietly fell back to showing unfiltered results,
  which is exactly why this had gone unnoticed. Fixed the same way.

### 3. Real verification workflow
- **New:** `verification_request_model.dart` + `verification_repository.dart`
  — replaces the old `Future.delayed(seconds: 2)` fake submit entirely.
  Documents upload to a **private** Storage path
  (`verification/{uid}/{requestId}/...`), a `verification_requests`
  document is created with status `submitted`, and the UI now shows a real
  status screen (pending / approved / rejected + reason) instead of always
  re-showing the wizard.
- Removed the false "Your ID is encrypted" claim (nothing in the code
  demonstrated encryption) — replaced with an accurate description of what
  actually happens (private storage path, reviewer-only access).
- Approval/rejection happens **only** via the `reviewVerificationRequest`
  Cloud Function, gated on a `reviewer`/`admin` custom claim. The client
  can move its own request from nothing → `pending`; nothing else.

### 4. Backend-controlled trust fields
- `listing_repository.dart`'s `updateListing()` used to accept *any* map
  and write it straight to Firestore — a modified client could set
  `isVerified`, `isFeatured`, `status`, even `agentId`. It's now allowlisted
  to owner-safe fields only (`kOwnerEditableListingFields`).
- **New:** `firestore.rules` — the actual enforcement (the allowlist above
  is defense-in-depth; this is what a modified APK can't get around).
  Users can't self-elevate role/verification/admin, can't touch another
  user's listing, can't write to `transactions` at all, etc.
- **New:** `storage.rules` — verification documents are unreadable by
  anyone except the uploader and a reviewer.

### 5. Payment & entitlement integrity
- `paystack_service.dart` no longer lets the client create the pending
  transaction with a client-supplied amount. It now sends only a `planId`;
  the Cloud Function looks up the real price from a server-side
  `PLAN_CATALOG` and creates the transaction itself.
- `boost_listing_screen.dart` / `premium_screen.dart` updated to send
  `planId` instead of `amountKobo`.
- **New Cloud Functions** (`functions/index.js`):
  `initializePaystackTransaction`, `paystackWebhook` (verifies the
  signature, idempotent — a retried webhook can't double-grant),
  `verifyPaystackTransaction`. The boost function also checks the listing
  actually belongs to the paying user before it'll even start a charge.

### 6. Location accuracy
- **The 0,0 bug:** `edit_listing_screen.dart` fell back to `(0, 0)` — a
  real coordinate in the Gulf of Guinea — if `_selectedPin` was ever null.
  Now falls back to the listing's own last-known coordinates, never zero.
- Added `locationPrecision` (`exact`/`approximate`) to `PropertyLocation`
  so the UI can eventually stop implying every listing's pin is exact.

### 7. Drawer navigation + visual polish
- Fixed six dead links that just closed the drawer and went nowhere: **How
  We Verify Agents, Safety Tips, FAQ, Contact Us, About Propsure** now
  route to the info screens that already existed but were never wired up;
  **Go Premium Agent** now goes to `/payment/premium`.
- **My Listings** was pointing at `/search` (wrong) — now goes to the new
  `AgentListingsScreen` (see below).
- Removed **Agent Directory** — there's no screen behind it; a link with
  nothing there is worse than no link.
- Replaced hard-coded `badge: '3'` / `badge: '5'` with real unread counts
  from `totalUnreadProvider` / the new `notificationsUnreadCountProvider`.
- Visual polish: each drawer row is now its own rounded, tappable card
  with real press feedback (was a flat `ListTile` with no spacing),
  section headers got more breathing room.

### 8. Removed the duplicate edit-listing screen
- `/listing/:id/edit` used to build a second, less-complete edit screen
  (`UploadListingScreen(editListingId:)`) that had drifted from
  `EditListingScreen` — it never actually loaded the listing's existing
  category or location. It's now a redirect to `/listing/edit/:id` so old
  links still work, but there's only one real edit screen.
- `/profile/listings` used to build `SavedListingsScreen` (your bookmarks,
  not your own inventory). **New:** `agent_listings_screen.dart` — a real
  "my listings" screen with status, pause/republish, edit, delete. This is
  the focused version; the fuller dashboard (completeness score, view/save/
  enquiry analytics) is a Phase 2 addition on top of this screen.

## Deploying this

```bash
# 1. Firestore + Storage rules
firebase deploy --only firestore:rules,storage

# 2. Cloud Functions
cd functions
npm install
firebase functions:config:set paystack.secret_key="sk_live_xxxxx"
firebase deploy --only functions

# 3. One-time category cleanup (safe to skip, safe to re-run)
cd ../migrations
GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json node normalize_categories.js

# 4. Bootstrap your first admin (one time, from a trusted machine —
#    after this, use setAdminOrReviewerClaim to promote anyone else)
node -e "
const admin = require('firebase-admin');
admin.initializeApp();
admin.auth().setCustomUserClaims('YOUR_ADMIN_UID', { admin: true, reviewer: true })
  .then(() => console.log('done'));
"
```

Then rebuild and release the Flutter app with the updated `lib/` — the old
app (without these changes) will still work against the new rules for
everything except the removed client-side transaction write and any
listing-update that touches a locked field, which will now fail with a
permission error instead of silently succeeding.

## Phone/Play Console activation (repeated from earlier, for this drop)
1. Firebase Console → Authentication → Sign-in method → enable **Phone**.
2. Play Console → your app → Setup → App Integrity → App signing → copy
   the **SHA-1 and SHA-256 from the App signing key certificate**.
3. Paste into Firebase Console → Project Settings → Your apps → SHA
   certificate fingerprints; download the refreshed `google-services.json`.
4. Enable the **Play Integrity API** in Google Cloud Console for this
   Firebase project.

## Explicitly deferred to Phase 2+ (not silently dropped — just sequenced)
- Full supplier dashboard (completeness score, views/saves/enquiries,
  bulk actions) — `AgentListingsScreen` above is the foundation for it.
- Booking state-machine enforcement via Cloud Functions
  (`confirmBooking`/`rejectBooking`/etc.) — `firestore.rules` above already
  stops a tenant reading/editing someone else's booking, but the full
  `pending → confirmed → completed` state machine isn't server-enforced yet.
- Soft-delete/archive for listings (currently still a hard delete).
- Report/block/moderation queue, deterministic chat IDs, notification
  deep links, analytics events, bulk CSV import, saved-search alerts,
  cursor pagination for `watchListings()`.
