import '../../data/models/listing_model.dart';

/// Rooms an agent can name on a still taken from the video, and the tour
/// chapters / "what the video shows" list built from those names.
/// Nothing here is guessed: a room counts as shown only when the agent
/// labelled a real still from the video with it.
enum RoomKind { living, dining, kitchen, bedroom, bathroom, compound, other }

/// A still can be named "Kitchen" or "Kitchen · Gas cooker". The part before
/// the dot is the room; chapters and coverage only look at the room.
String baseRoomLabel(String label) {
  final i = label.indexOf('·');
  return (i < 0 ? label : label.substring(0, i)).trim();
}

/// Quick "what is this view" choices for a room, so one space can be shown in
/// several clear pieces (the cooker, then the sink).
List<String> detailChoices(RoomKind kind) {
  switch (kind) {
    case RoomKind.kitchen:
      return const ['Gas cooker', 'Oven', 'Sink', 'Cabinets', 'Counter', 'Pantry', 'Window'];
    case RoomKind.living:
      return const ['Wide view', 'Windows', 'Ceiling', 'Floor', 'TV area', 'Entrance'];
    case RoomKind.dining:
      return const ['Wide view', 'Windows', 'Ceiling', 'Floor'];
    case RoomKind.bedroom:
      return const ['Wide view', 'Wardrobe', 'Windows', 'Ceiling', 'En-suite'];
    case RoomKind.bathroom:
      return const ['Shower', 'Bathtub', 'Toilet', 'Sink', 'Tiles'];
    case RoomKind.compound:
      return const ['Front', 'Gate', 'Parking', 'Fence', 'Backyard'];
    case RoomKind.other:
      return const ['Wide view', 'Windows', 'Ceiling', 'Floor'];
  }
}

RoomKind roomKindOf(String label) {
  final t = label.toLowerCase();
  if (t.contains('living') || t.contains('parlour') || t.contains('parlor') || t.contains('lounge') || t.contains('sitting')) return RoomKind.living;
  if (t.contains('dining')) return RoomKind.dining;
  if (t.contains('kitchen')) return RoomKind.kitchen;
  if (t.contains('bed')) return RoomKind.bedroom;
  if (t.contains('bath') || t.contains('toilet') || t.contains('shower') || t.contains('wc')) return RoomKind.bathroom;
  if (t.contains('compound') || t.contains('outside') || t.contains('exterior') || t.contains('gate') || t.contains('parking') || t.contains('yard') || t.contains('front of')) return RoomKind.compound;
  return RoomKind.other;
}

/// Quick choices when naming a still. Bedrooms and bathrooms are numbered up to
/// the counts on the listing (max 6) so renters can tell them apart.
List<String> roomChoices({required int bedrooms, required int bathrooms}) {
  final beds = bedrooms.clamp(0, 6);
  final baths = bathrooms.clamp(0, 6);
  return [
    'Living room',
    'Dining area',
    'Kitchen',
    if (beds <= 1) ...[if (beds == 1) 'Bedroom'] else for (var i = 1; i <= beds; i++) 'Bedroom $i',
    if (baths <= 1) ...[if (baths == 1) 'Bathroom'] else for (var i = 1; i <= baths; i++) 'Bathroom $i',
    'Toilet',
    'Balcony',
    'Compound',
  ];
}

class TourChapter {
  final String label;
  final int startMs;
  final RoomKind kind;
  const TourChapter(this.label, this.startMs, this.kind);
}

/// Chapters from labelled stills that came from the video, in video order.
/// The same label is listed once, at its earliest moment. Each chapter starts
/// about a second and a half before its still so the room is in view.
List<TourChapter> chaptersOf(ListingModel l) {
  final seen = <String>{};
  final withTime = l.stills.where((s) => s.source == 'video' && s.timestampMs != null && (s.label ?? '').trim().isNotEmpty).toList()
    ..sort((a, b) => a.timestampMs!.compareTo(b.timestampMs!));
  final out = <TourChapter>[];
  for (final s in withTime) {
    final label = baseRoomLabel(s.label!);
    if (label.isEmpty || !seen.add(label.toLowerCase())) continue;
    final start = (s.timestampMs! - 1500) < 0 ? 0 : s.timestampMs! - 1500;
    out.add(TourChapter(label, start, roomKindOf(label)));
  }
  return out;
}

class CoverageItem {
  final String label;
  final bool shown;
  const CoverageItem(this.label, this.shown);
}

class VideoCoverage {
  final List<CoverageItem> items;
  const VideoCoverage(this.items);
  int get shownCount => items.where((i) => i.shown).length;
  int get total => items.length;
  List<CoverageItem> get missing => items.where((i) => !i.shown).toList();
}

bool _isResidentialType(String propertyType) {
  final t = propertyType.toLowerCase();
  return !(t.contains('office') || t.contains('shop') || t.contains('warehouse') || t.contains('land'));
}

/// What a home of this size would normally show, checked against [labels].
/// Returns null when there is nothing sensible to compare (commercial space,
/// or the agent has labelled no rooms at all, so we do not claim anything).
VideoCoverage? coverageFromLabels(List<String> labels, {required int bedrooms, required int bathrooms, required String propertyType, required bool commercial}) {
  if (commercial || !_isResidentialType(propertyType)) return null;
  final named = labels.map(baseRoomLabel).where((e) => e.isNotEmpty).toList();
  if (named.isEmpty) return null;
  int distinct(RoomKind k) => named.where((n) => roomKindOf(n) == k).map((n) => n.toLowerCase()).toSet().length;
  bool any(RoomKind k) => named.any((n) => roomKindOf(n) == k);
  final beds = bedrooms.clamp(0, 6);
  final baths = bathrooms.clamp(0, 6);
  final shownBeds = distinct(RoomKind.bedroom);
  final shownBaths = distinct(RoomKind.bathroom);
  return VideoCoverage([
    CoverageItem('Living room', any(RoomKind.living)),
    CoverageItem('Kitchen', any(RoomKind.kitchen)),
    for (var i = 0; i < beds; i++) CoverageItem(beds == 1 ? 'Bedroom' : 'Bedroom ${i + 1}', i < shownBeds),
    for (var i = 0; i < baths; i++) CoverageItem(baths == 1 ? 'Bathroom' : 'Bathroom ${i + 1}', i < shownBaths),
    CoverageItem('Compound', any(RoomKind.compound)),
  ]);
}

/// Coverage for a published listing, from the labels on its video stills.
VideoCoverage? coverageOf(ListingModel l) {
  final labels = [for (final s in l.stills) if (s.source == 'video') s.label ?? ''];
  return coverageFromLabels(
    labels,
    bedrooms: l.bedrooms,
    bathrooms: l.bathrooms,
    propertyType: l.propertyType,
    commercial: l.category == 'commercial',
  );
}
