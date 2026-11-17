import '../../data/models/listing_model.dart';

/// How recently a home's availability was confirmed. The windows mirror the
/// server job (functions/lib/config.js): needs a refresh after 7 days, hidden
/// after 21. Agent confirmation is labelled as the agent's confirmation —
/// it is not an independent visit.
enum Freshness { confirmed, needsRefresh, stale, unknown }

class FreshnessInfo {
  final Freshness state;
  final DateTime? at;
  final String? by;
  const FreshnessInfo(this.state, this.at, this.by);

  String get short {
    if (at == null) return 'Availability not confirmed';
    return 'Updated ${relativeDays(at!)}';
  }

  /// Used on the passport / detail rows.
  String get confirmedLabel {
    if (at == null) return 'Not confirmed';
    return 'Confirmed ${relativeDays(at!)}';
  }

  String get byLabel => by == 'inspection'
      ? 'Confirmed after a visit'
      : by == 'propsure'
          ? 'Confirmed by Propsure'
          : 'Confirmed by the agent';
}

FreshnessInfo freshnessOf(ListingModel l, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final at = l.availabilityConfirmedAt;
  if (at == null) return FreshnessInfo(Freshness.unknown, null, l.availabilityConfirmedBy);
  final days = n.difference(at).inDays;
  if (l.status == 'stale' || days >= 21) return FreshnessInfo(Freshness.stale, at, l.availabilityConfirmedBy);
  if (l.needsRefresh || days >= 7) return FreshnessInfo(Freshness.needsRefresh, at, l.availabilityConfirmedBy);
  return FreshnessInfo(Freshness.confirmed, at, l.availabilityConfirmedBy);
}

/// "today", "yesterday", "2 days ago", "3 weeks ago".
String relativeDays(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (d <= 0) return 'today';
  if (d == 1) return 'yesterday';
  if (d < 14) return '$d days ago';
  if (d < 60) return '${(d / 7).floor()} weeks ago';
  return '${(d / 30).floor()} months ago';
}
