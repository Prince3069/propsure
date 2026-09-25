import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/repositories/saved_search_repository.dart';
import '../../providers/app_providers.dart';

/// Lets a user view, toggle alerts on/off for, or delete their saved
/// searches. Matching against new listings happens server-side (the
/// `checkSavedSearches` scheduled Cloud Function) — this screen only
/// manages what's saved, it doesn't run any matching itself.
class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text('Saved Searches',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
        body: EmptyState(
          icon: Icons.notifications_active_outlined,
          title: 'Get notified of new listings',
          subtitle: 'Sign in to save a search and get alerted the moment a match goes live.',
          action: ElevatedButton(
            onPressed: () => context.push('/auth?redirect=/saved-searches'),
            child: const Text('Sign In'),
          ),
        ),
      );
    }

    final searchesAsync = ref.watch(mySavedSearchesProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Saved Searches', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: searchesAsync.when(
        data: (searches) {
          if (searches.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_active_outlined,
              title: 'No saved searches yet',
              subtitle: 'Search for a property, add filters, then tap "Save search & get alerts".',
              action: TextButton(
                onPressed: () => context.push('/search'),
                child: const Text('Start Searching'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: searches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = searches[i];
              final summary = [
                if (s.propertyType != null) s.propertyType,
                if (s.area != null) s.area,
                if (s.minBedrooms != null) '${s.minBedrooms}+ beds',
                if (s.minPrice != null || s.maxPrice != null)
                  '₦${s.minPrice?.toStringAsFixed(0) ?? '0'}–${s.maxPrice?.toStringAsFixed(0) ?? 'any'}',
              ].where((x) => x != null).join(' · ');

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(_searchRouteFor(s)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          if (summary.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(summary,
                                  style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Switch(
                    value: s.alertsEnabled,
                    onChanged: (v) => ref
                        .read(savedSearchRepositoryProvider)
                        .setAlertsEnabled(s.id, v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.text3, size: 20),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete saved search?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(savedSearchRepositoryProvider).delete(s.id);
                      }
                    },
                  ),
                ]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        // Friendly failure state instead of the raw exception.
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Couldn\'t load your saved searches right now.',
                style: TextStyle(fontSize: 13, color: AppColors.text3)),
          ),
        ),
      ),
    );
  }

  String _searchRouteFor(SavedSearchModel s) {
    final params = <String, String>{};
    if (s.query != null) params['q'] = s.query!;
    if (s.category != null) params['category'] = s.category!;
    if (s.propertyType != null) params['type'] = s.propertyType!;
    if (params.isEmpty) return '/search';
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '/search?$qs';
  }
}
