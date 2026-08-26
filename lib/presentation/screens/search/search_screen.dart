import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../../data/models/listing_model.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final String? initialType;
  const SearchScreen({super.key, this.initialQuery, this.initialCategory, this.initialType});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  bool _showFilters = false;

  // Filters
  String? _area;
  String? _propertyType;
  String? _category;
  int? _minBeds;
  double? _minPrice;
  double? _maxPrice;
  bool _verifiedOnly = false;
  bool _nearMe = false;
  SortOrder _sort = SortOrder.newest;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.text = widget.initialQuery ?? '';
    _category = widget.initialCategory;
    _propertyType = widget.initialType;
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void dispose() { _tabCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  void _apply() {
    final q = _searchCtrl.text.trim();
    final f = ListingFilter(
      query: q.isNotEmpty ? q : null,
      area: _area,
      propertyType: _propertyType,
      category: _category,
      minBedrooms: _minBeds,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      isVerified: _verifiedOnly ? true : null,
      sortOrder: _sort,
    );
    ref.read(listingFilterProvider.notifier).state = f;
  }

  void _clear() {
    setState(() {
      _area = null; _propertyType = null; _minBeds = null;
      _minPrice = null; _maxPrice = null;
      _verifiedOnly = false; _nearMe = false; _sort = SortOrder.newest;
    });
    _apply();
  }

  int get _activeFilters {
    int c = 0;
    if (_area != null) c++;
    if (_propertyType != null) c++;
    if (_minBeds != null) c++;
    if (_minPrice != null || _maxPrice != null) c++;
    if (_verifiedOnly) c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: _SearchInputBar(
            controller: _searchCtrl,
            onChanged: (_) => _apply(),
            onSubmitted: (_) => _apply(),
          ),
        ),
        actions: [
          Stack(alignment: Alignment.center, children: [
            IconButton(
              icon: Icon(Icons.tune_rounded,
                color: _showFilters ? AppColors.primary : AppColors.text2),
              style: IconButton.styleFrom(
                backgroundColor: _showFilters ? AppColors.primaryPale : null),
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
            if (_activeFilters > 0)
              Positioned(top: 8, right: 8,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(child: Text('$_activeFilters',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
                )),
          ]),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined, size: 16), text: 'Map View'),
            Tab(icon: Icon(Icons.view_list_rounded, size: 16), text: 'List View'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.text3,
          labelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      body: isDesktop
          ? Row(children: [
              // Sidebar filters on desktop
              SizedBox(width: 280,
                child: _FiltersPanel(
                  area: _area, propertyType: _propertyType, minBeds: _minBeds,
                  minPrice: _minPrice, maxPrice: _maxPrice,
                  verifiedOnly: _verifiedOnly, sort: _sort,
                  onArea: (v) { setState(() => _area = v); _apply(); },
                  onType: (v) { setState(() => _propertyType = v); _apply(); },
                  onBeds: (v) { setState(() => _minBeds = v); _apply(); },
                  onPrice: (mn, mx) { setState(() { _minPrice = mn; _maxPrice = mx; }); _apply(); },
                  onVerified: (v) { setState(() => _verifiedOnly = v); _apply(); },
                  onSort: (v) { setState(() => _sort = v); _apply(); },
                  onClear: _clear,
                  isDesktop: true,
                )),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: _buildTabContent()),
            ])
          : Column(children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showFilters
                    ? _FiltersPanel(
                        area: _area, propertyType: _propertyType, minBeds: _minBeds,
                        minPrice: _minPrice, maxPrice: _maxPrice,
                        verifiedOnly: _verifiedOnly, sort: _sort,
                        onArea: (v) { setState(() => _area = v); _apply(); },
                        onType: (v) { setState(() => _propertyType = v); _apply(); },
                        onBeds: (v) { setState(() => _minBeds = v); _apply(); },
                        onPrice: (mn, mx) { setState(() { _minPrice = mn; _maxPrice = mx; }); _apply(); },
                        onVerified: (v) { setState(() => _verifiedOnly = v); _apply(); },
                        onSort: (v) { setState(() => _sort = v); _apply(); },
                        onClear: _clear,
                        isDesktop: false,
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(child: _buildTabContent()),
            ]),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _MapView(filter: ref.watch(listingFilterProvider)),
        _ListView(filter: ref.watch(listingFilterProvider)),
      ],
    );
  }
}

