// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/listing_model.dart';
import '../../../services/location_service.dart';
import '../../providers/app_providers.dart';

class UploadListingScreen extends ConsumerStatefulWidget {
  final String? editListingId;
  const UploadListingScreen({super.key, this.editListingId});

  @override
  ConsumerState<UploadListingScreen> createState() =>
      _UploadListingScreenState();
}

class _UploadListingScreenState extends ConsumerState<UploadListingScreen> {
  int _step = 0;

  // ── Photos step ─────────────────────────────────────────────
  List<XFile> _images = [];
  XFile? _videoFile;
  XFile? _video360File;

  // ── Location step ────────────────────────────────────────────
  String? _area;
  String? _city = 'Abuja (FCT)';
  LatLng? _selectedPin;
  final _addressCtrl = TextEditingController();

  // ── Details step ─────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _propertyType;
  String? _category;
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _toilets = 1;
  bool _furnished = false;
  bool _petsAllowed = false;
  bool _parkingAvailable = false;
  List<String> _amenities = [];

  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Image picker using Photo Picker (no permissions needed) ──
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 75,
    );
    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (picked != null) setState(() => _videoFile = picked);
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _submit() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      context.push('/auth?redirect=/listing/upload');
      return;
    }
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please add at least 1 photo'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill Title and Price'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_area == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select an area'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    final notifier = ref.read(listingUploadProvider.notifier);
    final id = await notifier.uploadListing(
      data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
        'propertyType': _propertyType ?? 'Flat / Apartment',
        'category': _category ?? 'For Rent',
        'location': await _buildLocation(),
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'toilets': _toilets,
        'isFurnished': _furnished,
        'petsAllowed': _petsAllowed,
        'parkingAvailable': _parkingAvailable,
        'amenities': _amenities,
      },
      imagePaths: _images.map((f) => f.path).toList(),
      videoPath: _videoFile?.path,
      video360Path: _video360File?.path,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    final uploadState = ref.read(listingUploadProvider);
    if (id != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(listingId: id),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Upload Failed', style: TextStyle(fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Text(
              uploadState.error ?? 'Upload failed. Please try again.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<PropertyLocation> _buildLocation() async {
    const areaCenters = <String, List<double>>{
      'Maitama': [9.0820, 7.4836],
      'Wuse 2': [9.0700, 7.4850],
      'Wuse': [9.0600, 7.4700],
      'Asokoro': [9.0480, 7.5100],
      'Garki': [9.0500, 7.4600],
      'Jabi': [9.0800, 7.4400],
      'Gwarinpa': [9.1100, 7.4000],
      'Kubwa': [9.1400, 7.3200],
      'Life Camp': [9.1000, 7.4200],
      'Guzape': [9.0300, 7.4900],
    };
    final area = _area ?? 'Wuse';
    final center =
        areaCenters[area] ?? [AppConstants.abujaLat, AppConstants.abujaLng];
    final lat = _selectedPin?.latitude ?? center[0];
    final lng = _selectedPin?.longitude ?? center[1];
    final city = _city ?? 'Abuja (FCT)';
    final address = _addressCtrl.text.trim();
    final full = address.isNotEmpty ? '$address, $area, $city' : '$area, $city';
    return PropertyLocation(
      latitude: lat,
      longitude: lng,
      geohash: GeoFirePoint(GeoPoint(lat, lng)).geohash,
      area: area,
      city: city,
      street: address,
      fullAddress: full,
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(listingUploadProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _PostTopBar(step: _step),
        _StepBar(step: _step),
        Expanded(child: _body()),
        _BottomBar(
          step: _step,
          isLoading: _isLoading || uploadState.isUploading,
          progress: uploadState.progress,
          onBack: _step > 0 ? () => setState(() => _step--) : null,
          onNext: _step < 3 ? _advanceStep : _submit,
          isLast: _step == 3,
        ),
      ]),
    );
  }

  void _advanceStep() {
    if (_step == 0 && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least 1 photo to continue'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_step == 1 && _area == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select an area to continue'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _step++);
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return _StepPhotos(
          images: _images,
          videoFile: _videoFile,
          video360File: _video360File,
          onPickImages: _pickImages,
          onPickVideo: _pickVideo,
          onRemoveImage: (i) => setState(() => _images.removeAt(i)),
          onRemoveVideo: () => setState(() => _videoFile = null),
          onRemove360: () => setState(() => _video360File = null),
        );
      case 1:
        return _StepLocation(
          city: _city,
          area: _area,
          selectedPin: _selectedPin,
          addressCtrl: _addressCtrl,
          onPinSelected: (pin) => setState(() => _selectedPin = pin),
          onCityChanged: (v) => setState(() {
            _city = v;
            _area = null;
          }),
          onAreaChanged: (v) => setState(() => _area = v),
        );
      case 2:
        return _StepDetails(
          titleCtrl: _titleCtrl,
          descCtrl: _descCtrl,
          priceCtrl: _priceCtrl,
          propertyType: _propertyType,
          category: _category,
          bedrooms: _bedrooms,
          bathrooms: _bathrooms,
          toilets: _toilets,
          furnished: _furnished,
          petsAllowed: _petsAllowed,
          parkingAvailable: _parkingAvailable,
          amenities: _amenities,
          onPropertyTypeChanged: (v) => setState(() => _propertyType = v),
          onCategoryChanged: (v) => setState(() => _category = v),
          onBedroomsChanged: (v) => setState(() => _bedrooms = v),
          onBathroomsChanged: (v) => setState(() => _bathrooms = v),
          onToiletsChanged: (v) => setState(() => _toilets = v),
          onFurnishedChanged: (v) => setState(() => _furnished = v!),
          onAmenitiesChanged: (v) => setState(() => _amenities = v),
          onPetsChanged: (v) => setState(() => _petsAllowed = v),
          onParkingChanged: (v) => setState(() => _parkingAvailable = v),
        );
      case 3:
        return _StepReview(
          title: _titleCtrl.text,
          price: _priceCtrl.text,
          area: _area ?? '',
          city: _city ?? '',
          propertyType: _propertyType ?? '',
          bedrooms: _bedrooms,
          bathrooms: _bathrooms,
          imageCount: _images.length,
          has360: _video360File != null,
          amenities: _amenities,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── TOP BAR ──────────────────────────────────────────────────────────────────
class _PostTopBar extends StatelessWidget {
  final int step;
  const _PostTopBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            GestureDetector(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('List Property',
                    style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const Text('Add Videos (0/10 available)',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── STEP BAR ─────────────────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});

  @override
  Widget build(BuildContext context) {
    final labels = ['Photos', 'Location', 'Details', 'Submit'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
          children: List.generate(4, (i) {
        final done = i < step;
        final current = i == step;
        return Expanded(
            child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done || current ? AppColors.primary : AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : Text('${i + 1}',
                        style: TextStyle(
                            color: current ? Colors.white : AppColors.text3,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 3),
            Text(labels[i],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: current ? AppColors.primary : AppColors.text3,
                )),
          ]),
          if (i < 3)
            Expanded(
                child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 14),
              color: i < step ? AppColors.primary : AppColors.border,
            )),
        ]));
      })),
    );
  }
}

