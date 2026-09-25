import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/listing_ranking.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/app_providers.dart';

/// Replaces the old `/profile/listings` route, which built
/// `SavedListingsScreen` — an agent's own inventory has nothing to do with
/// what they've bookmarked from other agents. Backed by
/// `agentListingsProvider`, which Phase 2 also fixed to stop hard-filtering
/// to `status == 'active'` (an owner couldn't previously see their own
/// paused or archived listings here at all).
///
/// Phase 2 additions on top of the Phase 1 version: status tabs (so
/// archived listings have somewhere to live, with a Restore action),
/// a completeness score per listing, and trust/boost/premium badges —
/// this is the "supplier dashboard" foundation the review asked for.
/// Still deferred: response-rate/enquiry analytics, bulk actions — those
/// need the analytics-event and enquiry-model work from later in Phase 2/3.
class AgentListingsScreen extends ConsumerStatefulWidget {
  const AgentListingsScreen({super.key});
  @override
  ConsumerState<AgentListingsScreen> createState() => _AgentListingsScreenState();
}

class _AgentListingsScreenState extends ConsumerState<AgentListingsScreen> {
  String _tab = 'active'; // 'active' | 'paused' | 'draft' | 'archived'

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text('My Listings',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
        body: EmptyState(
          icon: Icons.home_work_outlined,
          title: 'Manage your properties',
          subtitle: 'Sign in to see and manage the listings you\'ve posted.',
          action: ElevatedButton(
            onPressed: () => context.push('/auth?redirect=/profile/listings'),
            child: const Text('Sign In'),
          ),
        ),
      );
    }

    final listingsAsync = ref.watch(agentListingsProvider(userId));
    final user = ref.watch(currentUserModelProvider).value;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('My Listings',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add property',
            onPressed: () => context.push('/listing/upload'),
          ),
        ],
      ),
      body: listingsAsync.when(
        data: (all) {
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.home_work_outlined,
              title: 'No listings yet',
              subtitle: 'Post your first property to start getting enquiries.',
              action: ElevatedButton(
                onPressed: () => context.push('/listing/upload'),
                child: const Text('List a Property'),
              ),
            );
          }

          final active = all.where((l) => l.status == 'active').toList();
          final paused = all.where((l) => l.status == 'paused').toList();
          final drafts = all.where((l) => l.status == 'draft').toList();
          final archived = all.where((l) => l.status == 'archived').toList();
          final shown = switch (_tab) {
            'paused' => paused,
            'draft' => drafts,
            'archived' => archived,
            _ => active,
          };

          return Column(children: [
            // ── Trust/entitlement status row ──
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: _AgentStatusRow(
                  verificationStatus: user.verificationStatus,
                  isPremium: user.isPremium,
                  premiumPlan: user.premiumPlan,
                ),
              ),
            // ── Bulk-import drafts banner — surfaces the moment there's
            // something waiting on the agent, since drafts are otherwise
            // invisible everywhere else in the app by design. ──
            if (drafts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = 'draft'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.info.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.drafts_outlined, size: 16, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${drafts.length} imported listing${drafts.length == 1 ? '' : 's'} waiting for photos before they can go live',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.info),
                    ]),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: _StatCard(label: 'Active', value: '${active.length}', color: AppColors.success)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Paused', value: '${paused.length}', color: AppColors.gold)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Archived', value: '${archived.length}', color: AppColors.text3)),
              ]),
            ),
            // ── Tabs ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _TabChip(label: 'Active (${active.length})', selected: _tab == 'active', onTap: () => setState(() => _tab = 'active')),
                  const SizedBox(width: 8),
                  _TabChip(label: 'Paused (${paused.length})', selected: _tab == 'paused', onTap: () => setState(() => _tab = 'paused')),
                  const SizedBox(width: 8),
                  _TabChip(label: 'Drafts (${drafts.length})', selected: _tab == 'draft', onTap: () => setState(() => _tab = 'draft')),
                  const SizedBox(width: 8),
                  _TabChip(label: 'Archived (${archived.length})', selected: _tab == 'archived', onTap: () => setState(() => _tab = 'archived')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text('No ${_tab == 'draft' ? 'draft' : _tab} listings',
                          style: const TextStyle(color: AppColors.text3)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      children: shown
                          .map((l) => _AgentListingRow(
                                listing: l,
                                onEdit: () => context.push('/listing/edit/${l.id}'),
                                onView: () => context.push('/listing/${l.id}'),
                                onTogglePause: () async {
                                  final repo = ref.read(listingRepositoryProvider);
                                  final next = l.status == 'active' ? 'paused' : 'active';
                                  try {
                                    await repo.updateStatus(l.id, next);
                                  } catch (e) {
                                    // Friendly message instead of the raw
                                    // exception (which for a Firestore
                                    // error reads like
                                    // "[cloud_firestore/permission-denied]
                                    // Missing or insufficient permissions.").
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text('Couldn\'t update this listing. Please try again.')));
                                    }
                                  }
                                },
                                onArchive: () => ref
                                    .read(listingRepositoryProvider)
                                    .archiveListing(l.id, userId),
                                onRestore: () => ref
                                    .read(listingRepositoryProvider)
                                    .restoreListing(l.id),
                                // Publishing a draft (Phase 3 bulk-import
                                // flow) requires at least one photo — the
                                // same bar every other listing had to
                                // clear before it could go live. If there
                                // are none yet, send them to Edit instead
                                // of silently failing.
                                onPublish: () async {
                                  if (l.images.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text('Add at least one photo before publishing.')));
                                    }
                                    context.push('/listing/edit/${l.id}');
                                    return;
                                  }
                                  try {
                                    await ref.read(listingRepositoryProvider).updateStatus(l.id, 'active');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Published!'), backgroundColor: AppColors.success));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text('Couldn\'t publish this listing. Please try again.')));
                                    }
                                  }
                                },
                                onDeletePermanently: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text(l.status == 'draft' ? 'Discard draft?' : 'Delete permanently?'),
                                      content: Text(l.status == 'draft'
                                          ? 'This imported row will be removed.'
                                          : 'This cannot be undone — the listing and its data will be gone for good.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel')),
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text(l.status == 'draft' ? 'Discard' : 'Delete',
                                                style: const TextStyle(color: AppColors.error))),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await ref
                                        .read(listingRepositoryProvider)
                                        .deleteListingPermanently(l.id, userId);
                                  }
                                },
                              ))
                          .toList(),
                    ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// A rough 0-100% completeness score computed purely from what's already
