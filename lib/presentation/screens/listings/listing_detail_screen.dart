import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  int _photoIdx = 0;
  bool _descExpanded = false;
  final _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _requireAuth(String action) {
    if (!ref.read(isSignedInProvider)) {
      context.push(
          '/auth?redirect=${Uri.encodeComponent('/listing/${widget.listingId}')}');
      return;
    }
    if (action == 'chat') _openChat();
    if (action == 'book') _showBookingSheet();
  }

  Future<void> _openChat() async {
    final listing = ref.read(listingByIdProvider(widget.listingId)).value;
    if (listing == null) return;
    final userId = ref.read(currentUserIdProvider)!;
    final user = ref.read(currentUserModelProvider).value;
    final chatId = await ref.read(chatRepositoryProvider).getOrCreateChat(
          userId: userId,
          agentId: listing.agentId,
          listingId: listing.id,
          userName: user?.name ?? 'User',
          agentName: listing.agentName,
          listingTitle: listing.title,
          listingThumbnail:
              listing.images.isNotEmpty ? listing.images.first : '',
        );
    if (mounted) context.push('/chat/$chatId');
  }

  void _showBookingSheet() {
    final listing = ref.read(listingByIdProvider(widget.listingId)).value;
    if (listing == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(
        listingId: listing.id,
        agentId: listing.agentId,
        listingTitle: listing.title,
      ),
    );
  }

  Future<void> _callAgent(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareListing() async {
    final listing = ref.read(listingByIdProvider(widget.listingId)).value;
    if (listing == null) return;
    final shareUrl = 'https://propsure.app/listing/${listing.id}';
    final text = '${listing.title}\n${listing.location.fullAddress}\n$shareUrl';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Property link copied. You can paste it anywhere to share.')),
    );
    final whatsapp = Uri.https('wa.me', '/', {'text': text});
    if (await canLaunchUrl(whatsapp)) {
      await launchUrl(whatsapp, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openListingLocation(dynamic listing) async {
    final lat = listing.location.latitude as double;
    final lng = listing.location.longitude as double;
    final query = '$lat,$lng';
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _toggleSave() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _requireAuth('save');
      return;
    }
    final savedIds =
        ref.read(currentUserModelProvider).value?.savedListings ?? [];
    final isSaved = savedIds.contains(widget.listingId);
    final repo = ref.read(listingRepositoryProvider);
    if (isSaved) {
      await repo.unsaveListing(userId: userId, listingId: widget.listingId);
    } else {
      await repo.saveListing(userId: userId, listingId: widget.listingId);
    }
  }

  // ─── DELETE LISTING ───
  Future<void> _deleteListing() async {
    final listing = ref.read(listingByIdProvider(widget.listingId)).value;
    if (listing == null) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to delete this listing')),
      );
      return;
    }

    final user = ref.read(currentUserModelProvider).value;
    final isOwner = listing.agentId == userId;
    final isAdmin = user?.role == 'admin';

    if (!isOwner && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You do not have permission to delete this listing')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this listing?'),
            const SizedBox(height: 8),
            Text(
              listing.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All images and data will be permanently removed.',
              style: TextStyle(fontSize: 12, color: AppColors.text3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final repo = ref.read(listingRepositoryProvider);
    await repo.deleteListing(widget.listingId, listing.agentId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing deleted successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(listingByIdProvider(widget.listingId));
    final isSignedIn = ref.watch(isSignedInProvider);
    final savedIds =
        ref.watch(currentUserModelProvider).value?.savedListings ?? [];
    final isSaved = savedIds.contains(widget.listingId);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return listingAsync.when(
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Listing not found')),
          );
        }

        final userId = ref.read(currentUserIdProvider);
        final user = ref.read(currentUserModelProvider).value;
        final canEdit = (userId != null && listing.agentId == userId) ||
            (user?.role == 'admin');
        final canDelete = canEdit;

        if (isDesktop) {
          return _DesktopLayout(
            listing: listing,
            isSaved: isSaved,
            isSignedIn: isSignedIn,
            onSave: _toggleSave,
            onShare: _shareListing,
            onOpenLocation: () => _openListingLocation(listing),
            onChat: () => _requireAuth('chat'),
            onBook: () => _requireAuth('book'),
            onCall: () => _callAgent(listing.agentPhone),
            onDelete: canDelete ? _deleteListing : null,
            onEdit: canEdit
                ? () => context.push('/listing/edit/${listing.id}')
                : null,
            descExpanded: _descExpanded,
            onExpandDesc: () => setState(() => _descExpanded = !_descExpanded),
            photoIdx: _photoIdx,
            pageCtrl: _pageCtrl,
            onPageChanged: (i) => setState(() => _photoIdx = i),
          );
        }

        return _MobileLayout(
          listing: listing,
          isSaved: isSaved,
          isSignedIn: isSignedIn,
          onSave: _toggleSave,
          onShare: _shareListing,
          onOpenLocation: () => _openListingLocation(listing),
          onChat: () => _requireAuth('chat'),
          onBook: () => _requireAuth('book'),
          onCall: () => _callAgent(listing.agentPhone),
          onDelete: canDelete ? _deleteListing : null,
          onEdit: canEdit
              ? () => context.push('/listing/edit/${listing.id}')
              : null,
          descExpanded: _descExpanded,
          onExpandDesc: () => setState(() => _descExpanded = !_descExpanded),
          photoIdx: _photoIdx,
          pageCtrl: _pageCtrl,
          onPageChanged: (i) => setState(() => _photoIdx = i),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
    );
  }
}

// ─── MOBILE LAYOUT ──────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final dynamic listing;
  final bool isSaved, isSignedIn, descExpanded;
  final VoidCallback onSave,
      onShare,
      onOpenLocation,
      onChat,
      onBook,
      onCall,
      onExpandDesc;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final int photoIdx;
  final PageController pageCtrl;
  final ValueChanged<int> onPageChanged;

  const _MobileLayout({
    required this.listing,
    required this.isSaved,
    required this.isSignedIn,
    required this.onSave,
    required this.onShare,
    required this.onOpenLocation,
    required this.onChat,
    required this.onBook,
    required this.onCall,
    required this.descExpanded,
    required this.onExpandDesc,
    this.onDelete,
    this.onEdit,
    required this.photoIdx,
    required this.pageCtrl,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        CustomScrollView(slivers: [
          _PhotoSliver(
            listing: listing,
            isSaved: isSaved,
            onSave: onSave,
            onShare: onShare,
            onDelete: onDelete,
            onEdit: onEdit,
            photoIdx: photoIdx,
            pageCtrl: pageCtrl,
            onPageChanged: onPageChanged,
          ),
          SliverToBoxAdapter(
              child: _DetailBody(
            listing: listing,
            descExpanded: descExpanded,
            onExpandDesc: onExpandDesc,
            onOpenLocation: onOpenLocation,
            onCall: onCall,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ]),
        Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ActionBar(
              isSignedIn: isSignedIn,
              onChat: onChat,
              onBook: onBook,
              onCall: onCall,
            )),
      ]),
    );
  }
}

