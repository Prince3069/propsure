import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/rooms.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';
import '../area/area_screen.dart' show AreaPreviewCard;
import 'tour_chapters_widgets.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override
  ConsumerState<ListingDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<ListingDetailScreen> {
  int _mode = 0; // 0 video, 1 photos
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(listingByIdProvider(widget.listingId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(appBar: const PsTopBar(backLabel: 'Back'), body: PsError(onRetry: () => ref.invalidate(listingByIdProvider(widget.listingId)))),
      data: (l) {
        final uid = ref.watch(currentUserIdProvider);
        if (l == null || (!l.isLive && l.agentId != uid)) {
          return Scaffold(backgroundColor: AppColors.surface, appBar: const PsTopBar(backLabel: 'Back'), body: const PsEmpty(icon: Icons.home_outlined, title: 'This home is not available', message: 'It may have been rented or removed.'));
        }
        final saved = ref.watch(savedIdsProvider).contains(l.id);
        final profile = ref.watch(publicProfileProvider(l.agentId)).asData?.value;
        final cost = MoveInBreakdown.of(l);
        final fresh = freshnessOf(l);
        final showVideo = l.hasVideo && _mode == 0;
        final photos = l.images;
        final chapters = chaptersOf(l);
        final coverage = coverageOf(l);

        Widget circle(IconData icon, String label, VoidCallback onTap) => Semantics(button: true, label: label, child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: AppColors.text))));

        Widget check(IconData icon, Color color, String t, {String? trailing}) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Text(t, style: AppText.body)),
              if (trailing != null) Text(trailing, style: AppText.small),
            ]));

        final idOk = profile?.identityReviewed ?? false;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Column(children: [
            Expanded(child: ListView(padding: EdgeInsets.zero, children: [
              SizedBox(height: 330, child: Stack(fit: StackFit.expand, children: [
                if (showVideo)
                  PsNetImage(l.posterUrl ?? l.coverUrl)
                else if (photos.isEmpty)
                  PsNetImage(l.coverUrl)
                else
                  PageView.builder(controller: _pc, itemCount: photos.length, onPageChanged: (i) => setState(() => _page = i), itemBuilder: (_, i) => PsNetImage(photos[i])),
                if (showVideo)
                  Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Semantics(button: true, label: 'Play tour', child: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TourPlayerPage(listing: l))), customBorder: const CircleBorder(), child: Container(width: 76, height: 76, decoration: const BoxDecoration(color: Color(0xAA1A1A2E), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48)))),
                    const SizedBox(height: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xAA1A1A2E), borderRadius: BorderRadius.circular(20)), child: Text(l.videoDurationSec != null ? 'Watch ${_mmss(l.videoDurationSec!)} tour' : 'Watch tour', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                  ])),
                SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: Align(alignment: Alignment.topCenter, child: Row(children: [
                  circle(Icons.arrow_back_ios_new_rounded, 'Back', () => context.canPop() ? context.pop() : context.go('/home')),
                  const Spacer(),
                  circle(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, saved ? 'Remove from saved' : 'Save', () => toggleSaved(context, ref, l.id)),
                  const SizedBox(width: 10),
                  circle(Icons.share_outlined, 'Copy link', () async { await Clipboard.setData(ClipboardData(text: 'https://propsure.africa/l/${l.id}')); if (context.mounted) showPsSnack(context, 'Link copied'); }),
                ])))),
                if (l.hasVideo) Positioned(left: 0, right: 0, bottom: 28, child: Center(child: SizedBox(width: 230, child: PsSegmented(labels: ['Video', '${photos.length} photos'], index: _mode, onChanged: (i) => setState(() => _mode = i))))),
                if (!showVideo && photos.length > 1) Positioned(right: 14, bottom: 30, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xAA1A1A2E), borderRadius: BorderRadius.circular(12)), child: Text('${_page + 1}/${photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12)))),
              ])),
              Transform.translate(offset: const Offset(0, -20), child: Container(
                decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (l.isSponsored) const Padding(padding: EdgeInsets.only(bottom: 8), child: PsPill('Sponsored', tone: PsTone.warning, small: true)),
                  Text(l.title, style: AppText.h1.copyWith(fontSize: 30)),
                  const SizedBox(height: 6),
                  Row(children: [const Icon(Icons.location_on_rounded, color: AppColors.text2, size: 20), const SizedBox(width: 6), Expanded(child: Text(l.location.isApproximate ? '${[l.location.area, l.location.city].where((e) => e.isNotEmpty).join(', ')} · approximate location' : l.location.fullAddress, style: AppText.body))]),
                  if (l.hasVideo && chapters.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ChapterChips(chapters: chapters, onTap: (c) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TourPlayerPage(listing: l, startMs: c.startMs)))),
                  ],
                  const Divider(height: 28),
                  Text(l.priceLabel, style: AppText.h1.copyWith(fontSize: 36, color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Flexible(child: Text(cost.cardLabel, style: AppText.title)),
                    if (l.categoryEnum.hasMoveInCost) ...[Container(width: 1, height: 28, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 14)), PsLink('See breakdown', chevron: true, underline: false, onTap: () => context.push('/listing/${l.id}/costs'))],
                  ]),
                  const SizedBox(height: 16),
                  PsCard(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _Fact(Icons.bed_outlined, '${l.bedrooms} ${l.bedrooms == 1 ? 'bed' : 'beds'}'),
                    _Fact(Icons.shower_outlined, '${l.bathrooms} ${l.bathrooms == 1 ? 'bath' : 'baths'}'),
                    for (final a in l.amenities.where((a) => a == 'Borehole / Water' || a == 'Prepaid Meter').take(2)) _Fact(a == 'Prepaid Meter' ? Icons.credit_card_outlined : Icons.water_drop_outlined, a == 'Borehole / Water' ? 'Water' : 'Prepaid meter'),
                  ])),
                  if (l.hasVideo && coverage != null) ...[const SizedBox(height: 14), CoverageCard(coverage: coverage)],
                  const SizedBox(height: 14),
                  AreaPreviewCard(city: l.location.city.isNotEmpty ? l.location.city : l.location.state, area: l.location.area),
                  const SizedBox(height: 14),
                  PsCard(onTap: () => context.push('/check-account?listing=${l.id}'), semanticLabel: 'Before you pay, check the account name', child: Row(children: [
                    const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 30),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Before you pay', style: AppText.title), Text('Check the name on the account', style: AppText.small)])),
                    const Icon(Icons.chevron_right_rounded),
                  ])),
                  const SizedBox(height: 14),
                  PsCard(onTap: () => context.push('/listing/${l.id}/passport'), semanticLabel: 'What has been checked', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text('What has been checked', style: AppText.h2)), const Icon(Icons.chevron_right_rounded)]),
                    check(idOk ? Icons.check_circle_rounded : Icons.remove_circle_rounded, idOk ? AppColors.primary : AppColors.text3, idOk ? 'Agent ID checked' : 'Agent ID not checked'),
                    const Divider(height: 1),
                    check(fresh.at != null && !l.needsRefresh ? Icons.check_circle_rounded : Icons.remove_circle_rounded, fresh.at != null && !l.needsRefresh ? AppColors.primary : AppColors.gold, fresh.at != null ? (l.needsRefresh ? 'Availability needs a refresh' : 'Availability confirmed') : 'Availability not confirmed', trailing: fresh.at != null ? relativeDays(fresh.at!) : null),
                    const Divider(height: 1),
                    check(l.authority.isCurrent ? Icons.check_circle_rounded : Icons.remove_circle_rounded, l.authority.isCurrent ? AppColors.primary : AppColors.text3, l.authority.isCurrent ? 'Authority to market reviewed' : 'Authority to market not reviewed'),
                    const Divider(height: 1),
                    check(l.titleReview.isCurrent ? Icons.check_circle_rounded : Icons.remove_circle_rounded, l.titleReview.isCurrent ? AppColors.primary : AppColors.text3, l.titleReview.isCurrent ? 'Property title reviewed' : 'Property title not reviewed'),
                  ])),
                  const SizedBox(height: 14),
                  PsCard(onTap: () => context.push('/agent/${l.agentId}'), semanticLabel: 'View agent', child: Row(children: [
                    PsAvatar(url: profile?.photo ?? l.agentPhoto, name: profile?.name ?? l.agentName, size: 60),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile?.agencyName?.isNotEmpty == true ? profile!.agencyName! : l.agentName, style: AppText.h3), Text('Property agent', style: AppText.small)])),
                    PsLink('View agent', chevron: true, underline: false, onTap: () => context.push('/agent/${l.agentId}')),
                  ])),
                  if (l.description.isNotEmpty) ...[const SizedBox(height: 18), Text('About this home', style: AppText.h2), const SizedBox(height: 6), Text(l.description, style: AppText.body)],
                  if (l.amenities.isNotEmpty) ...[const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: [for (final a in l.amenities) PsPill(a, tone: PsTone.neutral, small: true)])],
                  const SizedBox(height: 18),
                  Center(child: PsLink('Report a concern', onTap: () => context.push('/listing/${l.id}/report'), underline: false)),
                ]),
              )),
            ])),
            if (l.agentId != uid) PsBottomBar(children: [
              Row(children: [
                Expanded(child: PsButton('Ask a question', kind: PsButtonKind.outline, onPressed: () => openChatAbout(context, ref, l))),
                const SizedBox(width: 12),
                Expanded(child: PsButton('Book inspection', onPressed: () => requestInspection(context, ref, l))),
              ]),
            ]),
          ]),
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Fact(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 30, color: AppColors.primary), const SizedBox(height: 6), Text(label, style: AppText.small.copyWith(color: AppColors.text))]);
}

