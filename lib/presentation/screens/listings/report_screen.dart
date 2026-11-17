import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../services/functions_service.dart';
import '../../providers/app_providers.dart';

class ReportConcernScreen extends ConsumerStatefulWidget {
  final String listingId;
  const ReportConcernScreen({super.key, required this.listingId});
  @override
  ConsumerState<ReportConcernScreen> createState() => _ReportState();
}

class _ReportState extends ConsumerState<ReportConcernScreen> {
  static const _reasons = [
    ('no_longer_available', 'No longer available'),
    ('incorrect_details', 'Incorrect cost or details'),
    ('authority_concern', 'Agent authority concern'),
    ('suspicious_payment', 'Suspicious payment request'),
  ];
  String _reason = 'no_longer_available';
  final _msg = TextEditingController();
  XFile? _file;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    if (_msg.text.trim().length < 5) { setState(() => _error = 'Tell us a little more so we can review it.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final paths = <String>[];
      if (_file != null) {
        final path = 'support/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await FirebaseStorage.instance.ref(path).putData(await _file!.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
        paths.add(path);
      }
      final ref0 = await ref.read(functionsServiceProvider).createSupportRequest(kind: 'report', topic: 'report', subject: 'Listing report', message: _msg.text.trim(), reason: _reason, listingId: widget.listingId, evidencePaths: paths);
      if (!mounted) return;
      showPsSnack(context, 'Report received. Reference $ref0');
      context.pushReplacement('/support/status');
    } on AppException catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'We could not send your report. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(listingByIdProvider(widget.listingId)).asData?.value;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: 'Report a concern', action: const PropsureLogo(size: 24)),
      body: ListView(padding: kPagePadding, children: [
        if (l != null) PsCard(padding: const EdgeInsets.all(8), onTap: () => context.push('/listing/${l.id}'), semanticLabel: l.title, child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(AppRadius.sm), child: SizedBox(width: 96, height: 72, child: PsNetImage(l.coverUrl))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.title, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis), Text('${l.location.area}, Abuja', style: AppText.small)])),
          const Icon(Icons.chevron_right_rounded),
        ])),
        const SizedBox(height: 20),
        Text('What seems wrong?', style: AppText.h1.copyWith(fontSize: 26)),
        const SizedBox(height: 10),
        for (final r in _reasons) Padding(padding: const EdgeInsets.only(bottom: 8), child: PsCard(
          color: _reason == r.$1 ? AppColors.primaryPale : null,
          borderColor: _reason == r.$1 ? AppColors.primary : null,
          onTap: () => setState(() => _reason = r.$1),
          semanticLabel: r.$2,
          child: Row(children: [Icon(_reason == r.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: _reason == r.$1 ? AppColors.primary : AppColors.text3), const SizedBox(width: 14), Expanded(child: Text(r.$2, style: AppText.title))]),
        )),
        const SizedBox(height: 12),
        PsField(label: 'Tell us more', controller: _msg, maxLines: 4, maxLength: 500, hint: 'What happened?'),
        const SizedBox(height: 12),
        PsCard(onTap: () async { final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 80); if (x != null) setState(() => _file = x); }, semanticLabel: 'Attach evidence', child: Row(children: [
          const Icon(Icons.attach_file_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_file == null ? 'Attach evidence' : 'Photo attached', style: AppText.title), Text('Add photos, screenshots or other files (optional)', style: AppText.small)])),
          const Icon(Icons.chevron_right_rounded),
        ])),
        const SizedBox(height: 12),
        Row(children: [const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.text2), const SizedBox(width: 8), Text('Your report is not posted publicly.', style: AppText.small)]),
        const SizedBox(height: 8),
        Row(children: [const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text('For immediate danger, contact local emergency services.', style: AppText.small))]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600))),
        const SizedBox(height: 16),
        PsButton('Submit report', loading: _busy, onPressed: _submit),
        const SizedBox(height: 24),
      ]),
    );
  }
}
