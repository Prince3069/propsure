import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/listing_category.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../../data/repositories/saved_search_repository.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';
import '../../providers/city_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final String? initialType;
  const SearchScreen({super.key, this.initialQuery, this.initialCategory, this.initialType});
  @override
  ConsumerState<SearchScreen> createState() => _SearchState();
}

class _SearchState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _q.text = widget.initialQuery ?? '';
    // Seed the shared filter once from route params; later edits stay in the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_seeded || !mounted) return;
      _seeded = true;
      final n = ref.read(listingFilterProvider.notifier);
      var f = ref.read(listingFilterProvider);
      if (widget.initialQuery != null) f = f.copyWith(query: widget.initialQuery);
      if (widget.initialCategory != null) f = f.copyWith(category: widget.initialCategory);
      if (widget.initialType != null) f = f.copyWith(propertyType: widget.initialType);
      n.set(f);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _setFilter(ListingFilter f) => ref.read(listingFilterProvider.notifier).set(f);

  Future<void> _saveSearch(ListingFilter f) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) { context.push('/auth?redirect=/search'); return; }
    final label = [
      if (f.category != null) ListingCategory.fromAny(f.category).chipLabel,
      if (f.minBedrooms != null) '${f.minBedrooms}+ bed',
      if (f.area != null) f.area!,
      if (f.maxMoveIn != null) 'move-in up to ${Money.short(f.maxMoveIn!.round())}',
      if (f.query != null && f.query!.isNotEmpty) '"${f.query}"',
    ].join(' · ');
    await runAction(context, () => ref.read(savedSearchRepositoryProvider).save(SavedSearchModel.fromFilter(userId: uid, label: label.isEmpty ? 'My search' : label, filter: f)), success: 'Search saved. We will alert you in the app when a new home matches.');
  }

  int _extraFilters(ListingFilter f) =>
      (f.area != null ? 1 : 0) +
      (f.propertyType != null ? 1 : 0) +
      (f.minBedrooms != null ? 1 : 0) +
      ((f.maxMoveIn != null || f.maxPrice != null) ? 1 : 0) +
      (f.mustHave.isNotEmpty ? 1 : 0) +
      (f.recentlyConfirmedOnly ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(listingFilterProvider);
    final city = f.city ?? ref.watch(selectedCityProvider);
    final async = ref.watch(filteredListingsProvider(f));
    final saved = ref.watch(savedIdsProvider);
    final extra = _extraFilters(f);
    final count = async.asData?.value.length;
    final heading = f.maxMoveIn != null
        ? 'Homes that fit your budget'
        : count == null
            ? 'Homes in $city'
            : '$count ${count == 1 ? 'home' : 'homes'} in $city';

    Widget chip(String label, VoidCallback onRemove) => Padding(padding: const EdgeInsets.only(right: 8), child: PsChip(label, selected: true, removable: true, onTap: onRemove));
    Widget typeChip(String label, ListingCategory? c) {
      final on = c == null ? f.category == null : (f.category != null && ListingCategory.fromAny(f.category) == c);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PsChip(label, selected: on, onTap: () => _setFilter(c == null ? f.copyWith(clearCategory: true) : f.copyWith(category: c.value))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 8, 16, 0), child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/home'), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)),
            Expanded(child: PsField(label: '', controller: _q, hint: 'Area or keyword', prefix: const Icon(Icons.search_rounded), textInputAction: TextInputAction.search, onChanged: (v) => _setFilter(v.trim().isEmpty ? f.copyWith(clearQuery: true) : f.copyWith(query: v.trim())))),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: extra > 0 ? 'Filters, $extra active' : 'Filters',
              child: InkWell(
                onTap: () => context.push('/search/filters'),
                borderRadius: BorderRadius.circular(14),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: extra > 0 ? AppColors.primary : AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: extra > 0 ? AppColors.primary : AppColors.border)), child: Icon(Icons.tune_rounded, color: extra > 0 ? Colors.white : AppColors.primary)),
                  if (extra > 0)
                    Positioned(right: -4, top: -4, child: Container(width: 20, height: 20, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)), child: Text('$extra', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)))),
                ]),
              ),
            ),
          ])),
          SizedBox(height: 58, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(24, 8, 24, 2), children: [
            typeChip('All homes', null),
            typeChip('Rent', ListingCategory.rent),
            typeChip('Sale', ListingCategory.sale),
            typeChip('Short stay', ListingCategory.shortStay),
            typeChip('Commercial', ListingCategory.commercial),
            if (extra > 0) const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(height: 48, child: VerticalDivider(width: 12, thickness: 1))),
            if (f.area != null) chip(f.area!, () => _setFilter(f.copyWith(clearArea: true))),
            if (f.minBedrooms != null) chip('${f.minBedrooms}+ beds', () => _setFilter(f.copyWith(clearBeds: true))),
            if (f.maxMoveIn != null) chip('Up to ${Money.short(f.maxMoveIn!.round())} move-in', () => _setFilter(f.copyWith(clearMoveIn: true))),
            if (f.maxPrice != null && f.maxMoveIn == null) chip('Rent up to ${Money.short(f.maxPrice!.round())}', () => _setFilter(f.copyWith(clearPrice: true))),
            if (f.mustHave.isNotEmpty) chip('${f.mustHave.length} must-have', () => _setFilter(f.copyWith(mustHave: const []))),
            if (f.recentlyConfirmedOnly) chip('Recently confirmed', () => _setFilter(f.copyWith(recentlyConfirmedOnly: false))),
            if (extra > 0 || f.category != null) PsChip('Clear all', onTap: () { _q.clear(); _setFilter(ListingFilter.empty); }),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(24, 6, 24, 10), child: Row(children: [
            Expanded(child: Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.h3)),
            const SizedBox(width: 12),
            SizedBox(width: 150, child: PsSegmented(labels: const ['List', 'Map'], index: 0, onChanged: (i) { if (i == 1) context.pushReplacement('/map'); })),
          ])),
          Expanded(child: async.when(
            loading: () => const PsListingSkeleton(),
            error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(filteredListingsProvider(f))),
            data: (list) {
              if (list.isEmpty) {
                final anyFilter = extra > 0 || f.category != null || (f.query ?? '').isNotEmpty;
                return PsEmpty(icon: Icons.search_off_rounded, title: 'No homes match yet', message: 'Try a wider budget or fewer must-haves, or save this search and we will tell you when one appears.', actionLabel: anyFilter ? 'Clear filters' : null, onAction: anyFilter ? () { _q.clear(); _setFilter(ListingFilter.empty); } : null);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) {
                  final l = list[i];
                  return ListingCard(listing: l, isSaved: saved.contains(l.id), onSaveTap: () => toggleSaved(context, ref, l.id), onTap: () => context.push('/listing/${l.id}'));
                },
              );
            },
          )),
        ]),
        Positioned(left: 0, right: 0, bottom: 16, child: Center(child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))]),
          child: PsButton('Save search & get alerts', icon: Icons.notifications_none_rounded, expand: false, onPressed: () => _saveSearch(f)),
        ))),
      ])),
    );
  }
}
