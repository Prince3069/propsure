import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

/// Agent Pro: fixed 30-day access, not a subscription. It buys tools, never
/// verification or ranking certainty.
class AgentPlanScreen extends ConsumerStatefulWidget {
  const AgentPlanScreen({super.key});
  @override
  ConsumerState<AgentPlanScreen> createState() => _PlanState();
}

class _PlanState extends ConsumerState<AgentPlanScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pricing = ref.watch(pricingProvider);
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final active = user?.isPremium ?? false;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Agent tools'),
      body: pricing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(pricingProvider)),
        data: (p) {
          final pro = p.agentPro;
          Widget tick(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
                Container(width: 26, height: 26, decoration: const BoxDecoration(color: AppColors.primaryPale, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 16, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: Text(t, style: AppText.body)),
              ]));
          return Column(children: [
            Expanded(child: ListView(padding: kPagePadding, children: [
              const PsHeadline('Less admin.', accent: 'Better follow-up.', size: 34),
              const SizedBox(height: 8),
              Text('Tools to help you manage listings, leads and viewings in one place.', style: AppText.bodyMuted),
              const SizedBox(height: 16),
              PsSegmented(labels: const ['Monthly', 'Annual'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
              const SizedBox(height: 12),
              if (_tab == 1 || pro == null)
                const PsNote('Annual access is not available yet. Agent Pro is a fixed 30-day pass.', icon: Icons.info_outline_rounded)
              else
                PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const PsPill('Pilot pricing', tone: PsTone.success),
                  const SizedBox(height: 10),
                  Text('Agent Pro', style: AppText.h1),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Money.full(pro.amountNaira), style: AppText.h1.copyWith(fontSize: 40, color: AppColors.primary)),
                    const SizedBox(width: 6),
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('/ ${pro.days} days', style: AppText.bodyMuted)),
                  ]),
                  const SizedBox(height: 8),
                  tick('Up to ${p.proLimit} active listings'),
                  tick('Video-to-listing drafts'),
                  tick('Lead and inspection tracking'),
                  tick('Shareable agent storefront'),
                  const Divider(height: 24),
                  Row(children: [const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.text2), const SizedBox(width: 8), Text('Paid plans do not buy verification.', style: AppText.small)]),
                ])),
              const SizedBox(height: 12),
              PsCard(child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Free starter', style: AppText.h3), Text('Start with ${p.freeLimit} active homes.', style: AppText.small)])),
                const PsIconCircle(Icons.home_outlined, size: 48),
              ])),
              const SizedBox(height: 8),
            ])),
            PsBottomBar(row: false, children: [
              PsButton(active ? 'Extend Agent Pro' : 'Choose Agent Pro', onPressed: pro == null || _tab == 1 ? null : () => context.push('/checkout?plan=${pro.id}&label=${Uri.encodeComponent('Agent Pro')}&amount=${pro.amountNaira}')),
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(active && user?.premiumExpiresAt != null ? 'Active until ${user!.premiumExpiresAt!.day}/${user.premiumExpiresAt!.month}/${user.premiumExpiresAt!.year}. It does not renew automatically.' : 'Fixed 30-day access. It does not renew automatically.', textAlign: TextAlign.center, style: AppText.caption)),
            ]),
          ]);
        },
      ),
    );
  }
}
