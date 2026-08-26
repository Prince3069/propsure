import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class AgentProfileScreen extends ConsumerWidget {
  final String agentId;
  const AgentProfileScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(userByIdProvider(agentId));
    final agentListingsAsync = ref.watch(agentListingsProvider(agentId));
    final cols = AppBreakpoints.gridCols(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: agentAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
        data: (agent) {
          // ── Guard: agent not found ────────────────────────────────
          if (agent == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Agent not found')),
            );
          }

          // ── Full page ─────────────────────────────────────────────
          return CustomScrollView(slivers: [
            // ── GREEN HEADER ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(children: [
                      // Back + Report row
                      Row(children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showReport(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.flag_outlined,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Avatar
                      Stack(alignment: Alignment.bottomRight, children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage:
                              (agent.profilePhoto?.isNotEmpty == true)
                                  ? NetworkImage(agent.profilePhoto!)
                                  : null,
                          child: (agent.profilePhoto == null ||
                                  agent.profilePhoto!.isEmpty)
                              ? Text(
                                  agent.name.isNotEmpty
                                      ? agent.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800))
                              : null,
                        ),
                        if (agent.isVerified)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.verified_rounded,
                                color: AppColors.primary, size: 16),
                          ),
                      ]),
                      const SizedBox(height: 12),

                      // Name
                      Text(agent.name,
                          style: GoogleFonts.syne(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),

                      // Agency name
                      if (agent.agencyName?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(agent.agencyName!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                      const SizedBox(height: 8),

                      // Badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (agent.isVerified) ...[
                            const _WhitePill('✓ Verified Agent'),
                            const SizedBox(width: 8),
                          ],
                          _WhitePill(_roleLabel(agent.role)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats
                      Row(children: [
                        _AgentStat('${agent.totalListings}', 'Listings'),
                        _StatDivider(),
                        _AgentStat(
                            agent.rating != null
                                ? agent.rating!.toStringAsFixed(1)
                                : '—',
                            'Rating'),
                        _StatDivider(),
                        _AgentStat('${agent.reviewCount}', 'Reviews'),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),

            // ── BIO ────────────────────────────────────────────────
            if (agent.bio?.isNotEmpty == true)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(agent.bio!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),

            // ── CONTACT BUTTONS ────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (!ref.read(isSignedInProvider)) {
                          context.push('/auth?redirect=/agent/$agentId');
                          return;
                        }
                        context.push('/messages');
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 16),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri(scheme: 'tel', path: agent.phone);
                        if (await canLaunchUrl(uri)) {
                          launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ]),
              ),
            ),

            // ── TRUST INDICATORS ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: '🛡️ Trust Indicators'),
                    const SizedBox(height: 10),
                    Row(children: [
                      _TrustBadge(
                        icon: Icons.verified_rounded,
                        color: AppColors.primary,
                        label: 'ID Verified',
                        active: agent.isVerified,
                      ),
                      const SizedBox(width: 8),
                      _TrustBadge(
                        icon: Icons.phone_rounded,
                        color: AppColors.success,
                        label: 'Phone Verified',
                        active: agent.isPhoneVerified,
                      ),
                      const SizedBox(width: 8),
                      _TrustBadge(
                        icon: Icons.star_rounded,
                        color: AppColors.gold,
                        label: 'Top Rated',
                        active: (agent.rating ?? 0) >= 4.5,
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // ── LISTINGS HEADER ────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 20, 14, 10),
                child: SectionHeader(title: 'Active Listings'),
              ),
            ),

            // ── LISTINGS GRID ──────────────────────────────────────
            agentListingsAsync.when(
              loading: () => SliverToBoxAdapter(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: 4,
                  itemBuilder: (_, __) => const SkeletonCard(),
                ),
              ),
              error: (e, _) =>
                  SliverToBoxAdapter(child: Center(child: Text('$e'))),
              data: (listings) {
                if (listings.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('No active listings',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: cols == 1 ? 1.55 : 0.74,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => ListingCard(
                        listing: listings[i],
                        onTap: () => ctx.push('/listing/${listings[i].id}'),
                      ),
                      childCount: listings.length,
                    ),
                  ),
                );
              },
            ),
          ]); // end CustomScrollView
        },
      ),
    );
  }

  void _showReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text('Report Agent',
              style:
                  GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...[
            'Fake agent / scam',
            'Inappropriate behaviour',
            'Wrong information',
            'Other'
          ].map((r) => ListTile(
                dense: true,
                leading: const Icon(Icons.flag_outlined,
                    color: AppColors.error, size: 18),
                title: Text(r, style: const TextStyle(fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Report submitted. Thank you.')));
                },
              )),
        ]),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'agent':
        return 'Property Agent';
      case 'landlord':
        return 'Landlord';
      default:
        return 'Member';
    }
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
class _WhitePill extends StatelessWidget {
  final String label;
  const _WhitePill(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );
}

class _AgentStat extends StatelessWidget {
  final String value, label;
  const _AgentStat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.syne(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2));
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool active;
  const _TrustBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.08) : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    active ? color.withValues(alpha: 0.3) : AppColors.border),
          ),
          child: Column(children: [
            Icon(icon, size: 20, color: active ? color : AppColors.text3),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: active ? color : AppColors.text3),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}