// ─── BOTTOM BAR ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int step;
  final bool isLoading;
  final double progress;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final bool isLast;
  const _BottomBar({
    required this.step,
    required this.isLoading,
    required this.progress,
    required this.onBack,
    required this.onNext,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isLoading && progress > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).toInt()}% uploaded',
              style: const TextStyle(fontSize: 11, color: AppColors.text3)),
          const SizedBox(height: 8),
        ],
        Row(children: [
          if (onBack != null) ...[
            SizedBox(
              width: 100,
              child: OutlinedButton(
                onPressed: isLoading ? null : onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isLast ? 'Submit Listing' : 'Continue →',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── STEP 0: PHOTOS ───────────────────────────────────────────────────────────
class _StepPhotos extends StatelessWidget {
  final List<XFile> images;
  final XFile? videoFile, video360File;
  final VoidCallback onPickImages, onPickVideo;
  final void Function(int) onRemoveImage;
  final VoidCallback onRemoveVideo, onRemove360;

  const _StepPhotos({
    required this.images,
    required this.videoFile,
    required this.video360File,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveImage,
    required this.onRemoveVideo,
    required this.onRemove360,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // ── WhatsApp shortcut ─────────────────────────────────────────────
      GestureDetector(
        onTap: () async {
          final msg = '🏡 *NEW PROPERTY LISTING REQUEST*\n'
              '━━━━━━━━━━━━━━━━━━━━━\n\n'
              'Hi Propsure! I want to list my property.\n\n'
              '*Property Details*\n'
              '📍 Location: \n'
              '🏠 Property Type: \n'
              '💰 Price: ₦ /year\n'
              '🛏 Bedrooms: \n'
              '🚿 Bathrooms: \n'
              '✅ Amenities: \n\n'
              '*My Contact*\n'
              '👤 Name: \n'
              '📞 Phone: \n\n'
              '━━━━━━━━━━━━━━━━━━━━━\n'
              '_Sent via Propsure App_';
          final uri = Uri.parse('https://wa.me/2348107286686'
              '?text=${Uri.encodeComponent(msg)}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Text('📲', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Don\'t want to fill form?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  Text('Send details via WhatsApp — our team lists it for you',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white60),
          ]),
        ),
      ),

      // ── Photos grid ────────────────────────────────────────────────────
      Text('Photos *',
          style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('Add at least 1 photo. More photos = more inquiries.',
          style: TextStyle(fontSize: 12, color: AppColors.text3)),
      const SizedBox(height: 12),

      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: images.length + 1,
        itemBuilder: (_, i) {
          if (i == images.length) {
            return GestureDetector(
              onTap: onPickImages,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.primaryPale,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.primary, size: 28),
                    SizedBox(height: 4),
                    Text('Add Photos',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }
          return Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(images[i].path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            if (i == 0)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('Cover',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemoveImage(i),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
          ]);
        },
      ),
      const SizedBox(height: 20),

      // ── Video ────────────────────────────────────────────────────────────
      Text('Video (Optional)',
          style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (videoFile == null)
        GestureDetector(
          onTap: onPickVideo,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.bg,
            ),
            child: const Row(children: [
              Icon(Icons.videocam_outlined, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text('Add a walkthrough video', style: TextStyle(fontSize: 13)),
            ]),
          ),
        )
      else
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.videocam_rounded, color: AppColors.primary),
          title: const Text('Video added', style: TextStyle(fontSize: 13)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: onRemoveVideo,
          ),
        ),
    ]);
  }
}

// ─── STEP 1: LOCATION ─────────────────────────────────────────────────────────
class _StepLocation extends StatelessWidget {
  final String? city, area;
  final LatLng? selectedPin;
  final TextEditingController addressCtrl;
  final ValueChanged<LatLng> onPinSelected;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onAreaChanged;

  const _StepLocation({
    required this.city,
    required this.area,
    required this.selectedPin,
    required this.addressCtrl,
    required this.onPinSelected,
    required this.onCityChanged,
    required this.onAreaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sectionLabel('CITY'),
      _PropsureDropdown<String>(
        value: city,
        items: AppConstants.nigeriaCities,
        hint: 'Select city',
        icon: Icons.location_city_outlined,
        onChanged: onCityChanged,
      ),
      const SizedBox(height: 16),
      _sectionLabel('AREA / NEIGHBOURHOOD'),
      _PropsureDropdown<String>(
        value: area,
        items: AppConstants.abujaAreas,
        hint: 'Select area',
        icon: Icons.near_me_outlined,
        onChanged: onAreaChanged,
      ),
      const SizedBox(height: 16),
      _sectionLabel('FULL ADDRESS (Optional)'),
      TextField(
        controller: addressCtrl,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.home_outlined),
          hintText: 'e.g. 12 River Park Estate',
        ),
      ),
      const SizedBox(height: 16),
      _PropertyPinPicker(
        area: area,
        selectedPin: selectedPin,
        onPinSelected: onPinSelected,
      ),
    ]);
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.text3)),
      );
}

