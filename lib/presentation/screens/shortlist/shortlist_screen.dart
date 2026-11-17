import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../../data/repositories/shortlist_repository.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// A private shortlist shared with invited people. Public listing facts and
/// private notes are separate: notes are visible to members only (enforced by
/// firestore.rules), and membership changes happen on the server.
class ShortlistScreen extends ConsumerWidget {
  final String shortlistId;
  const ShortlistScreen({super.key, required this.shortlistId});

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref.read(functionsServiceProvider).createShortlistInvite(shortlistId);
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) showPsSnack(context, 'Invite link copied. It works for 7 days and for up to 5 people.');
    } catch (e) {
      if (context.mounted) showPsSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _note(BuildContext context, WidgetRef ref, ShortlistModel s, String listingId) async {
    final uid = ref.read(currentUserIdProvider)!;
    final c = TextEditingController(text: s.notes[listingId]?[uid] ?? '');
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add a note', style: AppText.h3),
          const SizedBox(height: 4),
          Text('Only people in this shortlist can see it.', style: AppText.caption),
          const SizedBox(height: 12),
          PsField(label: 'Note', controller: c, maxLines: 3, maxLength: 200),
          const SizedBox(height: 12),
          PsButton('Save note', onPressed: () => Navigator.pop(ctx, c.text)),
        ]),
      ),
    );
    if (text != null && context.mounted) {
      await runAction(context, () => ref.read(shortlistRepositoryProvider).setNote(s.id, listingId, uid, text));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shortlistProvider(shortlistId));
    final uid = ref.watch(currentUserIdProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const PsError(message: 'You may not have access to this shortlist. Ask the owner to invite you again.'),
        data: (s) {
          if (s == null) return const PsEmpty(icon: Icons.group_outlined, title: 'Shortlist not found', message: 'It may have been deleted.');
          final isOwner = s.ownerId == uid;
          return SafeArea(
            child: Column(children: [
              PsTopBar(title: s.name, action: PsLink('Share', onTap: isOwner ? () => _invite(context, ref) : null)),
              Expanded(
                child: ListView(padding: kPagePadding, children: [
                  const PsHeadline('House hunting,', accent: 'better together.'),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (final id in s.memberIds.take(5)) Padding(padding: const EdgeInsets.only(right: 8), child: PsAvatar(name: s.memberNames[id] ?? 'M', size: 44)),
                    const SizedBox(width: 6),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.memberNames.values.join(' + '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title),
                      Text('Private shortlist', style: AppText.small),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  if (s.listingIds.isEmpty)
                    const PsEmpty(icon: Icons.bookmark_add_outlined, title: 'No homes yet', message: 'Add homes from Saved to start comparing together.'),
                  for (final id in s.listingIds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ref.watch(listingByIdProvider(id)).when(
                            loading: () => const PsListingSkeleton(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (l) => l == null ? const SizedBox.shrink() : _Item(l: l, s: s, uid: uid, onNote: () => _note(context, ref, s, id), onRemove: () => runAction(context, () => ref.read(shortlistRepositoryProvider).removeListing(s.id, id))),
                          ),
                    ),
                  Row(children: [
                    Expanded(child: PsButton('Compare homes', kind: PsButtonKind.outline, icon: Icons.compare_arrows_rounded, onPressed: s.listingIds.length < 2 ? null : () {
                      final n = ref.read(compareListProvider.notifier)..clear();
                      for (final id in s.listingIds.take(3)) { n.toggle(id); }
                      context.push('/compare');
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: PsButton('Add a home', icon: Icons.add_rounded, onPressed: () => context.go('/saved'))),
                  ]),
                  const SizedBox(height: 14),
                  PsCard(child: Row(children: [
                    const Icon(Icons.group_outlined, color: AppColors.text2),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Only invited people can see your notes.', style: AppText.small)),
                    if (isOwner) PsButton('Invite someone', expand: false, onPressed: () => _invite(context, ref)),
                  ])),
                  const SizedBox(height: 24),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final ListingModel l;
  final ShortlistModel s;
  final String? uid;
  final VoidCallback onNote;
  final VoidCallback onRemove;
  const _Item({required this.l, required this.s, required this.uid, required this.onNote, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final notes = s.notes[l.id] ?? const {};
    final cost = MoveInBreakdown.of(l);
    return PsCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/listing/${l.id}'),
      semanticLabel: l.title,
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, height: 120, child: PsNetImage(l.coverUrl, radius: BorderRadius.circular(AppRadius.md))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title)), PsIconButton(icon: Icons.close_rounded, tooltip: 'Remove from shortlist', onPressed: onRemove, size: 40)]),
            Text(l.location.area, style: AppText.small),
            const SizedBox(height: 6),
            Text(l.priceLabel, style: AppText.title.copyWith(color: AppColors.primary)),
            if (l.categoryEnum.hasMoveInCost) Text(cost.cardLabel, style: AppText.small.copyWith(color: AppColors.text)),
            if (!l.isActive) const Padding(padding: EdgeInsets.only(top: 6), child: PsPill('May no longer be available', tone: PsTone.warning, small: true)),
          ])),
        ]),
        const SizedBox(height: 10),
        for (final e in notes.entries.where((e) => e.value.isNotEmpty))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text('${e.value}\n— ${s.memberNames[e.key] ?? 'Member'}', style: AppText.small),
          ),
        Align(alignment: Alignment.centerLeft, child: PsLink(notes[uid]?.isNotEmpty == true ? 'Edit your note' : 'Add a note', onTap: onNote, underline: false)),
      ]),
    );
  }
}
