import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../providers/app_providers.dart';

class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});
  @override
  ConsumerState<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _subCtrl  = TextEditingController();
  final _msgCtrl  = TextEditingController();
  String _category = 'General Inquiry';
  bool _submitting = false;
  bool _submitted  = false;

  static const _categories = [
    'General Inquiry', 'Listing Issues', 'Account & Login',
    'Payment & Billing', 'Report a Scam', 'Technical Problem',
    'Partnership', 'Other',
  ];

  @override
  void dispose() {
    _subCtrl.dispose(); _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final uid  = ref.read(currentUserIdProvider);
      final user = ref.read(currentUserModelProvider).value;
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId':    uid ?? 'anonymous',
        'userName':  user?.name ?? 'Anonymous',
        'userPhone': user?.phone ?? '',
        'category':  _category,
        'subject':   _subCtrl.text.trim(),
        'message':   _msgCtrl.text.trim(),
        'status':    'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Contact Support', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop()),
      ),
      body: _submitted ? _SuccessView() : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Quick contact cards
          Row(children: [
            Expanded(child: _QuickCard(
              icon: Icons.chat_bubble_outline_rounded, color: const Color(0xFF25D366),
              label: 'WhatsApp', sub: 'Fastest response',
              onTap: () => launchUrl(Uri.parse('https://wa.me/2348000000000'),
                  mode: LaunchMode.externalApplication),
            )),
            const SizedBox(width: 10),
            Expanded(child: _QuickCard(
              icon: Icons.email_outlined, color: AppColors.info,
              label: 'Email', sub: 'hello@propsure.africa',
              onTap: () => launchUrl(Uri.parse('mailto:hello@propsure.africa')),
            )),
          ]),
          const SizedBox(height: 20),

          Text('Send us a message',
              style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('We usually respond within 24 hours',
              style: TextStyle(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 14),

          Form(key: _formKey, child: Column(children: [
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined)),
              items: _categories.map((c) =>
                DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),

            // Subject
            TextFormField(
              controller: _subCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Subject *',
                prefixIcon: Icon(Icons.subject_rounded)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a subject' : null,
            ),
            const SizedBox(height: 12),

            // Message
            TextFormField(
              controller: _msgCtrl,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message *',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 68),
                  child: Icon(Icons.message_outlined))),
              validator: (v) => v == null || v.trim().length < 10
                  ? 'Please enter a message (at least 10 characters)' : null,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_submitting ? 'Sending…' : 'Send Message'),
              ),
            ),
          ])),

          const SizedBox(height: 28),
          // Response time note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.primaryPale2)),
            child: Row(children: [
              const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Mon–Fri: 8am–6pm WAT\nSat: 9am–3pm WAT\nWe respond to all tickets within 24 hours.',
                style: const TextStyle(fontSize: 12, color: AppColors.primary, height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 20),
          Text('Message Sent!', style: GoogleFonts.syne(
              fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 8),
          const Text("We've received your message and will get back to you within 24 hours.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.text2, height: 1.6)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ]),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String label, sub; final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.color,
      required this.label, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
      ]),
    ),
  );
}
