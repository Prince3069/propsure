import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

class SavedListingsScreen extends ConsumerStatefulWidget {
  const SavedListingsScreen({super.key});
  @override
  ConsumerState<SavedListingsScreen> createState() => _SavedState();
}

class _SavedState extends ConsumerState<SavedListingsScreen> {
  int _tab = 0;
  bool _compareMode = false;
  final Set<String> _picked = {};
  int _sort = 0; // 0 recent, 1 price low, 2 price high
  bool _busy = false;

  Future<void> _invite(List<ListingModel> saved) async {
    final uid = ref.read(currentUserIdProvider);
    final user = ref.read(currentUserModelProvider).asData?.value;
    if (uid == null || user == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(shortlistRepositoryProvider);
      final existing = ref.read(myShortlistsProvider).asData?.value ?? const [];
      final id = existing.isNotEmpty ? existing.first.id : await repo.create(uid: uid, ownerName: user.name, listingIds: saved.map((l) => l.id).toList());
      final url = await ref.read(functionsServiceProvider).createShortlistInvite(id);
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      showPsSnack(context, 'Invite link copied. It works for 7 days and for up to 5 people.');
      context.push('/shortlist/$id');
    } catch (e) {
      if (mounted) showPsSnack(context, 'Could not create the invite. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(child: PsEmpty(icon: Icons.bookmark_border_rounded, title: 'Sign in to save homes', message: 'Your saved homes stay with your account.', actionLabel: 'Sign in', onAction: () => context.push('/auth?redirect=/saved'))),
      );
    }
    final saved = ref.watch(savedListingsProvider(uid));
    final shortlists = ref.watch(myShortlistsProvider).asData?.value ?? const [];
    final savedIds = ref.watch(savedIdsProvider);

    List<ListingModel> sorted(List<ListingModel> l) {
      final c = [...l];
      if (_sort == 1) c.sort((a, b) => a.price.compareTo(b.price));
      if (_sort == 2) c.sort((a, b) => b.price.compareTo(a.price));
      return c;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), children: [
        Row(children: [const PropsureLogo(), const Spacer()]),
        const SizedBox(height: 12),
        Text('Saved homes', style: AppText.h1.copyWith(fontSize: 34)),
        const SizedBox(height: 14),
        PsSegmented(labels: const ['My shortlist', 'With others'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        const SizedBox(height: 12),
        if (_tab == 0) ...[
          Row(children: [
            Expanded(child: PsButton(_compareMode ? (_picked.length >= 2 ? 'Compare ${_picked.length}' : 'Pick 2 or 3') : 'Compare', kind: PsButtonKind.outline, icon: Icons.compare_arrows_rounded, onPressed: () {
              if (!_compareMode) { setState(() { _compareMode = true; _picked.clear(); }); return; }
              if (_picked.length >= 2) {
                final n = ref.read(compareListProvider.notifier);
                n.clear();
                for (final id in _picked) { n.toggle(id); }
                setState(() => _compareMode = false);
                context.push('/compare');
              } else {
                setState(() => _compareMode = false);
              }
            })),
            const SizedBox(width: 12),
            Expanded(child: PsButton(const ['Sort: Recent', 'Sort: Price ↑', 'Sort: Price ↓'][_sort], kind: PsButtonKind.outline, icon: Icons.sort_rounded, onPressed: () => setState(() => _sort = (_sort + 1) % 3))),
          ]),
          const SizedBox(height: 12),
          saved.when(
            loading: () => const PsListingSkeleton(),
            error: (_, __) => PsError(onRetry: () => ref.invalidate(savedListingsProvider(uid))),
            data: (list) {
              if (list.isEmpty) return const PsEmpty(icon: Icons.bookmark_border_rounded, title: 'No saved homes yet', message: 'Tap the bookmark on any home to keep it here.');
              final items = sorted(list);
              return Column(children: [
                for (final l in items.take(60)) Padding(padding: const EdgeInsets.only(bottom: 12), child: Stack(children: [
                  ListingCard(listing: l, compact: true, isSaved: savedIds.contains(l.id), onSaveTap: () => toggleSaved(context, ref, l.id), onTap: () => _compareMode ? setState(() { _picked.contains(l.id) ? _picked.remove(l.id) : (_picked.length < 3 ? _picked.add(l.id) : null); }) : context.push('/listing/${l.id}')),
                  if (_compareMode) Positioned(left: 8, top: 8, child: Container(decoration: BoxDecoration(color: _picked.contains(l.id) ? AppColors.primary : Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)), padding: const EdgeInsets.all(4), child: Icon(Icons.check_rounded, size: 18, color: _picked.contains(l.id) ? Colors.white : Colors.transparent))),
                ])),
                const SizedBox(height: 4),
                PsCard(color: AppColors.primaryPale, child: Row(children: [
                  const PsIconCircle(Icons.group_add_outlined, size: 56),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Share your shortlist', style: AppText.h3), Text('Decide together, without forwarding 20 videos.', style: AppText.small)])),
                  const SizedBox(width: 8),
                  PsButton('Invite someone', expand: false, loading: _busy, onPressed: () => _invite(items)),
                ])),
              ]);
            },
          ),
        ] else ...[
          if (shortlists.isEmpty)
            const PsEmpty(icon: Icons.groups_outlined, title: 'Nothing shared yet', message: 'Invite a family member or friend from My shortlist and decide together.')
          else
            for (final s in shortlists) Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(onTap: () => context.push('/shortlist/${s.id}'), semanticLabel: s.name, child: Row(children: [
              const PsIconCircle(Icons.groups_outlined, size: 52),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: AppText.title), Text('${s.listingIds.length} homes · ${s.memberIds.length} ${s.memberIds.length == 1 ? 'person' : 'people'}', style: AppText.small)])),
              const Icon(Icons.chevron_right_rounded),
            ]))),
        ],
      ])),
    );
  }
}
