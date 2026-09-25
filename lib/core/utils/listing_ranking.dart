import '../../data/models/listing_model.dart';

/// A rough 0-100% completeness score computed purely from what's already
/// on the model — no new fields needed. Originally lived inline in
/// agent_listings_screen.dart; moved here so listing_repository.dart's
/// ranking can use the exact same number the supplier dashboard shows,
/// rather than two separate definitions of "complete" drifting apart.
int listingCompletenessScore(ListingModel l) {
  var points = 0;
  const total = 8;
  if (l.title.trim().length >= 10) points++;
  if (l.description.trim().length >= 60) points++;
  if (l.price > 0) points++;
  if (l.images.length >= 3) points++;
  if (l.images.length >= 6) points++;
  if (l.amenities.isNotEmpty) points++;
  if (l.videoUrl != null || l.video360Url != null) points++;
  if (l.additionalInfo?.trim().isNotEmpty ?? false) points++;
  return ((points / total) * 100).round();
}

/// Blended ranking score for the DEFAULT ("newest"/relevance) sort order.
///
/// Before Phase 4, the default sort was just "featured first, then
/// createdAt descending" — which meant a barely-filled-out, unverified,
/// month-old listing with a boost still buried every genuinely fresh,
/// complete, verified listing that hadn't paid for a boost. The review's
/// "Improve ranking using freshness, completeness, verification, and
/// response signals" item asks for exactly this blend.
///
/// This is a heuristic, not a trained model — weights were chosen to
/// reflect the review's own stated priority (freshness and completeness
/// matter more day-to-day than a paid boost alone), and are easy to
/// retune later once there's real click/conversion data to tune against.
/// Response-rate isn't included yet: it lives on the agent, not the
/// listing, and EnquiryRepository doesn't have enough volume yet for a
/// per-agent rate to be a fair signal (see PHASE3_README's deferred list).
double listingRankScore(ListingModel l) {
  double score = 0;

  // Freshness: full marks at 0 days old, decaying to 0 by 60 days.
  final ageDays = DateTime.now().difference(l.createdAt).inHours / 24;
  final freshness = (1 - (ageDays / 60)).clamp(0.0, 1.0);
  score += freshness * 40;

  // Completeness: a well-filled-out listing converts better and deserves
  // to be seen — this is the biggest single factor.
  score += (listingCompletenessScore(l) / 100) * 35;

  // Verification: a real, reviewed trust signal.
  if (l.verificationStatus == VerificationStatus.approved) score += 15;

  // Featured: still counts, but no longer automatically wins over
  // everything else the way a bare "isFeatured ? -1 : 1" comparator did.
  if (l.isFeatured) score += 10;

  return score;
}

int compareListingsByRank(ListingModel a, ListingModel b) =>
    listingRankScore(b).compareTo(listingRankScore(a));