// ─── SEARCH INPUT BAR ─────────────────────────────────────────────────────
class _SearchInputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const _SearchInputBar({required this.controller, this.onChanged, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border2)),
      child: Row(children: [
        const SizedBox(width: 10),
        const Icon(Icons.search_rounded, size: 18, color: AppColors.text3),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Search area, type, price…',
            border: InputBorder.none, fillColor: Colors.transparent, filled: false,
            isDense: true, contentPadding: EdgeInsets.zero,
          ),
        )),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: () { controller.clear(); onChanged?.call(''); },
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.close_rounded, size: 16, color: AppColors.text3)),
          ),
      ]),
    );
  }
}

// ─── FILTERS PANEL ────────────────────────────────────────────────────────
class _FiltersPanel extends StatelessWidget {
  final String? area, propertyType;
  final int? minBeds;
  final double? minPrice, maxPrice;
  final bool verifiedOnly;
  final SortOrder sort;
  final ValueChanged<String?> onArea, onType;
  final ValueChanged<int?> onBeds;
  final Function(double?, double?) onPrice;
  final ValueChanged<bool> onVerified;
  final ValueChanged<SortOrder> onSort;
  final VoidCallback onClear;
  final bool isDesktop;

  const _FiltersPanel({
    this.area, this.propertyType, this.minBeds,
    this.minPrice, this.maxPrice,
    required this.verifiedOnly, required this.sort,
    required this.onArea, required this.onType, required this.onBeds,
    required this.onPrice, required this.onVerified, required this.onSort,
    required this.onClear, required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isDesktop) ...[
            Row(children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              GestureDetector(onTap: onClear,
                child: Text('Clear all', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
            ]),
            const SizedBox(height: 14),
          ],

          _FLabel('LOCATION'),
          const SizedBox(height: 6),
          _FilterDrop(value: area, hint: 'Any area',
            items: AppConstants.abujaAreas.skip(1).toList(), onChanged: onArea),

          const SizedBox(height: 12),
          _FLabel('PROPERTY TYPE'),
          const SizedBox(height: 6),
          _FilterDrop(value: propertyType, hint: 'Any type',
            items: AppConstants.propertyTypes.map((t) => t['label']!).toList(), onChanged: onType),

          const SizedBox(height: 12),
          _FLabel('MIN BEDROOMS'),
          const SizedBox(height: 6),
          Row(children: [null, 1, 2, 3, 4, 5].map((b) {
            final sel = minBeds == b;
            return Expanded(child: GestureDetector(
              onTap: () => onBeds(b),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                ),
                child: Center(child: Text(b == null ? 'Any' : '$b+',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : AppColors.text))),
              ),
            ));
          }).toList()),

          const SizedBox(height: 12),
          _FLabel('PRICE RANGE (₦/YR)'),
          const SizedBox(height: 6),
          ...AppConstants.priceRanges.skip(1).map((r) {
            final mn = (r['min'] as int).toDouble();
            final mx = (r['max'] as int).toDouble();
            final sel = minPrice == mn && maxPrice == mx;
            return GestureDetector(
              onTap: () => onPrice(mn, mx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryPale : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
                ),
                child: Row(children: [
                  Text(r['label'] as String, style: TextStyle(
                    fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: sel ? AppColors.primary : AppColors.text)),
                  const Spacer(),
                  if (sel) const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                ]),
              ),
            );
          }),

          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => onVerified(!verifiedOnly),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: verifiedOnly ? AppColors.primaryPale : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: verifiedOnly ? AppColors.primary : AppColors.border, width: verifiedOnly ? 1.5 : 1),
                ),
                child: Row(children: [
                  Icon(Icons.verified_rounded, size: 14, color: verifiedOnly ? AppColors.primary : AppColors.text3),
                  const SizedBox(width: 6),
                  Text('Verified only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: verifiedOnly ? AppColors.primary : AppColors.text)),
                  const Spacer(),
                  if (verifiedOnly) const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                ]),
              ),
            )),
          ]),

          const SizedBox(height: 12),
          _FLabel('SORT BY'),
          const SizedBox(height: 6),
          _FilterDrop(
            value: sort == SortOrder.newest ? 'Newest first'
                : sort == SortOrder.priceAsc ? 'Price: Low to High'
                : sort == SortOrder.priceDesc ? 'Price: High to Low' : 'Oldest first',
            hint: 'Sort by',
            items: const ['Newest first', 'Oldest first', 'Price: Low to High', 'Price: High to Low'],
            onChanged: (v) {
              if (v == 'Newest first') onSort(SortOrder.newest);
              else if (v == 'Oldest first') onSort(SortOrder.oldest);
              else if (v == 'Price: Low to High') onSort(SortOrder.priceAsc);
              else onSort(SortOrder.priceDesc);
            },
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: TextButton(onPressed: onClear,
                child: const Text('Clear all filters'))),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _FLabel extends StatelessWidget {
  final String text;
  const _FLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.text3, letterSpacing: 0.6));
}

