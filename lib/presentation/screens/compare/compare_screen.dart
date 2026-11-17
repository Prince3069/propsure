import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/utils/move_in_cost.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Side-by-side comparison of up to three homes. Missing details are shown as
/// "Ask agent" — never guessed. Scrolls sideways when more than two columns.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  String _utility(ListingModel l, List<String> keys) {
    for (final a in l.amenities) {
      final low = a.toLowerCase();
      if (keys.any(low.contains)) return a;
    }
    return 'Ask agent';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(compareListProvider);
    final listings = [for (final id in ids) ref.watch(listingByIdProvider(id)).asData?.value].whereType<ListingModel>().toList();
    final w = (MediaQuery.of(context).size.width - 48 - 96) / 2; // value columns fit two on a phone

    Widget cell(String t, {bool bold = false, Color? color}) => SizedBox(
          width: w.clamp(120, 220),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(t, style: AppText.body.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color))),
        );

    List<(String, String Function(ListingModel))> rows() => [
          ('Annual rent', (l) => l.categoryEnum.hasMoveInCost ? Money.short(l.price) : l.priceLabel),
          ('Move-in', (l) {
            if (!l.categoryEnum.hasMoveInCost) return 'Not applicable';
            if (l.charges.isEmpty) return 'Ask agent';
            final b = MoveInBreakdown.of(l);
            return b.complete ? Money.short(b.subtotal) : '${Money.short(b.subtotal)} + unconfirmed';
          }),
          ('Bedrooms', (l) => '${l.bedrooms}'),
          ('Bathrooms', (l) => '${l.bathrooms}'),
          ('Water', (l) => _utility(l, ['water', 'borehole'])),
          ('Power', (l) => _utility(l, ['meter', 'power', 'electric', 'generator', 'solar'])),
          ('Availability', (l) => freshnessOf(l).short),
          ('Authority', (l) => l.authority.isCurrent ? 'Reviewed' : 'Not reviewed'),
        ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: 'Compare homes', centerTitle: true, action: PsLink('Clear', underline: false, onTap: () => ref.read(compareListProvider.notifier).clear())),
      body: listings.isEmpty
          ? PsEmpty(icon: Icons.compare_arrows_rounded, title: 'Nothing to compare yet', message: 'Choose up to three homes from Saved or a listing page.', actionLabel: 'Go to Saved', onAction: () => context.go('/saved'))
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(width: 96),
                    for (final l in listings)
                      SizedBox(
                        width: w.clamp(120, 220),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(height: 120, child: PsNetImage(l.coverUrl, radius: BorderRadius.circular(AppRadius.md))),
                            const SizedBox(height: 8),
                            Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
                          ]),
                        ),
                      ),
                  ]),
                  const Divider(),
                  for (final r in rows()) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 96, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(r.$1, style: AppText.small))),
                      for (final l in listings) cell(r.$2(l), bold: r.$1 == 'Move-in', color: r.$2(l) == 'Ask agent' ? AppColors.goldDark : null),
                    ]),
                    const Divider(height: 1),
                  ],
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('Missing details are shown, not guessed.', style: AppText.caption)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const SizedBox(width: 96),
                    for (final l in listings)
                      SizedBox(width: w.clamp(120, 220), child: Padding(padding: const EdgeInsets.only(right: 8), child: PsButton('View home', kind: PsButtonKind.outline, onPressed: () => context.push('/listing/${l.id}')))),
                  ]),
                ]),
              ),
              Padding(
                padding: kPagePadding,
                child: Column(children: [
                  const SizedBox(height: 16),
                  PsButton('Share comparison', onPressed: () async {
                    final user = ref.read(currentUserModelProvider).asData?.value;
                    if (user == null) {
                      context.push('/auth?reason=save&redirect=${Uri.encodeComponent('/compare')}');
                      return;
                    }
                    try {
                      final id = await ref.read(shortlistRepositoryProvider).create(uid: user.uid, ownerName: user.displayName, name: 'Comparison', listingIds: ids);
                      final url = await ref.read(functionsServiceProvider).createShortlistInvite(id);
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) { showPsSnack(context, 'Link copied. Anyone you send it to can join this private shortlist.'); context.push('/shortlist/$id'); }
                    } catch (e) {
                      if (context.mounted) showPsSnack(context, e.toString(), error: true);
                    }
                  }),
                ]),
              ),
            ]),
    );
  }
}