/// on the model — no new fields needed. Used to nudge agents toward
/// listings that will actually rank and convert, per the review's
/// "listing completeness score" ask for the supplier dashboard.
// listingCompletenessScore now lives in core/utils/listing_ranking.dart so
// listing_repository.dart's ranking and this dashboard use the exact same
// definition of "complete" — see that file for the scoring breakdown.

class _AgentStatusRow extends StatelessWidget {
  final VerificationStatus verificationStatus;
  final bool isPremium;
  final String? premiumPlan;
  const _AgentStatusRow(
      {required this.verificationStatus, required this.isPremium, this.premiumPlan});

  @override
  Widget build(BuildContext context) {
    final verified = verificationStatus == VerificationStatus.approved;
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: verified ? AppColors.success.withOpacity(0.1) : AppColors.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: verified ? AppColors.success.withOpacity(0.3) : AppColors.border),
          ),
          child: Row(children: [
            Icon(verified ? Icons.verified_rounded : Icons.pending_outlined,
                size: 16, color: verified ? AppColors.success : AppColors.text3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                verified
                    ? 'Verified agent'
                    : verificationStatus == VerificationStatus.pending
                        ? 'Verification pending'
                        : 'Not verified yet',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: verified ? AppColors.success : AppColors.text2),
              ),
            ),
          ]),
        ),
      ),
      if (isPremium) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(premiumPlan == 'agent_elite' ? 'Elite' : 'Pro',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ]),
        ),
      ],
    ]);
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.text2)),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _StatCard({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color ?? AppColors.text)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
        ]),
      );
}

class _AgentListingRow extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onEdit, onView, onTogglePause, onArchive, onRestore, onPublish, onDeletePermanently;
  const _AgentListingRow({
    required this.listing,
    required this.onEdit,
    required this.onView,
    required this.onTogglePause,
    required this.onArchive,
    required this.onRestore,
    required this.onPublish,
    required this.onDeletePermanently,
  });

  @override
  Widget build(BuildContext context) {
    final isPaused = listing.status == 'paused';
    final isArchived = listing.status == 'archived';
    final isDraft = listing.status == 'draft';
    final score = listingCompletenessScore(listing);
    final now = DateTime.now();
    final isStale = listing.updatedAt != null && now.difference(listing.updatedAt!).inDays > 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: listing.images.isNotEmpty
                  ? Image.network(listing.images.first, fit: BoxFit.cover)
                  : Container(color: AppColors.bg, child: const Icon(Icons.home_outlined, color: AppColors.text3)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onView,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(listing.formattedPriceWithPeriod,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _Badge(
                      text: isDraft ? 'Draft' : (isArchived ? 'Archived' : (isPaused ? 'Paused' : 'Active')),
                      color: isDraft ? AppColors.info : (isArchived ? AppColors.text3 : (isPaused ? AppColors.gold : AppColors.success)),
                    ),
                    if (listing.isFeatured) const _Badge(text: '⭐ Featured', color: AppColors.gold),
                    if (listing.verificationStatus == VerificationStatus.approved)
                      const _Badge(text: '✓ Verified', color: AppColors.success),
                    if (isStale && !isArchived && !isDraft) const _Badge(text: 'Stale · 30d+', color: AppColors.error),
                    if (isDraft && listing.images.isEmpty) const _Badge(text: 'Needs photos', color: AppColors.error),
                  ]),
                ],
              ),
            ),
          ),
          if (isDraft)
            ElevatedButton(
              onPressed: onPublish,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero),
              child: const Text('Publish', style: TextStyle(fontSize: 12)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.text3),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'pause') onTogglePause();
              if (v == 'archive') onArchive();
              if (v == 'restore') onRestore();
              if (v == 'delete') onDeletePermanently();
            },
            itemBuilder: (_) => [
              if (!isArchived) const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!isArchived && !isDraft)
                PopupMenuItem(value: 'pause', child: Text(isPaused ? 'Republish' : 'Pause')),
              if (!isArchived && !isDraft) const PopupMenuItem(value: 'archive', child: Text('Archive')),
              if (isArchived) const PopupMenuItem(value: 'restore', child: Text('Restore')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(isDraft ? 'Discard' : 'Delete Permanently', style: const TextStyle(color: AppColors.error))),
            ],
          ),
        ]),
        if (!isArchived) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 5,
                  backgroundColor: AppColors.bg,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      score >= 80 ? AppColors.success : (score >= 50 ? AppColors.gold : AppColors.error)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$score% complete', style: const TextStyle(fontSize: 10, color: AppColors.text3)),
          ]),
        ],
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}
