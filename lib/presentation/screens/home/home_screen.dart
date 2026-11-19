import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/city.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/greeting.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';
import '../../providers/city_provider.dart';
import '../bulk_upload/whatsapp_bot_screen.dart' show openWhatsApp;
import 'home_widgets.dart';

/// Discover. One layout that adapts: phone and tablet get the green header
/// with the tour-of-the-day card; wide windows get a two-column hero.
/// Everything shown comes from real listings: no invented counts or claims.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ListingCategory _cat = ListingCategory.rent;
  bool _askedCity = false;

  static const _types = [ListingCategory.rent, ListingCategory.sale, ListingCategory.shortStay];

  // Budget shortcuts per type, in naira. Short stays have no move-in budget row.
  static const _budgets = <ListingCategory, List<double>>{
    ListingCategory.rent: [1500000, 3000000, 6000000],
    ListingCategory.sale: [30000000, 60000000, 120000000],
  };

  /// One tour per day: stable through the day, different tomorrow.
  ListingModel? _tourOfTheDay(List<ListingModel> items) {
    final tours = items.where((l) => l.videoStatus == VideoStatus.ready && (l.posterUrl ?? '').isNotEmpty).toList();
    if (tours.isEmpty) return null;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return tours[dayOfYear % tours.length];
  }

  void _openSearch({double? maxMoveIn}) {
    final city = ref.read(selectedCityProvider);
    var f = ListingFilter.empty.copyWith(category: _cat.value, city: city);
    if (maxMoveIn != null) f = f.copyWith(maxMoveIn: maxMoveIn);
    ref.read(listingFilterProvider.notifier).set(f);
    context.push('/search?category=${_cat.value}');
  }

  void _pickCity() {
    showCityPicker(
      context,
      current: ref.read(selectedCityProvider),
      options: ref.read(cityOptionsProvider),
      onPick: (c) => ref.read(selectedCityProvider.notifier).select(c),
      onNotify: (c) {
        final number = ref.read(whatsappAssistNumberProvider);
        openWhatsApp(context, number, 'Hello Propsure, please tell me when you open in $c.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);
    final saved = ref.watch(savedIdsProvider);
    final unread = (ref.watch(notificationsUnreadCountProvider).asData?.value ?? 0) > 0;
    final city = ref.watch(selectedCityProvider);
    final period = ref.watch(dayPeriodProvider).asData?.value ?? dayPeriodAt(DateTime.now());
    final firstName = firstNameOf(ref.watch(currentUserModelProvider).asData?.value?.name);

    // First time on this device and more than one city is open: ask once.
    ref.listen<List<CityOption>>(cityOptionsProvider, (_, opts) {
      if (_askedCity || !cityNeverChosen()) return;
      if (opts.where((o) => o.open).length > 1) {
        _askedCity = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pickCity();
        });
      }
    });

    final all = feed.asData?.value ?? const <ListingModel>[];
    final inCity = all.where((l) => listingInCity(l, city)).toList();
    final tour = _tourOfTheDay(inCity);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    final body = wide
        ? _wide(context, feed, inCity, saved, city, period, firstName, tour)
        : _phone(context, feed, inCity, saved, city, period, firstName, tour, unread);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(homeFeedProvider), child: body),
    );
  }

  // ── shared pieces ──────────────────────────────────────────────────────────

  Widget _typeSwitch() => HomeSearchCard(
        types: [for (final c in _types) (label: c.chipLabel, selected: _cat == c, onTap: () => setState(() => _cat = c))],
        onSearch: _openSearch,
      );

  Widget _budgetRow() {
    final opts = _budgets[_cat];
    if (opts == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_cat.hasMoveInCost ? 'Total move-in budget' : 'Budget', style: AppText.title)),
          if (_cat.hasMoveInCost) Text('Rent + agency + caution', style: AppText.small),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final v in opts) ...[
              PsChip('Up to ${Money.short(v)}', onTap: () => _openSearch(maxMoveIn: v)),
              const SizedBox(width: 10),
            ],
            PsChip('Any budget', onTap: _openSearch),
          ]),
        ),
      ]),
    );
  }

  Widget _quickTiles() {
    Widget tile(IconData i, String label, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Column(children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                  alignment: Alignment.center,
                  child: Icon(i, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(fontWeight: FontWeight.w700, color: AppColors.text)),
              ]),
            ),
          ),
        );
    void go(ListingCategory c) {
      setState(() => _cat = c);
      _openSearch();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(children: [
        tile(Icons.home_outlined, 'Rent', () => go(ListingCategory.rent)),
        const SizedBox(width: 12),
        tile(Icons.apartment_rounded, 'Buy', () => go(ListingCategory.sale)),
        const SizedBox(width: 12),
        tile(Icons.hotel_outlined, 'Short stay', () => go(ListingCategory.shortStay)),
        const SizedBox(width: 12),
        tile(Icons.play_circle_outline_rounded, 'Video tours', () => context.go('/tours')),
      ]),
    );
  }

  Widget _reels(List<ListingModel> inCity, {double height = 216, double width = 142}) {
    final tours = inCity.where((l) => l.videoStatus == VideoStatus.ready && (l.posterUrl ?? '').isNotEmpty).take(10).toList();
    if (tours.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PsSectionTitle('Video tours', action: 'See all', onAction: () => context.go('/tours')),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _Reel(listing: tours[i], width: width, onTap: () => context.push('/listing/${tours[i].id}')),
          ),
        ),
      ]),
    );
  }

  Widget _fresh(AsyncValue<List<ListingModel>> feed, List<ListingModel> inCity, Set<String> saved, String city, {required int columns}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PsSectionTitle('Fresh in $city', action: 'See all', onAction: _openSearch),
        const SizedBox(height: 12),
        feed.when(
          loading: () => const Column(children: [PsListingSkeleton(), SizedBox(height: 16), PsListingSkeleton()]),
          error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(homeFeedProvider)),
          data: (_) {
            final items = inCity.where((l) => l.categoryEnum == _cat).take(columns == 1 ? 8 : columns * 2).toList();
            if (items.isEmpty) {
              return PsEmpty(
                icon: Icons.home_work_outlined,
                title: 'No homes in $city yet',
                message: 'Try another type or city, or save a search and we will tell you when a matching home appears.',
                actionLabel: 'Save a search',
                onAction: _openSearch,
              );
            }
            Widget card(ListingModel l) => ListingCard(
                  listing: l,
                  isSaved: saved.contains(l.id),
                  onSaveTap: () => toggleSaved(context, ref, l.id),
                  onTap: () => context.push('/listing/${l.id}'),
                );
            if (columns == 1) {
              return Column(children: [for (final l in items) Padding(padding: const EdgeInsets.only(bottom: 16), child: card(l))]);
            }
            return LayoutBuilder(builder: (context, c) {
              const gap = 24.0;
              final w = (c.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(spacing: gap, runSpacing: gap, children: [for (final l in items) SizedBox(width: w, child: card(l))]);
            });
          },
        ),
      ]),
    );
  }

  /// Only claims the app can already keep.
  Widget _trust() {
    Widget item(IconData i, String t) => Expanded(
          child: Column(children: [
            PsIconCircle(i, size: 44),
            const SizedBox(height: 8),
            Text(t, textAlign: TextAlign.center, style: AppText.small.copyWith(fontWeight: FontWeight.w700, color: AppColors.text, height: 1.25)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.primaryPale, borderRadius: BorderRadius.circular(20)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item(Icons.image_outlined, 'Stills taken from the video'),
        item(Icons.payments_outlined, 'Honest move-in costs'),
        item(Icons.account_balance_outlined, 'Check the account name'),
      ]),
    );
  }

  Widget _shortlistCard() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: PsCard(
          onTap: _startShortlist,
          semanticLabel: 'Hunting with someone? Start a shortlist',
          child: Row(children: [
            const Icon(Icons.group_outlined, size: 34, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hunting with someone?', style: AppText.title), Text('Start a shortlist', style: AppText.small)])),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      );

  // ── phone / tablet ─────────────────────────────────────────────────────────

  Widget _phone(BuildContext context, AsyncValue<List<ListingModel>> feed, List<ListingModel> inCity, Set<String> saved, String city, DayPart period, String? firstName, ListingModel? tour, bool unread) {
    return ListView(padding: EdgeInsets.zero, children: [
      ContentFrame(
        maxWidth: 640,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          HomeHeader(
            period: period,
            firstName: firstName,
            city: city,
            onCity: _pickCity,
            onBell: () => context.push('/notifications'),
            unread: unread,
            tour: tour,
            onTour: tour == null ? null : () => context.push('/listing/${tour.id}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Transform.translate(offset: const Offset(0, -34), child: _typeSwitch()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _budgetRow(),
              _quickTiles(),
              _reels(inCity),
              _fresh(feed, inCity, saved, city, columns: 1),
              _trust(),
              const SizedBox(height: 16),
              _shortlistCard(),
            ]),
          ),
        ]),
      ),
    ]);
  }

  // ── desktop ────────────────────────────────────────────────────────────────

  Widget _wide(BuildContext context, AsyncValue<List<ListingModel>> feed, List<ListingModel> inCity, Set<String> saved, String city, DayPart period, String? firstName, ListingModel? tour) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1180 ? 3 : 2;
    final move = (tour != null && tour.chargesComplete && tour.categoryEnum.hasMoveInCost) ? MoveInBreakdown.of(tour).subtotal : null;
    return ListView(padding: EdgeInsets.zero, children: [
      ContentFrame(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 40),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 11,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PsPill('${greetingFor(period)}${firstName != null ? ', $firstName' : ''} · $city', icon: Icons.wb_twilight_rounded, tone: PsTone.success),
                  const SizedBox(height: 20),
                  PsHeadline('Your next home.', accent: 'Fewer surprises.', size: 64),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text('Walk through real video tours, see the full cost to move in, and know what the video did not show.', style: AppText.body.copyWith(fontSize: 19, height: 1.45, color: AppColors.text2)),
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _typeSwitch()),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _budgetRow()),
                ]),
              ),
              const SizedBox(width: 40),
              Expanded(flex: 9, child: _WideTour(tour: tour, period: period, moveIn: move, onTap: tour == null ? null : () => context.push('/listing/${tour.id}'))),
            ]),
            _reels(inCity, height: 300, width: 190),
            _fresh(feed, inCity, saved, city, columns: cols),
            const SizedBox(height: 48),
            _AgentBand(onList: () => context.push('/listing/new'), onWhatsApp: () => context.push('/whatsapp-assist')),
            const SizedBox(height: 56),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _startShortlist() async {
    final user = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) {
      context.push('/auth?reason=save&redirect=${Uri.encodeComponent('/saved')}');
      return;
    }
    context.go('/saved');
  }
}