// ─── DESKTOP LAYOUT ──────────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final dynamic listing;
  final bool isSaved, isSignedIn, descExpanded;
  final VoidCallback onSave,
      onShare,
      onOpenLocation,
      onChat,
      onBook,
      onCall,
      onExpandDesc;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final int photoIdx;
  final PageController pageCtrl;
  final ValueChanged<int> onPageChanged;

  const _DesktopLayout({
    required this.listing,
    required this.isSaved,
    required this.isSignedIn,
    required this.onSave,
    required this.onShare,
    required this.onOpenLocation,
    required this.onChat,
    required this.onBook,
    required this.onCall,
    required this.descExpanded,
    required this.onExpandDesc,
    this.onDelete,
    this.onEdit,
    required this.photoIdx,
    required this.pageCtrl,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title:
            Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              onPressed: onDelete,
            ),
          IconButton(
              icon: const Icon(Icons.share_outlined), onPressed: onShare),
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? AppColors.primary : null,
            ),
            onPressed: onSave,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 3,
            child: SingleChildScrollView(
                child: Column(children: [
              _DesktopGallery(
                  images: listing.images as List<String>,
                  photoIdx: photoIdx,
                  onSelect: onPageChanged),
              _DetailBody(
                  listing: listing,
                  descExpanded: descExpanded,
                  onExpandDesc: onExpandDesc,
                  onOpenLocation: onOpenLocation,
                  onCall: onCall),
              const SizedBox(height: 32),
            ]))),
        SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _StickyPanel(
                  listing: listing,
                  isSignedIn: isSignedIn,
                  onChat: onChat,
                  onBook: onBook,
                  onCall: onCall),
            )),
      ]),
    );
  }
}

