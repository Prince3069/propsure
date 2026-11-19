import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/greeting.dart';
import '../../core/utils/city.dart';
import '../../data/models/listing_model.dart';
import 'app_providers.dart';

/// Where Propsure is open. A city is "open" as soon as it has a live listing;
/// nothing needs to be switched on by hand. Cities in `comingSoon` are shown
/// in the picker so people can ask to be told when they open.
const String kDefaultCity = 'Abuja';
const List<String> kDefaultComingSoon = ['Lagos', 'Port Harcourt', 'Ibadan', 'Enugu', 'Kano'];

const _boxKey = 'selectedCity';

class SelectedCityNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = Hive.box('settings_box').get(_boxKey) as String?;
    return (saved == null || saved.trim().isEmpty) ? kDefaultCity : saved;
  }

  void select(String city) {
    final c = canonicalCity(city);
    if (c.isEmpty) return;
    Hive.box('settings_box').put(_boxKey, c);
    state = c;
  }
}

final selectedCityProvider = NotifierProvider<SelectedCityNotifier, String>(SelectedCityNotifier.new);

/// True when the user has never chosen a city on this device.
bool cityNeverChosen() => (Hive.box('settings_box').get(_boxKey) as String?) == null;

class CityOption {
  final String name;
  final int homes; // live listings seen
  final bool open; // has at least one live listing
  const CityOption(this.name, this.homes, this.open);
}

/// Open cities (from live listings) first, then coming-soon cities from
/// `public_config/app` field `comingSoonCities` (list of names).
final cityOptionsProvider = Provider<List<CityOption>>((ref) {
  final feed = ref.watch(homeFeedProvider).asData?.value ?? const <ListingModel>[];
  final counts = <String, int>{};
  for (final l in feed) {
    final c = listingCity(l);
    if (c.isEmpty) continue;
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final cfg = ref.watch(appConfigProvider).asData?.value['comingSoonCities'];
  final soon = (cfg is List ? cfg.map((e) => canonicalCity(e.toString())).where((e) => e.isNotEmpty).toList() : kDefaultComingSoon);
  final open = counts.entries.map((e) => CityOption(e.key, e.value, true)).toList()
    ..sort((a, b) => b.homes.compareTo(a.homes));
  // Abuja is where we start: always offered, even before its first listing loads.
  if (!open.any((o) => o.name == kDefaultCity)) open.insert(0, const CityOption(kDefaultCity, 0, true));
  final openNames = open.map((o) => o.name).toSet();
  return [
    ...open,
    for (final s in soon)
      if (!openNames.contains(s)) CityOption(s, 0, false),
  ];
});

/// Re-emits the current time of day every minute, so the greeting changes
/// while the app stays open.
final dayPeriodProvider = StreamProvider.autoDispose<DayPart>((ref) async* {
  var last = dayPeriodAt(DateTime.now());
  yield last;
  await for (final _ in Stream<void>.periodic(const Duration(minutes: 1))) {
    final now = dayPeriodAt(DateTime.now());
    if (now != last) {
      last = now;
      yield now;
    }
  }
});
