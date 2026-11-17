import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';
import '../listings/listing_detail_screen.dart' show TourPlayerPage;

/// Swipe through real video tours. Nothing autoplays: tap play to watch.
/// Only listings whose video finished processing and was reviewed appear.
class ToursScreen extends ConsumerStatefulWidget {
  const ToursScreen({super.key});
  @override
  ConsumerState<ToursScreen> createState() => _ToursState();
}

class _ToursState extends ConsumerState<ToursScreen> {
  int _tab = 0; // 0 For you, 1 Near you
  Position? _pos;

  Future<void> _near() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        if (mounted) showPsSnack(context, 'Location is off, so we cannot sort by distance.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() { _pos = pos; _tab = 1; });
    } catch (_) {
      if (mounted) showPsSnack(context, 'Could not get your location.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homeFeedProvider);
    final saved = ref.watch(savedIdsProvider);
    var list = (async.asData?.value ?? const <ListingModel>[]).where((l) => l.hasVideo && l.isLive).toList();
    if (_tab == 1 && _pos != null) {
      double d(ListingModel l) => Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude, l.location.latitude, l.location.longitude);
      list.sort((a, b) => d(a).compareTo(d(b)));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (async.isLoading && list.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (list.isEmpty)
          const SafeArea(child: PsEmpty(icon: Icons.videocam_off_outlined, title: 'No tours yet', message: 'Video tours appear here once agents add them. Browse homes in the meantime.'))
        else
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: list.length,
            itemBuilder: (_, i) {
              final l = list[i];
              final cost = MoveInBreakdown.of(l);
              return Stack(fit: StackFit.expand, children: [
                PsNetImage(l.posterUrl ?? l.coverUrl),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Colors.transparent, Color(0xCC000000)], stops: [0, .4, 1]))),
                Center(child: Semantics(button: true, label: 'Play tour of ${l.title}', child: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TourPlayerPage(listing: l))), customBorder: const CircleBorder(), child: Container(width: 76, height: 76, decoration: const BoxDecoration(color: Color(0xAA1A1A2E), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48))))),
                Positioned(right: 14, bottom: 190, child: Column(children: [
                  _Side(saved.contains(l.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, 'Save', () => toggleSaved(context, ref, l.id)),
                  const SizedBox(height: 18),
                  _Side(Icons.compare_arrows_rounded, 'Compare', () {
                    final ok = ref.read(compareListProvider.notifier).toggle(l.id);
                    showPsSnack(context, ok ? 'Updated your comparison.' : 'You can compare up to 3 homes.');
                  }),
                  const SizedBox(height: 18),
                  _Side(Icons.ios_share_rounded, 'Share', () async { await Clipboard.setData(ClipboardData(text: 'https://propsure.africa/l/${l.id}')); if (context.mounted) showPsSnack(context, 'Link copied'); }),
                ])),
                Positioned(left: 20, right: 90, bottom: 96, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (l.isSponsored) const Padding(padding: EdgeInsets.only(bottom: 6), child: PsPill('Sponsored', tone: PsTone.warning, small: true)),
                  Text(l.title, style: AppText.h1.copyWith(color: Colors.white, fontSize: 28)),
                  Row(children: [const Icon(Icons.location_on_rounded, color: Colors.white70, size: 18), const SizedBox(width: 4), Text('${l.location.area}, Abuja', style: AppText.body.copyWith(color: Colors.white70))]),
                  const SizedBox(height: 6),
                  Text(l.priceLabel, style: AppText.h1.copyWith(color: Colors.white, fontSize: 28)),
                  Text(cost.cardLabel, style: AppText.body.copyWith(color: Colors.white70)),
                  Text(freshnessOf(l).short, style: AppText.small.copyWith(color: Colors.white70)),
                ])),
                Positioned(left: 20, right: 20, bottom: 24, child: PsButton('View home & book inspection', trailingIcon: Icons.chevron_right_rounded, onPressed: () => context.push('/listing/${l.id}'))),
              ]);
            },
          ),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tours', style: AppText.h1.copyWith(color: Colors.white, fontSize: 28)),
          const SizedBox(height: 8),
          Row(children: [
            PsChip('For you', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
            const SizedBox(width: 8),
            PsChip('Near you', selected: _tab == 1, onTap: _near),
          ]),
        ]))),
      ]),
    );
  }
}

class _Side extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Side(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => Semantics(button: true, label: label, child: InkWell(onTap: onTap, child: Column(children: [Icon(icon, color: Colors.white, size: 30), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))])));
}