// ─── PHOTO SLIVER APP BAR ─────────────────────────────────────────────────
class _PhotoSliver extends StatelessWidget {
  final dynamic listing;
  final bool isSaved;
  final VoidCallback onSave, onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final int photoIdx;
  final PageController pageCtrl;
  final ValueChanged<int> onPageChanged;

  const _PhotoSliver({
    required this.listing,
    required this.isSaved,
    required this.onSave,
    required this.onShare,
    this.onDelete,
    this.onEdit,
    required this.photoIdx,
    required this.pageCtrl,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final images = listing.images as List<String>;
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.surface,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.black54,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 19),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        // ── Edit Button ──
        if (onEdit != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 19),
                onPressed: onEdit,
              ),
            ),
          ),
        // ── Delete Button ──
        if (onDelete != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.red.withOpacity(0.15),
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 19),
                onPressed: onDelete,
              ),
            ),
          ),
        // ── Share Button ──
        Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: Colors.white, size: 19),
              onPressed: () {
                HapticFeedback.lightImpact();
                onShare();
              },
            ),
          ),
        ),
        // ── Save Button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
          child: GestureDetector(
            onTap: onSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.sm,
              ),
              child: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isSaved ? AppColors.primary : AppColors.text2,
                size: 16,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(children: [
          images.isEmpty
              ? Container(
                  color: AppColors.primaryPale2,
                  child: const Center(
                      child: Icon(Icons.home_outlined,
                          size: 64, color: AppColors.text3)))
              : PageView.builder(
                  controller: pageCtrl,
                  itemCount: images.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: images[i].trim(),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _DetailImageFallback(),
                    errorWidget: (_, __, ___) => const _DetailImageFallback(),
                  ),
                ),
          // Photo counter
          if (images.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_camera_outlined,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    '${photoIdx + 1}/${images.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ),
          // Badges on image
          Positioned(
            bottom: 16,
            left: 16,
            child: Row(children: [
              if (listing.isFeatured)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.goldDark, AppColors.gold]),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Featured',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              if (listing.isFeatured && listing.isVerified)
                const SizedBox(width: 8),
              if (listing.isVerified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Verified',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── DESKTOP GALLERY ─────────────────────────────────────────────────────
class _DesktopGallery extends StatelessWidget {
  final List<String> images;
  final int photoIdx;
  final ValueChanged<int> onSelect;

  const _DesktopGallery({
    required this.images,
    required this.photoIdx,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      images.isEmpty
          ? Container(
              height: 360,
              color: AppColors.primaryPale2,
              child: const Center(
                  child: Icon(Icons.home_outlined,
                      size: 64, color: AppColors.text3)))
          : Stack(children: [
              CachedNetworkImage(
                imageUrl: images[photoIdx].trim(),
                height: 360,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _DetailImageFallback(),
                errorWidget: (_, __, ___) => const _DetailImageFallback(),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Row(children: [
                  if (images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${photoIdx + 1}/${images.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ]),
              ),
            ]),
      if (images.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
            height: 80,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: i == photoIdx
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: images[i].trim(),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _DetailImageFallback(),
                      errorWidget: (_, __, ___) => const _DetailImageFallback(),
                    ),
                  ),
                ),
              ),
            )),
      ],
    ]);
  }
}

