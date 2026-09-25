# Propsure — Phase 3 (Growth & Supplier Productivity)

Builds on Phases 1 and 2. Same rule as before: every fix here was
confirmed by reading the actual file, not assumed from the review.

## What changed, and why

### 1. Bulk CSV import — was skipping every safeguard
`bulk_upload_screen.dart` already had real CSV parsing/validation, but the
actual Firestore write had two serious problems:
- Wrote the raw CSV category value ("For Rent") straight into Firestore —
  the same category-normalization bug fixed everywhere else, reintroduced
  here because this screen hand-built its own map instead of going
  through `ListingCategory`.
- Published every row with `status: 'active'` **immediately**, with
  `images: []` — i.e. live, public, zero-photo listings, seconds after a
  CSV was parsed. The review is explicit: bulk imports must land as
  drafts requiring confirmation before publishing.

Now every imported row lands as `status: 'draft'` — invisible to search,
home, and everyone but the importing agent — until it's reviewed.

### 2. Drafts tab in `AgentListingsScreen`
Added alongside Active/Paused/Archived from Phase 2:
- A banner surfaces the moment there are drafts waiting.
- **Publish** is blocked (redirects to Edit instead) until the listing
  has at least one photo — the same bar a normal single upload has to
  clear, just enforced at the draft-review step instead of at CSV-parse
  time, since a CSV obviously can't carry image files.
- **Discard** replaces "Delete Permanently" for drafts specifically —
  same underlying action, clearer label for what it actually is.

### 3. Enquiries — "not every property interaction is a viewing"
- **New:** `EnquiryModel` / `EnquiryRepository` → `enquiries` collection.
  General question / call request / application request, with budget
  range, preferred contact channel, and response-time tracking
  (`responseMinutes`) — this is also the shape of signal a lead-gen
  product like LeadRadar actually wants: not just "someone looked," but
  what they asked, how they wanted to be reached, and how fast the agent
  responded.
- Added additively to `listing_detail_screen.dart`: a "Not ready to book
  a tour? Ask a quick question instead →" link inside the existing
  booking sheet opens a new `_QuickEnquirySheet`. The existing viewing
  -booking flow is completely untouched — this is a new, separate path,
  not a rework of something that already worked.
- `agentResponseRateProvider` gives a ready-to-use response-rate number
  for the supplier dashboard once there's enough enquiry volume to make
  it meaningful.

### 4. Saved searches & alerts
- **New:** `SavedSearchModel` / `SavedSearchRepository` → `saved_searches`
  collection. A saved search is a frozen `ListingFilter` plus an
  alerts-on/off toggle.
- "Save search & get alerts" button added to the search filter panel
  (both mobile and desktop layouts), and a new **Saved Searches** screen
  (`/saved-searches`, linked from the drawer) to view, toggle, or delete them.
- **New Cloud Function:** `checkSavedSearches`, scheduled every 15
  minutes — finds listings created since its last run, matches them
  in-memory against every saved search with alerts enabled, and creates
  a real `notifications` document per match (reusing the existing
  notification pipeline `notifications_screen.dart` already reads from,
  rather than inventing a second delivery mechanism).
- **Deploy note:** this scheduled function needs the Cloud Scheduler API
  enabled and your project on the Blaze (pay-as-you-go) plan — scheduled
  functions aren't available on the free Spark plan. It also needs a
  Firestore composite index on `listings` for `status` (==) + `createdAt`
  (>) — Firebase will give you the exact console link to create it the
  first time the function runs and fails, or you can add it proactively
  in `firestore.indexes.json`.

### 5. A real bug caught in my own draft, before it shipped
While adding `checkSavedSearches`, an editing pass on `functions/index.js`
briefly corrupted the comment header above `setAdminOrReviewerClaim` into
`}); Guarded\n// so a user can NEVER...` — a syntax error that would have
failed to deploy. Caught it by re-reading the file and running
`node --check index.js`, which now passes cleanly. Flagging this
explicitly rather than quietly fixing it, since you should know a
mistake happened and was caught, not just that the end result looks fine.

## Deploying this

```bash
# Rules (adds enquiries, saved_searches, draft status)
firebase deploy --only firestore:rules

# New function
cd functions
firebase deploy --only functions:checkSavedSearches
```

If this is the project's first scheduled function, confirm the project is
on Blaze and the Cloud Scheduler API is enabled in Google Cloud Console
before deploying, or the deploy will fail with a clear error telling you
which of the two is missing.

## Explicitly deferred to Phase 4
- Supplier response-rate signals surfaced *in the dashboard UI* itself
  (the provider exists — `agentResponseRateProvider` — but
  `AgentListingsScreen` doesn't render it yet; wanted enough real enquiry
  data to exist first rather than shipping a number that's always "N/A").
- Viewing availability slots/time windows (currently still a single
  date/time picker with no supplier-defined availability).
- Cursor pagination and indexed search for `watchListings()` — still
  downloads up to the configured limit and filters/sorts in memory.
- Ranking that blends freshness/completeness/verification/response
  signals — current sort is still featured-first then newest/price.
- Controlled premium benefit *consumption* (e.g. "2 free boosts/month" as
  an actual decrementing credit ledger) — `isPremium`/`premiumPlan` exist
  and are correctly server-granted, but nothing yet tracks or limits
  usage of the benefits that come with them.
- Admin moderation queue for `reports` (still just data collection, as
  noted in Phase 2).
