import 'package:flutter/material.dart' hide DayPeriod;
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/city.dart';
import '../../../core/utils/greeting.dart';
import '../../../core/widgets/ps_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/city_provider.dart';

/// Header colours for each part of the day.
class _Sky {
  final List<Color> gradient;
  final Color glow;
  final IconData icon;
  const _Sky(this.gradient, this.glow, this.icon);
}

_Sky _skyFor(DayPeriod p) {
  switch (p) {
    case DayPeriod.morning:
      return const _Sky([Color(0xFF14614A), Color(0xFF0F4C3A)],
          Color(0x66F5C95A), Icons.wb_sunny_outlined);
    case DayPeriod.afternoon:
      return const _Sky([Color(0xFF0F4C3A), Color(0xFF0C4232)],
          Color(0x55E8A93B), Icons.wb_cloudy_outlined);
    case DayPeriod.evening:
      return const _Sky([Color(0xFF0B3A2C), Color(0xFF0A2F25)],
          Color(0x44BFD8CC), Icons.nightlight_round);
  }

  // Defensive fallback for enum values added in a future SDK/version.
  return const _Sky([Color(0xFF0F4C3A), Color(0xFF0C4232)], Color(0x55E8A93B),
      Icons.wb_cloudy_outlined);
}

/// Green header: logo, city, bell, greeting, name, tagline and the
/// tour-of-the-day card (or a time-of-day illustration when there is none).
class HomeHeader extends StatelessWidget {
  final DayPeriod period;
  final String? firstName;
  final String city;
  final VoidCallback onCity;
  final VoidCallback onBell;
  final bool unread;
  final ListingModel? tour;
  final VoidCallback? onTour;
  final double
      bottomPad; // space under the text for the overlapping search card
  const HomeHeader({
    super.key,
    required this.period,
    required this.firstName,
    required this.city,
    required this.onCity,
    required this.onBell,
    required this.unread,
    this.tour,
    this.onTour,
    this.bottomPad = 64,
  });

  @override
  Widget build(BuildContext context) {
    final sky = _skyFor(period);
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: sky.gradient),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(34)),
              gradient: RadialGradient(
                  center: const Alignment(-0.6, -1.1),
                  radius: 0.9,
                  colors: [sky.glow, sky.glow.withValues(alpha: 0)]),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, top + 14, 22, bottomPad),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const _LogoOnDark(),
              const Spacer(),
              _CityChip(city: city, onTap: onCity),
              const SizedBox(width: 8),
              _Bell(onTap: onBell, dot: unread),
            ]),
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 168),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                                color: Color(0x22FFFFFF),
                                shape: BoxShape.circle),
                            child: Icon(sky.icon,
                                size: 18, color: const Color(0xFFF7D77C)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(greetingFor(period),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body.copyWith(
                                      color: const Color(0xCCFFFFFF),
                                      fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: firstName ?? 'Welcome'),
                                const TextSpan(
                                    text: '.',
                                    style: TextStyle(color: Color(0xFFF7D77C))),
                              ]),
                              style: AppText.display
                                  .copyWith(color: Colors.white, fontSize: 38)),
                        ),
                        const SizedBox(height: 8),
                        Text('Let’s find a home you can actually see.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(
                                color: const Color(0xC4FFFFFF),
                                fontSize: 16,
                                height: 1.35)),
                      ]),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 128,
                  height: 168,
                  child: tour != null
                      ? TourOfDayCard(listing: tour!, onTap: onTour)
                      : DayScene(period: period),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _LogoOnDark extends StatelessWidget {
  const _LogoOnDark();
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.home_work_outlined, color: Colors.white, size: 28),
      const SizedBox(width: 8),
      Text('Propsure',
          style: AppText.h2.copyWith(color: Colors.white, fontSize: 24)),
    ]);
  }
}

class _CityChip extends StatelessWidget {
  final String city;
  final VoidCallback onTap;
  const _CityChip({required this.city, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'City: $city. Change city',
      excludeSemantics: true,
      child: Material(
        color: const Color(0x1FFFFFFF),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 6),
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w600))),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  final VoidCallback onTap;
  final bool dot;
  const _Bell({required this.onTap, required this.dot});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notifications',
      excludeSemantics: true,
      child: Material(
        color: const Color(0x1FFFFFFF),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.notifications_none_rounded,
                  color: Colors.white, size: 22),
              if (dot)
                Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF0F4C3A), width: 1.5)))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A real still from an agent's own video. Never generated.
class TourOfDayCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  const TourOfDayCard({super.key, required this.listing, this.onTap});

  static String _dur(int? s) {
    if (s == null || s <= 0) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dur = _dur(listing.videoDurationSec);
    final area = listing.location.area.isNotEmpty
        ? listing.location.area
        : listing.location.city;
    return Semantics(
      button: true,
      label:
          'Tour of the day: ${listing.title}, $area, ${listing.priceLabel}. Open',
      excludeSemantics: true,
      child: Transform.rotate(
        angle: 0.07,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 12))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(fit: StackFit.expand, children: [
              PsNetImage(listing.posterUrl ?? listing.coverUrl),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment(0, -0.2),
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xBB000000)]))),
              if (dur.isNotEmpty)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xAA1A1A2E),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_circle_outline_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(dur,
                          style: AppText.small.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              Positioned(
                left: 9,
                right: 6,
                bottom: 8,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tour of the day',
                          style: AppText.small.copyWith(
                              color: const Color(0xD9FFFFFF), fontSize: 10.5)),
                      Text('$area · ${listing.priceLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
              Positioned.fill(
                  child: Material(
                      color: Colors.transparent, child: InkWell(onTap: onTap))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Fallback when a city has no video tour yet: a quiet scene for the time of day.
class DayScene extends StatelessWidget {
  final DayPeriod period;
  const DayScene({super.key, required this.period});
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
        child: CustomPaint(
            painter: _ScenePainter(period), size: const Size(128, 168)));
  }
}

class _ScenePainter extends CustomPainter {
  final DayPeriod p;
  _ScenePainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w * 0.62, h * 0.30);
    void halo(Color col, double r, double a) =>
        canvas.drawCircle(c, r, Paint()..color = col.withValues(alpha: a));
    switch (p) {
      case DayPeriod.morning:
        halo(const Color(0xFFF7D77C), 52, 0.10);
        halo(const Color(0xFFF7D77C), 40, 0.18);
        canvas.drawCircle(c, 26, Paint()..color = const Color(0xFFF7D77C));
        break;
      case DayPeriod.afternoon:
        halo(const Color(0xFFF5B94A), 44, 0.16);
        canvas.drawCircle(c, 24, Paint()..color = const Color(0xFFF5B94A));
        final cloud = Paint()..color = const Color(0xE6FFFFFF);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(w * 0.42, h * 0.46), width: 62, height: 26),
            cloud);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(w * 0.62, h * 0.42), width: 46, height: 28),
            cloud);
        break;
      case DayPeriod.evening:
        halo(const Color(0xFFF4EBC8), 50, 0.10);
        canvas.drawCircle(c, 24, Paint()..color = const Color(0xFFF4EBC8));
        canvas.drawCircle(
            c.translate(9, -7), 22, Paint()..color = const Color(0xFF0A2F25));
        final star = Paint()..color = Colors.white.withValues(alpha: 0.85);
        for (final o in [
          const Offset(0.18, 0.18),
          const Offset(0.38, 0.40),
          const Offset(0.1, 0.5),
          const Offset(0.9, 0.62)
        ]) {
          canvas.drawCircle(Offset(w * o.dx, h * o.dy), 1.6, star);
        }
        break;
    }
    final hill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.84)
      ..lineTo(w * 0.28, h * 0.70)
      ..lineTo(w * 0.52, h * 0.80)
      ..lineTo(w * 0.76, h * 0.64)
      ..lineTo(w, h * 0.84)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
        hill,
        Paint()
          ..color = const Color(0xFF0A3B2C)
              .withValues(alpha: p == DayPeriod.evening ? 1 : 0.9));
    // A small house on the hill: the product, quietly.
    final house = Paint()
      ..color = const Color(0xFFF7D77C).withValues(alpha: 0.9);
    final hx = w * 0.18, hy = h * 0.78;
    canvas.drawPath(
        Path()
          ..moveTo(hx, hy)
          ..lineTo(hx + 12, hy - 11)
          ..lineTo(hx + 24, hy)
          ..close(),
        house);
    canvas.drawRect(Rect.fromLTWH(hx + 3, hy, 18, 12), house);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.p != p;
}

/// Search card that overlaps the header: search field + type switch.
class HomeSearchCard extends StatelessWidget {
  final List<({String label, bool selected, VoidCallback onTap})> types;
  final VoidCallback onSearch;
  const HomeSearchCard(
      {super.key, required this.types, required this.onSearch});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x330F4C3A), blurRadius: 30, offset: Offset(0, 10))
        ],
      ),
      child: Column(children: [
        Semantics(
          button: true,
          label: 'Search by area, budget or property type',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onSearch,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(children: [
                const Icon(Icons.search_rounded,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Area, budget or property type',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body
                            .copyWith(color: AppColors.text3, fontSize: 16))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 4),
        PsSegmented(
          labels: [for (final t in types) t.label],
          index: types.indexWhere((t) => t.selected).clamp(0, types.length - 1),
          onChanged: (i) => types[i].onTap(),
        ),
      ]),
    );
  }
}

/// Bottom sheet to choose a city. Open cities first; the rest are "coming soon".
Future<void> showCityPicker(BuildContext context,
    {required String current,
    required List<CityOption> options,
    required ValueChanged<String> onPick,
    required ValueChanged<String> onNotify}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (ctx) {
      final open = options.where((o) => o.open).toList();
      final soon = options.where((o) => !o.open).toList();
      return SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                Center(
                    child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 16),
                Text('Where are you looking?', style: AppText.h2),
                const SizedBox(height: 4),
                Text('A city opens as soon as it has a live home.',
                    style: AppText.bodyMuted),
                const SizedBox(height: 14),
                for (final o in open)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 56,
                    leading: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                    title: Text(o.name, style: AppText.title),
                    subtitle: o.homes > 0
                        ? Text(
                            '${o.homes} ${o.homes == 1 ? 'home' : 'homes'} listed',
                            style: AppText.small)
                        : null,
                    trailing: o.name == current
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onPick(o.name);
                    },
                  ),
                if (soon.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Coming soon',
                      style:
                          AppText.small.copyWith(fontWeight: FontWeight.w700)),
                  for (final o in soon)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 56,
                      leading: const Icon(Icons.schedule_rounded,
                          color: AppColors.text3),
                      title: Text(o.name,
                          style:
                              AppText.title.copyWith(color: AppColors.text2)),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onNotify(o.name);
                        },
                        child: const Text('Notify me'),
                      ),
                    ),
                ],
              ]),
        ),
      );
    },
  );
}

/// Used by the Home header to open a tour.
void openListing(BuildContext context, ListingModel l) =>
    context.push('/listing/${l.id}');

/// Cities a listing can be filtered by, re-exported for screens that need it.
String cityOfListing(ListingModel l) => listingCity(l);
