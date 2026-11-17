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
