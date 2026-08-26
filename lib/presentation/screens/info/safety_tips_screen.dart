import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 190,
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
                    const Icon(Icons.shield_rounded, color: Colors.white, size: 38),
                    const SizedBox(height: 10),
                    Text('Safety Tips', style: GoogleFonts.syne(
                        fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Text('Stay safe while renting in Abuja',
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
              // Alert banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text(
                    'Never send money to anyone before physically inspecting a property. Always meet agents in person.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.5),
                  )),
                ]),
              ),
              const SizedBox(height: 20),

              _buildCategory(context,
                icon: Icons.search_rounded,
                color: const Color(0xFF3B82F6),
                title: 'For Tenants',
                tips: [
                  ('Inspect before paying', 'Never pay rent or any money before physically visiting and confirming the property exists and matches the listing photos.'),
                  ('Verify agent identity', 'Ask to see the agent\'s ID card and confirm they appear on Propsure with a Verified badge before proceeding.'),
                  ('Use secure payment', 'Avoid cash. Use bank transfer and keep every receipt. Never use unverified payment platforms.'),
                  ('Meet in public first', 'For the first meeting, choose a neutral public location like a bank or business centre. Take someone with you.'),
                  ('Check the documents', 'Before signing anything, verify the owner\'s title documents (Certificate of Occupancy, deed of assignment) at the Land Registry.'),
                  ('Use the in-app chat', 'Keep all communication within Propsure\'s chat. This protects you and creates a record if there is a dispute.'),
                ],
              ),
              const SizedBox(height: 16),

              _buildCategory(context,
                icon: Icons.home_outlined,
                color: AppColors.primary,
                title: 'For Landlords & Agents',
                tips: [
                  ('Screen tenants properly', 'Request government-issued ID, employment verification, and at least one reference before handing over keys.'),
                  ('Use formal agreements', 'Always sign a written tenancy agreement. Use a certified lawyer to draft it.'),
                  ('Never accept undated cheques', 'Only accept post-dated cheques from tenants you have thoroughly screened.'),
                  ('Report suspicious tenants', 'If a potential tenant shows unusual urgency to move in quickly or refuses standard screening, report them.'),
                  ('Complete your verification', 'Get your Propsure Verified badge. It builds trust and attracts genuine tenants.'),
                ],
              ),
              const SizedBox(height: 16),

              _buildCategory(context,
                icon: Icons.report_problem_outlined,
                color: const Color(0xFFDC2626),
                title: 'Red Flags to Watch Out For',
                tips: [
                  ('Price too good to be true', 'If a property is listed far below market rate, it is likely a scam. Always compare with similar listings.'),
                  ('Agent unavailable to meet', 'A genuine agent will always agree to show you the property in person. Remote-only requests are a major red flag.'),
                  ('Pressure to decide quickly', 'Scammers create false urgency. Take your time to verify everything properly.'),
                  ('Requests for payment upfront', 'Legitimate agents never ask for payment before showing you the property.'),
                  ('No contract offered', 'Always insist on a formal tenancy agreement. Refuse any "gentleman\'s agreement" arrangement.'),
                ],
              ),
              const SizedBox(height: 20),

              // Report section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Seen something suspicious?',
                      style: GoogleFonts.syne(
                          fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('Report any suspicious listing or agent directly from the listing page by tapping the flag icon. We review all reports within 24 hours.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 12),
                  const Text('📧 hello@propsure.africa',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ))),
      ]),
    );
  }

  Widget _buildCategory(BuildContext context, {
    required IconData icon, required Color color,
    required String title, required List<(String, String)> tips,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.syne(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
      ]),
      const SizedBox(height: 10),
      ...tips.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(child: Text('${e.key + 1}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.value.$1, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 3),
              Text(e.value.$2, style: const TextStyle(
                  fontSize: 12, color: AppColors.text2, height: 1.55)),
            ])),
          ]),
        ),
      )),
    ]);
  }
}