// ─── PROPERTY PIN PICKER ──────────────────────────────────────────────────────
class _PropertyPinPicker extends StatelessWidget {
  final String? area;
  final LatLng? selectedPin;
  final ValueChanged<LatLng> onPinSelected;

  const _PropertyPinPicker({
    required this.area,
    required this.selectedPin,
    required this.onPinSelected,
  });

  @override
  Widget build(BuildContext context) {
    const fallback = LatLng(AppConstants.abujaLat, AppConstants.abujaLng);
    final center = selectedPin ?? fallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PIN THE PROPERTY LOCATION',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
            color: AppColors.text3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primaryPale2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryPale2),
          ),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 13.5),
            markers: selectedPin == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('selected-property'),
                      position: selectedPin!,
                    ),
                  },
            onTap: onPinSelected,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            liteModeEnabled: true,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          selectedPin == null
              ? 'Tap the map to place the property pin for ${area ?? 'this area'}. The selected area is used as the starting point.'
              : 'Property pin selected. Coordinates will be saved with this listing.',
          style: const TextStyle(fontSize: 11, color: AppColors.text3),
        ),
      ],
    );
  }
}

// ─── STEP 2: DETAILS ─────────────────────────────────────────────────────────
class _StepDetails extends StatelessWidget {
  final TextEditingController titleCtrl, descCtrl, priceCtrl;
  final String? propertyType, category;
  final int bedrooms, bathrooms, toilets;
  final bool furnished, petsAllowed, parkingAvailable;
  final List<String> amenities;
  final ValueChanged<String?> onPropertyTypeChanged, onCategoryChanged;
  final ValueChanged<int> onBedroomsChanged,
      onBathroomsChanged,
      onToiletsChanged;
  final ValueChanged<bool?> onFurnishedChanged;
  final ValueChanged<List<String>> onAmenitiesChanged;
  final ValueChanged<bool> onPetsChanged, onParkingChanged;

