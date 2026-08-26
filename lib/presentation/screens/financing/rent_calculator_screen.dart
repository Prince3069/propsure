import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';

class RentCalculatorScreen extends ConsumerStatefulWidget {
  const RentCalculatorScreen({super.key});
  @override
  ConsumerState<RentCalculatorScreen> createState() =>
      _RentCalculatorScreenState();
}

class _RentCalculatorScreenState extends ConsumerState<RentCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _rentCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  int _months = 12;
  double _interestRate = 5.0; // % per year for financed option
  bool _showFinancing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _rentCtrl.addListener(() => setState(() {}));
    _incomeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _rentCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  double get _annualRent =>
      double.tryParse(_rentCtrl.text.replaceAll(',', '')) ?? 0;
  double get _monthlyIncome =>
      double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
  double get _monthlyRent => _annualRent / 12;
  double get _rentToIncomeRatio =>
      _monthlyIncome > 0 ? (_monthlyRent / _monthlyIncome) * 100 : 0;
  bool get _isAffordable => _rentToIncomeRatio <= 30;
  double get _recommendedMaxRent => _monthlyIncome * 0.3 * 12;

  // Financing calc
  double get _downPayment => _annualRent * 0.2; // 20% upfront
  double get _financedAmount => _annualRent - _downPayment;
  double get _monthlyPayment {
    if (_financedAmount <= 0) return 0;
    final r = _interestRate / 100 / 12;
    if (r == 0) return _financedAmount / _months;
    return _financedAmount *
        r *
        pow(1 + r, _months) /
        (pow(1 + r, _months) - 1);
  }

  double get _totalCost => _downPayment + (_monthlyPayment * _months);
  double pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) result *= base;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Rent Calculator',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Affordability'), Tab(text: 'Rent Financing')],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.text3,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_AffordabilityTab(this), _FinancingTab(this)],
      ),
    );
  }
}

class _AffordabilityTab extends StatelessWidget {
  final _RentCalculatorScreenState s;
  const _AffordabilityTab(this.s);

  @override
  Widget build(BuildContext context) {
    final ratio = s._rentToIncomeRatio;
    final affordable = s._isAffordable;

    return ListView(padding: const EdgeInsets.all(16), children: [
      _CalcField('Annual Rent (₦)', s._rentCtrl, hint: 'e.g. 1200000'),
      const SizedBox(height: 12),
      _CalcField('Monthly Income (₦)', s._incomeCtrl, hint: 'e.g. 300000'),
      const SizedBox(height: 20),
      if (s._annualRent > 0 && s._monthlyIncome > 0) ...[
        // Result card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: affordable ? AppColors.primaryPale : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: affordable
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.error.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(
                affordable
                    ? '✅ This rent is affordable'
                    : '⚠️ This may be too expensive',
                style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: affordable ? AppColors.primary : AppColors.error)),
            const SizedBox(height: 16),
            // Gauge
            ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (ratio / 50).clamp(0, 1),
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(ratio <= 30
                      ? AppColors.success
                      : ratio <= 40
                          ? AppColors.gold
                          : AppColors.error),
                  minHeight: 10,
                )),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('0%',
                  style: TextStyle(fontSize: 10, color: AppColors.text3)),
              Text('${ratio.toStringAsFixed(1)}% of income on rent',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: affordable ? AppColors.primary : AppColors.error)),
              const Text('50%',
                  style: TextStyle(fontSize: 10, color: AppColors.text3)),
            ]),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            _ResultRow('Monthly Rent', '₦${_fmt(s._monthlyRent)}'),
            _ResultRow('Monthly Income', '₦${_fmt(s._monthlyIncome)}'),
            _ResultRow('Rent-to-Income', '${ratio.toStringAsFixed(1)}%',
                color: affordable ? AppColors.success : AppColors.error),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                        affordable
                            ? 'Great! Financial experts recommend spending max 30% of income on rent.'
                            : 'Your recommended max annual rent is ₦${_fmt(s._recommendedMaxRent)}.',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.text2,
                            height: 1.4))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Monthly breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Monthly Breakdown',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Divider(height: 16),
            _ResultRow('Annual rent', '₦${_fmt(s._annualRent)}'),
            _ResultRow('Monthly rent', '₦${_fmt(s._monthlyRent)}'),
            _ResultRow('Weekly rent', '₦${_fmt(s._annualRent / 52)}'),
            _ResultRow('Daily rent', '₦${_fmt(s._annualRent / 365)}'),
          ]),
        ),
      ] else
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: const Column(children: [
            Icon(Icons.calculate_outlined, size: 44, color: AppColors.text3),
            SizedBox(height: 12),
            Text(
                'Enter rent and income above to see if this property fits your budget.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text3, fontSize: 13)),
          ]),
        ),
    ]);
  }
}

class _FinancingTab extends StatelessWidget {
  final _RentCalculatorScreenState s;
  const _FinancingTab(this.s);

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Intro
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💰 Pay Monthly, Not Yearly',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              SizedBox(height: 5),
              Text(
                  'Propsure partners with lenders so you can spread your rent across 12 months instead of paying all at once.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11, height: 1.4)),
            ]),
      ),
      const SizedBox(height: 20),

      _CalcField('Annual Rent (₦)', s._rentCtrl, hint: 'e.g. 1200000'),
      const SizedBox(height: 12),

      // Duration
      Row(children: [
        const Text('Repayment Period',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text)),
        const Spacer(),
        ...([6, 9, 12]).map((m) {
          final sel = s._months == m;
          return GestureDetector(
            onTap: () => (context as Element).markNeedsBuild(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border),
              ),
              child: Text('$m mo',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.text2)),
            ),
          );
        }),
      ]),
      const SizedBox(height: 20),

      if (s._annualRent > 0) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryPale,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text('Your Monthly Payment',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withOpacity(0.7),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('₦${_fmt(s._monthlyPayment)}',
                style: GoogleFonts.syne(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            const Text('/month for 12 months',
                style: TextStyle(color: AppColors.text3, fontSize: 12)),
            const Divider(height: 24),
            _ResultRow('Upfront payment (20%)', '₦${_fmt(s._downPayment)}'),
            _ResultRow('Financed amount', '₦${_fmt(s._financedAmount)}'),
            _ResultRow('Interest rate', '${s._interestRate}% p.a.'),
            _ResultRow('Total cost', '₦${_fmt(s._totalCost)}',
                color: s._totalCost > s._annualRent
                    ? AppColors.statusPending
                    : AppColors.success),
            _ResultRow(
                'You save upfront', '₦${_fmt(s._annualRent - s._downPayment)}',
                color: AppColors.success),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Rent financing is coming soon! We\'ll notify you.')));
              },
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              label: Text('Apply for Rent Financing',
                  style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
        const SizedBox(height: 10),
        Center(
            child: TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.handshake_outlined, size: 16),
          label: const Text('View our lending partners'),
        )),
      ] else
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: const Column(children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 44, color: AppColors.text3),
            SizedBox(height: 12),
            Text(
                'Enter the annual rent above to calculate your monthly payment plan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text3, fontSize: 13)),
          ]),
        ),
    ]);
  }
}

// ── SHARED ──────────────────────────────────────────────────────────────
class _CalcField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  const _CalcField(this.label, this.ctrl, {required this.hint});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text2)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            prefixText: '₦ ',
            prefixStyle: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ]);
}

class _ResultRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _ResultRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.text3))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.text)),
        ]),
      );
}

String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}
