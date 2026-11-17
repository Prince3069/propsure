import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../utils/format.dart';
import '../utils/freshness.dart';
import '../utils/move_in_cost.dart';
import '../../data/models/listing_model.dart';
import 'ps_widgets.dart';

export 'ps_widgets.dart';

/// Propsure wordmark: green house mark + name. No emoji, no claims.
class PropsureLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool light;
  const PropsureLogo({super.key, this.size = 36, this.showText = true, this.light = false});

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : AppColors.primary;
    return Semantics(
      label: 'Propsure',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light ? Colors.white : AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(Icons.home_rounded, size: size * 0.62, color: light ? AppColors.primary : Colors.white),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.3),
          Text('Propsure', style: AppText.h3.copyWith(color: fg, fontSize: size * 0.6, letterSpacing: -0.4)),
        ],
      ]),
    );
  }
}

/// The listing card from the mockups.
///
/// Honesty rules enforced here:
///  * "Sponsored" is shown for paid placement and is never styled as a check.
///  * Cost line says "Move-in" only when complete; otherwise "Subtotal … +
///    unconfirmed".
///  * Freshness is always dated.
///  * Location is shown as the area; precise pins are never implied.
class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  final VoidCallback? onSaveTap;
  final bool isSaved;
  final bool compact;
  final bool showMoveIn;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onSaveTap,
    this.isSaved = false,
    this.compact = false,
    this.showMoveIn = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final fresh = freshnessOf(l);
    final cost = MoveInBreakdown.of(l);
    final label = '${l.title}, ${l.priceLabel}, ${l.location.area}';
    return Semantics(
      button: true,
      label: label,
      child: PsCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        borderColor: l.isSponsored ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(
              aspectRatio: compact ? 16 / 9 : 4 / 3,
              child: PsNetImage(l.coverUrl, semanticLabel: 'Photo of ${l.title}'),
            ),
            if (l.hasVideo)
              const Positioned(left: 12, bottom: 12, child: PsPill('Video walkthrough', tone: PsTone.neutral, icon: Icons.play_arrow_rounded, small: true)),
            if (l.isSponsored)
              const Positioned(left: 12, top: 12, child: PsPill('Sponsored', tone: PsTone.warning, small: true)),
            Positioned(
              right: 8,
              top: 8,
              child: PsIconButton(
                icon: isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                tooltip: isSaved ? 'Remove from saved' : 'Save home',
                onImage: true,
                color: isSaved ? AppColors.error : AppColors.text,
                onPressed: onSaveTap,
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.priceLabel, style: AppText.h2.copyWith(color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.text2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(l.location.isApproximate ? '${l.location.area} (approximate area)' : l.location.area,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 14, runSpacing: 4, children: [
                _Fact(Icons.bed_outlined, '${l.bedrooms} bed'),
                _Fact(Icons.bathtub_outlined, '${l.bathrooms} bath'),
                if (l.toilets > 0) _Fact(Icons.wc_rounded, '${l.toilets} toilets'),
              ]),
              if (showMoveIn && l.categoryEnum.hasMoveInCost && l.charges.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(cost.cardLabel, style: AppText.label.copyWith(color: AppColors.text)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 16, color: fresh.state == Freshness.confirmed ? AppColors.primary : AppColors.goldDark),
                const SizedBox(width: 6),
                Expanded(child: Text(fresh.short, style: AppText.caption)),
                if (l.authority.isCurrent) const PsPill('Authority reviewed', small: true, icon: Icons.check_rounded),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: AppColors.text2),
        const SizedBox(width: 6),
        Text(text, style: AppText.small.copyWith(color: AppColors.text)),
      ]);
}

/// Horizontal compact card used in carousels.
class ListingMiniCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  const ListingMiniCard({super.key, required this.listing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return SizedBox(
      width: 232,
      child: PsCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        semanticLabel: '${l.title}, ${l.priceLabel}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 4 / 3, child: PsNetImage(l.coverUrl)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.priceLabel, style: AppText.title.copyWith(color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.text)),
              Text(l.location.area, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Section header with optional "See all" action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => PsSectionTitle(title, action: actionLabel, onAction: onAction);
}

/// "₦2.4m" etc. exposed for screens that only import common widgets.
String moneyShort(num v) => Money.short(v);
