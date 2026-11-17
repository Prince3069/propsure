import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/listing_category.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../../services/functions_service.dart';
import '../../../services/location_service.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// One screen for "Add a home" and "Edit home" (same components, as in the
/// mockups). New homes go Media → Details → Costs → Review. Editing shows the
/// same sections as tabs. Everything is saved as a DRAFT first; going live is
/// a server action that checks the plan limit, media and availability.
class AddListingScreen extends ConsumerStatefulWidget {
  final String? editListingId;
  const AddListingScreen({super.key, this.editListingId});
  @override
  ConsumerState<AddListingScreen> createState() => _State();
}

class _State extends ConsumerState<AddListingScreen> {
  int _step = 0;
  bool _loading = false;
  bool _busy = false;
  double _progress = 0;
  String _progressLabel = '';
  String? _error;
  ListingModel? _existing;
  bool _dirty = false;

  // media
  final List<String> _existingImages = [];
  final List<XFile> _newPhotos = [];
  XFile? _video;

  // details
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _street = TextEditingController();
  ListingCategory _cat = ListingCategory.rent;
  String _type = 'Flat / Apartment';
  String _area = 'Gwarinpa';
  int _beds = 2, _baths = 2, _toilets = 2;
  final Set<String> _amenities = {};
  bool _furnished = false, _pets = false, _parking = false;

  // costs
  List<ListingCharge> _charges = [];
  bool _chargesComplete = false;
  final _unconfirmed = TextEditingController();

  // review
  bool _availabilityOk = false;

  bool get _editing => widget.editListingId != null;
  static const _stepLabels = ['Media', 'Details', 'Costs', 'Review'];

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
    for (final c in [_title, _desc, _price, _street, _unconfirmed]) {
      c.addListener(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _street, _unconfirmed]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final l = await ref.read(listingRepositoryProvider).getById(widget.editListingId!);
    if (!mounted) return;
    if (l != null) {
      _existing = l;
      _title.text = l.title;
      _desc.text = l.description;
      _price.text = l.price > 0 ? l.price.round().toString() : '';
      _street.text = l.location.street;
      _cat = l.categoryEnum;
      _type = AppConstants.propertyTypes.any((t) => t['label'] == l.propertyType) ? l.propertyType : _type;
      _area = AppConstants.abujaAreas.contains(l.location.area) ? l.location.area : _area;
      _beds = l.bedrooms; _baths = l.bathrooms; _toilets = l.toilets;
      _amenities..clear()..addAll(l.amenities);
      _furnished = l.isFurnished; _pets = l.petsAllowed; _parking = l.parkingAvailable;
      _charges = [...l.charges];
      _chargesComplete = l.chargesComplete;
      _unconfirmed.text = l.unconfirmedCharges.join(', ');
      _existingImages..clear()..addAll(l.images);
    }
    setState(() { _loading = false; _dirty = false; });
  }

  // ── media pickers ────────────────────────────────────────────────────────
  Future<void> _pickVideo(ImageSource src) async {
    try {
      final x = await ImagePicker().pickVideo(source: src, maxDuration: const Duration(minutes: 5));
      if (x == null) return;
      final size = await File(x.path).length();
      if (size > 300 * 1024 * 1024) {
        setState(() => _error = 'That video is larger than 300 MB. Choose a shorter walkthrough.');
        return;
      }
      setState(() { _video = x; _error = null; _dirty = true; });
    } catch (_) {
      setState(() => _error = 'We could not open the camera or gallery. Check app permissions in Settings.');
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final xs = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (xs.isEmpty) return;
      setState(() {
        final room = 15 - _existingImages.length - _newPhotos.length;
        _newPhotos.addAll(xs.take(room < 0 ? 0 : room));
        _dirty = true;
      });
    } catch (_) {
      setState(() => _error = 'We could not open your photos. Check app permissions in Settings.');
    }
  }

