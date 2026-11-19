# What changed

## Design
All 45 mockup screens are implemented in `lib/presentation/screens/` on one shared kit (`core/widgets/ps_widgets.dart`, tokens in `core/constants/app_theme.dart`): green #0F4C3A, ivory #F8F6F0, charcoal #1A1A2E, gold #D4A02B, Plus Jakarta Sans, 24 px gutters, 48 px tap targets. Navigation is role-aware: renters get Discover / Tours / Saved / Inbox / Account; agents get Workspace / Listings / Leads / Inbox / Account.

## Product rules from the design brief, now enforced in code
- One category model (`for_rent`, `for_sale`, `short_stay`, `commercial`) with the price period derived from it.
- No "360" claims anywhere. Real video, a poster image, no autoplay. Frames from the video are suggested; the agent chooses the ones to keep.
- Unknown costs are never zero: the card says "Known move-in subtotal" and lists unconfirmed charges.
- Passport shows separate checks (identity, authority for this listing, availability, media & costs, title) and says plainly when title was not reviewed.
- Paid placement is labelled **Sponsored** and never "Verified". Paying does not change a check.
- Agent Pro is a fixed 30-day pass, not recurring.
- The rent planner says it is not financing.
- Approximate location is shown unless an exact pin was explicitly chosen.
- No invented ratings, review counts, "online" indicators or response-time claims.

## Backend
- Listings are created as drafts. `publishListing` owns status, the active-listing quota and the availability stamp. `confirmAvailability` and `setListingStatus` do the rest.
- Freshness: needs refresh after 7 days; hidden from search after 21 (`refreshFreshness`).
- Scoped passport written by the server (`authority`, `title`); identity comes from `public_profiles`.
- Payments: `getPricing`, `initializePaystackTransaction`, `paystackWebhook`, `verifyPaystackTransaction`, `reconcilePendingTransactions`. The server decides what was paid for.
- Support and reports: `createSupportRequest` (with a reference), `updateSupportRequest`. Serious report reasons put the listing under a safety hold.
- Shortlists: `createShortlistInvite`, `joinShortlist`.
- Media: upload original → `onOriginalVideoFinalized` queues a job → Cloud Run worker probes, makes a poster and candidate frames → agent confirms frames with `confirmVideoFrames`.
- Search alerts honour the "Search alerts" setting.

## Files removed
`upload_listing_screen`, `edit_listing_screen` (replaced by `add_listing_screen`, which handles both), `contact_screen`, `paystack_webview_screen`, `splash_screen`.

## Known gaps (also in DEPLOY.md)
Client `viewCount` increments were dropped (rules do not allow them; a server counter is the right fix). Reschedule and meeting-point directions on inspections are omitted because the backend has no support for them. Documents in "My home" show as not available yet.

## 1.1.1 UI and reliability pass
- One home per role (agents land on Workspace); Search/Map match legacy category spellings; Inbox index added.
- New bottom bar, rebuilt Search screen, shared green header on Listings, Leads, Inbox and Account.
- WhatsApp number now comes from Firestore `public_config/app`.
- Every error screen shows a small technical detail line; one bad listing no longer blanks a list.

## 1.2.0 part 1: new Home, city picker, responsive layout
- Home redesigned: green header with a time-of-day greeting (device clock, no location needed), first name, tour-of-the-day card (a real still from an agent's video; a time-of-day scene when the city has no tour), search card, move-in budget shortcuts, video tour row, fresh homes.
- City picker: the header chip opens a list of open cities (any city with a live listing) and coming-soon cities. Choice is remembered on the device. "Notify me" opens WhatsApp with a prefilled message. Optional `comingSoonCities` (list of names) in Firestore `public_config/app`.
- Search, Map and Home are scoped to the chosen city (legacy values such as FCT map to Abuja; listings with no city are never hidden).
- Responsive: phone (<600) bottom bar; tablet (600-1023) navigation rail; desktop (>=1024) top bar and two-column Home; content capped at 1200px.

## 1.2.0 part 2: every room, shown
- Agents name the rooms on stills taken from their video (quick choices numbered to the listing's bedrooms and bathrooms, or a typed name). Works at review time and later for already-published videos ("Name the rooms in your video").
- Renters get tappable room chapters on the listing and inside the tour player (tap to jump, active chapter follows playback), and a "What the video shows" card: what is shown and what is "not shown". Nothing appears until an agent has named rooms; nothing is guessed.
- New Cloud Function `updateStillLabels` (owner only; changes label text only).
- Indexes: added listings (status+propertyType+createdAt, status+isFeatured+createdAt), users (verificationStatus+verificationExpiresAt, needed by the nightly expiry job) and reports (reporterId+createdAt). Every query in the app and in functions was checked against firestore.indexes.json.

## 1.2.0 part 3: "Check before you pay"
- New screen `/check-account` (linked from every listing's "Before you pay" card): pick the bank, type the 10-digit account number, and see the registered account name next to the agent's name. Result is match, different or unknown. We never say "safe"; "different" and "unknown" tell the renter to ask the agent why before paying.
- New Cloud Functions `listBanks` and `checkAccountName` (sign-in required, 10 checks per person per day, only the last 4 digits are logged). Uses Paystack Resolve Account Number. **Real names need your LIVE Paystack key** (`PAYSTACK_SECRET_KEY` in functions/.env); test mode only resolves test accounts.

## 1.2.0 part 4: "Life around the home"
- Residents report power, water, flooding, security, internet and roads for an area (fixed answer choices, one report per person per area per topic, 12 a day, agents with a listing in that area cannot report on it).
- Listing page shows an area card; `/area` shows the full report; `/area/report` collects reports. Reports are dated and counted; fewer than 3 show as "Early reports".
- New Cloud Function `submitAreaReport`; new Firestore collection `area_summaries` (read-only for clients).

## 1.2.0 part 5: website fixes
- Photos, videos, documents and avatars are picked as bytes on the web (no `dart:io`), via `core/utils/upload.dart`. Phones behave as before.
- Payment on the web: Paystack opens in the same tab and returns to `/payment/callback`, which verifies with the server. Phones still use the in-app checkout.
- Map: the website shows a "map is on the app" page unless you add a web Maps key and build with `--dart-define=MAPS_WEB=true`.
- `web/index.html`, manifest and robots.txt updated; clean URLs (`usePathUrlStrategy`). Profile city list now comes from the open cities.

## 1.2.0 part 6: share pages and sitemap
- `https://propsure.africa/l/<id>` now returns a preview page (title, area, price, photo) for WhatsApp/Facebook/Google, then opens the listing. Only the area is shown, never the street.
- `/sitemap.xml` lists live homes. Functions: `shareListing`, `sitemap`. `firebase.json` has the rewrites (admin site untouched).
