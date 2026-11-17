import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/listing_category.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/repositories/saved_search_repository.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Search alerts: the actual filter brief for each saved search, a pause
/// switch, and delivery. Only in-app alerts exist today; WhatsApp and email
/// need separate permission and backend work, so they are shown as not
/// available rather than as a promise.
class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  List<String> _chips(SavedSearchModel s) => [
        if (s.category != null) ListingCategory.fromAny(s.category).chipLabel,
        if (s.propertyType != null) s.propertyType!,
        if (s.area != null) s.area!,
        if (s.minBedrooms != null) '${s.minBedrooms}+ beds',
        if (s.maxPrice != null) 'Up to ${Money.short(s.maxPrice!)}',
        if (s.query != null && s.query!.isNotEmpty) '“${s.query}”',
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final async = uid == null ? null : ref.watch(mySavedSearchesProvider(uid));
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(padding: EdgeInsets.zero, children: [
        PsGreenHeader(
          padding: const EdgeInsets.fromLTRB(12, 0, 24, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PsTopBar(dark: true, backLabel: 'Back'),
            Padding(padding: const EdgeInsets.only(left: 12), child: Text('Your search alerts', style: AppText.display.copyWith(color: Colors.white))),
            Padding(padding: const EdgeInsets.fromLTRB(12, 6, 0, 0), child: Text('Good matches, not constant noise.', style: AppText.body.copyWith(color: Colors.white70))),
          ]),
        ),
        Padding(
          padding: kPagePadding,
          child: async == null
              ? const PsEmpty(icon: Icons.lock_outline_rounded, title: 'Sign in to save searches', message: 'We can tell you when a matching home is confirmed.')
              : async.when(
                  loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => PsError(onRetry: () => ref.invalidate(mySavedSearchesProvider(uid!))),
                  data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 16),
                    if (list.isEmpty)
                      const PsEmpty(icon: Icons.notifications_none_rounded, title: 'No saved searches yet', message: 'Search for homes, then choose “Save search & get alerts”.'),
                    for (final s in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PsCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(s.label, style: AppText.h3)),
                              Column(children: [
                                Switch(value: s.alertsEnabled, onChanged: (v) => runAction(context, () => ref.read(savedSearchRepositoryProvider).setAlertsEnabled(s.id, v))),
                                Text(s.alertsEnabled ? 'In-app alerts' : 'Paused', style: AppText.caption),
                              ]),
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, runSpacing: 8, children: [for (final c in _chips(s)) PsPill(c, tone: PsTone.neutral)]),
                            const Divider(height: 28),
                            Row(children: [
                              Expanded(child: PsLink('View matches', underline: false, onTap: () => context.push('/search?q=${Uri.encodeComponent(s.query ?? '')}&category=${s.category ?? ''}&type=${s.propertyType ?? ''}'))),
                              PsIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Delete this search', onPressed: () => runAction(context, () => ref.read(savedSearchRepositoryProvider).delete(s.id))),
                            ]),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text('Send via', style: AppText.h3),
                    const SizedBox(height: 10),
                    const Row(children: [
                      Expanded(child: PsChip('In-app', selected: true)),
                      SizedBox(width: 8),
                      Expanded(child: PsChip('WhatsApp')),
                      SizedBox(width: 8),
                      Expanded(child: PsChip('Email')),
                    ]),
                    const SizedBox(height: 6),
                    Text('WhatsApp and email alerts are not available yet. Alerts arrive in the app and as a notification.', style: AppText.caption),
                    const SizedBox(height: 16),
                    PsButton('Save another search', kind: PsButtonKind.outline, icon: Icons.add_rounded, onPressed: () => context.push('/search')),
                    const SizedBox(height: 24),
                  ]),
                ),
        ),
      ]),
    );
  }
}
