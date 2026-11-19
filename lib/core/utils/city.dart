import '../../data/models/listing_model.dart';

/// Names that mean the same place in listing data.
const Map<String, String> _cityAliases = {
  'fct': 'Abuja',
  'f.c.t': 'Abuja',
  'federal capital territory': 'Abuja',
  'abuja municipal': 'Abuja',
  'amac': 'Abuja',
  'lagos state': 'Lagos',
  'ph': 'Port Harcourt',
  'port-harcourt': 'Port Harcourt',
};

String canonicalCity(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final alias = _cityAliases[t.toLowerCase()];
  if (alias != null) return alias;
  // "Abuja, FCT" style values: take the first part.
  final first = t.split(',').first.trim();
  final alias2 = _cityAliases[first.toLowerCase()];
  if (alias2 != null) return alias2;
  return first.isEmpty ? '' : first[0].toUpperCase() + first.substring(1);
}

/// The city a listing belongs to, using its city then its state.
String listingCity(ListingModel l) {
  final c = canonicalCity(l.location.city);
  if (c.isNotEmpty) return c;
  return canonicalCity(l.location.state);
}

/// True when [l] is in [city]. A listing with no city and no state is never
/// hidden by a city filter (old data must not disappear).
bool listingInCity(ListingModel l, String city) {
  final lc = listingCity(l);
  if (lc.isEmpty) return true;
  return lc.toLowerCase() == canonicalCity(city).toLowerCase();
}

