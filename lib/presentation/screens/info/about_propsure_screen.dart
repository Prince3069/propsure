import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';

class AboutPropsureScreen extends StatelessWidget {
  const AboutPropsureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text('🏡', style: TextStyle(fontSize: 36)),
                        ),
                        const SizedBox(height: 14),
                        Text('About Propsure',
                            style: GoogleFonts.syne(
                                fontSize: 28, fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        const Text("Abuja's most trusted property platform",
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(context,
                        icon: Icons.flag_rounded,
                        color: const Color(0xFF3B82F6),
                        title: 'Our Mission',
                        body: "Propsure is Abuja's fastest-growing property rental platform, connecting tenants directly with verified landlords and agents across the FCT. We are committed to making property search safe, transparent, and accessible to every Nigerian.",
                      ),
                      _buildSection(context,
                        icon: Icons.visibility_rounded,
                        color: AppColors.primary,
                        title: 'Our Vision',
                        body: "To become Nigeria's most trusted property marketplace — where technology, community, and integrity come together to transform how people find homes.",
                      ),
                      _buildSection(context,
                        icon: Icons.verified_user_rounded,
                        color: AppColors.gold,
                        title: 'Why We Verify',
                        body: "Every agent on Propsure goes through a rigorous verification process including NIN identity check, phone verification, and optional CAC registration check. This means tenants never deal with fake listings or ghost agents.",
                      ),
                      _buildSection(context,
                        icon: Icons.location_city_rounded,
                        color: const Color(0xFF7C3AED),
                        title: 'Why Abuja?',
                        body: "Abuja is Nigeria's capital and one of Africa's fastest-growing cities. We start here because we know Abuja best — the neighbourhoods, the agents, and the tenants. Expansion to other Nigerian cities is coming soon.",
                      ),

                      // Stats
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primary]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          Text('Propsure in Numbers',
                              style: GoogleFonts.syne(
                                  fontSize: 16, fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 16),
                          Row(children: [
                            _StatCol('1,200+', 'Listings'),
                            _StatDivider(),
                            _StatCol('800+', 'Verified Agents'),
                            _StatDivider(),
                            _StatCol('4.8★', 'App Rating'),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // Team
                      _buildSection(context,
                        icon: Icons.people_outline_rounded,
                        color: AppColors.primary,
                        title: 'Built by Prince Dev Labs',
                        body: "Propsure is built and maintained by Prince Dev Labs Limited, a Nigerian technology company based in Abuja. We build products that solve real Nigerian problems.",
                      ),

                      // Contact
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Get in Touch',
                                style: GoogleFonts.syne(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            _ContactRow(Icons.email_outlined,   'hello@propsure.africa'),
                            _ContactRow(Icons.phone_outlined,   '+234 800 000 0000'),
                            _ContactRow(Icons.location_on_outlined, 'Abuja, FCT, Nigeria'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required IconData icon, required Color color,
    required String title, required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.syne(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          ]),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(
              fontSize: 13, color: AppColors.text2, height: 1.65)),
        ]),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String value, label;
  const _StatCol(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: GoogleFonts.syne(
        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
  ]));
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2));
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
    ]),
  );
}
