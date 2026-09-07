import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../../data/models/listing_model.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final String? initialType;
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.initialType,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
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
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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
      _area = null;
      _propertyType = null;
      _minBeds = null;
      _minPrice = null;
      _maxPrice = null;
      _verifiedOnly = false;
      _nearMe = false;
      _sort = SortOrder.newest;
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: _showFilters ? AppColors.primary : AppColors.text2,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _showFilters ? AppColors.primaryPale : null,
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              if (_activeFilters > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilters',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined, size: 16), text: 'Map View'),
            Tab(
                icon: Icon(Icons.view_list_rounded, size: 16),
                text: 'List View'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.text3,
          labelStyle: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _FiltersPanel(
                    area: _area,
                    propertyType: _propertyType,
                    minBeds: _minBeds,
                    minPrice: _minPrice,
                    maxPrice: _maxPrice,
                    verifiedOnly: _verifiedOnly,
                    sort: _sort,
                    onArea: (v) {
                      setState(() => _area = v);
                      _apply();
                    },
                    onType: (v) {
                      setState(() => _propertyType = v);
                      _apply();
                    },
                    onBeds: (v) {
                      setState(() => _minBeds = v);
                      _apply();
                    },
                    onPrice: (mn, mx) {
                      setState(() {
                        _minPrice = mn;
                        _maxPrice = mx;
                      });
                      _apply();
                    },
                    onVerified: (v) {
                      setState(() => _verifiedOnly = v);
                      _apply();
                    },
                    onSort: (v) {
                      setState(() => _sort = v);
                      _apply();
                    },
                    onClear: _clear,
                    isDesktop: true,
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: _buildTabContent()),
              ],
            )
          : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _showFilters
                      ? _FiltersPanel(
                          area: _area,
                          propertyType: _propertyType,
                          minBeds: _minBeds,
                          minPrice: _minPrice,
                          maxPrice: _maxPrice,
                          verifiedOnly: _verifiedOnly,
                          sort: _sort,
                          onArea: (v) {
                            setState(() => _area = v);
                            _apply();
                          },
                          onType: (v) {
                            setState(() => _propertyType = v);
                            _apply();
                          },
                          onBeds: (v) {
                            setState(() => _minBeds = v);
                            _apply();
                          },
                          onPrice: (mn, mx) {
                            setState(() {
                              _minPrice = mn;
                              _maxPrice = mx;
                            });
                            _apply();
                          },
                          onVerified: (v) {
                            setState(() => _verifiedOnly = v);
                            _apply();
                          },
                          onSort: (v) {
                            setState(() => _sort = v);
                            _apply();
                          },
                          onClear: _clear,
                          isDesktop: false,
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(child: _buildTabContent()),
              ],
            ),
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

  const _SearchInputBar({
    required this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border2),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, size: 18, color: AppColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search area, type, price…',
                border: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged?.call('');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child:
                    Icon(Icons.close_rounded, size: 16, color: AppColors.text3),
              ),
            ),
        ],
      ),
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
    this.area,
    this.propertyType,
    this.minBeds,
    this.minPrice,
    this.maxPrice,
    required this.verifiedOnly,
    required this.sort,
    required this.onArea,
    required this.onType,
    required this.onBeds,
    required this.onPrice,
    required this.onVerified,
    required this.onSort,
    required this.onClear,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Row(
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClear,
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            _FLabel('LOCATION'),
            const SizedBox(height: 6),
            _FilterDrop(
              value: area,
              hint: 'Any area',
              icon: Icons.location_on_outlined,
              items: AppConstants.abujaAreas.skip(1).toList(),
              onChanged: onArea,
            ),
            const SizedBox(height: 12),
            _FLabel('PROPERTY TYPE'),
            const SizedBox(height: 6),
            _FilterDrop(
              value: propertyType,
              hint: 'Any type',
              icon: Icons.home_work_outlined,
              items:
                  AppConstants.propertyTypes.map((t) => t['label']!).toList(),
              onChanged: onType,
            ),
            const SizedBox(height: 12),
            _FLabel('MIN BEDROOMS'),
            const SizedBox(height: 6),
            Row(
              children: [null, 1, 2, 3, 4, 5].map((b) {
                final sel = minBeds == b;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onBeds(b),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          b == null ? 'Any' : '$b+',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primaryPale : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.border,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        r['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? AppColors.primary : AppColors.text,
                        ),
                      ),
                      const Spacer(),
                      if (sel)
                        const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onVerified(!verifiedOnly),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            verifiedOnly ? AppColors.primaryPale : AppColors.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: verifiedOnly
                              ? AppColors.primary
                              : AppColors.border,
                          width: verifiedOnly ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: verifiedOnly
                                ? AppColors.primary
                                : AppColors.text3,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Verified only',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: verifiedOnly
                                  ? AppColors.primary
                                  : AppColors.text,
                            ),
                          ),
                          const Spacer(),
                          if (verifiedOnly)
                            const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FLabel('SORT BY'),
            const SizedBox(height: 6),
            _FilterDrop(
              icon: Icons.sort_rounded,
              value: sort == SortOrder.newest
                  ? 'Newest first'
                  : sort == SortOrder.priceAsc
                      ? 'Price: Low to High'
                      : sort == SortOrder.priceDesc
                          ? 'Price: High to Low'
                          : 'Oldest first',
              hint: 'Sort by',
              items: const [
                'Newest first',
                'Oldest first',
                'Price: Low to High',
                'Price: High to Low'
              ],
              onChanged: (v) {
                if (v == 'Newest first')
                  onSort(SortOrder.newest);
                else if (v == 'Oldest first')
                  onSort(SortOrder.oldest);
                else if (v == 'Price: Low to High')
                  onSort(SortOrder.priceAsc);
                else
                  onSort(SortOrder.priceDesc);
              },
            ),
            if (!isDesktop) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onClear,
                  child: const Text('Clear all filters'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FLabel extends StatelessWidget {
  final String text;
  const _FLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.text3,
          letterSpacing: 0.6,
        ),
      );
}

