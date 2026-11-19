import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';
import '../../providers/city_provider.dart';

/// Map search. Pins show annual rent and sit at each listing's APPROXIMATE
/// location; exact addresses are not shown on the map.
/// The website only shows the map when the Google Maps script (with a web API
/// key) is added to web/index.html and the build uses --dart-define=MAPS_WEB=true.
const bool kMapsOnWeb = bool.fromEnvironment('MAPS_WEB', defaultValue: false);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapState();
}

class _MapState extends ConsumerState<MapScreen> {
  static const _center = LatLng(AppConstants.abujaLat, AppConstants.abujaLng);
  static const _style = '[{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},{"featureType":"transit","stylers":[{"visibility":"off"}]},{"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#e8efe9"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c8ddd4"}]}]';

  GoogleMapController? _ctrl;
  final Map<String, BitmapDescriptor> _pins = {};
  String? _selected;

  Future<BitmapDescriptor> _pin(String text, bool selected) async {
    final key = '$text|$selected';
    final cached = _pins[key];
    if (cached != null) return cached;
    const ratio = 3.0;
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: selected ? Colors.white : AppColors.primary, fontSize: 13 * ratio, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 20 * ratio, h = tp.height + 12 * ratio;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(h / 2));
    c.drawRRect(r, Paint()..color = selected ? AppColors.primary : Colors.white);
    c.drawRRect(r, Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = 2 * ratio);
    tp.paint(c, Offset(10 * ratio, 6 * ratio));
    final img = await rec.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final d = BitmapDescriptor.fromBytes(Uint8List.fromList(bytes));
    _pins[key] = d;
    return d;
  }

  Future<Set<Marker>> _markers(List<ListingModel> list) async {
    final out = <Marker>{};
    for (final l in list.take(80)) {
      if (l.location.latitude == 0 && l.location.longitude == 0) continue;
      out.add(Marker(
        markerId: MarkerId(l.id),
        position: LatLng(l.location.latitude, l.location.longitude),
        icon: await _pin(Money.short(l.price.round()), _selected == l.id),
        onTap: () => setState(() => _selected = l.id),
      ));
    }
    return out;
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        if (mounted) showPsSnack(context, 'Location is off. You can still search by area.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14));
    } catch (_) {
      if (mounted) showPsSnack(context, 'Could not get your location.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && !kMapsOnWeb) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: PsTopBar(title: 'Map', onBack: () => context.canPop() ? context.pop() : context.go('/home')),
        body: PsEmpty(
          icon: Icons.map_outlined,
          title: 'The map is on the app',
          message: 'On the website you can browse homes in a list. Use the Propsure app to see them on a map.',
          actionLabel: 'See homes in a list',
          onAction: () => context.pushReplacement('/search'),
        ),
      );
    }
    final filter = ref.watch(listingFilterProvider);
    final async = ref.watch(filteredListingsProvider(filter));
    final list = async.asData?.value ?? const <ListingModel>[];
    ListingModel? sel;
    for (final l in list) { if (l.id == _selected) sel = l; }
    final saved = ref.watch(savedIdsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(children: [
        FutureBuilder<Set<Marker>>(
          future: _markers(list),
          builder: (_, snap) => GoogleMap(
            initialCameraPosition: const CameraPosition(target: _center, zoom: 12),
            style: _style,
            markers: snap.data ?? const {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) => _ctrl = c,
            onTap: (_) => setState(() => _selected = null),
          ),
        ),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(children: [
          Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => context.pushReplacement('/search'),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
                const Icon(Icons.search_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(filter.area != null ? '${filter.area}, ${ref.watch(selectedCityProvider)}' : 'Search ${ref.watch(selectedCityProvider)}', style: AppText.title)),
                IconButton(tooltip: 'Filters', onPressed: () => context.push('/search/filters'), icon: const Icon(Icons.tune_rounded, color: AppColors.primary)),
              ])),
            ),
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _Pill(filter.category == null ? 'All homes' : ListingCategoryLabel.of(filter.category!), filter.category != null, () => context.push('/search/filters')),
            const SizedBox(width: 8),
            _Pill(filter.minBedrooms == null ? 'Beds' : '${filter.minBedrooms}+ beds', false, () => context.push('/search/filters')),
            const SizedBox(width: 8),
            _Pill(filter.maxMoveIn != null ? 'Up to ${Money.short(filter.maxMoveIn!.round())}' : 'Budget', false, () => context.push('/search/filters')),
          ]))),
        ]))),
        Positioned(
          right: 16,
          bottom: sel == null ? 120 : 290,
          child: FloatingActionButton.small(heroTag: 'locate', backgroundColor: Colors.white, foregroundColor: AppColors.primary, onPressed: _locate, child: const Icon(Icons.my_location_rounded)),
        ),
        if (sel == null)
          Positioned(left: 16, bottom: 120, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.circle, size: 8, color: AppColors.primary), const SizedBox(width: 6), Text('Annual rent', style: AppText.caption.copyWith(color: AppColors.text))]))),
        if (sel != null)
          Positioned(left: 0, right: 0, bottom: 0, child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16)]),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border2, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: SizedBox(width: 120, height: 130, child: PsNetImage(sel.coverUrl))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(sel.title, style: AppText.h3, maxLines: 2, overflow: TextOverflow.ellipsis)), IconButton(tooltip: saved.contains(sel.id) ? 'Remove from saved' : 'Save', onPressed: () => toggleSaved(context, ref, sel!.id), icon: Icon(saved.contains(sel.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: AppColors.primary))]),
                  Text('${sel.location.area}, Abuja', style: AppText.small),
                  const SizedBox(height: 4),
                  Text(sel.priceLabel, style: AppText.h2.copyWith(color: AppColors.primary)),
                  Text(MoveInBreakdown.of(sel).cardLabel, style: AppText.small),
                  Row(children: [const Icon(Icons.my_location_outlined, size: 14, color: AppColors.text2), const SizedBox(width: 4), Text('Approximate location', style: AppText.caption)]),
                ])),
              ]),
              const SizedBox(height: 10),
              PsButton('View home', kind: PsButtonKind.outline, onPressed: () => context.push('/listing/${sel!.id}')),
            ])),
          )),
      ]),
    );
  }
}

class ListingCategoryLabel {
  static String of(String raw) {
    switch (raw) {
      case 'for_sale': return 'Sale';
      case 'short_stay': return 'Short stay';
      case 'commercial': return 'Commercial';
      default: return 'Rent';
    }
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Pill(this.label, this.filled, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
        color: filled ? AppColors.primary : Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11), child: Row(children: [Text(label, style: AppText.title.copyWith(color: filled ? Colors.white : AppColors.text)), const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: filled ? Colors.white : AppColors.text)]))),
      );
}