/// Full-screen tour. Never autoplays: the viewer taps play. Low-data mode
/// uses the smaller rendition when one exists.
class TourPlayerPage extends StatefulWidget {
  final ListingModel listing;
  /// Where to start, in milliseconds (a tapped room chapter). 0 = the beginning.
  final int startMs;
  const TourPlayerPage({super.key, required this.listing, this.startMs = 0});
  @override
  State<TourPlayerPage> createState() => _TourPlayerState();
}

class _TourPlayerState extends State<TourPlayerPage> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final low = Hive.box('settings_box').get('lowData', defaultValue: true) as bool;
    final url = (low && widget.listing.videoLowUrl != null) ? widget.listing.videoLowUrl! : widget.listing.videoUrl!;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _c = c;
    c.initialize().then((_) async {
      if (widget.startMs > 0) {
        await c.seekTo(Duration(milliseconds: widget.startMs));
        await c.play();
      }
      if (mounted) setState(() {});
    }).catchError((_) { if (mounted) setState(() => _failed = true); });
    c.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final chapters = chaptersOf(widget.listing);
    int? active;
    if (ready) {
      final pos = c.value.position.inMilliseconds;
      for (var i = 0; i < chapters.length; i++) {
        if (chapters[i].startMs <= pos) active = i;
      }
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Stack(children: [
        Center(child: _failed
            ? const Padding(padding: EdgeInsets.all(24), child: Text('This video could not be played. Check your connection.', style: TextStyle(color: Colors.white), textAlign: TextAlign.center))
            : ready
                ? AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))
                : const CircularProgressIndicator()),
        Positioned(left: 8, top: 8, child: IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white))),
        if (ready) Positioned(left: 16, right: 16, bottom: 16, child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (chapters.isNotEmpty) ...[
            ChapterChips(
              chapters: chapters,
              activeIndex: active,
              dark: true,
              onTap: (ch) async {
                await c.seekTo(Duration(milliseconds: ch.startMs));
                await c.play();
              },
            ),
            const SizedBox(height: 10),
          ],
          VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.white)),
          const SizedBox(height: 8),
          IconButton(iconSize: 48, tooltip: c.value.isPlaying ? 'Pause' : 'Play', onPressed: () => c.value.isPlaying ? c.pause() : c.play(), icon: Icon(c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white)),
        ])),
      ])),
    );
  }
}
