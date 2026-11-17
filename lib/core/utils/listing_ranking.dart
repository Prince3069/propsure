import '../../data/models/listing_model.dart';

/// A rough 0-100 completeness score computed from what is on the model.
/// Used for ranking and for the agent's "complete your listing" hints.
int listingCompletenessScore(ListingModel l) {
  var points = 0;
  const total = 9;
  if (l.title.trim().length >= 10) points++;
  if (l.description.trim().length >= 60) points++;
  if (l.price > 0) points++;
  if (l.images.length >= 3) points++;
  if (l.images.length >= 6) points++;
  if (l.amenities.isNotEmpty) points++;
  if (l.hasVideo) points++;
  if (l.charges.isNotEmpty || !l.categoryEnum.hasMoveInCost) points++;
  if (l.additionalInfo?.trim().isNotEmpty ?? false) points++;
  return ((points / total) * 100).round();
}

/// Blended score for the default sort.
///
///  * Freshness is measured from the last availability confirmation (not
///    from when the listing was first created).
///  * Completeness rewards listings that show costs, photos and video.
///  * A current authority check adds a modest, real signal.
///  * Paid placement is capped and is shown to renters as "Sponsored"; it
///    never changes any check. A safety hold removes the boost entirely.
double listingRankScore(ListingModel l) {
  double score = 0;
  final basis = l.availabilityConfirmedAt ?? l.publishedAt ?? l.createdAt;
  final ageDays = DateTime.now().difference(basis).inHours / 24;
  score += (1 - (ageDays / 21)).clamp(0.0, 1.0) * 45;
  score += (listingCompletenessScore(l) / 100) * 35;
  if (l.authority.isCurrent) score += 10;
  if (l.isSponsored) score += 10;
  return score;
}

int compareListingsByRank(ListingModel a, ListingModel b) =>
    listingRankScore(b).compareTo(listingRankScore(a));
