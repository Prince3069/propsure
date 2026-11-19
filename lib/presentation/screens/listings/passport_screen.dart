import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Scoped checks, each with its own meaning and its own limits. Nothing on
/// this screen says the property is "verified".
class PassportScreen extends ConsumerWidget {
  final String listingId;
  const PassportScreen({super.key, required this.listingId});

  static (String, PsTone) _entry(PassportEntry e) {
    switch (e.state) {
      case 'reviewed':
        return e.isCurrent ? ('Reviewed', PsTone.success) : ('Expired', PsTone.warning);
      case 'rejected':
        return ('Not approved', PsTone.danger);
      case 'needs_changes':
        return ('Needs changes', PsTone.warning);
      default:
        return ('Not reviewed', PsTone.neutral);
    }
  }

  void _sheet(BuildContext c, String title, String body) => showModalBottomSheet<void>(
        context: c,
        backgroundColor: AppColors.card,
        builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.h2), const SizedBox(height: 10), Text(body, style: AppText.body), const SizedBox(height: 12)]))),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listingByIdProvider(listingId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Property passport'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(listingByIdProvider(listingId))),
        data: (l) {
          if (l == null) return const PsEmpty(icon: Icons.home_outlined, title: 'Listing not found', message: 'This home may have been removed.');
          final profile = ref.watch(publicProfileProvider(l.agentId)).asData?.value;
          final idOk = profile?.identityReviewed ?? false;
          final fresh = freshnessOf(l);
          final auth = _entry(l.authority);
          final title = _entry(l.titleReview);
          final updated = l.updatedAt != null ? 'Updated ${relativeDays(l.updatedAt!)}' : '';

          Widget row(IconData icon, String t, String sub, String pill, PsTone tone, String? when, String detailTitle, String detail, {bool muted = false}) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PsCard(color: muted ? AppColors.primaryPale2 : null, onTap: () => _sheet(context, detailTitle, detail), semanticLabel: t, child: Row(children: [
                  PsIconCircle(icon, size: 56),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.h3), Text(sub, style: AppText.small)])),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [PsPill(pill, tone: tone, small: true), if (when != null && when.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(when, style: AppText.caption))]),
                  const Icon(Icons.chevron_right_rounded),
                ])),
              );

          return Column(children: [
            Expanded(child: ListView(padding: kPagePadding, children: [
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: SizedBox(width: 150, height: 110, child: PsNetImage(l.coverUrl))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.title, style: AppText.h2), const SizedBox(height: 4), Row(children: [const Icon(Icons.location_on_rounded, size: 16, color: AppColors.text2), const SizedBox(width: 4), Expanded(child: Text('${l.location.area}, Abuja', style: AppText.small))])])),
              ]),
              const SizedBox(height: 18),
              const PsHeadline('Know what', accent: 'we know.', size: 38),
              const SizedBox(height: 14),
              row(Icons.person_outline_rounded, 'Agent identity', 'Identity only, not ownership', idOk ? 'Checked' : 'Not checked', idOk ? PsTone.success : PsTone.neutral, profile?.identityCheckedAt != null ? 'Updated ${relativeDays(profile!.identityCheckedAt!)}' : null, 'Agent identity', 'We reviewed a government ID and selfie to confirm who the agent is. This does not prove they own or may rent out this home.'),
              row(Icons.description_outlined, 'Authority to market', l.authority.state == 'reviewed' ? 'Reviewed for this listing' : 'Not reviewed for this listing', auth.$1, auth.$2, l.authority.checkedAt != null ? 'Updated ${relativeDays(l.authority.checkedAt!)}' : null, 'Authority to market', l.authority.limitation ?? 'Reviewed for this listing only. It does not prove title and does not cover other listings.'),
              row(Icons.event_available_outlined, 'Availability', fresh.confirmedLabel, fresh.at == null ? 'Not confirmed' : (l.needsRefresh ? 'Needs refresh' : 'Confirmed'), fresh.at == null || l.needsRefresh ? PsTone.warning : PsTone.success, fresh.at != null ? 'Updated ${relativeDays(fresh.at!)}' : null, 'Availability', '${fresh.byLabel}. Homes can be rented quickly, so ask the agent before arranging a visit if the date is not recent.'),
              row(Icons.image_outlined, 'Media & costs', 'Provided by agent · See dates', 'Provided', PsTone.neutral, updated, 'Media & costs', 'Photos, video and fees are provided by the agent. Fees marked unconfirmed are not included in the move-in total.'),
              row(Icons.article_outlined, 'Property title', title.$1 == 'Reviewed' ? 'Reviewed' : 'Not reviewed', title.$1 == 'Reviewed' ? 'Reviewed' : 'Not reviewed', title.$2, l.titleReview.checkedAt != null ? 'Updated ${relativeDays(l.titleReview.checkedAt!)}' : null, 'Property title', l.titleReview.limitation ?? 'Title review is a separate check. Unless it says reviewed, no one at Propsure has checked the title documents.', muted: true),
              const PsNote('Checks have limits. Verify independently before payment.', icon: Icons.info_outline_rounded),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                PsLink('View evidence details', chevron: true, onTap: () => context.push('/info/how-checks-work')),
                PsLink('Report an inconsistency', chevron: true, onTap: () => context.push('/listing/${l.id}/report')),
              ]),
            ])),
            PsBottomBar(children: [PsButton('Book an inspection', trailingIcon: Icons.arrow_forward_rounded, onPressed: () => requestInspection(context, ref, l))]),
          ]);
        },
      ),
    );
  }
}
