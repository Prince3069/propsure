import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/paystack_service.dart';

/// Secure Paystack WebView checkout.
/// Opens Paystack's hosted page — we never handle card numbers in our app.
/// Listens for the callback URL to detect completion, then verifies server-side.
class PaystackWebviewScreen extends ConsumerStatefulWidget {
  final String checkoutUrl;
  final String reference;
  final String transactionType;
  final String listingTitle;

  const PaystackWebviewScreen({
    super.key,
    required this.checkoutUrl,
    required this.reference,
    required this.transactionType,
    required this.listingTitle,
  });

  @override
  ConsumerState<PaystackWebviewScreen> createState() =>
      _PaystackWebviewScreenState();
}

class _PaystackWebviewScreenState
    extends ConsumerState<PaystackWebviewScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _verifying = false;
  String? _error;

  // Callback URL — Paystack redirects here after payment
  // Must match exactly what you set in Paystack dashboard + Cloud Function
  // Paystack redirects to this URL after payment completes.
  // Must match EXACTLY what is set in your Paystack dashboard & Cloud Function.
  static const _callbackUrl = 'https://propsure.africa/payment/callback';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (err) {
          if (err.isForMainFrame ?? false) {
            setState(() { _loading = false; _error = 'Connection error. Please check your internet.'; });
          }
        },
        onNavigationRequest: (request) {
          final url = request.url;

          // ── Detect successful payment redirect ────────────────────────
          if (url.startsWith(_callbackUrl)) {
            _handleCallback(url);
            return NavigationDecision.prevent;
          }

          // ── Detect Paystack's own cancel ─────────────────────────────
          if (url.contains('paystack.com/close') || url.contains('cancel')) {
            _handleCancelled();
            return NavigationDecision.prevent;
          }

          // ── Block any redirect outside paystack.com ───────────────────
          // This prevents open-redirect attacks
          final uri = Uri.tryParse(url);
          final allowed = ['paystack.com', 'standard.paystack.com', 'propsure.africa'];
          if (uri != null && !allowed.any((h) => uri.host.endsWith(h))) {
            // Log suspicious redirect attempt
            debugPrint('🚨 BLOCKED suspicious redirect to: $url');
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<void> _handleCallback(String url) async {
    setState(() { _loading = true; _verifying = true; });

    // Parse reference from callback URL (Paystack appends ?reference=xxx&trxref=xxx)
    final uri = Uri.parse(url);
    final ref = uri.queryParameters['reference'] ?? widget.reference;

    // Verify payment server-side (never trust client-side alone)
    final result = await PaystackService.verifyPayment(ref);

    if (!mounted) return;
    setState(() { _loading = false; _verifying = false; });

    if (result.success) {
      _showSuccess();
    } else {
      _showFailure(result.error ?? 'Payment could not be verified.');
    }
  }

  void _handleCancelled() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmCancelSheet(
        onStay: () => Navigator.pop(context),
        onLeave: () { Navigator.pop(context); context.pop(); },
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(type: widget.transactionType, title: widget.listingTitle),
    );
  }

  void _showFailure(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Payment Failed', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(context); context.pop(); }, child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(context); _ctrl.reload(); },
              child: const Text('Try Again'),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Secure Checkout', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700)),
          Row(children: [
            const Icon(Icons.lock_rounded, size: 10, color: AppColors.success),
            const SizedBox(width: 3),
            Text('Powered by Paystack', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
          ]),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _handleCancelled(),
        ),
        actions: [
          // Show security indicator
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_user_rounded, size: 12, color: AppColors.success),
                SizedBox(width: 4),
                Text('SSL Secure', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _ctrl),
        if (_loading)
          Container(
            color: AppColors.surface,
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(_verifying ? 'Verifying payment…' : 'Loading secure checkout…',
                style: Theme.of(context).textTheme.bodyMedium),
            ])),
          ),
        if (_error != null)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(32),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.text3),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () { setState(() => _error = null); _ctrl.reload(); },
                child: const Text('Retry')),
            ])),
          ),
      ]),
    );
  }
}

class _ConfirmCancelSheet extends StatelessWidget {
  final VoidCallback onStay, onLeave;
  const _ConfirmCancelSheet({required this.onStay, required this.onLeave});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      Text('Cancel payment?', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Your payment has not been processed yet. Are you sure you want to leave?',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.text2)),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: onStay, child: const Text('Continue Payment'))),
        const SizedBox(width: 12),
        Expanded(child: TextButton(
          onPressed: onLeave,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Yes, Cancel'),
        )),
      ]),
    ]),
  );
}

class _SuccessDialog extends StatelessWidget {
  final String type, title;
  const _SuccessDialog({required this.type, required this.title});

  String get _message {
    switch (type) {
      case 'boost': return 'Your listing "$title" is now boosted and will appear at the top of search results.';
      case 'premium': return 'Your Premium subscription is now active. Enjoy all premium benefits!';
      case 'reservation': return 'Property reserved! The agent has been notified.';
      default: return 'Payment completed successfully.';
    }
  }

  String get _emoji {
    switch (type) {
      case 'boost': return '🚀';
      case 'premium': return '⭐';
      case 'reservation': return '🏡';
      default: return '✅';
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_emoji, style: const TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      Text('Payment Successful!', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context); // Close dialog
          context.go('/home');    // Return home
        },
        child: Text('Done', style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
      )),
    ]),
  );
}
