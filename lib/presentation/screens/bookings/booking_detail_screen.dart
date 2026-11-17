import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/booking_labels.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Inspection detail: when, where, who, and the next action. Rescheduling is
/// intentionally not offered until agents can fulfil it; cancel and re-request.
class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Inspection details'),
      body: FutureBuilder<BookingModel?>(
        future: ref.read(bookingRepositoryProvider).getBookingById(bookingId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final b = snap.data;
          if (b == null) return const PsEmpty(icon: Icons.event_busy_outlined, title: 'Inspection not found', message: 'It may have been removed.');
          return _Body(b: b, uid: uid);
        },
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final BookingModel b;
  final String? uid;
  const _Body({required this.b, required this.uid});
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late String _status = widget.b.status;

  Future<void> _do(Future<void> Function() f, String newStatus, String done) async {
    final ok = await runAction(context, f, success: done);
    if (ok && mounted) setState(() => _status = newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final uid = widget.uid ?? '';
    final isAgent = uid == b.agentId;
    final repo = ref.read(bookingRepositoryProvider);
    final active = _status == AppConstants.bookingPending || _status == AppConstants.bookingConfirmed;
    final tone = _status == AppConstants.bookingConfirmed ? PsTone.success : _status == AppConstants.bookingPending ? PsTone.warning : PsTone.neutral;

    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 24), children: [
      PsCard(
        color: AppColors.primaryPale,
        borderColor: AppColors.primaryPale2,
        child: Row(children: [
          const Icon(Icons.event_outlined, size: 32, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(formatVisit(b.dateTime), style: AppText.h3)),
          PsPill(bookingStatusLabel(_status), tone: tone),
        ]),
      ),
      const SizedBox(height: 12),
      PsCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/listing/${b.listingId}'),
        semanticLabel: b.listingTitle,
        child: Row(children: [
          SizedBox(width: 110, height: 96, child: PsNetImage(b.listingThumbnail, radius: BorderRadius.circular(12))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.listingTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
            const SizedBox(height: 6),
            Text('View home', style: AppText.label.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
          ])),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
      const SizedBox(height: 12),
      PsRowGroup([
        const PsListRow(icon: Icons.location_on_outlined, title: 'Meeting point', subtitle: 'Agree the exact meeting point in the conversation before you go.', chevron: false),
        PsListRow(
          leading: PsAvatar(url: isAgent ? b.userPhoto : b.agentPhoto, name: isAgent ? b.userName : b.agentName, size: 48),
          title: isAgent ? b.userName : b.agentName,
          subtitle: isAgent ? 'Renter' : 'Property agent',
          trailing: PsButton('Message', expand: false, kind: PsButtonKind.outline, icon: Icons.chat_bubble_outline_rounded, onPressed: () async {
            final l = await ref.read(listingRepositoryProvider).getById(b.listingId);
            if (l != null && context.mounted) await openChatAbout(context, ref, l);
          }),
          chevron: false,
        ),
      ]),
      const SizedBox(height: 12),
      PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const PsIconCircle(Icons.checklist_rounded), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('What to check', style: AppText.title), Text('A quick guide for a smooth inspection.', style: AppText.small)]))]),
        const SizedBox(height: 8),
        for (final t in const [('Water and power', Icons.water_drop_outlined), ('Room condition', Icons.home_outlined), ('All fees in writing', Icons.description_outlined)])
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(t.$2, size: 20), const SizedBox(width: 12), Text(t.$1, style: AppText.body)])),
      ])),
      if (b.message != null && b.message!.isNotEmpty) ...[const SizedBox(height: 12), PsNote('Message: ${b.message}')],
      const SizedBox(height: 16),
      if (isAgent && _status == AppConstants.bookingPending) ...[
        PsButton('Confirm inspection', onPressed: () => _do(() => repo.confirmBooking(b.id, actorId: uid), AppConstants.bookingConfirmed, 'Inspection confirmed.')),
        const SizedBox(height: 10),
        PsButton('Decline', kind: PsButtonKind.outline, onPressed: () => _do(() => repo.rejectBooking(b.id, actorId: uid, reason: 'Not available at that time'), AppConstants.bookingRejected, 'Inspection declined.')),
      ] else if (isAgent && _status == AppConstants.bookingConfirmed && b.dateTime.isBefore(DateTime.now())) ...[
        PsButton('Mark as completed', onPressed: () => _do(() => repo.completeBooking(b.id, actorId: uid), AppConstants.bookingCompleted, 'Marked as completed.')),
      ],
      if (!isAgent && active) ...[
        PsButton('Share visit details', icon: Icons.share_outlined, onPressed: () async {
          await Clipboard.setData(ClipboardData(text: 'I am visiting ${b.listingTitle} on ${formatVisit(b.dateTime)} with ${b.agentName}.'));
          if (context.mounted) showPsSnack(context, 'Visit details copied. Send them to someone you trust.');
        }),
      ],
      if (active) ...[
        const SizedBox(height: 10),
        PsButton('Cancel inspection', kind: PsButtonKind.danger, icon: Icons.close_rounded, onPressed: () async {
          final sure = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Cancel this inspection?'), content: const Text('The other person will be told.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel inspection'))]));
          if (sure == true) await _do(() => repo.cancelBooking(b.id, actorId: uid), AppConstants.bookingCancelled, 'Inspection cancelled.');
        }),
      ],
    ]);
  }
}
