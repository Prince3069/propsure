import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/listing_category.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/app_providers.dart';

/// "Find the right fit". The budget toggle matters: a move-in budget and an
/// annual-rent budget are different filters, and unknown costs are never
/// treated as zero.
class FiltersScreen extends ConsumerStatefulWidget {
  const FiltersScreen({super.key});
  @override
  ConsumerState<FiltersScreen> createState() => _FiltersState();
}

class _FiltersState extends ConsumerState<FiltersScreen> {
  static const _cats = [ListingCategory.rent, ListingCategory.sale, ListingCategory.shortStay];
  static const _features = [('Water', 'Borehole / Water', Icons.water_drop_outlined), ('Prepaid meter', 'Prepaid Meter', Icons.bolt_rounded), ('Parking', 'Parking Space', Icons.local_parking_rounded)];

  late ListingFilter _f;
  final _budget = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = ref.read(listingFilterProvider);
    final b = _f.budgetIsMoveIn ? _f.maxMoveIn : _f.maxPrice;
    if (b != null) _budget.text = Money.full(b.round()).replaceAll('₦', '');
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  void _applyBudgetText(String raw) {
    final v = Money.parse(raw);
    setState(() {
      if (v == null || v <= 0) {
        _f = _f.copyWith(clearMoveIn: true, clearPrice: true);
      } else if (_f.budgetIsMoveIn) {
        _f = _f.copyWith(maxMoveIn: v, clearPrice: true);
      } else {
        _f = _f.copyWith(maxPrice: v, clearMoveIn: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cat = _f.category == null ? ListingCategory.rent : ListingCategory.fromAny(_f.category);
    final beds = _f.minBedrooms;
    Widget label(String t, {String? sub}) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.h3), if (sub != null) Text(sub, style: AppText.small)]));
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 0), child: Row(children: [
          Expanded(child: Text('Find the right fit', style: AppText.h1)),
          PsLink('Reset', onTap: () { setState(() { _f = ListingFilter.empty; _budget.clear(); }); }),
        ])),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), children: [
          label('Location'),
          PsDropdown<String>(label: '', value: _f.area, hint: 'Any area in Abuja', items: AppConstants.abujaAreas.where((a) => a != 'All Abuja').toList(), itemLabel: (a) => '$a, Abuja', onChanged: (v) => setState(() => _f = v == null ? _f.copyWith(clearArea: true) : _f.copyWith(area: v))),
          label('What are you looking for?'),
          PsSegmented(labels: [for (final c in _cats) c.chipLabel], index: _cats.indexOf(cat).clamp(0, 2), onChanged: (i) => setState(() => _f = _f.copyWith(category: _cats[i].value))),
          label('Budget'),
          PsSegmented(labels: const ['Total move-in', 'Annual rent'], index: _f.budgetIsMoveIn ? 0 : 1, onChanged: (i) => setState(() { _f = _f.copyWith(budgetIsMoveIn: i == 0); _applyBudgetText(_budget.text); })),
          const SizedBox(height: 12),
          PsField(label: _f.budgetIsMoveIn ? 'Maximum move-in cost' : 'Maximum annual rent', controller: _budget, keyboardType: TextInputType.number, prefix: const Padding(padding: EdgeInsets.all(14), child: Text('₦')), onChanged: _applyBudgetText),
          const SizedBox(height: 4),
          Text(_f.budgetIsMoveIn ? 'Covers rent, agency, legal and other known fees.' : 'Annual rent only. Other fees are shown on each home.', style: AppText.caption),
          label('Bedrooms'),
          Row(children: [
            for (final o in const [null, 1, 2, 3, 4]) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: PsChip(o == null ? 'Any' : (o == 4 ? '4+' : '$o'), selected: beds == o, onTap: () => setState(() => _f = o == null ? _f.copyWith(clearBeds: true) : _f.copyWith(minBedrooms: o))))),
          ]),
          label('Must-have features', sub: 'Homes must include these features.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in _features) PsChip(f.$1, icon: f.$3, selected: _f.mustHave.contains(f.$2), onTap: () => setState(() { final s = {..._f.mustHave}; s.contains(f.$2) ? s.remove(f.$2) : s.add(f.$2); _f = _f.copyWith(mustHave: s.toList()); })),
          ]),
          label('Availability'),
          PsRowGroup([PsToggleRow(icon: Icons.event_available_outlined, title: 'Recently confirmed only', subtitle: 'Show homes that are still available.', value: _f.recentlyConfirmedOnly, onChanged: (v) => setState(() => _f = _f.copyWith(recentlyConfirmedOnly: v)))]),
          const SizedBox(height: 10),
          const PsNote('Unknown fees stay visible, never guessed.', icon: Icons.info_outline_rounded),
        ])),
        PsBottomBar(children: [
          PsButton('Show matching homes', trailingIcon: Icons.arrow_forward_rounded, onPressed: () { ref.read(listingFilterProvider.notifier).set(_f); context.pop(); }),
        ]),
      ])),
    );
  }
}
