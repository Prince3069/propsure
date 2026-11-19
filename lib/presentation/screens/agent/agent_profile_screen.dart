import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Agent profile. Identity is shown separately from listing-specific
/// authority. Ratings and review counts are NOT shown: there is no verified
/// review history yet, and we do not invent one.
class AgentProfileScreen extends ConsumerWidget {
  final String agentId;
  const AgentProfileScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(publicProfileProvider(agentId));
    final listings = ref.watch(_agentPublicListings(agentId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: p.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(publicProfileProvider(agentId))),
        data: (a) {
          if (a == null) return const SafeArea(child: PsEmpty(icon: Icons.person_off_outlined, title: 'Profile not found', message: 'This profile is not available.'));
          final first = listings.asData?.value.isNotEmpty == true ? listings.asData!.value.first : null;
          return SafeArea(
            child: Column(children: [
              PsTopBar(backLabel: 'Back', action: PsLink('Share', onTap: null)),
              Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  PsAvatar(url: a.photo, name: a.name, size: 96),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.agencyName?.isNotEmpty == true ? a.agencyName! : a.name, style: AppText.h1.copyWith(color: AppColors.primary)),
                    Text('${a.role == 'landlord' ? 'Landlord' : 'Property agent'}', style: AppText.small),
                    const SizedBox(height: 8),
                    if (a.identityReviewed) const PsPill('Agent ID checked', icon: Icons.verified_user_outlined),
                  ])),
                ]),
                const SizedBox(height: 16),
                PsCard(padding: EdgeInsets.zero, child: Column(children: [
                  const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Trust details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
                  PsListRow(icon: Icons.person_outline_rounded, title: a.identityReviewed ? 'Identity checked' : 'Identity not checked', subtitle: a.identityReviewed ? 'Government ID reviewed by Propsure${a.identityCheckedAt != null ? ' · ${a.identityCheckedAt!.day}/${a.identityCheckedAt!.month}/${a.identityCheckedAt!.year}' : ''}' : 'This agent has not completed an identity check.', onTap: () => context.push('/info/how-checks-work')),
                  const Divider(height: 1),
                  PsListRow(icon: Icons.description_outlined, title: 'Authority to market: listing-specific', subtitle: 'Shown on each home’s passport, not on the profile.', onTap: () => context.push('/info/how-checks-work')),
                  const Divider(height: 1),
                  PsListRow(icon: Icons.schedule_rounded, title: 'Availability updates: shown per home', subtitle: 'Each home shows when it was last confirmed.', onTap: () => context.push('/info/how-checks-work')),
                ])),
                if (a.bio != null && a.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('About', style: AppText.h3), const SizedBox(height: 6), Text(a.bio!, style: AppText.body)])),
                ],
                const SizedBox(height: 20),
                const PsSectionTitle('Active homes'),
                const SizedBox(height: 10),
                listings.when(
                  loading: () => const PsListingSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => list.isEmpty
                      ? Text('No active homes right now.', style: AppText.bodyMuted)
                      : Column(children: [for (final l in list.take(5)) Padding(padding: const EdgeInsets.only(bottom: 12), child: ListingCard(listing: l, compact: true, isSaved: ref.watch(savedIdsProvider).contains(l.id), onSaveTap: () => toggleSaved(context, ref, l.id), onTap: () => context.push('/listing/${l.id}')))]),
                ),
                const Divider(height: 32),
                PsLink('Report agent', onTap: () => context.push('/support?topic=report_agent'), underline: false),
              ])),
              PsBottomBar(children: [
                PsButton('Message', kind: PsButtonKind.outline, icon: Icons.chat_bubble_outline_rounded, onPressed: first == null ? null : () => openChatAbout(context, ref, first)),
                PsButton('Call', icon: Icons.phone_outlined, onPressed: first == null || first.agentPhone.isEmpty ? null : () => launchUrl(Uri(scheme: 'tel', path: first.agentPhone))),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

final _agentPublicListings = StreamProvider.family((ref, String id) => ref.watch(listingRepositoryProvider).watchAgentPublicListings(id));