class _FilterDrop extends StatelessWidget {
  final String? value, hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const _FilterDrop({
    this.value,
    this.hint,
    required this.items,
    required this.onChanged,
    this.icon = Icons.tune_rounded,
  });

  @override
  Widget build(BuildContext context) {
    // CarPlaza-style form field: floating label + leading icon + rounded
    // outline, instead of a bare unlabeled box. Reads far more polished,
    // especially once several of these sit stacked in the filter panel.
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.text3, size: 20),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        labelText: hint ?? 'Any',
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        isDense: true,
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(hint ?? 'Any',
              style: const TextStyle(color: AppColors.text3)),
        ),
        ...items.map(
          (v) => DropdownMenuItem(value: v, child: Text(v)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

// ─── MAP VIEW ─────────────────────────────────────────────────────────────
// Real Google Map (was previously a fake decorative placeholder with
// hardcoded "Enable google_maps_flutter in pubspec" text — that text never
// checked anything, it was just a static label). google_maps_flutter is
// already wired up correctly elsewhere in the app (see map_screen.dart), so
// this reuses the same pattern: real markers built from the filtered
// listings, tap a pin to preview, tap the preview to open the listing.
class _MapView extends ConsumerStatefulWidget {
  final ListingFilter filter;
  const _MapView({required this.filter});

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  GoogleMapController? _mapCtrl;
  ListingModel? _preview;
  bool _locating = false;

  static const _abujaCenter =
      LatLng(AppConstants.abujaLat, AppConstants.abujaLng);

  static const _mapStyle = '''
[
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#e8f0ec"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c8ddd4"}]}
]
''';

  Set<Marker> _markersFrom(List<ListingModel> items) {
    final markers = <Marker>{};
    for (final listing in items) {
      final lat = listing.location.latitude;
      final lng = listing.location.longitude;
      if (lat == 0 && lng == 0) continue;
      markers.add(Marker(
        markerId: MarkerId(listing.id),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          listing.isFeatured
              ? BitmapDescriptor.hueYellow
              : BitmapDescriptor.hueGreen,
        ),
        onTap: () => setState(() => _preview = listing),
      ));
    }
    return markers;
  }

  Future<void> _nearMe() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Location permission required. Enable in Settings.')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      await _mapCtrl?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 15),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get your location.')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(filteredListingsProvider(widget.filter));

    return Stack(
      children: [
        listings.when(
          data: (items) => GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _abujaCenter,
              zoom: AppConstants.defaultMapZoom,
            ),
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
            tiltGesturesEnabled: false,
            style: _mapStyle,
            markers: _markersFrom(items),
            onMapCreated: (ctrl) => _mapCtrl = ctrl,
            onTap: (_) => setState(() => _preview = null),
          ),
          loading: () => Container(
            color: AppColors.primaryPale2,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Container(
            color: AppColors.primaryPale2,
            child: Center(child: Text('Could not load map: $e')),
          ),
        ),
        // Result count chip
        Positioned(
          top: 12,
          left: 12,
          child: listings.maybeWhen(
            data: (items) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Text('${items.length} listings',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
        // Listing preview card
        if (_preview != null)
          Positioned(
            bottom: 84,
            left: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => context.push('/listing/${_preview!.id}'),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.lg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                    child: SizedBox(
                      width: 96,
                      height: 92,
                      child: _preview!.images.isNotEmpty
                          ? Image.network(_preview!.images.first,
                              fit: BoxFit.cover)
                          : Container(
                              color: AppColors.primaryPale2,
                              child: const Icon(Icons.home_outlined,
                                  color: AppColors.text3)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fmtShort(_preview!.price),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                          const SizedBox(height: 2),
                          Text(_preview!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(_preview!.location.area,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.text3)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.text3,
                    onPressed: () => setState(() => _preview = null),
                  ),
                ]),
              ),
            ),
          ),
        // Near Me button
        Positioned(
          bottom: 20,
          right: 14,
          child: FloatingActionButton.extended(
            onPressed: _locating ? null : _nearMe,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            elevation: 2,
            icon: _locating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.near_me_rounded, size: 18),
            label: const Text(
              'Near Me',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
      ],
    );
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
            subtitle:
                'Try adjusting your filters or search in a different area.',
            action: TextButton(
              onPressed: () => ref.read(listingFilterProvider.notifier).state =
                  const ListingFilter(),
              child: const Text('Clear all filters'),
            ),
          );
        }
        return Column(
          children: [
            // Results strip
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      fontSize: 13,
                    ),
                  ),
                  const Text(
                    ' properties found',
                    style: TextStyle(color: AppColors.text2, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: const [
                        Icon(Icons.sort_rounded,
                            size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Sort',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: cols == 1 ? 1.6 : 0.74,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final uid = ref.watch(currentUserIdProvider);
                  final savedIds = ref
                          .watch(currentUserModelProvider)
                          .value
                          ?.savedListings ??
                      [];
                  return ListingCard(
                    listing: items[i],
                    onTap: () => ctx.push('/listing/${items[i].id}'),
                    isSaved: savedIds.contains(items[i].id),
                    onSaveTap: uid == null
                        ? () => ctx.push('/auth?redirect=/search')
                        : () {
                            final repo = ref.read(listingRepositoryProvider);
                            if (savedIds.contains(items[i].id)) {
                              repo.unsaveListing(
                                  userId: uid, listingId: items[i].id);
                            } else {
                              repo.saveListing(
                                  userId: uid, listingId: items[i].id);
                            }
                          },
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.74,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonCard(),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