// ─── DETAIL BODY ─────────────────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  final dynamic listing;
  final bool descExpanded;
  final VoidCallback onExpandDesc, onOpenLocation, onCall;

  const _DetailBody({
    required this.listing,
    required this.descExpanded,
    required this.onExpandDesc,
    required this.onOpenLocation,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final amentities = listing.amenities as List<String>;
    return Container(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Price + Status ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtPrice(listing.price),
                      style: GoogleFonts.syne(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text('/year',
                        style: TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ),
                const Spacer(),
                _StatusPill(listing.status as String),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Title ──
          Text(listing.title, style: t.headlineMedium),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 15, color: AppColors.text3),
            const SizedBox(width: 3),
            Expanded(
                child: Text(
              listing.location.fullAddress as String,
              style: t.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )),
          ]),
          const SizedBox(height: 16),

          // ── Feature chips ──
          Wrap(spacing: 8, runSpacing: 8, children: [
            _FeatChip(Icons.bed_outlined, '${listing.bedrooms} Bedrooms'),
            _FeatChip(Icons.bathtub_outlined, '${listing.bathrooms} Bathrooms'),
            _FeatChip(Icons.wc_outlined, '${listing.toilets} Toilets'),
            _FeatChip(Icons.home_outlined, listing.propertyType as String),
            if (listing.isFurnished == true)
              _FeatChip(Icons.chair_outlined, 'Furnished'),
            if (listing.parkingAvailable == true)
              _FeatChip(Icons.local_parking_outlined, 'Parking'),
            if (listing.petsAllowed == true)
              _FeatChip(Icons.pets_outlined, 'Pets OK'),
          ]),
          const Divider(height: 24),

          // ── About ──
          Text('About this property', style: t.titleLarge),
          const SizedBox(height: 8),
          Text(
            listing.description as String,
            maxLines: descExpanded ? null : 4,
            overflow: descExpanded ? null : TextOverflow.ellipsis,
            style: t.bodyMedium,
          ),
          if ((listing.description as String).length > 200)
            GestureDetector(
              onTap: onExpandDesc,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  descExpanded ? 'Show less' : 'Read more',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ),

          // ── Amenities ──
          if (amentities.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Amenities', style: t.titleLarge),
            const SizedBox(height: 10),
            Wrap(
                spacing: 7,
                runSpacing: 7,
                children: amentities
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(a,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ))
                    .toList()),
          ],
          const Divider(height: 24),

          // ── Map ──
          Text('Location', style: t.titleLarge),
          const SizedBox(height: 10),
          _LocationCard(
            listing: listing,
            onOpenLocation: onOpenLocation,
          ),
          const Divider(height: 24),

          // ── Agent ──
          Text('Listed by', style: t.titleLarge),
          const SizedBox(height: 10),
          _AgentCard(listing: listing, onCall: onCall),
          if (listing.isVerified == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.verified_rounded,
                    color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'This listing has been verified by Propsure for authenticity.',
                  style: TextStyle(color: AppColors.success, fontSize: 12),
                )),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DetailImageFallback extends StatelessWidget {
  const _DetailImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryPale2,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: AppColors.text3, size: 36),
          SizedBox(height: 6),
          Text('Image unavailable',
              style: TextStyle(color: AppColors.text3, fontSize: 10)),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final dynamic listing;
  final VoidCallback onOpenLocation;

  const _LocationCard({required this.listing, required this.onOpenLocation});

  @override
  Widget build(BuildContext context) {
    final lat = listing.location.latitude as double;
    final lng = listing.location.longitude as double;
    final hasCoordinates = lat != 0 && lng != 0;
    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryPale2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          if (hasCoordinates)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('listing-${listing.id}'),
                  position: LatLng(lat, lng),
                  infoWindow:
                      InfoWindow(title: listing.location.area as String),
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              liteModeEnabled: true,
            )
          else
            Center(
              child: Text(
                listing.location.area as String,
                style: const TextStyle(
                  color: AppColors.text2,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      listing.location.fullAddress as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onOpenLocation,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.open_in_new_rounded,
                          color: Colors.white, size: 17),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.text2),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
        ]),
      );
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final configs = {
      'active': (AppColors.success, const Color(0xFFDCFCE7)),
      'rented': (AppColors.statusRented, const Color(0xFFF3E8FF)),
      'pending': (AppColors.statusPending, const Color(0xFFFEF3C7)),
    };
    final (fg, bg) = configs[status] ?? (AppColors.text3, AppColors.bg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: fg,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final dynamic listing;
  final VoidCallback onCall;

  const _AgentCard({required this.listing, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryPale2,
          backgroundImage:
              listing.agentPhoto != null && listing.agentPhoto!.isNotEmpty
                  ? NetworkImage(listing.agentPhoto!)
                  : null,
          child: (listing.agentPhoto == null || listing.agentPhoto!.isEmpty)
              ? Text(
                  (listing.agentName as String).isNotEmpty
                      ? (listing.agentName as String)[0].toUpperCase()
                      : 'A',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(
              listing.agentName as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.text),
            ),
            const SizedBox(width: 4),
            if (listing.isVerified)
              const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 14),
          ]),
          const Text('Property Agent',
              style: TextStyle(fontSize: 10, color: AppColors.text3)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.star_rounded, color: AppColors.goldStar, size: 12),
            const SizedBox(width: 3),
            const Text('4.9 · 47 reviews',
                style: TextStyle(fontSize: 10, color: AppColors.text3)),
          ]),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Text(
              '✓ Verified Agent',
              style: TextStyle(
                  fontSize: 9,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ])),
        GestureDetector(
          onTap: onCall,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary]),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.call_rounded, color: Colors.white, size: 19),
          ),
        ),
      ]),
    );
  }
}

