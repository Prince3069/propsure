import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/paystack_service.dart';
import '../../providers/app_providers.dart';
import 'paystack_webview_screen.dart';

// PAYMENT: Paystack only.
class BoostListingScreen extends ConsumerStatefulWidget {
  final String listingId;
  const BoostListingScreen({super.key, required this.listingId});
  @override
  ConsumerState<BoostListingScreen> createState() => _BoostListingScreenState();
}

class _BoostListingScreenState extends ConsumerState<BoostListingScreen> {
  int _plan = 1;
  bool _loading = false;
  String? _error;

  static const _plans = [
    {'days': 7,  'priceNGN': 5000,  'priceKobo': 500000,  'label': 'Starter',  'tag': ''},
    {'days': 14, 'priceNGN': 10000, 'priceKobo': 1000000, 'label': 'Standard', 'tag': 'POPULAR'},
    {'days': 30, 'priceNGN': 20000, 'priceKobo': 2000000, 'label': 'Premium',  'tag': 'BEST VALUE'},
  ];

  List<String> _benefits(int plan) {
    final base = ['⭐ Featured badge on your listing card', 'Top of search results in your area', '"Featured Listings" section on homepage'];
    if (plan >= 1) base.add('🏠 Homepage carousel placement');
    if (plan == 2) { base.add('🔔 Push to users watching your area'); base.add('📊 Boost performance analytics'); }
    return base;
  }

  Future<void> _pay() async {
    setState(() { _loading = true; _error = null; });

    final user = ref.read(currentUserModelProvider).value;
    final userId = ref.read(currentUserIdProvider);
    if (user == null || userId == null) {
      setState(() { _loading = false; _error = 'Please sign in to continue.'; });
      return;
    }

    final plan = _plans[_plan];
    final result = await PaystackService.initPayment(
      userId: userId,
      userEmail: user.email ?? '${user.phone}@propsure.temp',
      amountKobo: plan['priceKobo'] as int,
      type: 'boost',
      metadata: {
        'listingId': widget.listingId,
        'boostDays': plan['days'],
        'planLabel': plan['label'],
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
          transactionType: 'boost',
          listingTitle: 'Listing Boost — ${plan['days']} days',
        )));
    } else {
      setState(() => _error = result.error ?? 'Could not start payment. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plans[_plan];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Boost Listing', style: GoogleFonts.syne(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⭐ Boost your listing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            SizedBox(height: 5),
            Text('Boosted listings get 10× more views and 5× more enquiries.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 20),

        Text('Choose a plan', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),

        ..._plans.asMap().entries.map((e) {
          final i = e.key; final p = e.value; final sel = _plan == i;
          return GestureDetector(
            onTap: () => setState(() => _plan = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sel ? AppColors.primaryPale : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
              ),
              child: Row(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: sel ? AppColors.primary : AppColors.bg,
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: 2)),
                  child: sel ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p['label'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                      color: sel ? AppColors.primary : AppColors.text)),
                    if ((p['tag'] as String).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: i == 2 ? AppColors.gold : AppColors.primary,
                          borderRadius: BorderRadius.circular(99)),
                        child: Text(p['tag'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text('${p['days']} days boost', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₦${_fmtNGN(p['priceNGN'] as int)}',
                    style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800,
                      color: sel ? AppColors.primary : AppColors.text)),
                  Text('one-time', style: const TextStyle(fontSize: 10, color: AppColors.text3)),
                ]),
              ]),
            ),
          );
        }),

        const SizedBox(height: 8),
        // Benefits
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("What's included in ${plan['label']}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            ..._benefits(_plan).map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Container(width: 18, height: 18,
                  decoration: const BoxDecoration(color: AppColors.primaryPale, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 11, color: AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(b, style: const TextStyle(fontSize: 12, color: AppColors.text2))),
              ]),
            )),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error))),
            ]),
          ),
        ],

        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _pay,
            child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lock_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text('Pay ₦${_fmtNGN(plan['priceNGN'] as int)} Securely',
                    style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 14)),
                ]),
          )),
        const SizedBox(height: 12),
        const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.text3),
          SizedBox(width: 4),
          Text('256-bit SSL · Powered by Paystack', style: TextStyle(fontSize: 10, color: AppColors.text3)),
        ])),
        const SizedBox(height: 32),
      ]),
    );
  }

  String _fmtNGN(int n) => n >= 1000 ? '${n ~/ 1000},000' : '$n';
}