class _FilterDrop extends StatelessWidget {
  final String? value, hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDrop({this.value, this.hint, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value,
        hint: Text(hint ?? '', style: const TextStyle(color: AppColors.text3, fontSize: 13)),
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        items: [
          DropdownMenuItem<String>(value: null, child: Text(hint ?? 'Any')),
          ...items.map((v) => DropdownMenuItem(value: v, child: Text(v))),
        ],
        onChanged: onChanged,
      )),
    );
  }
}

// ─── MAP VIEW ─────────────────────────────────────────────────────────────
class _MapView extends ConsumerWidget {
  final ListingFilter filter;
  const _MapView({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(filteredListingsProvider(filter));
    return Stack(children: [
      // Map placeholder (replace with GoogleMap widget)
      Container(
        color: const Color(0xFFD4E6DC),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.map_outlined, size: 48, color: Color(0xFF5A8070)),
          const SizedBox(height: 8),
          const Text('Google Maps', style: TextStyle(color: Color(0xFF5A8070), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Enable google_maps_flutter in pubspec', style: TextStyle(color: const Color(0xFF5A8070).withOpacity(0.6), fontSize: 11)),
        ])),
      ),
      // Price pins
      listings.when(
        data: (items) => Stack(
          children: items.take(10).toList().asMap().entries.map((e) {
            final offsets = [
              const Offset(0.3, 0.35), const Offset(0.55, 0.5), const Offset(0.7, 0.42),
              const Offset(0.4, 0.6), const Offset(0.6, 0.28), const Offset(0.25, 0.55),
              const Offset(0.75, 0.6), const Offset(0.5, 0.7), const Offset(0.2, 0.45), const Offset(0.65, 0.65),
            ];
            final off = offsets[e.key % offsets.length];
            return Positioned(
              left: MediaQuery.of(context).size.width * off.dx,
              top: 300 * off.dy,
              child: GestureDetector(
                onTap: () => context.push('/listing/${e.value.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary, borderRadius: BorderRadius.circular(99),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Text(_fmtShort(e.value.price),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
            );
          }).toList(),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      // Near Me button
      Positioned(
        bottom: 20, right: 14,
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          elevation: 2,
          icon: const Icon(Icons.near_me_rounded, size: 18),
          label: const Text('Near Me', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    ]);
  }
}

String _fmtShort(double price) {
  if (price >= 1000000) return '₦${(price / 1000000).toStringAsFixed(1)}M';
  if (price >= 1000) return '₦${(price / 1000).toStringAsFixed(0)}k';
  return '₦${price.toStringAsFixed(0)}';
}

// ─── LIST VIEW ────────────────────────────────────────────────────────────
class _ListView extends ConsumerWidget {
  final ListingFilter filter;
  const _ListView({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(filteredListingsProvider(filter));
    final cols = AppBreakpoints.gridCols(context);

    return listings.when(
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results found',
            subtitle: 'Try adjusting your filters or search in a different area.',
            action: TextButton(
              onPressed: () => ref.read(listingFilterProvider.notifier).state = const ListingFilter(),
              child: const Text('Clear all filters'),
            ),
          );
        }
        return Column(children: [
          // Results strip
          Container(
            color: AppColors.surface, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              Text('${items.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text, fontSize: 13)),
              const Text(' properties found', style: TextStyle(color: AppColors.text2, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Row(children: const [
                  Icon(Icons.sort_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Sort', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.primary),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: cols == 1 ? 1.6 : 0.74,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final uid = ref.watch(currentUserIdProvider);
                final savedIds = ref.watch(currentUserModelProvider).value?.savedListings ?? [];
                return ListingCard(
                  listing: items[i],
                  onTap: () => ctx.push('/listing/${items[i].id}'),
                  isSaved: savedIds.contains(items[i].id),
                  onSaveTap: uid == null
                    ? () => ctx.push('/auth?redirect=/search')
                    : () {
                        final repo = ref.read(listingRepositoryProvider);
                        if (savedIds.contains(items[i].id)) {
                          repo.unsaveListing(userId: uid, listingId: items[i].id);
                        } else {
                          repo.saveListing(userId: uid, listingId: items[i].id);
                        }
                      },
                );
              },
            ),
          ),
        ]);
      },
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.74),
        itemCount: 6, itemBuilder: (_, __) => const SkeletonCard(),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
