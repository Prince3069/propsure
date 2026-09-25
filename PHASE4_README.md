# Propsure — Phase 4 (Scale)

Builds on Phases 1–3. Per the plan from the start, this is the last of
the four originally scoped phases — there's no Phase 5. What's listed
under "Explicitly deferred" below is optional future work, not something
already promised.

**Important context for this phase specifically:** I don't have Flutter/
Dart SDK or pub.dev access in this environment, so nothing across any of
the four phases has been run through a real compiler — only manually
traced. Treat your first `flutter analyze`/build as the real check, not a
formality, and send me the actual errors if there are any.

## What changed, and why

### 1. Cursor pagination — the review's core "Firestore query scalability" ask
`watchListings()` was a live `.snapshots()` stream capped at a fixed
limit (30–40 depending on caller) with no way to ask for more — the
review's literal complaint: "downloads up to N active documents... may
work at small scale but will become expensive and slow as inventory
grows."
- **New:** `ListingRepository.fetchListingsPage()` — a one-shot `.get()`
  query with `startAfterDocument` cursoring, returning a `ListingPage`
  (items + last document + whether more exist).
- **New:** `SearchResultsController` (in `app_providers.dart`) — holds
  accumulated pages and a `loadMore()` method.
- `search_screen.dart`'s grid (`_ListView`) now uses this controller with
  a scroll listener that calls `loadMore()` near the bottom, instead of
  `filteredListingsProvider`'s single capped snapshot. The map view still
  uses the old capped provider — pagination doesn't make sense for a
  bounded map viewport, so that one was left alone deliberately.
- **Caveat, stated plainly:** price range, min bedrooms, and free-text
  search still can't be expressed as Firestore `where` clauses without a
  real search index (Algolia/Typesense/etc. — a third-party integration
  decision, not something to bolt on silently). Those filters still apply
  to each fetched page after the fact, so a page can come back with fewer
  than the requested page size. What this fixes is the actual problem —
  the app no longer pulls everything into memory — not full-text search,
  which the review itself flags as needing a dedicated service.

### 2. Ranking — freshness + completeness + verification + featured
The default sort was "featured always wins, then just newest." A
barely-filled-out, unverified, month-old boosted listing would bury a
genuinely fresh, complete, verified one with no boost.
- **New:** `core/utils/listing_ranking.dart` — `listingRankScore()`
  blends freshness (decaying over 60 days), completeness (the same score
  `AgentListingsScreen` shows agents, now shared from one place instead
  of two definitions drifting apart), verification, and featured status.
  Weighted so freshness+completeness (75 of 100 points) matter more than
  a paid boost alone (10 points) — matching the review's own stated
  priority.
- Response-rate is explicitly NOT in this score yet — it's a per-agent
  signal, not a listing signal, and there isn't enough enquiry volume for
  it to be fair. Noted as still deferred.
- Wired into both `watchListings()` and `fetchListingsPage()`'s default
  sort branch.

### 3. Property comparison (review 3.4)
- **New:** `compareListProvider` — simple in-memory, session-only
  selection of up to 3 listing IDs (deliberately not persisted — it's a
  shortlist tool for right now, not a saved feature).
- **New:** `CompareScreen` (`/compare`) — side-by-side table: price,
  type, category, bedrooms, bathrooms, area, verification, featured,
  furnished, amenities.
- Added additively to `listing_detail_screen.dart` — a compare icon next
  to the existing Report button (Phase 2) and Share button, for anyone
  viewing a listing they don't own. Deliberately did NOT touch
  `ListingCard`/the search grid to add a selection checkbox there — you'd
  flagged UI quality as something you're watching, and adding a
  multi-select mode to a card used across the whole app is a much bigger
  visual-regression risk than an additive icon on one detail screen.

### 4. A mistake caught before it shipped, this phase
While threading the new `onCompareToggle`/`isInCompare` parameters through
`_MobileLayout` → `_PhotoSliver` and `_DesktopLayout` (three classes, same
pattern used for Report in Phase 2), I initially wrote the compare-toggle
snackbar helper method assuming it sat in the same state class as
`_markRead()` — which is actually in `chat_screen.dart`, a different
file. The `str_replace` correctly failed with "string not found" instead
of silently landing in the wrong place; re-checked the actual file
structure and inserted it next to `_reportListing()` instead, where it
belongs. Mentioning this because a caught mistake is worth knowing about
even when the tooling itself prevented the bad outcome.

## Deploying this

No new Cloud Functions or rules changes this phase — everything is
client-side (repository method, provider, two screens, one shared util).
Nothing to redeploy on the Firebase side beyond what Phases 1–3 already
cover.

## Explicitly deferred (optional future work, not a promised phase)
- Supplier response-rate blended into ranking, once there's real enquiry
  volume to make it a fair signal.
- Viewing availability time-slots (still a single date/time picker with
  no supplier-defined availability windows).
- A real premium-benefit usage ledger — `isPremium`/`premiumPlan` are
  correctly granted server-side, but nothing tracks or limits consumption
  of whatever benefits come with a plan (e.g. "2 free boosts/month").
- Admin moderation queue for the `reports` collection Phase 2 started
  collecting. Deliberately NOT built inside this consumer app — the
  review itself recommends a separate admin app or secure internal tool
  rather than raw Firestore console editing or grafting admin screens
  onto the tenant/agent-facing product. If you want this, it's worth
  scoping as its own small project rather than a corner of Propsure.
- Multi-city expansion — this is a business-readiness decision (the
  review's own framing: "expand only after city-level supply and demand
  metrics are healthy"), not a code change waiting to happen.
- A trained/data-driven ranking model — `listingRankScore()` is a
  reasonable heuristic, not something tuned against real click or
  conversion data, because that data doesn't exist yet.
