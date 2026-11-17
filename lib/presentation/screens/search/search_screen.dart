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

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(listingFilterProvider);
    final async = ref.watch(filteredListingsProvider(f));
    final saved = ref.watch(savedIdsProvider);

    Widget chip(String label, VoidCallback onRemove) => Padding(padding: const EdgeInsets.only(right: 8), child: PsChip(label, selected: true, removable: true, onTap: onRemove));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 8, 16, 0), child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/home'), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)),
            Expanded(child: PsField(label: '', controller: _q, hint: 'Search area or keyword', prefix: const Icon(Icons.search_rounded), textInputAction: TextInputAction.search, onChanged: (v) => _setFilter(v.trim().isEmpty ? f.copyWith(clearQuery: true) : f.copyWith(query: v.trim())))),
            const SizedBox(width: 8),
            Semantics(button: true, label: 'Filters', child: InkWell(onTap: () => context.push('/search/filters'), borderRadius: BorderRadius.circular(14), child: Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: const Icon(Icons.tune_rounded, color: AppColors.primary)))),
          ])),
          SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(24, 10, 24, 6), children: [
            if (f.category != null) chip(ListingCategory.fromAny(f.category).chipLabel, () => _setFilter(f.copyWith(clearCategory: true))),
            if (f.area != null) chip(f.area!, () => _setFilter(f.copyWith(clearArea: true))),
            if (f.minBedrooms != null) chip('${f.minBedrooms} beds', () => _setFilter(f.copyWith(clearBeds: true))),
            if (f.maxMoveIn != null) chip('Up to ${Money.short(f.maxMoveIn!.round())} move-in', () => _setFilter(f.copyWith(clearMoveIn: true))),
            if (f.maxPrice != null && f.maxMoveIn == null) chip('Rent up to ${Money.short(f.maxPrice!.round())}', () => _setFilter(f.copyWith(clearPrice: true))),
            if (f.mustHave.isNotEmpty) chip('${f.mustHave.length} must-have', () => _setFilter(f.copyWith(mustHave: const []))),
            if (f.recentlyConfirmedOnly) chip('Recently confirmed', () => _setFilter(f.copyWith(recentlyConfirmedOnly: false))),
            if (f.activeFilterCount > 0) Padding(padding: const EdgeInsets.only(left: 4), child: PsChip('Clear filters ${f.activeFilterCount}', selected: false, onTap: () { _q.clear(); _setFilter(ListingFilter.empty); })),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(24, 6, 24, 8), child: Row(children: [
            Expanded(child: Text(f.maxMoveIn != null ? 'Homes that fit your budget' : 'Homes in Abuja', style: AppText.h2)),
            SizedBox(width: 168, child: PsSegmented(labels: const ['List', 'Map'], index: 0, onChanged: (i) { if (i == 1) context.push('/map'); })),
          ])),
          Expanded(child: async.when(
            loading: () => const PsListingSkeleton(),
            error: (_, __) => PsError(onRetry: () => ref.invalidate(filteredListingsProvider(f))),
            data: (raw) {
              final list = raw;
              if (list.isEmpty) {
                return PsEmpty(icon: Icons.search_off_rounded, title: 'No homes match yet', message: 'Try a wider budget or fewer must-haves, or save this search and we will tell you when one appears.', actionLabel: f.activeFilterCount > 0 ? 'Clear filters' : null, onAction: f.activeFilterCount > 0 ? () { _q.clear(); _setFilter(ListingFilter.empty); } : null);
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
        Positioned(left: 0, right: 0, bottom: 16, child: Center(child: PsButton('Save search & get alerts', icon: Icons.notifications_none_rounded, expand: false, onPressed: () => _saveSearch(f)))),
      ])),
    );
  }
}
