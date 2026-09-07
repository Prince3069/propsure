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
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/listing_model.dart';
import '../../../services/location_service.dart';
import '../../providers/app_providers.dart';

class EditListingScreen extends ConsumerStatefulWidget {
  final String listingId;
  const EditListingScreen({super.key, required this.listingId});

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  // ── Existing listing data ──
  ListingModel? _listing;
  bool _loading = true;
  bool _saving = false;

  // ── Photos step ─────────────────────────────────────────────
  List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  List<String> _imagesToDelete = [];

  // ── Location step ────────────────────────────────────────────
  String? _area;
  String? _city;
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

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    final listing =
        await ref.read(listingRepositoryProvider).getById(widget.listingId);
    if (listing == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing not found')),
        );
        context.go('/home');
      }
      return;
    }

    // Check if user is the owner
    final userId = ref.read(currentUserIdProvider);
    final user = ref.read(currentUserModelProvider).value;
    final isOwner = listing.agentId == userId;
    final isAdmin = user?.role == 'admin';

    if (!isOwner && !isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You do not have permission to edit this listing')),
        );
        context.go('/home');
      }
      return;
    }

    setState(() {
      _listing = listing;
      _loading = false;

      // Populate fields
      _titleCtrl.text = listing.title;
      _descCtrl.text = listing.description;
      _priceCtrl.text = listing.price.toStringAsFixed(0);
      _propertyType = listing.propertyType;
      _category = listing.category;
      _bedrooms = listing.bedrooms;
      _bathrooms = listing.bathrooms;
      _toilets = listing.toilets;
      _furnished = listing.isFurnished;
      _petsAllowed = listing.petsAllowed;
      _parkingAvailable = listing.parkingAvailable;
      _amenities = List.from(listing.amenities);

      _area = listing.location.area;
      _city = listing.location.city;
      _selectedPin =
          LatLng(listing.location.latitude, listing.location.longitude);
      _addressCtrl.text = listing.location.street ?? '';
      _existingImageUrls = List.from(listing.images);
    });
  }

  // ── Image picker ──
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 75);
    if (picked.isNotEmpty) {
      setState(() => _newImages.addAll(picked));
    }
  }

  Future<void> _removeExistingImage(int index) async {
    setState(() {
      _imagesToDelete.add(_existingImageUrls[index]);
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _removeNewImage(int index) async {
    setState(() => _newImages.removeAt(index));
  }

  // ── Submit ──
  Future<void> _saveChanges() async {
    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill Title and Price'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    if (_area == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select an area'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);

    final repo = ref.read(listingRepositoryProvider);

    // ── Step 1: Delete removed images ──
    for (final imageUrl in _imagesToDelete) {
      await repo.deleteImage(imageUrl);
    }

    // ── Step 2: Upload new images ──
    final newImageUrls = <String>[];
    int existingCount = _existingImageUrls.length;
    for (int i = 0; i < _newImages.length; i++) {
      final url = await repo.uploadImage(
          _newImages[i].path, widget.listingId, existingCount + i);
      newImageUrls.add(url);
    }

    // ── Step 3: Update Firestore ──
    final allImages = [..._existingImageUrls, ...newImageUrls];

    final location = PropertyLocation(
      latitude: _selectedPin?.latitude ?? 0,
      longitude: _selectedPin?.longitude ?? 0,
      geohash: _selectedPin != null
          ? GeoFirePoint(
                  GeoPoint(_selectedPin!.latitude, _selectedPin!.longitude))
              .geohash
          : '',
      area: _area!,
      city: _city ?? 'Abuja (FCT)',
      street: _addressCtrl.text.trim(),
      fullAddress: _addressCtrl.text.trim().isNotEmpty
          ? '${_addressCtrl.text.trim()}, $_area, ${_city ?? 'Abuja (FCT)'}'
          : '$_area, ${_city ?? 'Abuja (FCT)'}',
    );

    await repo.updateListing(widget.listingId, {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
      'propertyType': _propertyType ?? 'Flat / Apartment',
      'category': _category ?? 'For Rent',
      'location': location.toMap(),
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'toilets': _toilets,
      'isFurnished': _furnished,
      'petsAllowed': _petsAllowed,
      'parkingAvailable': _parkingAvailable,
      'amenities': _amenities,
      'images': allImages,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Listing updated successfully!'),
            backgroundColor: AppColors.success),
      );
      context.go('/listing/${widget.listingId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Listing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Listing')),
        body: const Center(child: Text('Listing not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Edit Listing',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveChanges,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save',
                    style: GoogleFonts.syne(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontSize: 14)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photos Section ──
            Text('Photos',
                style: GoogleFonts.syne(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Tap on any photo to remove it. Add new photos below.',
                style: TextStyle(fontSize: 12, color: AppColors.text3)),
            const SizedBox(height: 12),

            // Existing photos
            if (_existingImageUrls.isNotEmpty) ...[
              const Text('Existing Photos',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2)),
              const SizedBox(height: 6),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _existingImageUrls[i],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: AppColors.bg,
                            child: const Icon(Icons.broken_image,
                                color: AppColors.text3),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(i),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                      if (i == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Cover',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // New photos
            if (_newImages.isNotEmpty) ...[
              const Text('New Photos',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2)),
              const SizedBox(height: 6),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(_newImages[i].path),
                            width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeNewImage(i),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Add photos button
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.primary,
                      style: BorderStyle.solid,
                      width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primaryPale,
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.primary, size: 28),
                    SizedBox(height: 4),
                    Text('Add More Photos',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Details Section ──
            const Divider(),
            const SizedBox(height: 16),

            Text('Property Details',
                style: GoogleFonts.syne(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // Title
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Listing Title *',
                hintText: 'e.g. 3 Bedroom Duplex at River Park',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 14),

            // Description
            TextField(
              controller: _descCtrl,
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

            // Price
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Price (₦) per year *',
                prefixIcon: Icon(Icons.attach_money_rounded),
                suffixText: '/year',
              ),
            ),
            const SizedBox(height: 14),

            // Category
            _PropsureDropdown<String>(
              value: _category,
              items: const [
                'For Rent',
                'For Sale',
                'Short Stay',
                'Lease',
                'Joint Venture'
              ],
              hint: 'Select category',
              icon: Icons.category_outlined,
              label: 'CATEGORY *',
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 14),

            // Property type
            _PropsureDropdown<String>(
              value: _propertyType,
              items: const [
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
              ],
              hint: 'Select type',
              icon: Icons.home_outlined,
              label: 'PROPERTY TYPE *',
              onChanged: (v) => setState(() => _propertyType = v),
            ),
            const SizedBox(height: 20),

            // Rooms
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
                value: _bedrooms,
                onChanged: (v) => setState(() => _bedrooms = v),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _RoomCounter(
                icon: Icons.bathtub_outlined,
                label: 'Bathrooms',
                value: _bathrooms,
                onChanged: (v) => setState(() => _bathrooms = v),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _RoomCounter(
                icon: Icons.wc_outlined,
                label: 'Toilets',
                value: _toilets,
                onChanged: (v) => setState(() => _toilets = v),
              )),
            ]),
            const SizedBox(height: 20),

            // Extras
            Row(children: [
              Expanded(
                  child: CheckboxListTile(
                value: _furnished,
                onChanged: (v) => setState(() => _furnished = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: const Text('Furnished', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
              )),
              Expanded(
                  child: CheckboxListTile(
                value: _petsAllowed,
                onChanged: (v) => setState(() => _petsAllowed = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: const Text('Pets OK', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
              )),
            ]),
            CheckboxListTile(
              value: _parkingAvailable,
              onChanged: (v) => setState(() => _parkingAvailable = v ?? false),
              contentPadding: EdgeInsets.zero,
              title: const Text('Parking Available',
                  style: TextStyle(fontSize: 13)),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
            ),
            const SizedBox(height: 16),

            // Amenities
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
              children: AppConstants.amenities.map((a) {
                final on = _amenities.contains(a);
                return GestureDetector(
                  onTap: () {
                    final updated = List<String>.from(_amenities);
                    if (on) {
                      updated.remove(a);
                    } else {
                      updated.add(a);
                    }
                    setState(() => _amenities = updated);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: on ? AppColors.primary : AppColors.border),
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
            const SizedBox(height: 20),

            // ── Location Section ──
            const Divider(),
            const SizedBox(height: 16),

            Text('Location',
                style: GoogleFonts.syne(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // City
            _PropsureDropdown<String>(
              value: _city,
              items: AppConstants.nigeriaCities,
              hint: 'Select city',
              icon: Icons.location_city_outlined,
              label: 'CITY',
              onChanged: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: 14),

            // Area
            _PropsureDropdown<String>(
              value: _area,
              items: AppConstants.abujaAreas.skip(1).toList(),
              hint: 'Select area',
              icon: Icons.near_me_outlined,
              label: 'AREA *',
              onChanged: (v) => setState(() => _area = v),
            ),
            const SizedBox(height: 14),

            // Address
            TextField(
              controller: _addressCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Full Address (Optional)',
                hintText: 'e.g. 12 River Park Estate',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Map pin
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PIN PROPERTY LOCATION',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.text3)),
                  const SizedBox(height: 6),
                  Container(
                    height: 160,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPale2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedPin ??
                            const LatLng(
                                AppConstants.abujaLat, AppConstants.abujaLng),
                        zoom: 14,
                      ),
                      markers: _selectedPin != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selected-property'),
                                position: _selectedPin!,
                              ),
                            }
                          : {},
                      onTap: (pos) => setState(() => _selectedPin = pos),
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      liteModeEnabled: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Tap the map to update the property pin location.',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.text3)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveChanges,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Save Changes',
                        style: GoogleFonts.syne(
                            fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
