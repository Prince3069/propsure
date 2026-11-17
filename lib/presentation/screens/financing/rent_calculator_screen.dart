import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/app_providers.dart';

/// Planning arithmetic only. This is not financing, a loan or an offer.
class RentPlannerScreen extends ConsumerStatefulWidget {
  const RentPlannerScreen({super.key});
  @override
  ConsumerState<RentPlannerScreen> createState() => _PlannerState();
}

class _PlannerState extends ConsumerState<RentPlannerScreen> {
  final _rent = TextEditingController();
  final _other = TextEditingController();
  final _income = TextEditingController();

  @override
  void dispose() {
    for (final c in [_rent, _other, _income]) { c.dispose(); }
    super.dispose();
  }

  int _n(TextEditingController c) => (Money.parse(c.text) ?? 0).round();

  Widget _field(String label, IconData icon, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PsField(
          label: label,
          controller: c,
          hint: '0',
          keyboardType: TextInputType.number,
          prefix: Icon(icon, color: AppColors.text2),
          suffix: Padding(padding: const EdgeInsets.only(right: 12), child: Text('NGN', style: AppText.small)),
          onChanged: (_) => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rent = _n(_rent), other = _n(_other), income = _n(_income);
    final total = rent + other;
    final monthlyEq = (rent / 12).round();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Plan your move'),
      body: ListView(padding: kPagePadding, children: [
        const PsHeadline('Know what', accent: 'you can afford.', size: 34),
        const SizedBox(height: 8),
        Text('Plan your budget, avoid surprises and find homes that fit.', style: AppText.bodyMuted),
        const SizedBox(height: 16),
        _field('Annual rent', Icons.home_outlined, _rent),
        _field('Other move-in costs', Icons.savings_outlined, _other),
        _field('Monthly income', Icons.account_balance_wallet_outlined, _income),
        PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Move-in total', style: AppText.title),
          const SizedBox(height: 4),
          Text(Money.full(total), style: AppText.h1.copyWith(fontSize: 38, color: AppColors.primary)),
          const Divider(height: 28),
          Text('Monthly rent equivalent', style: AppText.title),
          const SizedBox(height: 4),
          Text(Money.full(monthlyEq), style: AppText.h1.copyWith(fontSize: 32, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('Annual rent ÷ 12. Not a monthly payment offer.', style: AppText.small),
          if (income > 0 && rent > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('That is about ${(monthlyEq * 100 / income).round()}% of your monthly income.', style: AppText.small)),
          const SizedBox(height: 14),
          const PsNote('Keep room for transport, power and emergencies.', icon: Icons.info_outline_rounded),
        ])),
        const SizedBox(height: 16),
        PsButton('Find homes within this budget', trailingIcon: Icons.arrow_forward_rounded, onPressed: total <= 0 ? null : () {
          ref.read(listingFilterProvider.notifier).set(ListingFilter(maxMoveIn: total.toDouble()));
          context.push('/search');
        }),
        const SizedBox(height: 24),
      ]),
    );
  }
}
