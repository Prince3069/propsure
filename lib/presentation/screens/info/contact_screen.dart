import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../providers/app_providers.dart';

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});
  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _msgCtrl     = TextEditingController();
  String _category   = 'General Inquiry';
  bool _sending      = false;
  bool _sent         = false;

  static const _categories = [
    'General Inquiry', 'Technical Support', 'Billing & Payments',
    'Listing Issues', 'Report a Scam', 'Account Issues', 'Other',
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final uid  = ref.read(currentUserIdProvider);
    final user = ref.read(currentUserModelProvider).value;

    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId':    uid ?? 'anonymous',
        'name':      user?.name ?? 'Anonymous',
        'email':     user?.email ?? '',
        'phone':     user?.phone ?? '',
        'category':  _category,
        'subject':   _subjectCtrl.text.trim(),
        'message':   _msgCtrl.text.trim(),
        'status':    'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _sending = false; _sent = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Contact Support',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _sent ? _SuccessView() : _FormView(
        formKey: _formKey,
        category: _category,
        categories: _categories,
        onCategoryChanged: (v) => setState(() => _category = v),
        subjectCtrl: _subjectCtrl,
        msgCtrl: _msgCtrl,
        sending: _sending,
        onSend: _send,
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String category;
  final List<String> categories;
  final ValueChanged<String> onCategoryChanged;
  final TextEditingController subjectCtrl, msgCtrl;
  final bool sending;
  final VoidCallback onSend;

  const _FormView({
    required this.formKey, required this.category, required this.categories,
    required this.onCategoryChanged, required this.subjectCtrl,
    required this.msgCtrl, required this.sending, required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Hero banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.support_agent_rounded, color: Colors.white, size: 32),
            const SizedBox(height: 10),
            Text("We're here to help!", style: GoogleFonts.syne(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('We respond to all messages within 24 hours.',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 20),

        // Quick contact buttons
        Row(children: [
          Expanded(child: _QuickBtn(
            icon: Icons.chat_rounded, label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () async {
              final uri = Uri.parse('https://wa.me/2348000000000?text=Hi+Propsure+Support');
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: _QuickBtn(
            icon: Icons.email_outlined, label: 'Email',
            color: AppColors.primary,
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: 'hello@propsure.africa',
                query: 'subject=Support Request');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          )),
        ]),
        const SizedBox(height: 20),

        // Form
        Form(key: formKey, child: Column(children: [
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: categories.map((c) =>
                DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => onCategoryChanged(v!),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: subjectCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Subject *',
              prefixIcon: Icon(Icons.subject_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter a subject' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: msgCtrl,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message *',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 80),
                child: Icon(Icons.message_outlined),
              ),
            ),
            validator: (v) => v == null || v.trim().length < 10
                ? 'Please write at least 10 characters' : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(sending ? 'Sending...' : 'Send Message'),
            ),
          ),
        ])),
      ]),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(
              color: AppColors.primaryPale, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 44),
        ),
        const SizedBox(height: 20),
        Text('Message Sent!', style: GoogleFonts.syne(
            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 8),
        const Text(
          "Thanks for reaching out. We'll get back to you within 24 hours.",
          style: TextStyle(fontSize: 14, color: AppColors.text2, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => context.go('/home'),
          child: const Text('Back to Home'),
        ),
      ]),
    ),
  );
}
