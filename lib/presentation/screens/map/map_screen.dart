import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/app_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  ListingModel? _previewListing;
  bool _loadingLocation = false;
  String _selectedArea = 'All Abuja';
  double _radius = 5.0;

  // Abuja centre
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build markers when listings are available
    final listings = ref.read(homeFeedProvider).value ?? [];
    _buildMarkers(listings);
  }

  void _buildMarkers(List<ListingModel> listings) {
    final markers = <Marker>{};
    for (final listing in listings) {
      final lat = listing.location.latitude;
      final lng = listing.location.longitude;
      if (lat == 0 && lng == 0) continue; // skip listings without coordinates

      markers.add(Marker(
        markerId: MarkerId(listing.id),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          listing.isFeatured
              ? BitmapDescriptor.hueYellow // Gold for featured
              : BitmapDescriptor.hueGreen, // Green for regular
        ),
        infoWindow: InfoWindow(
          title: _fmtPrice(listing.price),
          snippet: listing.title,
        ),
        onTap: () => setState(() => _previewListing = listing),
      ));
    }
    if (mounted)
      setState(() => _markers
        ..clear()
        ..addAll(markers));
  }

  Future<void> _goToMyLocation() async {
    setState(() => _loadingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Location permission required. Enable in Settings.')));
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get your location.')));
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _goToArea(String area) async {
    // Area bounds for major Abuja areas
    const areaBounds = <String, LatLng>{
      'Maitama': LatLng(9.0820, 7.4836),
      'Wuse': LatLng(9.0600, 7.4700),
      'Wuse 2': LatLng(9.0700, 7.4850),
      'Asokoro': LatLng(9.0480, 7.5100),
      'Garki': LatLng(9.0500, 7.4600),
      'Jabi': LatLng(9.0800, 7.4400),
      'Gwarinpa': LatLng(9.1100, 7.4000),
      'Kubwa': LatLng(9.1400, 7.3200),
      'Life Camp': LatLng(9.1000, 7.4200),
      'Guzape': LatLng(9.0300, 7.4900),
    };
    final target = areaBounds[area];
    if (target != null) {
      await _mapCtrl?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 14)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(homeFeedProvider).value ?? [];

    return Scaffold(
      body: Stack(children: [
        // ── GOOGLE MAP ────────────────────────────────────────────────
        GoogleMap(
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
          markers: _markers,
          onMapCreated: (ctrl) {
            _mapCtrl = ctrl;

            _buildMarkers(listings);
          },
          onTap: (_) => setState(() => _previewListing = null),
        ),

        // ── TOP SEARCH + AREA CHIPS ───────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(children: [
                // Search bar
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppShadows.md,
                        ),
                        child: Row(children: [
                          const SizedBox(width: 13),
                          const Icon(Icons.search_rounded,
                              size: 18, color: AppColors.text3),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  _selectedArea == 'All Abuja'
                                      ? 'Search on map…'
                                      : _selectedArea,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.text3))),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/search'),
                    child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppShadows.md),
                        child: const Icon(Icons.tune_rounded,
                            color: AppColors.primary, size: 20)),
                  ),
                ]),
                const SizedBox(height: 8),
                // Area chips
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppConstants.abujaAreas.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final area = AppConstants.abujaAreas[i];
                      final on = _selectedArea == area;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedArea = area);
                          if (area != 'All Abuja') _goToArea(area);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 6),
                          decoration: BoxDecoration(
                            color: on ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: on ? [] : AppShadows.sm,
                          ),
                          child: Text(area,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: on ? Colors.white : AppColors.text2)),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── RADIUS SELECTOR ──────────────────────────────────────────
        Positioned(
          right: 12,
          top: MediaQuery.of(context).padding.top + 130,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.md),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [2.0, 5.0, 10.0, 20.0].map((r) {
                  final on = _radius == r;
                  return GestureDetector(
                    onTap: () => setState(() => _radius = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                          color: on ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${r.toInt()}km',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: on ? Colors.white : AppColors.text2)),
                    ),
                  );
                }).toList()),
          ),
        ),

        // ── NEAR ME + LISTING COUNT ───────────────────────────────────
        Positioned(
          bottom: _previewListing != null ? 228 : 110,
          left: 12,
          right: 12,
          child: Row(children: [
            GestureDetector(
              onTap: _goToMyLocation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppShadows.md),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _loadingLocation
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.near_me_rounded,
                          size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('Near Me',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ]),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Text('${listings.length} listings',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // ── LISTING PREVIEW CARD ─────────────────────────────────────
        if (_previewListing != null)
          Positioned(
            bottom: 90,
            left: 12,
            right: 12,
            child: _MapPreviewCard(
              listing: _previewListing!,
              onClose: () => setState(() => _previewListing = null),
              onTap: () => context.push('/listing/${_previewListing!.id}'),
            ),
          ),

        // ── LIST VIEW FAB ─────────────────────────────────────────────
        Positioned(
          bottom: 108,
          right: 12,
          child: FloatingActionButton.small(
            onPressed: () => context.push('/search'),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            elevation: 2,
            child: const Icon(Icons.view_list_rounded),
          ),
        ),
      ]),
    );
  }
}

// ─── MAP PREVIEW CARD ─────────────────────────────────────────────────────
class _MapPreviewCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onClose, onTap;
  const _MapPreviewCard(
      {required this.listing, required this.onClose, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.lg,
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 110,
              height: 105,
              child: listing.images.isNotEmpty
                  ? Image.network(listing.images.first,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : Container(color: AppColors.primaryPale2))
                  : Container(
                      color: AppColors.primaryPale2,
                      child: const Icon(Icons.home_outlined,
                          size: 36, color: AppColors.text3)),
            ),
          ),
          // Info
          Expanded(
              child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_fmtPrice(listing.price),
                  style: GoogleFonts.syne(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 3),
              Text(listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 11, color: AppColors.text3),
                const SizedBox(width: 2),
                Text(listing.location.area,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.text3)),
              ]),
              const SizedBox(height: 7),
              Row(children: [
                _Pill('🛏 ${listing.bedrooms}'),
                const SizedBox(width: 6),
                _Pill('🚿 ${listing.bathrooms}'),
                if (listing.isVerified) ...[
                  const SizedBox(width: 6),
                  _Pill('✓ Verified', green: true),
                ],
              ]),
            ]),
          )),
          // Buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                      onTap: onClose,
                      child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                              color: AppColors.bg, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: AppColors.text2))),
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('View',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool green;
  const _Pill(this.label, {this.green = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: green ? AppColors.primaryPale : AppColors.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: green
                  ? AppColors.primary.withOpacity(0.25)
                  : AppColors.border)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: green ? AppColors.primary : AppColors.text2)));
}

String _fmtPrice(double price) {
  if (price >= 1000000)
    return '₦${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)}M/yr';
  if (price >= 1000) return '₦${(price / 1000).toStringAsFixed(0)}k/yr';
  return '₦${price.toStringAsFixed(0)}/yr';
}
