import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/listing_category.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Discover: one search entry, intent chips and a fresh neighbourhood feed.
/// No invented counts or claims — everything shown comes from real listings.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ListingCategory _cat = ListingCategory.rent;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);
    final saved = ref.watch(savedIdsProvider);
    final unread = ref.watch(notificationsUnreadCountProvider).asData?.value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeFeedProvider),
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, AppSpace.gutter, 32), children: [
            Row(children: [
              const PropsureLogo(size: 36),
              const Spacer(),
              Semantics(
                label: 'Location: Abuja',
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                  child: Row(children: [const Icon(Icons.location_on, color: AppColors.primary, size: 22), const SizedBox(width: 6), Text('Abuja', style: AppText.title)]),
                ),
              ),
              const SizedBox(width: 4),
              Stack(children: [
                PsIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onPressed: () => context.push('/notifications')),
                if (unread > 0) Positioned(right: 10, top: 10, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)))),
              ]),
            ]),
            const SizedBox(height: 20),
            const PsHeadline('Your next home.', accent: 'Fewer surprises.'),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Search by area, budget or property type',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => context.push('/search?category=${_cat.value}'),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                  child: Row(children: [const Icon(Icons.search_rounded, color: AppColors.text2), const SizedBox(width: 12), Text('Area, budget or property type', style: AppText.bodyMuted.copyWith(color: AppColors.text3))]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in const [ListingCategory.rent, ListingCategory.sale, ListingCategory.shortStay]) ...[
                  PsChip(c.chipLabel, selected: _cat == c, onTap: () => setState(() => _cat = c)),
                  const SizedBox(width: 10),
                ],
                PsLink('Watch walkthroughs', chevron: true, onTap: () => context.go('/tours')),
              ]),
            ),
            const SizedBox(height: 20),
            PsSectionTitle('Fresh in Abuja', action: 'See all', onAction: () => context.push('/search?category=${_cat.value}')),
            const SizedBox(height: 12),
            feed.when(
              loading: () => const Column(children: [PsListingSkeleton(), SizedBox(height: 16), PsListingSkeleton()]),
              error: (_, __) => PsError(onRetry: () => ref.invalidate(homeFeedProvider)),
              data: (all) {
                final items = all.where((l) => l.categoryEnum == _cat).take(8).toList();
                if (items.isEmpty) {
                  return PsEmpty(
                    icon: Icons.home_work_outlined,
                    title: 'No homes here yet',
                    message: 'We only show homes whose availability has been recently confirmed. Try another type or check back soon.',
                    actionLabel: 'Save a search',
                    onAction: () => context.push('/search?category=${_cat.value}'),
                  );
                }
                return Column(children: [
                  for (final l in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ListingCard(
                        listing: l,
                        isSaved: saved.contains(l.id),
                        onSaveTap: () => toggleSaved(context, ref, l.id),
                        onTap: () => context.push('/listing/${l.id}'),
                      ),
                    ),
                ]);
              },
            ),
            PsCard(
              onTap: () => _startShortlist(context),
              semanticLabel: 'Hunting with someone? Start a shortlist',
              child: Row(children: [
                const Icon(Icons.group_outlined, size: 34, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hunting with someone?', style: AppText.title), Text('Start a shortlist', style: AppText.small)])),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _startShortlist(BuildContext context) async {
    final user = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) {
      context.push('/auth?reason=save&redirect=${Uri.encodeComponent('/saved')}');
      return;
    }
    context.go('/saved');
  }
}