class _Reel extends StatelessWidget {
  final ListingModel listing;
  final double width;
  final VoidCallback onTap;
  const _Reel({required this.listing, required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final area = listing.location.area.isNotEmpty ? listing.location.area : listing.location.city;
    final s = listing.videoDurationSec;
    final dur = (s == null || s <= 0) ? '' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      label: 'Video tour, $area, ${listing.priceLabel}',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            PsNetImage(listing.posterUrl ?? listing.coverUrl),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment(0, 0.1), end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xBB000000)]))),
            if (dur.isNotEmpty)
              Positioned(
                left: 9,
                top: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xAA1A1A2E), borderRadius: BorderRadius.circular(9)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_circle_outline_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(dur, style: AppText.small.copyWith(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            Positioned(
              left: 10,
              right: 8,
              bottom: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(area, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: const Color(0xD9FFFFFF), fontSize: 12)),
                Text(listing.priceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
            ),
            Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: onTap))),
          ]),
        ),
      ),
    );
  }
}

/// Large hero card on wide screens: the tour of the day, or the time-of-day
/// scene when the city has no video tour yet.
class _WideTour extends StatelessWidget {
  final ListingModel? tour;
  final DayPart period;
  final double? moveIn;
  final VoidCallback? onTap;
  const _WideTour({required this.tour, required this.period, required this.moveIn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = tour;
    return AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x440F4C3A), blurRadius: 50, offset: Offset(0, 28))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: l == null
              ? Container(
                  color: AppColors.primaryDark,
                  child: Center(child: FittedBox(child: SizedBox(width: 300, height: 392, child: DayScene(period: period)))),
                )
              : Stack(fit: StackFit.expand, children: [
                  PsNetImage(l.posterUrl ?? l.coverUrl),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment(0, 0.2), end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC000000)]))),
                  Center(child: Container(width: 76, height: 76, decoration: const BoxDecoration(color: Color(0xCC1A1A2E), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 46))),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 20,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Tour of the day', style: AppText.small.copyWith(color: const Color(0xD9FFFFFF))),
                      Text('${l.location.area.isNotEmpty ? l.location.area : l.location.city} · ${l.priceLabel}', style: AppText.h2.copyWith(color: Colors.white)),
                      if (moveIn != null) Text('Total move-in ${Money.short(moveIn!)}', style: AppText.body.copyWith(color: Colors.white)),
                    ]),
                  ),
                  Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: onTap))),
                ]),
        ),
      ),
    );
  }
}

class _AgentBand extends StatelessWidget {
  final VoidCallback onList;
  final VoidCallback onWhatsApp;
  const _AgentBand({required this.onList, required this.onWhatsApp});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(32)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('For agents and landlords', style: AppText.small.copyWith(color: const Color(0xFFF7D77C), fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('Send one video.\nGet a listing that sells.', style: AppText.h1.copyWith(color: Colors.white, fontSize: 40, height: 1.08)),
            const SizedBox(height: 14),
            Text('We pull clear stills from your walkthrough. You review them, then publish. You stay in control.', style: AppText.body.copyWith(color: const Color(0xD9FFFFFF), fontSize: 17, height: 1.45)),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, children: [
              PsButton('List a home', onPressed: onList, kind: PsButtonKind.onDark, expand: false),
              OutlinedButton.icon(
                onPressed: onWhatsApp,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: const Text('Send on WhatsApp'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), minimumSize: const Size(48, 52), padding: const EdgeInsets.symmetric(horizontal: 22)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
