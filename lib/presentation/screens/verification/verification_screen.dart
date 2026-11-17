import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../../data/models/verification_request_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Three separate things, explained separately:
///  1. identity (a person), 2. authority to market ONE listing, 3. freshness.
/// Documents are private: uploaded to a write-once path and viewed only by
/// reviewers through short-lived links. Rejection reasons are shown here.
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  VerificationRequestModel? _latest(List<VerificationRequestModel> all, bool Function(VerificationRequestModel) test) {
    for (final r in all) {
      if (test(r)) return r;
    }
    return null;
  }

  (String, PsTone) _state(VerificationRequestModel? r) {
    if (r == null) return ('Not started', PsTone.neutral);
    switch (r.status) {
      case VerificationRequestStatus.approved:
        return ('Reviewed', PsTone.success);
      case VerificationRequestStatus.submitted:
      case VerificationRequestStatus.underReview:
        return ('In review', PsTone.info);
      case VerificationRequestStatus.needsChanges:
        return ('Needs changes', PsTone.warning);
      case VerificationRequestStatus.rejected:
        return ('Not approved', PsTone.danger);
      case VerificationRequestStatus.expired:
        return ('Expired', PsTone.warning);
      default:
        return ('Draft', PsTone.neutral);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(myVerificationRequestsProvider).asData?.value ?? const <VerificationRequestModel>[];
    final identity = _latest(all, (r) => r.requestType == 'identity');
    final authority = _latest(all, (r) => r.requestType != 'identity' && r.requestType != 'title');
    final iState = _state(identity);
    final aState = _state(authority);
    final user = ref.watch(currentUserModelProvider).asData?.value;

    Widget step(IconData icon, String title, String? pill, PsTone tone, String body, {String? action, VoidCallback? onTap, String? reason}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PsIconCircle(icon, size: 56),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.h3),
              if (pill != null) Padding(padding: const EdgeInsets.only(top: 6), child: PsPill(pill, tone: tone, small: true)),
              const SizedBox(height: 6),
              Text(body, style: AppText.small),
            ])),
          ]),
          if (reason != null) Padding(padding: const EdgeInsets.only(top: 10), child: PsNote('Reviewer note: $reason', tone: PsTone.warning, icon: Icons.info_outline_rounded)),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 12), child: PsButton(action, kind: PsButtonKind.outline, onPressed: onTap)),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Verification'),
      body: ListView(padding: kPagePadding, children: [
        const PsHeadline('Build trust with', accent: 'evidence.', size: 32),
        const SizedBox(height: 6),
        Text('Different checks mean different things.', style: AppText.bodyMuted),
        const SizedBox(height: 16),
        step(Icons.badge_outlined, '1. Confirm your identity', iState.$1, iState.$2, identity == null ? 'Government ID + selfie' : 'This confirms who you are. It does not prove you can rent out any property.',
            action: (identity == null || identity.status == VerificationRequestStatus.rejected || identity.status == VerificationRequestStatus.needsChanges || identity.status == VerificationRequestStatus.expired) ? 'Start identity check' : null,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _SubmitScreen(type: 'identity'))),
            reason: identity?.rejectionReason),
        step(Icons.home_outlined, '2. Confirm property authority', 'Per listing', PsTone.neutral, 'Show your permission to market the home. Each listing is reviewed on its own.${authority != null ? '\nLatest: ${aState.$1}' : ''}',
            action: 'Add authority for a listing',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _SubmitScreen(type: 'authority'))),
            reason: authority?.rejectionReason),
        step(Icons.event_available_outlined, '3. Keep availability fresh', null, PsTone.neutral, 'Confirm homes are still available. Renters see the date.', action: 'Open my listings', onTap: () => context.go('/my-listings')),
        if (user != null && (user.verificationExpiresAt != null) && user.isVerified)
          Text('Identity review valid until ${user.verificationExpiresAt!.day}/${user.verificationExpiresAt!.month}/${user.verificationExpiresAt!.year}.', style: AppText.caption),
        const SizedBox(height: 4),
        PsCard(child: Row(children: [
          const Icon(Icons.shield_outlined, size: 30, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Who sees your documents?', style: AppText.title), Text('Not displayed publicly. Used for review by Propsure staff only, through short-lived links.', style: AppText.small)])),
        ])),
        const SizedBox(height: 16),
        PsButton('See how checks work', trailingIcon: Icons.arrow_forward_rounded, onPressed: () => context.push('/info/how-checks-work')),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _SubmitScreen extends ConsumerStatefulWidget {
  final String type; // identity | authority
  const _SubmitScreen({required this.type});
  @override
  ConsumerState<_SubmitScreen> createState() => _SubmitState();
}

class _SubmitState extends ConsumerState<_SubmitScreen> {
  XFile? _selfie, _id, _doc;
  String? _listingId;
  bool _busy = false;
  String? _error;

  Future<void> _pick(void Function(XFile) set, {bool camera = false}) async {
    final x = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
    if (x != null) setState(() => set(x));
  }

  Future<void> _submit() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final identity = widget.type == 'identity';
    if (identity && (_selfie == null || _id == null)) { setState(() => _error = 'Add a clear selfie and a photo of your government ID.'); return; }
    if (!identity && (_listingId == null || _doc == null)) { setState(() => _error = 'Choose the listing and add the document that shows your permission.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(verificationRepositoryProvider).submitVerificationRequest(
            uid: uid,
            requestType: widget.type,
            listingId: _listingId,
            selfie: _selfie == null ? null : File(_selfie!.path),
            idDocument: _id == null ? null : File(_id!.path),
            propertyDocument: _doc == null ? null : File(_doc!.path),
          );
      if (!mounted) return;
      showPsSnack(context, 'Submitted. We will review it and tell you the result.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.toString().replaceFirst('Exception: ', '').split('\n').first; });
    }
  }

  Widget _picker(String label, XFile? f, VoidCallback onTap, {IconData icon = Icons.add_a_photo_outlined}) => PsCard(
        onTap: onTap,
        semanticLabel: label,
        child: Row(children: [PsIconCircle(f == null ? icon : Icons.check_rounded), const SizedBox(width: 14), Expanded(child: Text(f == null ? label : '$label: added', style: AppText.title)), const Icon(Icons.chevron_right_rounded)]),
      );

  @override
  Widget build(BuildContext context) {
    final identity = widget.type == 'identity';
    final uid = ref.watch(currentUserIdProvider);
    final mine = uid == null ? null : ref.watch(agentListingsProvider(uid)).asData?.value;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: identity ? 'Identity check' : 'Property authority'),
      body: ListView(padding: kPagePadding, children: [
        Text(identity ? 'Confirm who you are' : 'Show your permission to market a home', style: AppText.h1),
        const SizedBox(height: 8),
        Text(identity ? 'This does not prove you own or may rent out any property.' : 'Upload a document that shows the owner approved you to market this specific home. It does not prove title and does not cover other listings.', style: AppText.bodyMuted),
        const SizedBox(height: 16),
        if (!identity) ...[
          PsDropdown<String>(label: 'Which listing?', value: _listingId, hint: 'Choose a listing', items: [for (final l in mine ?? const <ListingModel>[]) l.id], itemLabel: (id) => (mine ?? const <ListingModel>[]).firstWhere((l) => l.id == id).title, onChanged: (v) => setState(() => _listingId = v)),
          const SizedBox(height: 12),
          _picker('Authority document', _doc, () => _pick((x) => _doc = x), icon: Icons.description_outlined),
        ] else ...[
          _picker('Government ID photo', _id, () => _pick((x) => _id = x), icon: Icons.badge_outlined),
          const SizedBox(height: 12),
          _picker('Selfie', _selfie, () => _pick((x) => _selfie = x, camera: true)),
        ],
        const SizedBox(height: 12),
        const PsNote('Files are private. They are not shown on your profile or listings.', icon: Icons.lock_outline_rounded),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600))),
        const SizedBox(height: 16),
        PsButton('Submit for review', loading: _busy, onPressed: _submit),
        const SizedBox(height: 24),
      ]),
    );
  }
}
