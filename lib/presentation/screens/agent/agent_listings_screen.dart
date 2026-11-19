import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../listings/tour_score.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// My listings: Active · Drafts · Paused · Archived. Includes the
/// availability-refresh queue and Mark rented. Nobody has to delete a home
/// just to stop enquiries; pause or mark rented instead.
class AgentListingsScreen extends ConsumerStatefulWidget {
  const AgentListingsScreen({super.key});
  @override
  ConsumerState<AgentListingsScreen> createState() => _State();
}

class _State extends ConsumerState<AgentListingsScreen> {
  int _tab = 0;
  static const _tabs = ['Active', 'Drafts', 'Paused', 'Archived'];

  bool _inTab(ListingModel l) => _inTabIndex(_tab, l);

  bool _inTabIndex(int tab, ListingModel l) {
    switch (tab) {
      case 0:
        return l.isLive;
      case 1:
        return l.isDraft;
      case 2:
        return l.status == 'paused';
      default:
        return l.status == 'archived' || l.status == 'rented';
    }
  }

  Future<void> _publish(ListingModel l) async {
    var ok = false;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
        title: const Text('Go live?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Renters will see this home and the date you confirm it is available.'),
          CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: ok, onChanged: (v) => set(() => ok = v ?? false), title: const Text('This home is available today.')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not yet')), TextButton(onPressed: ok ? () => Navigator.pop(c, true) : null, child: const Text('Go live'))],
      )),
    );
    if (go == true && mounted) {
      await runAction(context, () => ref.read(functionsServiceProvider).publishListing(l.id), success: 'Your home is live.');
    }
  }

  Future<void> _status(ListingModel l, String status, String done) =>
      runAction(context, () => ref.read(functionsServiceProvider).setListingStatus(l.id, status), success: done);

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final async = uid == null ? null : ref.watch(agentListingsProvider(uid));
    final all = async?.asData?.value ?? const <ListingModel>[];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(padding: EdgeInsets.zero, children: [
        PsGreenHeader(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const PropsureLogo(light: true, size: 30), const Spacer(), PsButton('Add', expand: false, kind: PsButtonKind.onDark, icon: Icons.add_rounded, onPressed: () => context.push('/listing/new'))]),
            const SizedBox(height: 12),
            Text('My listings', style: AppText.display.copyWith(color: Colors.white)),
          ]),
        ),
        Padding(
          padding: kPagePadding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            _TabBar(
              labels: _tabs,
              counts: [for (var i = 0; i < _tabs.length; i++) all.where((l) => _inTabIndex(i, l)).length],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            if (async == null)
              const PsEmpty(icon: Icons.lock_outline_rounded, title: 'Sign in', message: 'Sign in to manage your listings.')
            else
              async.when(
                loading: () => const Column(children: [PsListingSkeleton()]),
                error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(agentListingsProvider(uid!))),
                data: (all) {
                  final list = all.where(_inTab).toList();
                  if (list.isEmpty) {
                    return PsEmpty(icon: Icons.home_work_outlined, title: 'Nothing in ${_tabs[_tab].toLowerCase()}', message: _tab == 1 ? 'Drafts you start will wait here until you publish.' : 'Add a video listing to get started.', actionLabel: 'Add a home', onAction: () => context.push('/listing/new'));
                  }
                  return Column(children: [for (final l in list) _Card(l: l, tab: _tab, onPublish: () => _publish(l), onStatus: (s, m) => _status(l, s, m))]);
                },
              ),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

class _Card extends ConsumerWidget {
  final ListingModel l;
  final int tab;
  final VoidCallback onPublish;
  final Future<void> Function(String, String) onStatus;
  const _Card({required this.l, required this.tab, required this.onPublish, required this.onStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = freshnessOf(l);
    final cost = MoveInBreakdown.of(l);
    final needsRefresh = l.isLive && (f.state == Freshness.needsRefresh || f.state == Freshness.stale || f.state == Freshness.unknown);
    final missingCosts = l.categoryEnum.hasMoveInCost && l.charges.isEmpty;

    Widget status;
    if (l.isDraft) {
      status = PsPill(missingCosts ? 'Draft · missing move-in costs' : 'Draft', tone: missingCosts ? PsTone.warning : PsTone.neutral, small: true);
    } else if (f.state == Freshness.stale) {
      status = const PsPill('Hidden: confirm availability', tone: PsTone.danger, small: true);
    } else if (needsRefresh) {
      status = const PsPill('Refresh due', tone: PsTone.warning, icon: Icons.error_outline_rounded, small: true);
    } else if (l.isLive) {
      status = const PsPill('Active', small: true);
    } else {
      status = PsPill(l.status == 'rented' ? 'Rented' : l.status == 'paused' ? 'Paused' : 'Archived', tone: PsTone.neutral, small: true);
    }

    Widget primary;
    if (l.isDraft) {
      // One clear button. (Two side by side were wider than the card and the
      // Publish button was cut off the screen.)
      primary = PsButton('Publish', expand: false, onPressed: onPublish);
    } else if (needsRefresh) {
      primary = PsButton('Confirm availability', expand: false, icon: Icons.check_circle_outline_rounded, onPressed: () => runAction(context, () => ref.read(functionsServiceProvider).confirmAvailability(l.id), success: 'Availability confirmed today.'));
    } else if (l.isLive) {
      primary = PsButton('Mark rented', expand: false, kind: PsButtonKind.outline, onPressed: () => onStatus('rented', 'Marked as rented.'));
    } else {
      primary = PsButton('Resume', expand: false, kind: PsButtonKind.outline, onPressed: () async {
        await runAction(context, () => ref.read(functionsServiceProvider).publishListing(l.id), success: 'Back live. Availability confirmed today.');
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PsCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          InkWell(
            onTap: () => l.isLive ? context.push('/listing/${l.id}') : context.push('/listing/edit/${l.id}'),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, height: 110, child: PsNetImage(l.coverUrl, radius: BorderRadius.circular(12))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l.title}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
                const SizedBox(height: 4),
                Text(l.priceLabel, style: AppText.h3.copyWith(color: AppColors.primary)),
                const SizedBox(height: 6),
                status,
                const SizedBox(height: 6),
                if (l.isLive) Text(f.confirmedLabel == 'Not confirmed' ? 'Availability not confirmed' : 'Availability ${f.confirmedLabel.toLowerCase()}', style: AppText.caption),
                if (l.isSponsored) Text('Sponsored until ${l.featuredUntil?.day}/${l.featuredUntil?.month}', style: AppText.caption.copyWith(color: AppColors.goldDark)),
                if (l.categoryEnum.hasMoveInCost && l.charges.isNotEmpty) Text(cost.cardLabel, style: AppText.caption),
              ])),
            ]),
          ),
          if (l.videoStatus == VideoStatus.needsReview)
            Padding(padding: const EdgeInsets.only(top: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PsNote('Your video frames are ready to review. Choose your frames, then publish.', icon: Icons.photo_library_outlined, tone: PsTone.warning),
              const SizedBox(height: 8),
              PsButton('Review frames', expand: false, icon: Icons.photo_library_outlined, onPressed: () => context.push('/listing/${l.id}/frames')),
            ])),
          if (l.videoStatus == VideoStatus.ready && l.stills.any((x) => x.source == 'video') && !l.stills.any((x) => x.source == 'video' && (x.label ?? '').trim().isNotEmpty))
            Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
              const Icon(Icons.meeting_room_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(child: PsLink('Name the rooms in your video', onTap: () => context.push('/listing/${l.id}/frames'))),
            ])),
          if (l.videoStatus == VideoStatus.ready && l.stills.any((x) => x.source == 'video' && (x.label ?? '').trim().isNotEmpty))
            Padding(padding: const EdgeInsets.only(top: 10), child: TourScoreNote(listing: l)),
          const Divider(height: 24),
          Row(children: [
            PsLink(l.isDraft ? 'Edit draft' : 'Edit', onTap: () => context.push('/listing/edit/${l.id}')),
            const SizedBox(width: 12),
            if (l.videoStatus == VideoStatus.needsReview) PsLink('Review frames', onTap: () => context.push('/listing/${l.id}/frames')) else PsLink('Share', onTap: () async { await Clipboard.setData(ClipboardData(text: 'https://propsure.africa/l/${l.id}')); if (context.mounted) showPsSnack(context, 'Link copied.'); }),
            const Spacer(),
            Flexible(child: primary),
          ]),
          if (l.isLive || l.status == 'paused')
            Align(alignment: Alignment.centerRight, child: PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (v) {
                if (v == 'pause') onStatus('paused', 'Paused. Renters no longer see it.');
                if (v == 'archive') onStatus('archived', 'Archived.');
                if (v == 'boost') context.push('/payment/boost/${l.id}');
              },
              itemBuilder: (_) => [
                if (l.isLive) const PopupMenuItem(value: 'boost', child: Text('Promote (Sponsored)')),
                if (l.isLive) const PopupMenuItem(value: 'pause', child: Text('Pause listing')),
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
              child: const Padding(padding: EdgeInsets.all(8), child: Text('More…')),
            )),
        ]),
      ),
    );
  }
}


/// Four equal tabs that always fit the screen, each with a live count.
class _TabBar extends StatelessWidget {
  final List<String> labels;
  final List<int> counts;
  final int index;
  final ValueChanged<int> onChanged;
  const _TabBar({required this.labels, required this.counts, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.md + 2)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              label: '${labels[i]}, ${counts[i]}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 48,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: i == index ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(labels[i], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: i == index ? Colors.white : AppColors.text)),
                      if (counts[i] > 0) ...[
                        const SizedBox(width: 5),
                        Text('${counts[i]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == index ? Colors.white70 : AppColors.text3)),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