  // ── charges ──────────────────────────────────────────────────────────────
  Future<void> _addCharge({ListingCharge? edit, int? index}) async {
    final amount = TextEditingController(text: edit == null ? '' : edit.amount.round().toString());
    final label = TextEditingController(text: edit?.label ?? '');
    String type = edit?.type ?? 'agency';
    ChargePeriod period = edit?.period ?? ChargePeriod.oneTime;
    String refundable = edit?.refundable ?? 'unknown';
    String recipient = edit?.recipient ?? 'agent';
    final result = await showModalBottomSheet<ListingCharge>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(edit == null ? 'Add a charge' : 'Edit charge', style: AppText.h3),
              const SizedBox(height: 14),
              PsDropdown<String>(label: 'Type', value: type, items: const ['agency', 'legal', 'caution', 'service', 'utilities', 'other'], itemLabel: chargeTypeLabel, onChanged: (v) => set(() => type = v ?? type)),
              const SizedBox(height: 12),
              PsField(label: 'Name (optional)', controller: label, hint: 'e.g. Agreement fee'),
              const SizedBox(height: 12),
              PsField(label: 'Amount (₦)', controller: amount, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 12),
              PsDropdown<ChargePeriod>(label: 'How often', value: period, items: ChargePeriod.values, itemLabel: (p) => p == ChargePeriod.oneTime ? 'Once, at move-in' : p == ChargePeriod.annual ? 'Every year' : 'Every month', onChanged: (v) => set(() => period = v ?? period)),
              const SizedBox(height: 12),
              PsDropdown<String>(label: 'Refundable?', value: refundable, items: const ['yes', 'no', 'unknown'], itemLabel: (v) => v == 'yes' ? 'Yes' : v == 'no' ? 'No' : 'Not sure yet', onChanged: (v) => set(() => refundable = v ?? refundable)),
              const SizedBox(height: 12),
              PsDropdown<String>(label: 'Paid to', value: recipient, items: const ['agent', 'landlord', 'management', 'other'], itemLabel: (v) => v[0].toUpperCase() + v.substring(1), onChanged: (v) => set(() => recipient = v ?? recipient)),
              const SizedBox(height: 18),
              PsButton('Save charge', onPressed: () {
                final a = double.tryParse(amount.text);
                if (a == null) return;
                Navigator.pop(ctx, ListingCharge(type: type, label: label.text.trim().isEmpty ? chargeTypeLabel(type) : label.text.trim(), amount: a, period: period, refundable: refundable, recipient: recipient));
              }),
            ]),
          ),
        );
      }),
    );
    if (result != null) {
      setState(() {
        if (index == null) { _charges.add(result); } else { _charges[index] = result; }
        _dirty = true;
      });
    }
  }

  // ── build + save ─────────────────────────────────────────────────────────
  String? _validateForDraft() {
    if (_title.text.trim().length < 3) return 'Give your listing a title first.';
    return null;
  }

  ListingModel _model(String uid, String name, String phone, String? photo) {
    final price = Money.parse(_price.text) ?? 0;
    final loc = LocationService();
    final b = AreaBoundsLookup.centre(_area);
    final map = loc.buildLocationMap(
      latitude: b.$1,
      longitude: b.$2,
      area: _area,
      street: _street.text.trim().isEmpty ? null : _street.text.trim(),
      fullAddress: [if (_street.text.trim().isNotEmpty) _street.text.trim(), _area, 'Abuja'].join(', '),
    );
    return ListingModel(
      id: widget.editListingId ?? '',
      title: _title.text.trim(),
      description: _desc.text.trim(),
      price: price,
      propertyType: _type,
      bedrooms: _beds,
      bathrooms: _baths,
      toilets: _toilets,
      location: PropertyLocation.fromMap({...map, 'locationPrecision': 'approximate'}),
      images: _existingImages,
      agentId: uid,
      agentName: name,
      agentPhone: phone,
      agentPhoto: photo,
      category: _cat.value,
      charges: _cat.hasMoveInCost ? _charges : const [],
      chargesComplete: _cat.hasMoveInCost && _chargesComplete,
      unconfirmedCharges: _unconfirmed.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      createdAt: _existing?.createdAt ?? DateTime.now(),
      amenities: _amenities.toList(),
      isFurnished: _furnished,
      petsAllowed: _pets,
      parkingAvailable: _parking,
    );
  }

  Future<void> _save({required bool publish}) async {
    final user = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) return;
    final err = _validateForDraft();
    if (err != null) {
      setState(() { _error = err; _step = _editing ? 1 : 1; });
      return;
    }
    if (publish && !_availabilityOk) {
      setState(() => _error = 'Please confirm that this home is still available.');
      return;
    }
    setState(() { _busy = true; _error = null; _progress = 0; _progressLabel = 'Saving your details…'; });
    final repo = ref.read(listingRepositoryProvider);
    String? id = widget.editListingId;
    try {
      final model = _model(user.uid, user.displayName, user.phone, user.profilePhoto);
      id = await repo.saveDraft(model, existingId: id);

      // photos
      final urls = <String>[];
      for (var i = 0; i < _newPhotos.length; i++) {
        setState(() { _progressLabel = 'Uploading photo ${i + 1} of ${_newPhotos.length}…'; _progress = i / (_newPhotos.length + (_video != null ? 1 : 0)); });
        urls.add(await repo.uploadImage(_newPhotos[i].path, id, i));
      }
      if (urls.isNotEmpty) {
        _existingImages.addAll(urls);
        _newPhotos.clear();
        await repo.updateListing(id, {'images': _existingImages});
      }

      // video original → private path; the media worker does the rest
      bool videoSent = false;
      if (_video != null) {
        final task = repo.uploadOriginalVideo(listingId: id, ownerUid: user.uid, path: _video!.path);
        task.snapshotEvents.listen((s) {
          if (!mounted || s.totalBytes == 0) return;
          setState(() { _progress = s.bytesTransferred / s.totalBytes; _progressLabel = 'Uploading your walkthrough… ${(100 * s.bytesTransferred / s.totalBytes).round()}%'; });
        });
        await task;
        _video = null;
        videoSent = true;
      }

      if (publish && (_existing == null || _existing!.isDraft)) {
        setState(() => _progressLabel = 'Going live…');
        await ref.read(functionsServiceProvider).publishListing(id);
        if (!mounted) return;
        showPsSnack(context, 'Your home is live. Availability confirmed today.');
        context.go('/my-listings');
        return;
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      showPsSnack(context, videoSent ? 'Saved. Your video is processing; we will tell you when frames are ready to review.' : (_editing ? 'Changes saved.' : 'Draft saved.'));
      context.go('/my-listings');
    } on AppException catch (e) {
      _failed(e.message, id);
    } catch (e) {
      _failed(e.toString().replaceFirst('Exception: ', ''), id);
    }
  }

  void _failed(String message, String? id) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = id == null ? message : 'Your draft is saved, but: $message';
    });
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty || _busy) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text('You have changes that are not saved.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep editing')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave'))],
      ),
    );
    return r == true;
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = ref.watch(currentUserModelProvider).asData?.value;
    if (user != null && !user.isAgent) {
      return Scaffold(
        appBar: const PsTopBar(title: 'Add a home'),
        body: PsEmpty(icon: Icons.lock_outline_rounded, title: 'Use a listing account', message: 'Your account is set up for renting. Create an account as a landlord or agent to list homes.', actionLabel: 'Back', onAction: () => context.pop()),
      );
    }
    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: PsTopBar(
          title: _editing ? 'Edit home' : 'Add a home',
          action: Padding(padding: const EdgeInsets.only(right: 8), child: PsLink('Save draft', underline: false, onTap: _busy ? null : () => _save(publish: false))),
        ),
        bottomNavigationBar: _busy ? null : _bottom(),
        body: _busy
            ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
                LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                const SizedBox(height: 16),
                Text(_progressLabel, textAlign: TextAlign.center, style: AppText.body),
                const SizedBox(height: 8),
                Text('Keep this screen open until it finishes.', style: AppText.caption),
              ])))
            : ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 4, AppSpace.gutter, 24), children: [
                if (_editing)
                  PsSegmented(labels: const ['Media', 'Details', 'Costs', 'Availability'], index: _step, onChanged: (i) => setState(() => _step = i))
                else
                  PsSteps(labels: _stepLabels, current: _step),
                const SizedBox(height: 20),
                if (_error != null) ...[PsNote(_error!, icon: Icons.error_outline_rounded, tone: PsTone.warning), const SizedBox(height: 16)],
                [_media, _details, _costs, _editing ? _availability : _review][_step](),
              ]),
      ),
    );
  }

  Widget? _bottom() {
    final last = _editing ? _step == 3 : _step == 3;
    return PsBottomBar(row: false, children: [
      if (_editing)
        PsButton('Save changes', onPressed: () => _save(publish: false))
      else if (!last)
        PsButton('Continue', onPressed: () => setState(() { _error = null; _step++; }))
      else
        PsButton('Publish', onPressed: () => _save(publish: true)),
      if (!_editing && _step > 0) PsButton('Back', kind: PsButtonKind.ghost, onPressed: () => setState(() { _error = null; _step--; })),
    ]);
  }

  Widget _media() {
    final hasStills = _existing?.videoStatus == VideoStatus.needsReview;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Start with your walkthrough', style: AppText.display.copyWith(fontSize: 30)),
      const SizedBox(height: 8),
      Text('A single video helps renters understand your home. We suggest real frames from it for you to review.', style: AppText.bodyMuted),
      const SizedBox(height: 16),
      if (hasStills) ...[
        PsNote('Your video is ready. Review the suggested frames before they are shown.', icon: Icons.photo_library_outlined),
        const SizedBox(height: 8),
        PsButton('Review video stills', kind: PsButtonKind.outline, onPressed: () => context.push('/listing/${_existing!.id}/frames')),
        const SizedBox(height: 16),
      ],
      if (_existing != null && _existing!.videoStatus != VideoStatus.none && !hasStills)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: PsNote('Video status: ${_existing!.videoStatus.name}', icon: Icons.videocam_outlined)),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border2, width: 1.4)),
        child: Column(children: [
          const Icon(Icons.videocam_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(_video == null ? 'Upload a video' : 'Video chosen', style: AppText.h3),
          const SizedBox(height: 4),
          Text(_video == null ? "We'll suggest real photos from your video." : _video!.name, textAlign: TextAlign.center, style: AppText.small),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: PsButton('Choose video', onPressed: () => _pickVideo(ImageSource.gallery))),
            const SizedBox(width: 10),
            Expanded(child: PsButton('Record tour', kind: PsButtonKind.outline, onPressed: () => _pickVideo(ImageSource.camera))),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Center(child: Text('Or add photos instead', style: AppText.label.copyWith(color: AppColors.primary))),
      const SizedBox(height: 10),
      if (_existingImages.isNotEmpty || _newPhotos.isNotEmpty)
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < _existingImages.length; i++) _thumb(PsNetImage(_existingImages[i], width: 96, height: 96, radius: BorderRadius.circular(12)), () => setState(() { _existingImages.removeAt(i); _dirty = true; })),
            for (var i = 0; i < _newPhotos.length; i++) _thumb(ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_newPhotos[i].path), width: 96, height: 96, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 96, height: 96))), () => setState(() { _newPhotos.removeAt(i); _dirty = true; })),
          ]),
        ),
      const SizedBox(height: 8),
      PsButton('Add photos (${_existingImages.length + _newPhotos.length}/15)', kind: PsButtonKind.outline, icon: Icons.add_photo_alternate_outlined, onPressed: _pickPhotos),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final t in const [(Icons.home_outlined, 'Show every room', 'Include all key spaces, inside and out.'), (Icons.wb_sunny_outlined, 'Film slowly in daylight', 'Keep the camera steady.'), (Icons.privacy_tip_outlined, 'Avoid people and private documents', 'Keep the video on the home.')])
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(children: [Icon(t.$1, size: 28), const SizedBox(height: 6), Text(t.$2, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.text, fontWeight: FontWeight.w700)), Text(t.$3, textAlign: TextAlign.center, style: AppText.caption)]))),
      ]),
      const SizedBox(height: 16),
      const PsNote('Your original is preserved privately. Frames taken from your video are labelled as video stills.', icon: Icons.lock_outline_rounded),
    ]);
  }

  Widget _thumb(Widget child, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(children: [child, Positioned(right: 2, top: 2, child: InkWell(onTap: onRemove, child: const CircleAvatar(radius: 14, backgroundColor: Colors.white, child: Icon(Icons.close_rounded, size: 18))))]),
      );

  Widget _details() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PsField(label: 'Listing title', controller: _title, maxLength: 80, hint: '2-bedroom flat in Gwarinpa'),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: PsDropdown<ListingCategory>(label: 'Category', value: _cat, items: ListingCategory.values, itemLabel: (c) => c.label, onChanged: (v) => setState(() { _cat = v ?? _cat; _dirty = true; }))),
        const SizedBox(width: 12),
        Expanded(child: PsDropdown<String>(label: 'Property type', value: _type, items: [for (final t in AppConstants.propertyTypes) t['label']!], itemLabel: (s) => s, onChanged: (v) => setState(() { _type = v ?? _type; _dirty = true; }))),
      ]),
      const SizedBox(height: 14),
      PsField(label: _cat == ListingCategory.rent || _cat == ListingCategory.commercial ? 'Annual rent (₦)' : _cat == ListingCategory.shortStay ? 'Price per night (₦)' : 'Sale price (₦)', controller: _price, keyboardType: TextInputType.number, hint: '2400000', helper: 'The period is shown automatically from the category.'),
      const SizedBox(height: 14),
      Text('Rooms', style: AppText.label),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: PsStepper(label: 'Beds', value: _beds, onChanged: (v) => setState(() { _beds = v; _dirty = true; }))),
        const SizedBox(width: 8),
        Expanded(child: PsStepper(label: 'Baths', value: _baths, onChanged: (v) => setState(() { _baths = v; _dirty = true; }))),
      ]),
      const SizedBox(height: 14),
      PsDropdown<String>(label: 'Area', value: _area, items: AppConstants.abujaAreas, itemLabel: (s) => s, onChanged: (v) => setState(() { _area = v ?? _area; _dirty = true; })),
      const SizedBox(height: 12),
      PsField(label: 'Street or estate (optional)', controller: _street, helper: 'Renters see an approximate area, not your exact address.'),
      const SizedBox(height: 14),
      Text('Amenities', style: AppText.label),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in AppConstants.amenities) PsCheckTile(a, value: _amenities.contains(a), onChanged: (v) => setState(() { v ? _amenities.add(a) : _amenities.remove(a); _dirty = true; })),
      ]),
      const SizedBox(height: 14),
      PsField(label: 'Description', controller: _desc, maxLines: 5, maxLength: 500, hint: 'Describe the home honestly: condition, light, neighbourhood.'),
      const SizedBox(height: 8),
      PsToggleRow(title: 'Furnished', value: _furnished, onChanged: (v) => setState(() { _furnished = v; _dirty = true; })),
      PsToggleRow(title: 'Pets allowed', value: _pets, onChanged: (v) => setState(() { _pets = v; _dirty = true; })),
      PsToggleRow(title: 'Parking available', value: _parking, onChanged: (v) => setState(() { _parking = v; _dirty = true; })),
      if (_editing) const Padding(padding: EdgeInsets.only(top: 8), child: PsNote('Changes to details that were checked may need review.')),
    ]);
  }

  Widget _costs() {
    if (!_cat.hasMoveInCost) {
      return const PsNote('Move-in charges apply to rentals and commercial lets. For this category the price is shown as entered.');
    }
    final price = Money.parse(_price.text) ?? 0;
    final upfront = _charges.where((c) => c.isUpfront).fold<double>(0, (a, c) => a + c.amount);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Know the full cost', style: AppText.h1),
      const SizedBox(height: 6),
      Text('List every charge a renter must pay to move in. Unknown is not zero: anything you leave out is shown as unconfirmed.', style: AppText.bodyMuted),
      const SizedBox(height: 14),
      PsCard(child: Column(children: [
        Row(children: [Expanded(child: Text('Annual rent', style: AppText.body)), Text(Money.full(price), style: AppText.title)]),
        for (var i = 0; i < _charges.length; i++) ...[
          const Divider(height: 20),
          InkWell(
            onTap: () => _addCharge(edit: _charges[i], index: i),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_charges[i].label, style: AppText.body),
                Text('${_charges[i].period == ChargePeriod.monthly ? 'Every month' : _charges[i].period == ChargePeriod.annual ? 'Every year' : 'Once'} · ${refundableLabel(_charges[i].refundable)}', style: AppText.caption),
              ])),
              Text(Money.full(_charges[i].amount), style: AppText.title),
              PsIconButton(icon: Icons.close_rounded, tooltip: 'Remove ${_charges[i].label}', size: 40, onPressed: () => setState(() { _charges.removeAt(i); _dirty = true; })),
            ]),
          ),
        ],
        const Divider(height: 24),
        Row(children: [Expanded(child: Text(_chargesComplete && _unconfirmed.text.trim().isEmpty ? 'Move-in total' : 'Known move-in subtotal', style: AppText.title)), Text(Money.full(price + upfront), style: AppText.title.copyWith(color: AppColors.primary))]),
      ])),
      const SizedBox(height: 12),
      PsButton('Add a charge', kind: PsButtonKind.outline, icon: Icons.add_rounded, onPressed: () => _addCharge()),
      const SizedBox(height: 14),
      PsToggleRow(title: 'I have listed every required charge', subtitle: 'Only switch this on if nothing else must be paid to move in.', value: _chargesComplete, onChanged: (v) => setState(() { _chargesComplete = v; _dirty = true; })),
      const SizedBox(height: 8),
      PsField(label: 'Charges you are not sure about (optional)', controller: _unconfirmed, hint: 'e.g. Service charge, utilities', helper: 'Separate with commas. Renters will see these as unconfirmed.'),
    ]);
  }

  Widget _review() {
    final price = Money.parse(_price.text) ?? 0;
    final photos = _existingImages.length + _newPhotos.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Review', style: AppText.h1),
      const SizedBox(height: 12),
      PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_title.text.isEmpty ? 'Untitled home' : _title.text, style: AppText.h3),
        Text('$_area, Abuja · $_type', style: AppText.small),
        const SizedBox(height: 8),
        Text(Money.withPeriod(price, _cat), style: AppText.h2.copyWith(color: AppColors.primary)),
        const SizedBox(height: 8),
        Text('$_beds bed · $_baths bath · ${_amenities.length} amenities', style: AppText.small),
        Text(_video != null ? 'Video: ready to upload' : 'Video: none chosen', style: AppText.small),
        Text('Photos: $photos', style: AppText.small),
        Text(_cat.hasMoveInCost ? (_chargesComplete && _unconfirmed.text.trim().isEmpty ? 'Costs: complete' : 'Costs: shown as subtotal + unconfirmed') : 'Costs: not applicable', style: AppText.small),
      ])),
      const SizedBox(height: 12),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _availabilityOk,
        onChanged: (v) => setState(() => _availabilityOk = v ?? false),
        title: Text('I confirm this home is available today.', style: AppText.title),
        subtitle: Text('Renters see the date you confirmed. You will be asked to refresh it every 7 days.', style: AppText.caption),
      ),
      const PsNote('Publishing does not mark a home as checked. Authority and identity checks are separate and optional.', icon: Icons.info_outline_rounded),
    ]);
  }

  Widget _availability() {
    final l = _existing;
    if (l == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Availability', style: AppText.h1),
      const SizedBox(height: 8),
      Text(l.availabilityConfirmedAt == null ? 'Not confirmed yet.' : 'Last confirmed ${relativeDays(l.availabilityConfirmedAt!)}.', style: AppText.bodyMuted),
      const SizedBox(height: 16),
      if (l.isLive) PsButton('Still available: confirm today', onPressed: () async {
        final ok = await runAction(context, () => ref.read(functionsServiceProvider).confirmAvailability(l.id), success: 'Availability confirmed.');
        if (ok && mounted) context.pop();
      }),
      const SizedBox(height: 10),
      if (l.isLive) PsButton('Pause this listing', kind: PsButtonKind.outline, onPressed: () async { final ok = await runAction(context, () => ref.read(functionsServiceProvider).setListingStatus(l.id, 'paused'), success: 'Paused. Renters no longer see it.'); if (ok && mounted) context.pop(); }),
      const SizedBox(height: 10),
      if (l.isLive) PsButton('Mark as rented', kind: PsButtonKind.outline, onPressed: () async { final ok = await runAction(context, () => ref.read(functionsServiceProvider).setListingStatus(l.id, 'rented'), success: 'Marked as rented.'); if (ok && mounted) context.pop(); }),
    ]);
  }
}

/// Area centre used as an APPROXIMATE position. Exact pins are never implied.
class AreaBoundsLookup {
  static (double, double) centre(String area) {
    final b = LocationService().getAreaBounds(area);
    if (b == null) return (AppConstants.abujaLat, AppConstants.abujaLng);
    return (b.centerLat, b.centerLng);
  }
}