  const _StepDetails({
    required this.titleCtrl,
    required this.descCtrl,
    required this.priceCtrl,
    required this.propertyType,
    required this.category,
    required this.bedrooms,
    required this.bathrooms,
    required this.toilets,
    required this.furnished,
    required this.petsAllowed,
    required this.parkingAvailable,
    required this.amenities,
    required this.onPropertyTypeChanged,
    required this.onCategoryChanged,
    required this.onBedroomsChanged,
    required this.onBathroomsChanged,
    required this.onToiletsChanged,
    required this.onFurnishedChanged,
    required this.onAmenitiesChanged,
    required this.onPetsChanged,
    required this.onParkingChanged,
  });

  static const _propertyTypes = [
    'Flat / Apartment',
    'Duplex',
    'Terraced House',
    'Detached House',
    'Bungalow',
    'Self Contain',
    'Studio',
    'Office Space',
    'Shop / Store',
    'Land',
    'Warehouse',
  ];

  static const _categories = [
    'For Rent',
    'For Sale',
    'Short Stay',
    'Lease',
    'Joint Venture',
  ];

  static const _amenityOptions = [
    'Generator',
    'Solar Power',
    'Borehole / Water',
    'Prepaid Meter',
    'Security / CCTV',
    'Swimming Pool',
    'Gym / Fitness',
    'Fitted Kitchen',
    'Air Conditioning',
    'Furnished',
    'Parking Space',
    'Perimeter Fence',
    'Boys Quarters',
    'Garden / Lawn',
    'Elevator / Lift',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(
        controller: titleCtrl,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Listing Title *',
          hintText: 'e.g. 3 Bedroom Duplex at River Park',
          prefixIcon: Icon(Icons.title_rounded),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: descCtrl,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Description',
          hintText: 'Describe the property, nearby landmarks...',
          alignLabelWithHint: true,
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: 60),
            child: Icon(Icons.description_outlined),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: priceCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Price (₦) per year *',
          prefixIcon: Icon(Icons.attach_money_rounded),
          suffixText: '/year',
        ),
      ),
      const SizedBox(height: 14),
      _PropsureDropdown<String>(
        value: category,
        items: _categories,
        hint: 'Select category',
        icon: Icons.category_outlined,
        label: 'CATEGORY *',
        onChanged: onCategoryChanged,
      ),
      const SizedBox(height: 14),
      _PropsureDropdown<String>(
        value: propertyType,
        items: _propertyTypes,
        hint: 'Select type',
        icon: Icons.home_outlined,
        label: 'PROPERTY TYPE *',
        onChanged: onPropertyTypeChanged,
      ),
      const SizedBox(height: 20),
      Text('ROOMS',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.text3)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _RoomCounter(
          icon: Icons.bed_outlined,
          label: 'Bedrooms',
          value: bedrooms,
          onChanged: onBedroomsChanged,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _RoomCounter(
          icon: Icons.bathtub_outlined,
          label: 'Bathrooms',
          value: bathrooms,
          onChanged: onBathroomsChanged,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _RoomCounter(
          icon: Icons.wc_outlined,
          label: 'Toilets',
          value: toilets,
          onChanged: onToiletsChanged,
        )),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: CheckboxListTile(
          value: furnished,
          onChanged: onFurnishedChanged,
          contentPadding: EdgeInsets.zero,
          title: const Text('Furnished', style: TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
        )),
        Expanded(
            child: CheckboxListTile(
          value: petsAllowed,
          onChanged: (v) => onPetsChanged(v ?? false),
          contentPadding: EdgeInsets.zero,
          title: const Text('Pets OK', style: TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
        )),
      ]),
      CheckboxListTile(
        value: parkingAvailable,
        onChanged: (v) => onParkingChanged(v ?? false),
        contentPadding: EdgeInsets.zero,
        title: const Text('Parking Available', style: TextStyle(fontSize: 13)),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primary,
      ),
      const SizedBox(height: 16),
      Text('AMENITIES',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.text3)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _amenityOptions.map((a) {
          final on = amenities.contains(a);
          return GestureDetector(
            onTap: () {
              final updated = List<String>.from(amenities);
              if (on) {
                updated.remove(a);
              } else {
                updated.add(a);
              }
              onAmenitiesChanged(updated);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: on ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: on ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(a,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : AppColors.text2,
                  )),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

// ─── STEP 3: REVIEW ───────────────────────────────────────────────────────────
class _StepReview extends StatelessWidget {
  final String title, price, area, city, propertyType;
  final int bedrooms, bathrooms, imageCount;
  final bool has360;
  final List<String> amenities;

  const _StepReview({
    required this.title,
    required this.price,
    required this.area,
    required this.city,
    required this.propertyType,
    required this.bedrooms,
    required this.bathrooms,
    required this.imageCount,
    required this.has360,
    required this.amenities,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review & Submit',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Double-check your listing before publishing',
                style: TextStyle(fontSize: 12, color: AppColors.text3)),
            const Divider(height: 24),
            _ReviewRow('Title', title.isEmpty ? '(not set)' : title),
            _ReviewRow('Price', price.isEmpty ? '(not set)' : '₦$price/yr'),
            _ReviewRow('Location', area.isEmpty ? '(not set)' : '$area, $city'),
            _ReviewRow(
                'Type', propertyType.isEmpty ? '(not set)' : propertyType),
            _ReviewRow('Beds / Baths', '$bedrooms Beds · $bathrooms Baths'),
            _ReviewRow('Photos', '$imageCount uploaded'),
            if (has360) _ReviewRow('360° Video', '✓ Added'),
            if (amenities.isNotEmpty)
              _ReviewRow(
                  'Amenities',
                  amenities.take(4).join(', ') +
                      (amenities.length > 4 ? '…' : '')),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryPale2),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Your listing will appear on the home screen immediately '
              'after submission. Listings are FREE.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.primary, height: 1.5),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _ReviewRow extends StatelessWidget {
  final String label, value;
  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.text3)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── ROOM COUNTER ─────────────────────────────────────────────────────────────
class _RoomCounter extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _RoomCounter({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.text3)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: () {
              if (value > 0) onChanged(value - 1);
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.remove_rounded, size: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$value',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          GestureDetector(
            onTap: () => onChanged(value + 1),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  const Icon(Icons.add_rounded, size: 14, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── PROPSURE DROPDOWN ──────────────────────────────────────────────────────
class _PropsureDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String hint;
  final String? label;
  final IconData icon;
  final ValueChanged<T?> onChanged;

  const _PropsureDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.text3)),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(color: AppColors.text3, fontSize: 13)),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(item.toString(),
                        style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
            filled: true,
            fillColor: AppColors.surface,
          ),
          dropdownColor: AppColors.surface,
        ),
      ],
    );
  }
}

// ─── SUCCESS DIALOG ───────────────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final String listingId;
  const _SuccessDialog({required this.listingId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.success, shape: BoxShape.circle),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Listing Submitted!',
              style:
                  GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Your property is now LIVE on Propsure. Tenants can find it on the home screen right now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/home');
              },
              child: const Text('See it on Home Screen →'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/listing/$listingId');
            },
            child: const Text('View My Listing'),
          ),
        ]),
      ),
    );
  }
}
