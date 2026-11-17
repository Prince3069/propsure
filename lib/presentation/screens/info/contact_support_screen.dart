import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../services/functions_service.dart';
import '../../providers/app_providers.dart';
import '../bulk_upload/whatsapp_bot_screen.dart' show kWhatsAppAssistNumber;

const String kSupportEmail = 'support@propsure.africa';

/// One consolidated support screen (replaces the old Contact and Report
/// screens). Creates a real support request with a reference.
class SupportScreen extends ConsumerStatefulWidget {
  final String? topic;
  const SupportScreen({super.key, this.topic});
  @override
  ConsumerState<SupportScreen> createState() => _SupportState();
}

class _SupportState extends ConsumerState<SupportScreen> {
  static const _topics = {
    'listing_issue': 'Listing issue',
    'inspection': 'Inspection',
    'account_payment': 'Account or payment',
    'report': 'Report a concern',
    'other': 'Other',
  };
  late String _topic;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  XFile? _evidence;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.topic;
    _topic = _topics.containsKey(t) ? t! : (t == 'report_agent' ? 'report' : 'listing_issue');
    if (t == 'report_agent') _subject.text = 'Report an agent';
    if (t == 'account_payment') _subject.text = '';
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) { context.push('/auth?redirect=/support'); return; }
    if (_message.text.trim().length < 5) { setState(() => _error = 'Tell us a little more so we can help.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final paths = <String>[];
      if (_evidence != null) {
        final path = 'support/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await FirebaseStorage.instance.ref(path).putData(await _evidence!.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
        paths.add(path);
      }
      final kind = _topic == 'report' ? 'report' : 'support';
      if (kind == 'report') {
        setState(() { _busy = false; _error = 'To report a listing, open the listing and choose Report a concern.'; });
        return;
      }
      final reference = await ref.read(functionsServiceProvider).createSupportRequest(kind: kind, topic: _topic, subject: _subject.text.trim(), message: _message.text.trim(), evidencePaths: paths);
      if (!mounted) return;
      showPsSnack(context, 'We have your message. Reference $reference');
      context.pushReplacement('/support/status');
    } on AppException catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'We could not send that. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, String t) {
      final sel = _topic == t;
      return Expanded(child: InkWell(
        onTap: () => setState(() => _topic = t),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 104,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: sel ? AppColors.primaryPale : AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 32, color: AppColors.primary), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.text))]),
        ),
      ));
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Help & support'),
      body: ListView(padding: kPagePadding, children: [
        const PsHeadline('What do you need', accent: 'help with?', size: 34),
        const SizedBox(height: 16),
        Row(children: [
          tile(Icons.home_outlined, 'A listing or agent', 'listing_issue'),
          const SizedBox(width: 10),
          tile(Icons.event_outlined, 'An inspection', 'inspection'),
          const SizedBox(width: 10),
          tile(Icons.person_outline_rounded, 'My account or payment', 'account_payment'),
        ]),
        const SizedBox(height: 16),
        PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PsDropdown<String>(label: 'Topic', value: _topic == 'report' ? 'listing_issue' : _topic, items: const ['listing_issue', 'inspection', 'account_payment', 'other'], itemLabel: (k) => _topics[k]!, onChanged: (v) => setState(() => _topic = v ?? 'other')),
          const SizedBox(height: 12),
          PsField(label: 'Subject', controller: _subject, hint: 'Briefly summarise your question', maxLength: 120),
          const SizedBox(height: 12),
          PsField(label: 'Tell us what happened', controller: _message, hint: 'Include as much detail as possible…', maxLines: 5, maxLength: 500),
          const SizedBox(height: 12),
          Text('Add evidence (optional)', style: AppText.small.copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 6),
          PsCard(onTap: () async { final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 80); if (x != null) setState(() => _evidence = x); }, semanticLabel: 'Add evidence', child: Row(children: [const Icon(Icons.attach_file_rounded), const SizedBox(width: 12), Expanded(child: Text(_evidence == null ? 'Add a photo (optional)' : 'Photo added', style: AppText.title))])),
          const SizedBox(height: 10),
          const PsNote('Do not upload passwords or full ID details here. Keep your personal information safe.', icon: Icons.shield_outlined),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600))),
        ])),
        const SizedBox(height: 16),
        Text('Other ways to get help', style: AppText.title),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: PsButton('WhatsApp', kind: PsButtonKind.outline, icon: Icons.chat_rounded, onPressed: () => launchUrl(Uri.parse('https://wa.me/$kWhatsAppAssistNumber'), mode: LaunchMode.externalApplication))),
          const SizedBox(width: 12),
          Expanded(child: PsButton('Email', kind: PsButtonKind.outline, icon: Icons.mail_outline_rounded, onPressed: () => launchUrl(Uri(scheme: 'mailto', path: kSupportEmail)))),
        ]),
        const SizedBox(height: 12),
        PsButton('Send message', loading: _busy, onPressed: _send),
        const SizedBox(height: 12),
        Center(child: PsLink('View my requests', chevron: true, onTap: () => context.push('/support/status'))),
        const SizedBox(height: 24),
      ]),
    );
  }
}
