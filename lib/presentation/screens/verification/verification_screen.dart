import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/verification_request_model.dart';
import '../../providers/app_providers.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});
  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  int _step = 0;
  File? _selfieFile;
  File? _idFile;
  File? _propertyDocFile;
  File? _verificationVideoFile;
  bool _submitting = false;
  String? _submitError;
  bool _forceNewRequest = false;

  final _steps = ['Identity', 'Property Doc', 'Video Proof', 'Submit'];

  Future<void> _pickFile(String type) async {
    final picker = ImagePicker();
    if (type == 'video') {
      final v = await picker.pickVideo(source: ImageSource.camera);
      if (v != null) setState(() => _verificationVideoFile = File(v.path));
    } else {
      final img = await picker.pickImage(
          source: type == 'selfie' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80);
      if (img != null) {
        setState(() {
          if (type == 'selfie') _selfieFile = File(img.path);
          if (type == 'id') _idFile = File(img.path);
          if (type == 'doc') _propertyDocFile = File(img.path);
        });
      }
    }
  }

  // Real submission: uploads every selected document to a private Storage
  // path and creates a `verification_requests` document, via
  // VerificationRepository. There is no simulated delay and no success
  // dialog shown unless the upload + Firestore write both actually
  // succeeded — on failure the person sees the real error and nothing is
  // silently marked as submitted.
  Future<void> _submit() async {
    if (_selfieFile == null || _idFile == null || _propertyDocFile == null) {
      setState(() => _submitError =
          'Selfie, Government ID, and Property Document are all required.');
      return;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      setState(() => _submitError = 'Please sign in again and retry.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await ref.read(verificationRepositoryProvider).submitVerificationRequest(
            uid: uid,
            requestType: 'agent_authority',
            selfie: _selfieFile,
            idDocument: _idFile,
            propertyDocument: _propertyDocFile,
            video: _verificationVideoFile,
          );
      if (mounted) {
        setState(() => _submitting = false);
        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showSuccess() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryPale, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        size: 40, color: AppColors.primary)),
                const SizedBox(height: 16),
                Text('Submitted!',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'Your verification documents are under review. You will hear back within 24-48 hours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.text2)),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/profile');
                      },
                      child: const Text('Back to Profile'),
                    )),
              ]),
            ));
  }

  @override
  Widget build(BuildContext context) {
    // Real status gate: if the person already has a pending or approved
    // request, show that instead of always re-showing the submission
    // wizard. Rejected/needs-changes requests let them start a fresh one.
    final requestAsync = ref.watch(myVerificationRequestProvider);
    final existing = requestAsync.value;
    if (!_forceNewRequest &&
        existing != null &&
        existing.status != VerificationRequestStatus.draft) {
      if (existing.isPending || existing.isApproved) {
        return _VerificationStatusScreen(request: existing);
      }
      if (existing.isRejected) {
        return _VerificationStatusScreen(
          request: existing,
          onStartNew: () => setState(() => _forceNewRequest = true),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Get Verified',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        if (_submitError != null)
          Container(
            width: double.infinity,
            color: AppColors.error.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_submitError!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.error))),
            ]),
          ),
        // Progress bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _steps.asMap().entries.map((e) {
                final done = e.key < _step;
                final cur = e.key == _step;
                return Column(children: [
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.success
                            : cur
                                ? AppColors.primary
                                : AppColors.bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: done
                                ? AppColors.success
                                : cur
                                    ? AppColors.primary
                                    : AppColors.border,
                            width: 1.5),
                      ),
                      child: Center(
                          child: done
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                              : Text('${e.key + 1}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: cur
                                          ? Colors.white
                                          : AppColors.text3)))),
                  const SizedBox(height: 4),
                  Text(e.value,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: done || cur
                              ? AppColors.primary
                              : AppColors.text3)),
                ]);
              }).toList(),
            ),
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _steps.length,
                  backgroundColor: AppColors.bg,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                )),
          ]),
        ),

        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_step == 0)
            _StepIdentity(selfie: _selfieFile, id: _idFile, onPick: _pickFile),
          if (_step == 1)
            _StepPropertyDoc(
                doc: _propertyDocFile, onPick: () => _pickFile('doc')),
          if (_step == 2)
            _StepVideoProof(
                video: _verificationVideoFile,
                onPick: () => _pickFile('video')),
          if (_step == 3)
            _StepReview(
                selfie: _selfieFile,
                id: _idFile,
                doc: _propertyDocFile,
                video: _verificationVideoFile),
        ])),

        // Bottom buttons
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            if (_step > 0) ...[
              OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13)),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
                child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () {
                      if (_step < 3)
                        setState(() => _step++);
                      else
                        _submit();
                    },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_step == 3 ? 'Submit for Review' : 'Continue →',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, fontSize: 14)),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── REAL STATUS SCREEN ────────────────────────────────────────────────────
