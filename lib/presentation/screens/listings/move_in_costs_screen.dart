import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// "Know the full cost." Itemises what the agent has listed. Unknown is never
/// shown as zero: an incomplete list is headed "Known move-in subtotal +
/// unconfirmed charges", with the unconfirmed items named.
class MoveInCostsScreen extends ConsumerWidget {
  final String listingId;
  const MoveInCostsScreen({super.key, required this.listingId});

  static IconData _icon(String t) {
    switch (t) {
      case 'agency':
        return Icons.person_outline_rounded;
      case 'legal':
        return Icons.description_outlined;
      case 'caution':
        return Icons.shield_outlined;
      case 'service':
        return Icons.apartment_rounded;
      case 'utilities':
        return Icons.bolt_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listingByIdProvider(listingId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(backLabel: 'Back'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => PsError(onRetry: () => ref.invalidate(listingByIdProvider(listingId))),
        data: (l) {
          if (l == null) return const PsEmpty(icon: Icons.home_work_outlined, title: 'Home not found', message: 'This listing may have been removed.');
          final b = MoveInBreakdown.of(l);
          final upfront = l.charges.where((c) => c.isUpfront).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 24), children: [
            const PsHeadline('Know the', accent: 'full cost.', stacked: false, size: 34),
            Text('No surprises. Just clarity before you move.', style: AppText.bodyMuted),
            const SizedBox(height: 16),
            PsCard(
              padding: EdgeInsets.zero,
              child: Row(children: [
                SizedBox(width: 120, height: 96, child: PsNetImage(l.coverUrl, radius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.lg)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
                  const SizedBox(height: 4),
                  Text(l.location.area, style: AppText.small),
                ])),
                const SizedBox(width: 8),
              ]),
            ),
            const SizedBox(height: 16),
            PsCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Move-in cost breakdown', style: AppText.h3),
                const SizedBox(height: 12),
                _Row(icon: Icons.home_outlined, label: l.categoryEnum.hasMoveInCost ? 'Annual rent' : 'Price', sub: l.categoryEnum.hasMoveInCost ? '12 months' : null, amount: l.price),
                for (final c in upfront) ...[
                  const Divider(height: 24),
                  _Row(
                    icon: _icon(c.type),
                    label: c.label.isNotEmpty ? c.label : chargeTypeLabel(c.type),
                    sub: [
                      if (c.percent != null) '${c.percent!.toStringAsFixed(c.percent! % 1 == 0 ? 0 : 1)}% of annual rent' else 'Amount provided by agent',
                      recipientLabel(c.recipient),
                    ].join(' · '),
                    amount: c.amount,
                    pill: c.type == 'caution' || c.refundable != 'unknown' ? refundableLabel(c.refundable) : null,
                    pillTone: c.refundable == 'unknown' ? PsTone.warning : PsTone.success,
                  ),
                ],
                const Divider(height: 28),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.complete ? 'Move-in total' : 'Known move-in subtotal', style: AppText.h3),
                    Text(b.complete ? 'Annual rent + fees + deposit' : '+ unconfirmed charges', style: AppText.caption),
                  ])),
                  Text(Money.full(b.subtotal), style: AppText.h2.copyWith(color: AppColors.primary)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            if (!b.complete)
              PsNote(
                b.unconfirmed.isEmpty
                    ? 'The agent has not confirmed that every required charge is listed. Ask before you pay anything.'
                    : 'Not yet confirmed by the agent: ${b.unconfirmed.join(', ')}. These are not included above.',
                icon: Icons.warning_amber_rounded,
                tone: PsTone.warning,
              )
            else
              const PsNote('Fees provided by the agent. These are charges the agent listed, not a legal fee standard.'),
            if (b.recurring.isNotEmpty) ...[
              const SizedBox(height: 16),
              PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Charged every month', style: AppText.title),
                const SizedBox(height: 4),
                Text('Not included in the total above.', style: AppText.caption),
                const SizedBox(height: 10),
                for (final c in b.recurring)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                    Expanded(child: Text(c.label.isNotEmpty ? c.label : chargeTypeLabel(c.type), style: AppText.body)),
                    Text('${Money.full(c.amount)} / month', style: AppText.label),
                  ])),
              ])),
            ],
            const SizedBox(height: 16),
            const PsNote('Service charges and utilities: ask the agent. Prices can change, so confirm every amount in writing.', icon: Icons.receipt_long_outlined),
            const SizedBox(height: 20),
            PsButton('Ask about these costs', trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => openChatAbout(context, ref, l, prefill: 'Hello, please can you confirm the full move-in costs for ${l.title}, including service charge, utilities and which fees are refundable?')),
          ]);
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final double amount;
  final String? pill;
  final PsTone pillTone;
  const _Row({required this.icon, required this.label, this.sub, required this.amount, this.pill, this.pillTone = PsTone.warning});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PsIconCircle(icon, size: 44, bg: AppColors.muted, fg: AppColors.text2),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.title),
          if (sub != null) Text(sub!, style: AppText.caption),
        ])),
        Text(Money.full(amount), style: AppText.title),
      ]),
      if (pill != null) Padding(padding: const EdgeInsets.only(left: 56, top: 8), child: PsPill(pill!, tone: pillTone, small: true)),
    ]);
  }
}
