import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/paystack_service.dart';
import '../../providers/app_providers.dart';
import 'paystack_webview_screen.dart';

// PAYMENT: Paystack only — no other payment processors.
// All payments go through paystack_service.dart → Cloud Functions.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  int _billing = 0; // 0=monthly 1=yearly
  int _selectedPlan = 0;
  bool _loading = false;
  String? _error;

  static const _plans = [
    {
      'name': 'Agent Pro',
      'monthlyNGN': 10000, 'monthlyKobo': 1000000,
      'yearlyNGN': 100000, 'yearlyKobo': 10000000,
      'planId': 'agent_pro',
      'color': AppColors.primary,
      'tag': '',
      'features': [
        'Verified Agent badge on profile',
        'Up to 20 active listings',
        '2 free listing boosts per month',
        'Analytics dashboard',
        'Priority in search results',
        'Unlimited tenant chats',
      ],
    },
    {
      'name': 'Agent Elite',
      'monthlyNGN': 25000, 'monthlyKobo': 2500000,
      'yearlyNGN': 250000, 'yearlyKobo': 25000000,
      'planId': 'agent_elite',
      'color': AppColors.gold,
      'tag': 'BEST VALUE',
      'features': [
        'Everything in Pro',
        'Unlimited active listings',
        '10 free boosts per month',
        'Homepage featured slot',
        'Platform-certified badge',
        'Dedicated account manager',
        'Lead tracking CRM',
        'WhatsApp integration',
      ],
    },
  ];

  Future<void> _subscribe(Map<String, dynamic> plan) async {
    setState(() { _loading = true; _error = null; });

    final user = ref.read(currentUserModelProvider).value;
    final userId = ref.read(currentUserIdProvider);
    if (user == null || userId == null) {
      setState(() { _loading = false; _error = 'Please sign in to continue.'; });
      return;
    }

    final amountKobo = _billing == 0
        ? plan['monthlyKobo'] as int
        : plan['yearlyKobo'] as int;
    final amountNGN = _billing == 0
        ? plan['monthlyNGN'] as int
        : plan['yearlyNGN'] as int;

    final result = await PaystackService.initPayment(
      userId: userId,
      userEmail: user.email ?? '${user.phone}@propsure.temp',
      amountKobo: amountKobo,
      type: 'premium',
      metadata: {
        'planId': plan['planId'],
        'planName': plan['name'],
        'billing': _billing == 0 ? 'monthly' : 'yearly',
        'userId': userId,
      },
    );

    setState(() => _loading = false);
    if (!mounted) return;

    if (result.success && result.checkoutUrl != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) =>
        PaystackWebviewScreen(
          checkoutUrl: result.checkoutUrl!,
          reference: result.reference!,
          transactionType: 'premium',
          listingTitle: '${plan['name']} — ${_billing == 0 ? 'Monthly' : 'Yearly'}',
        )));
    } else {
      setState(() => _error = result.error ?? 'Could not start payment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Premium Plans', style: GoogleFonts.syne(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4881C), AppColors.gold]),
            borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Go Premium', style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              const Text('More visibility. More deals. More income.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        // Billing toggle
        Container(
          height: 44,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
          child: Row(children: [
            _BillingOption('Monthly', _billing == 0, () => setState(() => _billing = 0)),
            _BillingOption('Yearly · 2 months FREE', _billing == 1, () => setState(() => _billing = 1), isYearly: true),
          ]),
        ),
        const SizedBox(height: 16),

        ..._plans.asMap().entries.map((e) {
          final i = e.key; final plan = e.value;
          final isElite = i == 1;
          final color = plan['color'] as Color;
          final priceNGN = _billing == 0 ? plan['monthlyNGN'] as int : plan['yearlyNGN'] as int;
          final features = plan['features'] as List<String>;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isElite ? AppColors.gold : AppColors.border, width: isElite ? 2 : 1),
              boxShadow: isElite ? [BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))] : [],
            ),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(isElite ? 0.1 : 0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17))),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((plan['tag'] as String).isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(99)),
                        child: Text(plan['tag'] as String, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
                      const SizedBox(height: 4),
                    ],
                    Text(plan['name'] as String, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  ]),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₦${_fmt(priceNGN)}', style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
                    Text(_billing == 0 ? '/month' : '/year', style: TextStyle(fontSize: 11, color: color.withOpacity(0.6))),
                  ]),
                ]),
              ),
              // Features
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 12, color: AppColors.text2))),
                  ]),
                )).toList()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _subscribe(plan),
                    style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.lock_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Subscribe Securely', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
                        ]),
                  )),
              ),
            ]),
          );
        }),

        if (_error != null) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withOpacity(0.2))),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
        ),

        const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.text3),
          SizedBox(width: 4),
          Text('256-bit SSL · Secured by Paystack · Cancel anytime', style: TextStyle(fontSize: 10, color: AppColors.text3)),
        ])),
        const SizedBox(height: 40),
      ]),
    );
  }

  String _fmt(int p) {
    if (p >= 100000) return '${(p / 1000).toStringAsFixed(0)},000';
    if (p >= 1000) return '${p ~/ 1000},000';
    return '$p';
  }
}

class _BillingOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isYearly;
  const _BillingOption(this.label, this.selected, this.onTap, {this.isYearly = false});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9)),
      child: Center(child: Text(label,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: isYearly ? 11 : 13,
          color: selected ? Colors.white : AppColors.text2))),
    ),
  ));
}
