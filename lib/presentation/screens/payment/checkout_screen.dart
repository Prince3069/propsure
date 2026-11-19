import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../services/paystack_service.dart';
import '../../providers/app_providers.dart';

const String _callbackHost = 'propsure.africa';

/// Checkout for marketplace tools only (never rent or deposits). The paid
/// state is decided by the server after Paystack verification, never by
/// this screen.
class CheckoutScreen extends ConsumerStatefulWidget {
  final String planId;
  final String? listingId;
  final String label;
  final int amountNaira;
  const CheckoutScreen({super.key, required this.planId, this.listingId, required this.label, required this.amountNaira});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<CheckoutScreen> {
  final _email = TextEditingController();
  bool _busy = false, _seeded = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final uid = ref.read(currentUserIdProvider);
    final email = _email.text.trim();
    if (uid == null) { context.push('/auth?redirect=/plan'); return; }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) { setState(() => _error = 'Enter a valid email address for your receipt.'); return; }
    setState(() { _busy = true; _error = null; });
    final init = await PaystackService.initPayment(
      userId: uid,
      userEmail: email,
      planId: widget.planId,
      metadata: {if (widget.listingId != null) 'listingId': widget.listingId},
    );
    if (!mounted) return;
    if (!init.success || init.checkoutUrl == null) {
      setState(() { _busy = false; _error = init.error ?? 'Could not start payment.'; });
      return;
    }
    final ref0 = init.reference ?? '';
    if (kIsWeb) {
      // On the website Paystack's page replaces this one, then returns to
      // /payment/callback, which asks the server to verify the payment.
      final ok = await launchUrl(Uri.parse(init.checkoutUrl!), webOnlyWindowName: '_self');
      if (!mounted) return;
      if (!ok) setState(() { _busy = false; _error = 'We could not open the payment page. Please try again.'; });
      return;
    }
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _PayPage(url: init.checkoutUrl!, reference: ref0)));
    if (!mounted) return;
    setState(() => _busy = false);
    if (done == true) {
      showPsSnack(context, 'Payment confirmed.');
      context.go(widget.listingId != null ? '/my-listings' : '/workspace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    if (user != null && !_seeded) { _seeded = true; _email.text = user.email ?? ''; }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Checkout'),
      body: ListView(padding: kPagePadding, children: [
        Text('Marketplace tools only', style: AppText.small),
        const SizedBox(height: 6),
        const PsHeadline('Power your', accent: 'property business.', size: 34),
        const SizedBox(height: 8),
        Text('Get access to agent tools and manage listings, leads and more once payment is confirmed.', style: AppText.bodyMuted),
        const SizedBox(height: 16),
        PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Order summary', style: AppText.h3),
          const SizedBox(height: 12),
          Row(children: [
            const PsIconCircle(Icons.person_outline_rounded, size: 52),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.label, style: AppText.title)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Amount', style: AppText.caption), Text(Money.full(widget.amountNaira), style: AppText.h3)]),
          ]),
          const Divider(height: 24),
          Text('This payment is for agent tools, not rent or a deposit.', style: AppText.small),
        ])),
        const SizedBox(height: 16),
        Text('Payment provider', style: AppText.h3),
        const SizedBox(height: 8),
        PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Paystack', style: AppText.title),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.credit_card_rounded, color: AppColors.primary), const SizedBox(width: 12), Expanded(child: Text('Card or bank transfer: you choose on the next screen.', style: AppText.small))]),
        ])),
        const SizedBox(height: 16),
        PsField(label: 'Email address', controller: _email, keyboardType: TextInputType.emailAddress, errorText: _error),
        const SizedBox(height: 12),
        PsButton('Continue to Paystack', loading: _busy, onPressed: _pay),
        const SizedBox(height: 10),
        Center(child: PsLink('Review renewal and refund terms', onTap: () => context.push('/legal/terms'))),
        const SizedBox(height: 12),
        const PsNote('You will receive confirmation after payment verification.', icon: Icons.info_outline_rounded),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _PayPage extends StatefulWidget {
  final String url, reference;
  const _PayPage({required this.url, required this.reference});
  @override
  State<_PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<_PayPage> {
  late final WebViewController _c;
  bool _verifying = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) {
        final u = Uri.tryParse(r.url);
        if (u != null && u.host.endsWith(_callbackHost)) { _verify(); return NavigationDecision.prevent; }
        if (u != null && u.scheme == 'https' && (u.host.endsWith('paystack.com') || u.host.endsWith('paystack.co'))) return NavigationDecision.navigate;
        if (u != null && u.scheme == 'https') return NavigationDecision.navigate;
        return NavigationDecision.prevent;
      }))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _verify() async {
    if (_handled) return;
    _handled = true;
    setState(() => _verifying = true);
    final r = await PaystackService.verifyPayment(widget.reference);
    if (!mounted) return;
    if (r.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _verifying = false; _handled = false; });
      showPsSnack(context, r.error ?? 'We could not confirm the payment yet. If you were charged, it will appear in your account shortly or contact support.');
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: PsTopBar(title: 'Secure payment', onBack: () => Navigator.of(context).pop(false)),
        body: Stack(children: [
          WebViewWidget(controller: _c),
          if (_verifying) Container(color: Colors.white70, child: const Center(child: CircularProgressIndicator())),
        ]),
      );
}


/// Where Paystack returns the browser after payment (website only). The paid
/// state is still decided by the server, never by this page.
class PaymentCallbackScreen extends StatefulWidget {
  final String? reference;
  const PaymentCallbackScreen({super.key, required this.reference});
  @override
  State<PaymentCallbackScreen> createState() => _PaymentCallbackState();
}

class _PaymentCallbackState extends State<PaymentCallbackScreen> {
  bool _done = false;
  bool _ok = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final r = widget.reference;
    if (r == null || r.isEmpty) {
      setState(() { _done = true; _message = 'We could not find this payment. If you were charged, it will appear in your account shortly, or contact support.'; });
      return;
    }
    final res = await PaystackService.verifyPayment(r);
    if (!mounted) return;
    setState(() { _done = true; _ok = res.success; _message = res.success ? null : (res.error ?? 'We could not confirm the payment yet. If you were charged, it will appear in your account shortly, or contact support.'); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Payment', showBack: false),
      body: !_done
          ? const Center(child: CircularProgressIndicator())
          : PsEmpty(
              icon: _ok ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
              title: _ok ? 'Payment confirmed' : 'We could not confirm this payment yet',
              message: _ok ? 'Your agent tools are ready.' : (_message ?? ''),
              actionLabel: _ok ? 'Go to my workspace' : 'Contact support',
              onAction: () => context.go(_ok ? '/workspace' : '/support'),
            ),
    );
  }
}
