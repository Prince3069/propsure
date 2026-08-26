import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';

class HowWeVerifyScreen extends StatelessWidget {
  const HowWeVerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primaryDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary])),
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text('How We Verify Agents', style: GoogleFonts.syne(
                        fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Text('Our 5-step trust framework',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              )),
            ),
          ),
        ),
        SliverToBoxAdapter(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Intro
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryPale,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.primaryPale2),
                ),
                child: const Text(
                  'Every agent who lists on Propsure must complete our verification process. '
                  'We do this to protect tenants from fraudulent agents and fake listings.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.primary,
                      height: 1.6, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 24),

              Text('Verification Steps', style: GoogleFonts.syne(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 14),

              // Steps
              ..._steps.asMap().entries.map((e) => _StepCard(
                number: e.key + 1,
                step: e.value,
                isLast: e.key == _steps.length - 1,
              )),
              const SizedBox(height: 24),

              // Badge types
              Text('Verification Badges', style: GoogleFonts.syne(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 12),
              _BadgeCard(
                color: AppColors.primary,
                icon: Icons.verified_rounded,
                label: '✓ Verified Agent',
                description: 'NIN identity verification completed via Lumiid. '
                    'Phone number confirmed. Active on Propsure.',
              ),
              const SizedBox(height: 8),
              _BadgeCard(
                color: AppColors.gold,
                icon: Icons.workspace_premium_rounded,
                label: '⭐ Premium Agent',
                description: 'Verified + active premium subscription + '
                    'minimum 4.5 rating from tenants.',
              ),
              const SizedBox(height: 8),
              _BadgeCard(
                color: const Color(0xFF7C3AED),
                icon: Icons.business_rounded,
                label: '🏢 Agency Verified',
                description: 'Verified + CAC registration confirmed. '
                    'Registered real estate agency with proven track record.',
              ),
              const SizedBox(height: 24),

              // Reporting
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.flag_outlined, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Text('Report a Fake Agent', style: GoogleFonts.syne(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Despite our verification, we ask the community to help us. '
                    'If you encounter a suspicious agent or listing, tap the flag '
                    'icon on their profile. We investigate every report within 24 hours.',
                    style: TextStyle(fontSize: 13, color: AppColors.text2, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/info/contact'),
                    icon: const Icon(Icons.support_agent_outlined, size: 16),
                    label: const Text('Contact Support'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ))),
      ]),
    );
  }

  static const _steps = [
    (
      Icons.phone_android_rounded,
      AppColors.primary,
      'Phone Verification',
      'Agent must verify their Nigerian phone number via OTP before creating any listing.',
    ),
    (
      Icons.badge_outlined,
      Color(0xFF3B82F6),
      'NIN Identity Check',
      'We verify the agent\'s National Identification Number (NIN) through our Lumiid integration to confirm their real identity.',
    ),
    (
      Icons.location_on_outlined,
      Color(0xFF059669),
      'Abuja Location Confirmed',
      'Agents must confirm they are based in Abuja FCT and have active properties in the city.',
    ),
    (
      Icons.rate_review_outlined,
      Color(0xFFD97706),
      'Manual Review',
      'Our team reviews the agent\'s profile, first listing, and documentation before granting the Verified badge.',
    ),
    (
      Icons.star_outline_rounded,
      Color(0xFF7C3AED),
      'Ongoing Monitoring',
      'Verified agents are subject to ongoing review. Reports from tenants can trigger re-verification or badge removal.',
    ),
  ];
}

class _StepCard extends StatelessWidget {
  final int number;
  final (IconData, Color, String, String) step;
  final bool isLast;
  const _StepCard({required this.number, required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, desc) = step;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text('$number',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 14))),
          ),
          if (!isLast) Expanded(child: Container(
            width: 2, color: AppColors.border,
            margin: const EdgeInsets.symmetric(vertical: 4))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(
                    fontSize: 12, color: AppColors.text2, height: 1.55)),
              ])),
            ]),
          ),
        )),
      ]),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label, description;
  const _BadgeCard({
    required this.color, required this.icon,
    required this.label, required this.description,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 3),
        Text(description, style: const TextStyle(
            fontSize: 12, color: AppColors.text2, height: 1.5)),
      ])),
    ]),
  );
}
