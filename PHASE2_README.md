# Propsure — Phase 2 (Marketplace Operations)

Builds on Phase 1. Same rule as before: every fix here was confirmed by
reading the actual file, not assumed from the review.

## What changed, and why

### 1. `watchAgentListings` bug (found while building the dashboard)
- Hard-filtered `.where('status', isEqualTo: 'active')` — meaning the
  **My Listings** screen from Phase 1 could never show a listing you'd
  paused, so tapping "Republish" on something already hidden had no way
  to work. Removed the filter; an owner's own management view now shows
  everything they own, active or not. The *public* feed (`watchListings`)
  still correctly only shows `active`.

### 2. Soft delete / listing lifecycle
- `archiveListing()` / `restoreListing()` on `ListingRepository` —
  `status: archived`, `archivedAt`, `archivedBy`. Archived listings are
  excluded from every public query automatically (nothing queries for
  `status == 'archived'`), but the document survives, so a chat or
  booking that references it doesn't break.
- `deleteListingPermanently()` kept as a separate, clearly-labeled action
  for the one legitimate hard-delete case (privacy/legal takedown).
- `listing_detail_screen.dart`'s delete dialog now offers **Archive**
  (default) and **Delete Permanently** (secondary, red) instead of only
  ever hard-deleting.
- `AgentListingsScreen` now has Active / Paused / Archived tabs, with
  Restore on archived items.

### 3. Supplier dashboard (on top of Phase 1's AgentListingsScreen)
- Per-listing **completeness score** (title/description length, photo
  count, amenities, video, extra info — 8 checks, shown as a progress bar).
- **Verified** / **Featured** / **Stale (30+ days)** badges per listing.
- Agent-level status row: verification status, and a real premium badge
  (Pro/Elite) — which required adding `premiumPlan`/`premiumExpiresAt` to
  `UserModel` since the Cloud Function was already writing them but
  nothing read them back for display.
- Still deferred to Phase 3: response-rate/enquiry analytics, bulk actions
  — both need the enquiry model and analytics-event work that hasn't been
  built yet.

### 4. Report & block — the review's "report, block, and moderation flows"
- **New:** `ReportModel` / `ReportRepository` → `reports` collection.
- **Listing detail:** new Report button (flag icon) for anyone viewing a
  listing they don't own — bottom sheet with reason categories.
- **Chat:** the Report/Block menu items **already existed in the UI** —
  `PopupMenuButton` with "Report"/"Block" — but `onSelected: (v) {}` did
  nothing at all when tapped. Wired both up for real: Report opens a
  reason sheet and files a report against the other participant; Block
  sets your own uid into the chat's `blockedBy` array, which hides your
  input bar and shows an "Unblock" banner. Firestore rules deny a message
  `create` from anyone in that chat's `blockedBy` — so blocking is
  actually enforced server-side, not just a UI state.
- A moderation *queue* for admins to act on filed reports is a separate
  admin-tool project (same reasoning as the review: don't build this as
  raw Firestore console editing) — out of scope here.

### 5. Booking state machine (review 2.7)
- `confirmBooking`/`rejectBooking`/`cancelBooking`/`completeBooking` now
  require an `actorId` and stamp `confirmedBy`/`rejectedBy`/`cancelledBy`/
  `completedBy`/`completedAt` on the document — previously a bare status
  flip with no record of who did it.
- **firestore.rules** now enforces the actual state machine by role:
  only the agent can confirm/reject a pending request or complete a
  confirmed one; either side can cancel from pending/confirmed. Before
  this, any signed-in participant could call any transition on any
  booking they were part of, regardless of role.

### 6. View-count correctness
- `incrementView` was defined but **never called from anywhere** —
  view counts were simply always 0, not over-counted. Added
  `incrementViewOnce()`, deduplicated via a `viewedBy/{viewerId}`
  subcollection (a second view from the same person, or a screen
  rebuild, is a no-op), and wired it into `listing_detail_screen.dart` —
  once per visit, only for people who aren't the listing's own owner.

### 7. Bug found and fixed in Phase 1's own rules
- The Phase 1 `firestore.rules` draft for `chats`/`bookings` checked field
  names (`participants`, `tenantId`) that don't actually exist on
  `ChatModel`/`BookingModel` — the real fields are `participantIds` and
  `userId`. If deployed as originally written, this would have silently
  blocked every chat read/write and booking access. Caught and fixed
  before you deployed it, while building the block/report and booking
  rules on top of the same sections.

## Deploying this

```bash
firebase deploy --only firestore:rules
```

No new Cloud Functions in this phase — everything here is client +
rules. Functions from Phase 1 are unaffected.

## Explicitly deferred to Phase 3+
- Bulk CSV import with validation/drafts.
- Saved searches and alerts.
- Enquiry model distinct from bookings (general enquiry / call request /
  budget context) and the response-rate signals that depend on it.
- Cursor pagination and indexed search for `watchListings()` — still
  downloads up to the configured limit and filters/sorts in memory.
- Admin moderation queue for the `reports` collection.
- A true mutual/hidden block (currently self-directed: blocking stops
  *you* from sending, it doesn't hide you from the other person or
  remove the chat from their list).
