import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

final _latestSupportProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('support_requests')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());
});

/// Shows the real status of the user's most recent request. Steps only move
/// when the server changes the status.
class SupportStatusScreen extends ConsumerWidget {
  const SupportStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_latestSupportProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Support request'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => PsError(onRetry: () => ref.invalidate(_latestSupportProvider)),
        data: (r) {
          if (r == null) {
            return PsEmpty(icon: Icons.support_agent_rounded, title: 'No requests yet', message: 'When you contact support, you can follow it here.', actionLabel: 'Get help', onAction: () => context.push('/support'));
          }
          final status = r['status'] as String? ?? 'received';
          final stage = status == 'received' ? 0 : status == 'assigned' ? 1 : 2;
          final isReport = r['kind'] == 'report';
          final listingId = r['listingId'] as String?;
          final reference = r['reference'] as String? ?? '';
          final subject = (r['subject'] as String?)?.isNotEmpty == true ? r['subject'] as String : (isReport ? 'Report received' : 'Support request');

          Widget step(int i, String title, String body) {
            final done = stage >= i;
            return Padding(padding: const EdgeInsets.only(bottom: 18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? AppColors.primary : AppColors.text3, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.title.copyWith(color: done ? AppColors.text : AppColors.text2)), Text(body, style: AppText.small)])),
            ]));
          }

          return ListView(padding: kPagePadding, children: [
            const PsHeadline('We have your', accent: 'message.', size: 36),
            const SizedBox(height: 16),
            PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject, style: AppText.h3),
              const SizedBox(height: 8),
              PsPill(status == 'received' ? 'Received' : status == 'assigned' ? 'In review' : 'Outcome shared', tone: status == 'received' ? PsTone.neutral : status == 'assigned' ? PsTone.info : PsTone.success, icon: Icons.check_circle_outline_rounded),
              const SizedBox(height: 8),
              Text('Reference $reference', style: AppText.small),
            ])),
            const SizedBox(height: 20),
            step(0, 'Received', 'Your request has been received.'),
            step(1, 'Assigned for review', 'We will review your request and may reach out if we need more information.'),
            step(2, 'Outcome shared', 'We will update you here once there is an outcome.'),
            const Divider(height: 24),
            Text('Updates will appear here and in your inbox.', style: AppText.small),
            const SizedBox(height: 12),
            PsButton('Add more information', kind: PsButtonKind.outline, icon: Icons.add_circle_outline_rounded, onPressed: () => context.push('/support')),
            if (listingId != null && listingId.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: PsLink('View reported listing', chevron: true, onTap: () => context.push('/listing/$listingId'))),
            const SizedBox(height: 16),
            PsButton('Back to inbox', onPressed: () => context.go('/messages')),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}
