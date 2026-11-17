import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/booking_labels.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/repositories/enquiry_repository.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Inspection requests and enquiries that need a reply.
class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) {
      return Scaffold(backgroundColor: AppColors.surface, body: SafeArea(child: PsEmpty(icon: Icons.groups_outlined, title: 'Sign in to see your leads', message: 'Renters who ask about your homes appear here.', actionLabel: 'Sign in', onAction: () => context.push('/auth?redirect=/leads'))));
    }
    final bookings = ref.watch(_leadBookingsProvider(uid)).asData?.value ?? const [];
    final enquiries = ref.watch(agentEnquiriesProvider(uid)).asData?.value ?? const <EnquiryModel>[];
    final upcoming = bookings.where((b) => b.status == 'pending' || b.status == 'confirmed').toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final open = enquiries.where((e) => e.responseState == EnquiryResponseState.awaitingResponse).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), children: [
        Text('Leads', style: AppText.h1.copyWith(fontSize: 34, color: AppColors.primary)),
        Text('People asking about your homes.', style: AppText.bodyMuted),
        const SizedBox(height: 16),
        const PsSectionTitle('Inspection requests'),
        const SizedBox(height: 10),
        if (upcoming.isEmpty) Text('No inspections to handle.', style: AppText.bodyMuted),
        for (final b in upcoming) Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(onTap: () => context.push('/booking/${b.id}'), semanticLabel: b.listingTitle, child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PsPill(bookingStatusLabel(b.status), tone: b.status == 'confirmed' ? PsTone.success : PsTone.warning, small: true),
            const SizedBox(height: 6),
            Text(formatVisit(b.dateTime), style: AppText.title),
            Text('${b.userName} · ${b.listingTitle}', style: AppText.small, maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_right_rounded),
        ]))),
        const SizedBox(height: 14),
        const PsSectionTitle('Enquiries'),
        const SizedBox(height: 10),
        if (open.isEmpty) Text('No enquiries waiting for a reply.', style: AppText.bodyMuted),
        for (final e in open) Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.enquirerName.isEmpty ? 'A renter' : e.enquirerName, style: AppText.title),
          Text(e.listingTitle, style: AppText.small),
          if ((e.message ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(e.message!, style: AppText.body, maxLines: 3, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 10),
          Row(children: [
            if (e.enquirerPhone.isNotEmpty) Expanded(child: PsButton('Call', kind: PsButtonKind.outline, icon: Icons.phone_outlined, onPressed: () => launchUrl(Uri(scheme: 'tel', path: e.enquirerPhone)))),
            if (e.enquirerPhone.isNotEmpty) const SizedBox(width: 10),
            Expanded(child: PsButton('Mark replied', onPressed: () => runAction(context, () => ref.read(enquiryRepositoryProvider).markResponded(e.id), success: 'Marked as replied.'))),
          ]),
        ]))),
      ])),
    );
  }
}

final _leadBookingsProvider = StreamProvider.autoDispose.family((ref, String uid) => ref.watch(bookingRepositoryProvider).watchAgentBookings(uid));
