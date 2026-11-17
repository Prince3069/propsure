import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../services/functions_service.dart';
import '../../providers/app_providers.dart';

/// Paid placement. Always labelled Sponsored in search; never implies
/// verification or guaranteed enquiries.
class BoostListingScreen extends ConsumerStatefulWidget {
  final String listingId;
  const BoostListingScreen({super.key, required this.listingId});
  @override
  ConsumerState<BoostListingScreen> createState() => _BoostState();
}

class _BoostState extends ConsumerState<BoostListingScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(listingByIdProvider(widget.listingId)).asData?.value;
    final pricing = ref.watch(pricingProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Promote a listing'),
      body: pricing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            PsError(onRetry: () => ref.invalidate(pricingProvider)),
        data: (p) {
          final boosts = p.boosts;
          final sel = boosts
              .where((b) =>
                  b.id ==
                  (_selected ?? (boosts.isNotEmpty ? boosts.first.id : '')))
              .toList();
          final chosen = sel.isEmpty ? null : sel.first;
          final blocked = l != null && (!l.isLive || l.safetyHold);
          return Column(children: [
            Expanded(
                child: ListView(padding: kPagePadding, children: [
              const PsHeadline('Reach more',
                  accent: 'relevant renters.', size: 34),
              const SizedBox(height: 8),
              Text('Promoted placements are labelled Sponsored.',
                  style: AppText.bodyMuted),
              const SizedBox(height: 16),
              if (l != null)
                PsCard(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: SizedBox(
                              width: 110,
                              height: 96,
                              child: PsNetImage(l.coverUrl))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(l.title,
                                style: AppText.h3,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Text('${l.location.area}, Abuja',
                                style: AppText.small),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.event_available_outlined,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(freshnessOf(l).short,
                                      style: AppText.small.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)))
                            ]),
                          ])),
                    ])),
              if (blocked)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: PsNote(
                        'Only live listings that are not under review can be promoted.',
                        tone: PsTone.warning,
                        icon: Icons.info_outline_rounded)),
              const SizedBox(height: 20),
              Text('PILOT PRICING',
                  style: AppText.caption.copyWith(
                      letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < boosts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                      child: _Option(
                          opt: boosts[i],
                          selected: chosen?.id == boosts[i].id,
                          onTap: () =>
                              setState(() => _selected = boosts[i].id))),
                ],
              ]),
              const SizedBox(height: 14),
              const PsNote('Placement is paid. Enquiries are not guaranteed.',
                  icon: Icons.info_outline_rounded),
              const SizedBox(height: 14),
              PsLink('See placement rules',
                  chevron: true,
                  onTap: () => context.push('/info/how-checks-work')),
            ])),
            PsBottomBar(children: [
              PsButton('Continue to payment',
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: (chosen == null || blocked || l == null)
                      ? null
                      : () => context.push(
                          '/checkout?plan=${chosen.id}&listing=${l.id}&label=${Uri.encodeComponent('Promote: ${l.title}')}&amount=${chosen.amountNaira}')),
            ]),
          ]);
        },
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final PriceOption opt;
  final bool selected;
  final VoidCallback onTap;
  const _Option(
      {required this.opt, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '${opt.days} days, ${Money.full(opt.amountNaira)}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: selected ? AppColors.primaryPale : AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 2 : 1)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${opt.days} days', style: AppText.h3)),
                Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? AppColors.primary : AppColors.text3)
              ]),
              const SizedBox(height: 8),
              Text(Money.full(opt.amountNaira),
                  style: AppText.h1
                      .copyWith(fontSize: 26, color: AppColors.primary)),
              const SizedBox(height: 8),
              Text('Your listing will be promoted for ${opt.days} days.',
                  style: AppText.small),
            ]),
          ),
        ),
      );
}
