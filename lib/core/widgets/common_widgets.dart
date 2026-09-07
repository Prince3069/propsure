import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../../data/models/listing_model.dart';

// ─── PROPSURE LOGO ─────────────────────────────────────────────────────────
class PropsureLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool light;
  const PropsureLogo(
      {super.key, this.size = 32, this.showText = true, this.light = false});

  @override
  Widget build(BuildContext context) {
    final textColor = light ? Colors.white : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light ? Colors.white.withOpacity(0.9) : AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.24),
          ),
          child: Center(
            child: Text('🏡', style: TextStyle(fontSize: size * 0.52)),
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.28),
          Text('Propsure',
              style: GoogleFonts.syne(
                fontSize: size * 0.6,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.4,
              )),
        ],
      ],
    );
  }
}

// ─── PREMIUM LISTING CARD ──────────────────────────────────────────────────
class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  final VoidCallback? onSaveTap;
  final bool isSaved;
  final bool compact;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onSaveTap,
    this.isSaved = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: listing.isFeatured
                ? AppColors.gold.withOpacity(0.4)
                : AppColors.border,
            width: listing.isFeatured ? 1.5 : 1,
          ),
          boxShadow: listing.isFeatured ? AppShadows.gold : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardImage(
                listing: listing, onSaveTap: onSaveTap, isSaved: isSaved),
            _CardBody(listing: listing, compact: compact),
          ],
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onSaveTap;
  final bool isSaved;
  const _CardImage(
      {required this.listing, this.onSaveTap, required this.isSaved});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: listing.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: listing.images.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _ImgPlaceholder(),
                    errorWidget: (_, __, ___) => _ImgPlaceholder(),
                  )
                : _ImgPlaceholder(),
          ),
        ),
        // Top-left badges
        Positioned(
          top: 8,
          left: 8,
          child: Row(
            children: [
              if (listing.isFeatured) _FeatBadge(),
              if (listing.isVerified && !listing.isFeatured) _VeriBadge(),
              if (listing.isFeatured) const SizedBox(width: 6),
              if (listing.isFeatured && listing.isVerified) _VeriBadge(),
            ],
          ),
        ),
        // "Just Listed" badge (if created within 7 days)
        if (listing.createdAt
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
          Positioned(
            top: 8,
            left: listing.isFeatured || listing.isVerified ? 120 : 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        // 360 badge
        if (listing.videoUrl != null || listing.video360Url != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 11),
                  SizedBox(width: 3),
                  Text(
                    '360°',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Photo count
        if (listing.images.length > 1)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    '${listing.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Save button with animation
        if (onSaveTap != null)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onSaveTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.sm,
                ),
                child: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 16,
                  color: isSaved ? AppColors.primary : AppColors.text3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  final ListingModel listing;
  final bool compact;
  const _CardBody({required this.listing, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price row
          Row(
            children: [
              Text(
                _fmtPrice(listing.price),
                style: GoogleFonts.syne(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              _StatusBadge(listing.status),
            ],
          ),
          const SizedBox(height: 2),
          // Title
          Text(
            listing.title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          // Location
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 12, color: AppColors.text3),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  listing.location.area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.text3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Agent + Features row
          Row(
            children: [
              // Agent avatar
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primaryPale2,
                backgroundImage:
                    listing.agentPhoto != null && listing.agentPhoto!.isNotEmpty
                        ? NetworkImage(listing.agentPhoto!)
                        : null,
                child:
                    (listing.agentPhoto == null || listing.agentPhoto!.isEmpty)
                        ? Text(
                            listing.agentName.isNotEmpty
                                ? listing.agentName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          listing.agentName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (listing.isVerified) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.verified_rounded,
                            size: 10,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const Text(
                      'Agent',
                      style: TextStyle(
                        fontSize: 8,
                        color: AppColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              // Features icons
              _Feat(Icons.bed_outlined, '${listing.bedrooms}'),
              const SizedBox(width: 6),
              _Feat(Icons.bathtub_outlined, '${listing.bathrooms}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feat(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.text2),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.text2),
          ),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final configs = {
      'active': (AppColors.success, const Color(0xFFDCFCE7)),
      'rented': (AppColors.statusRented, const Color(0xFFF3E8FF)),
      'pending': (AppColors.statusPending, const Color(0xFFFEF3C7)),
      'expired': (AppColors.statusExpired, const Color(0xFFF3F4F6)),
    };
    final (fg, bg) = configs[status] ?? (AppColors.text3, AppColors.bg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 7,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FeatBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.goldDark, AppColors.gold],
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: Colors.white, size: 9),
            SizedBox(width: 3),
            Text(
              'Featured',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _VeriBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 9),
            SizedBox(width: 3),
            Text(
              'Verified',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _ImgPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primaryPale2,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined,
                  color: AppColors.text3, size: 30),
              SizedBox(height: 5),
              Text(
                'Image unavailable',
                style: TextStyle(color: AppColors.text3, fontSize: 9),
              ),
            ],
          ),
        ),
      );
}

// ─── SECTION HEADER ────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  const SectionHeader(
      {super.key, required this.title, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryPale,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                'See All',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── CATEGORY GRID ITEM ────────────────────────────────────────────────────
class CategoryItem extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final VoidCallback? onTap;
  const CategoryItem(
      {super.key,
      required this.icon,
      required this.label,
      required this.count,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryPale2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '$count items',
              style: const TextStyle(fontSize: 9, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EMPTY STATE ────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primaryPale,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.text3),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── SKELETON CARD ─────────────────────────────────────────────────────────
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});
  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(AppColors.bg, AppColors.border, _anim.value)!;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 80,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 11,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 10,
                      width: 120,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── PRICE FORMATTER ───────────────────────────────────────────────────────
String _fmtPrice(double price) {
  if (price >= 1000000) {
    final m = price / 1000000;
    return '₦${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}M';
  }
  if (price >= 1000) {
    return '₦${(price / 1000).toStringAsFixed(0)}k';
  }
  return '₦${price.toStringAsFixed(0)}';
}

// ─── GOLD BADGE (NEW) ─────────────────────────────────────────────────────
class GoldBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final double size;

  const GoldBadge({
    super.key,
    required this.label,
    this.icon,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldDark, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.gold,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: size * 0.7),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.7,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RESPONSIVE GRID ──────────────────────────────────────────────────────
class ResponsiveGrid extends StatelessWidget {
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final List<Widget> children;
  final double? childAspectRatio;

  const ResponsiveGrid({
    super.key,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
    required this.children,
    this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio ?? 0.74,
      ),
      itemCount: children.length,
      itemBuilder: (_, i) => children[i],
    );
  }
}