// ─── ACTION BAR ──────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final bool isSignedIn;
  final VoidCallback onCall, onChat, onBook;

  const _ActionBar({
    required this.isSignedIn,
    required this.onCall,
    required this.onChat,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onCall,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary]),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.call_rounded, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton.icon(
          onPressed: onChat,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
          label: Text(isSignedIn ? 'Chat' : 'Sign in to chat'),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12)),
        )),
        const SizedBox(width: 8),
        Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onBook,
              icon: const Icon(Icons.calendar_today_rounded, size: 15),
              label: Text(
                isSignedIn ? 'Book Inspection' : 'Sign in to book',
                style:
                    GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )),
      ]),
    );
  }
}

// ─── STICKY SIDE PANEL (Desktop) ─────────────────────────────────────────
class _StickyPanel extends StatelessWidget {
  final dynamic listing;
  final bool isSignedIn;
  final VoidCallback onCall, onChat, onBook;

  const _StickyPanel({
    required this.listing,
    required this.isSignedIn,
    required this.onCall,
    required this.onChat,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.lg,
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _fmtPrice(listing.price),
                  style: GoogleFonts.syne(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
                const Text('/year',
                    style: TextStyle(fontSize: 11, color: AppColors.text3)),
              ]),
              const Spacer(),
              _StatusPill(listing.status as String),
            ]),
            const SizedBox(height: 18),
            if (!isSignedIn) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.goldDark, size: 15),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Sign in to contact agent or book a tour',
                    style: TextStyle(color: AppColors.goldDark, fontSize: 12),
                  )),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onBook,
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: Text(
                    'Book Inspection Tour',
                    style: GoogleFonts.syne(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                )),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                label: const Text('Chat'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onCall,
                style:
                    OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                child: const Icon(Icons.call_rounded, size: 20),
              ),
            ]),
          ]),
    );
  }
}

// ─── BOOKING SHEET ────────────────────────────────────────────────────────
class _BookingSheet extends ConsumerStatefulWidget {
  final String listingId, agentId, listingTitle;

  const _BookingSheet({
    required this.listingId,
    required this.agentId,
    required this.listingTitle,
  });

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  final _msgCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }
    setState(() => _loading = true);
    final userId = ref.read(currentUserIdProvider)!;
    final user = ref.read(currentUserModelProvider).value!;
    final dt = DateTime(
        _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    await ref.read(bookingRepositoryProvider).createBooking(
          listingId: widget.listingId,
          agentId: widget.agentId,
          userId: userId,
          userName: user.name,
          userPhone: user.phone,
          listingTitle: widget.listingTitle,
          dateTime: dt,
          message: _msgCtrl.text.trim(),
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Inspection request sent! Agent will confirm shortly.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final times = [
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 10, minute: 0),
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 12, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 17, minute: 0),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: ListView(controller: ctrl, children: [
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 18),
          Text('Book Inspection Tour',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 3),
          Text(
            widget.listingTitle,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Text('Select Date', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = now.add(Duration(days: i + 1));
                  final sel = _date?.day == d.day && _date?.month == d.month;
                  return GestureDetector(
                    onTap: () => setState(() => _date = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              days[d.weekday - 1],
                              style: TextStyle(
                                  fontSize: 9,
                                  color:
                                      sel ? Colors.white70 : AppColors.text3),
                            ),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: sel ? Colors.white : AppColors.text),
                            ),
                            Text(
                              months[d.month - 1],
                              style: TextStyle(
                                  fontSize: 9,
                                  color:
                                      sel ? Colors.white70 : AppColors.text3),
                            ),
                          ]),
                    ),
                  );
                },
              )),
          const SizedBox(height: 18),
          Text('Select Time', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: times.map((t) {
                final sel = _time?.hour == t.hour && _time?.minute == t.minute;
                return GestureDetector(
                  onTap: () => setState(() => _time = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      t.format(context),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.text),
                    ),
                  ),
                );
              }).toList()),
          const SizedBox(height: 18),
          TextField(
            controller: _msgCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message to agent (optional)',
              hintText: 'Any questions or special requests?',
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _book,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Send Inspection Request',
                      style: GoogleFonts.syne(
                          fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }
}

String _fmtPrice(double price) {
  if (price >= 1000000) {
    return '₦${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)}M';
  }
  if (price >= 1000) {
    return '₦${(price / 1000).toStringAsFixed(0)}k';
  }
  return '₦${price.toStringAsFixed(0)}';
}
