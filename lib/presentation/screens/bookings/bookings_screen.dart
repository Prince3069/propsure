import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/booking_labels.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../providers/app_providers.dart';

/// Inspections. A requested appointment is visibly different from a
/// confirmed one; date, time, property and next action come first.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});
  @override
  ConsumerState<BookingsScreen> createState() => _State();
}

class _State extends ConsumerState<BookingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final isAgent = ref.watch(isAgentProvider);
    final async = uid == null ? null : (isAgent ? ref.watch(agentBookingsProvider(uid)) : ref.watch(userBookingsProvider(uid)));
    final cutoff = DateTime.now().subtract(const Duration(hours: 3));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(padding: EdgeInsets.zero, children: [
        PsGreenHeader(
          padding: const EdgeInsets.fromLTRB(12, 0, 24, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PsTopBar(dark: true),
            const Padding(padding: EdgeInsets.only(left: 12), child: PropsureLogo(light: true, size: 30)),
          ]),
        ),
        Padding(
          padding: kPagePadding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            Text('Inspections', style: AppText.display),
            Text('Your scheduled property viewings.', style: AppText.bodyMuted),
            const SizedBox(height: 16),
            PsSegmented(labels: const ['Upcoming', 'Past'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 16),
            if (async == null)
              const PsEmpty(icon: Icons.lock_outline_rounded, title: 'Sign in to see inspections', message: 'Requests you make appear here.')
            else
              async.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                error: (_, __) => PsError(onRetry: () => ref.invalidate(userBookingsProvider(uid!))),
                data: (all) {
                  final upcoming = all.where((b) => (b.status == AppConstants.bookingPending || b.status == AppConstants.bookingConfirmed) && b.dateTime.isAfter(cutoff)).toList()
                    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                  final past = all.where((b) => !upcoming.contains(b)).toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));
                  final list = _tab == 0 ? upcoming : past;
                  if (list.isEmpty) {
                    return PsEmpty(icon: Icons.event_outlined, title: _tab == 0 ? 'No upcoming inspections' : 'No past inspections', message: 'Request an inspection from a home or from a conversation.', actionLabel: 'Find a home', onAction: () => context.go('/home'));
                  }
                  return Column(children: [for (final b in list) _Tile(b: b, isAgent: isAgent)]);
                },
              ),
            const SizedBox(height: 12),
            PsCard(color: AppColors.primaryPale, borderColor: AppColors.primaryPale2, child: Row(children: [
              const Icon(Icons.shield_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Before you go', style: AppText.title), Text('Confirm the meeting point and let someone know.', style: AppText.small)])),
            ])),
            const SizedBox(height: 16),
            if (!isAgent) PsButton('Find another home', icon: Icons.add_rounded, onPressed: () => context.go('/home')),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final BookingModel b;
  final bool isAgent;
  const _Tile({required this.b, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final confirmed = b.status == AppConstants.bookingConfirmed;
    final pending = b.status == AppConstants.bookingPending;
    final tone = confirmed ? PsTone.success : pending ? PsTone.warning : PsTone.neutral;
    final label = pending ? (isAgent ? 'Needs your confirmation' : 'Awaiting agent confirmation') : bookingStatusLabel(b.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PsCard(
        onTap: () => context.push('/booking/${b.id}'),
        semanticLabel: '${b.listingTitle}, $label, ${formatVisit(b.dateTime)}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [PsPill(label, tone: tone, small: true), const Spacer(), const Icon(Icons.chevron_right_rounded)]),
          const SizedBox(height: 8),
          Text(formatVisit(b.dateTime), style: AppText.h3),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(width: 84, height: 84, child: PsNetImage(b.listingThumbnail, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.listingTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
              Text(isAgent ? 'With ${b.userName}' : 'With ${b.agentName}', style: AppText.small),
            ])),
          ]),
        ]),
      ),
    );
  }
}