// Shown instead of the wizard whenever the person already has a
// submitted/under_review/approved/rejected request. This is the "real
// status screen" the review asked for — status now comes from an actual
// Firestore document a reviewer acts on, not a hard-coded success dialog.
class _VerificationStatusScreen extends StatelessWidget {
  final VerificationRequestModel request;
  final VoidCallback? onStartNew;
  const _VerificationStatusScreen({required this.request, this.onStartNew});

  ({IconData icon, Color color, String title, String body}) get _content {
    switch (request.status) {
      case VerificationRequestStatus.submitted:
      case VerificationRequestStatus.underReview:
        return (
          icon: Icons.hourglass_top_rounded,
          color: AppColors.gold,
          title: 'Under Review',
          body:
              'Your documents were submitted and are being reviewed by Propsure staff. You will hear back within 24–48 hours.',
        );
      case VerificationRequestStatus.approved:
        return (
          icon: Icons.verified_rounded,
          color: AppColors.success,
          title: 'Verified',
          body:
              'You\'re verified! Your profile and listings now carry the Propsure Verified badge.',
        );
      case VerificationRequestStatus.rejected:
        return (
          icon: Icons.cancel_rounded,
          color: AppColors.error,
          title: 'Not Approved',
          body: request.rejectionReason?.isNotEmpty == true
              ? request.rejectionReason!
              : 'Your submission could not be approved. Please try again with clearer documents.',
        );
      case VerificationRequestStatus.needsChanges:
        return (
          icon: Icons.edit_note_rounded,
          color: AppColors.info,
          title: 'Changes Needed',
          body: request.rejectionReason?.isNotEmpty == true
              ? request.rejectionReason!
              : 'A reviewer requested changes to your submission.',
        );
      case VerificationRequestStatus.expired:
        return (
          icon: Icons.event_busy_rounded,
          color: AppColors.text3,
          title: 'Verification Expired',
          body: 'Please submit a new verification request to renew your badge.',
        );
      case VerificationRequestStatus.draft:
        return (
          icon: Icons.description_outlined,
          color: AppColors.text3,
          title: 'Draft',
          body: 'Continue your verification submission.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _content;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
          title: Text('Verification',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: c.color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(c.icon, size: 36, color: c.color),
            ),
            const SizedBox(height: 16),
            Text(c.title,
                style:
                    GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(c.body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.text2)),
            const SizedBox(height: 24),
            if (onStartNew != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStartNew,
                  child: const Text('Submit New Request'),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── STEP 1: IDENTITY ─────────────────────────────────────────────────────
class _StepIdentity extends StatelessWidget {
  final File? selfie, id;
  final Function(String) onPick;
  const _StepIdentity({this.selfie, this.id, required this.onPick});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader('Step 1: Identity Verification',
            'We need to confirm you are who you say you are.'),
        const SizedBox(height: 20),
        _DocUpload(
            label: 'Take a Selfie',
            icon: Icons.camera_alt_rounded,
            subtitle: 'Look directly at the camera',
            file: selfie,
            onTap: () => onPick('selfie'),
            required: true),
        const SizedBox(height: 12),
        _DocUpload(
            label: 'Government-Issued ID',
            icon: Icons.badge_outlined,
            subtitle: 'NIN slip, Passport, Driver\'s licence',
            file: id,
            onTap: () => onPick('id'),
            required: true),
        const SizedBox(height: 16),
        _InfoBox(
            'Your ID is stored in a private location only Propsure reviewers can access. It is never shown to tenants or other users.'),
      ]);
}

// ── STEP 2: PROPERTY DOCUMENT ────────────────────────────────────────────
class _StepPropertyDoc extends StatelessWidget {
  final File? doc;
  final VoidCallback onPick;
  const _StepPropertyDoc({this.doc, required this.onPick});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader('Step 2: Property Document',
            'Upload proof that you own or have rights to list this property.'),
        const SizedBox(height: 20),
        _DocUpload(
            label: 'Property Document',
            icon: Icons.description_outlined,
            subtitle:
                'C of O, Deed of Assignment, Tenancy agreement, or Agent authority letter',
            file: doc,
            onTap: onPick,
            required: true),
        const SizedBox(height: 16),
        _InfoBox(
            'Accepted: Certificate of Occupancy, Deed of Assignment, Tenancy Agreement, Letter of Authority from owner.'),
      ]);
}

// ── STEP 3: VIDEO PROOF ──────────────────────────────────────────────────
class _StepVideoProof extends StatelessWidget {
  final File? video;
  final VoidCallback onPick;
  const _StepVideoProof({this.video, required this.onPick});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader('Step 3: Video Verification',
            'Record a short video of yourself inside or outside the property.'),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: video != null ? AppColors.primaryPale : AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: video != null ? AppColors.primary : AppColors.border,
                  width: video != null ? 2 : 1),
            ),
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  video != null
                      ? Icons.check_circle_rounded
                      : Icons.videocam_rounded,
                  size: 36,
                  color: video != null ? AppColors.primary : AppColors.text3),
              const SizedBox(height: 8),
              Text(
                  video != null
                      ? '✓ Video recorded'
                      : 'Record Verification Video',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          video != null ? AppColors.primary : AppColors.text2)),
              const SizedBox(height: 4),
              const Text('30-60 seconds. Say your name and show the property.',
                  style: TextStyle(fontSize: 11, color: AppColors.text3),
                  textAlign: TextAlign.center),
            ])),
          ),
        ),
        const SizedBox(height: 16),
        _InfoBox(
            'This video proves you have physical access to the property. It will be reviewed by Propsure staff only.'),
      ]);
}

