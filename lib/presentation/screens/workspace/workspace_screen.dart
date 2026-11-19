import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../../data/repositories/enquiry_repository.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Agent home: counts come from real data, never placeholders.
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});
  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<WorkspaceScreen> {
  int _tab = 0;

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final user = ref.watch(currentUserModelProvider).asData?.value;
    if (uid == null) {
      return Scaffold(backgroundColor: AppColors.surface, body: SafeArea(child: PsEmpty(icon: Icons.work_outline_rounded, title: 'Sign in to open your workspace', message: 'Manage listings, leads and inspections in one place.', actionLabel: 'Sign in', onAction: () => context.push('/auth?redirect=/workspace'))));
    }
    final listingsAsync = ref.watch(agentListingsProvider(uid));
    final listings = listingsAsync.asData?.value ?? const <ListingModel>[];
    final bookings = ref.watch(_agentBookingsProvider(uid)).asData?.value ?? const [];
    final enquiries = ref.watch(agentEnquiriesProvider(uid)).asData?.value ?? const <EnquiryModel>[];

    final now = DateTime.now();
    bool today(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;
    final pending = bookings.where((b) => b.status == 'pending').length;
    final todayInspections = bookings.where((b) => b.status == 'confirmed' && today(b.dateTime)).length;
    final newEnq = enquiries.where((e) => e.responseState == EnquiryResponseState.awaitingResponse).length;
    final needsRefresh = listings.where((l) => l.isLive && (l.needsRefresh || freshnessOf(l).state != Freshness.confirmed)).toList();

    final shown = listings.where((l) => _tab == 0 ? l.isLive : _tab == 1 ? l.isDraft : l.status == 'paused').take(3).toList();

    Widget stat(IconData icon, Color bg, Color fg, String label, int n, String route) => Expanded(child: PsCard(onTap: () => context.go(route), semanticLabel: '${label.replaceAll('\n', ' ')} $n', padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: fg)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, maxLines: 2, style: AppText.small))),
          Row(children: [Expanded(child: Text('$n', style: AppText.h1.copyWith(fontSize: 30))), const Icon(Icons.chevron_right_rounded, size: 20)]),
        ])));

    Widget todo(String t, String route) => Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(onTap: () => context.go(route), semanticLabel: t, child: Row(children: [
          const Icon(Icons.check_box_outline_blank_rounded, color: AppColors.text3),
          const SizedBox(width: 14),
          Expanded(child: Text(t, style: AppText.title)),
          const Icon(Icons.chevron_right_rounded),
        ])));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            Row(children: [const PropsureLogo(light: true), const Spacer(), Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: PsAvatar(url: user?.profilePhoto, name: user?.name ?? 'A', size: 40))]),
            const SizedBox(height: 18),
            Text('AGENT WORKSPACE', style: AppText.caption.copyWith(color: Colors.white70, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text('Your workspace', style: AppText.h1.copyWith(color: Colors.white, fontSize: 34)),
            Text('${_greeting()}, ${(user?.name ?? '').trim().isEmpty ? 'there' : user!.name.trim().split(' ').first}.', style: AppText.h3.copyWith(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Everything you need to manage your listings, leads and inspections, in one place.', style: AppText.body.copyWith(color: Colors.white70)),
            const SizedBox(height: 16),
            PsButton('Add a video listing', kind: PsButtonKind.onDark, icon: Icons.add_rounded, onPressed: () => context.push('/listing/new')),
          ])),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            stat(Icons.chat_bubble_outline_rounded, AppColors.primaryPale, AppColors.primary, 'New\nenquiries', newEnq, '/leads'),
            const SizedBox(width: 10),
            stat(Icons.event_outlined, AppColors.warningPale, AppColors.goldDark, 'Inspections\ntoday', todayInspections, '/leads'),
            const SizedBox(width: 10),
            stat(Icons.sync_rounded, AppColors.errorPale, AppColors.error, 'Needs\nrefresh', needsRefresh.length, '/my-listings'),
          ]),
          const SizedBox(height: 22),
          Row(children: [Expanded(child: Text('Today’s priorities', style: AppText.h2)), PsLink('See all', onTap: () => context.go('/leads'), underline: false)]),
          const SizedBox(height: 10),
          if (pending == 0 && needsRefresh.isEmpty) Text('Nothing urgent right now.', style: AppText.bodyMuted),
          if (pending > 0) todo('Confirm $pending ${pending == 1 ? 'inspection' : 'inspections'}', '/leads'),
          if (needsRefresh.isNotEmpty) todo('Refresh availability on ${needsRefresh.length} ${needsRefresh.length == 1 ? 'home' : 'homes'}', '/my-listings'),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: Text('My listings', style: AppText.h2)), PsLink('See all', onTap: () => context.go('/my-listings'), underline: false)]),
          const SizedBox(height: 10),
          PsSegmented(labels: const ['Active', 'Drafts', 'Paused'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 12),
          if (listingsAsync.hasError)
            PsNote('Your listings could not be loaded. Open the Listings tab and tap Try again.\n${listingsAsync.error}', icon: Icons.error_outline_rounded, tone: PsTone.warning)
          else if (shown.isEmpty) Text(_tab == 1 ? 'No drafts.' : _tab == 2 ? 'Nothing paused.' : 'No active listings yet.', style: AppText.bodyMuted),
          for (final l in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(padding: const EdgeInsets.all(10), onTap: () => context.push(l.isDraft ? '/listing/edit/${l.id}' : '/listing/${l.id}'), semanticLabel: l.title, child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(AppRadius.sm), child: SizedBox(width: 110, height: 96, child: PsNetImage(l.coverUrl))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l.title} · ${l.location.area}', style: AppText.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(l.priceLabel, style: AppText.h3.copyWith(color: AppColors.primary)),
              const SizedBox(height: 4),
              if (l.isLive && (l.needsRefresh || freshnessOf(l).state != Freshness.confirmed))
                Row(children: [
                  Expanded(child: Row(children: [const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.goldDark), const SizedBox(width: 4), Flexible(child: Text('Availability due for refresh', style: AppText.caption.copyWith(color: AppColors.goldDark)))])),
                  PsButton('Update', kind: PsButtonKind.outline, expand: false, onPressed: () => runAction(context, () => ref.read(functionsServiceProvider).confirmAvailability(l.id), success: 'Availability confirmed for today.')),
                ])
              else
                PsPill(l.isDraft ? 'Draft' : l.status == 'paused' ? 'Paused' : freshnessOf(l).short, tone: l.isDraft ? PsTone.neutral : PsTone.success, small: true),
            ])),
          ]))),
          const SizedBox(height: 4),
          PsCard(color: AppColors.card, borderColor: AppColors.primary, onTap: () => context.push('/whatsapp-assist'), semanticLabel: 'Import from WhatsApp', child: Row(children: [
            const Icon(Icons.chat_rounded, size: 34, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Import from WhatsApp', style: AppText.h3.copyWith(color: AppColors.primary)), Text('Quickly add listings from shared property details', style: AppText.small)])),
            const Icon(Icons.chevron_right_rounded),
          ])),
        ])),
      ]),
    );
  }
}

final _agentBookingsProvider = StreamProvider.autoDispose.family((ref, String uid) => ref.watch(bookingRepositoryProvider).watchAgentBookings(uid));