// ── STEP 4: REVIEW ──────────────────────────────────────────────────────
class _StepReview extends StatelessWidget {
  final File? selfie, id, doc, video;
  const _StepReview({this.selfie, this.id, this.doc, this.video});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader('Review & Submit',
            'Check everything before submitting for review.'),
        const SizedBox(height: 20),
        _ReviewRow('Selfie', selfie != null ? '✓ Uploaded' : '✗ Missing',
            selfie != null),
        _ReviewRow('Government ID', id != null ? '✓ Uploaded' : '✗ Missing',
            id != null),
        _ReviewRow('Property Document',
            doc != null ? '✓ Uploaded' : '✗ Missing', doc != null),
        _ReviewRow('Video Proof', video != null ? '✓ Recorded' : '⚠ Optional',
            video != null),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(children: [
            Text('🛡', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Propsure Verified Badge',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  Text(
                      'After approval, your profile and listings get a verified badge. Verified agents get 3× more inquiries.',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11, height: 1.4)),
                ])),
          ]),
        ),
      ]);
}

class _ReviewRow extends StatelessWidget {
  final String label, value;
  final bool ok;
  const _ReviewRow(this.label, this.value, this.ok);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 18, color: ok ? AppColors.success : AppColors.error),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13))),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: ok ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── SHARED ──────────────────────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final String title, subtitle;
  const _StepHeader(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _DocUpload extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final File? file;
  final VoidCallback onTap;
  final bool required;
  const _DocUpload(
      {required this.label,
      required this.subtitle,
      required this.icon,
      this.file,
      required this.onTap,
      this.required = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: file != null ? AppColors.primaryPale : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: file != null ? AppColors.primary : AppColors.border,
                width: file != null ? 1.5 : 1),
          ),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: file != null ? AppColors.primaryPale2 : AppColors.bg,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(file != null ? Icons.check_rounded : icon,
                    color: file != null ? AppColors.primary : AppColors.text2,
                    size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: file != null
                                ? AppColors.primary
                                : AppColors.text)),
                    if (required)
                      const Text(' *',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w800)),
                  ]),
                  Text(file != null ? '✓ File selected' : subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: file != null
                              ? AppColors.primaryLight
                              : AppColors.text3)),
                ])),
            Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 18),
          ]),
        ),
      );
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withOpacity(0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.info, height: 1.4))),
        ]),
      );
}
