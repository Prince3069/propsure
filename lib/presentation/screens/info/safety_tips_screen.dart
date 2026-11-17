import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  void _detail(BuildContext c, String title, String body) => showModalBottomSheet<void>(
        context: c,
        backgroundColor: AppColors.card,
        builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.h2), const SizedBox(height: 10), Text(body, style: AppText.body), const SizedBox(height: 16)]))),
      );

  @override
  Widget build(BuildContext context) {
    Widget tip(IconData icon, String t, String s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(onTap: () => _detail(context, t, s), semanticLabel: t, child: Row(children: [
          PsIconCircle(icon, size: 52),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.title), Text(s, style: AppText.small, maxLines: 2, overflow: TextOverflow.ellipsis)])),
          const Icon(Icons.chevron_right_rounded),
        ])));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Stay safe'),
      body: ListView(padding: kPagePadding, children: [
        Text.rich(TextSpan(style: AppText.h1.copyWith(fontSize: 32), children: [const TextSpan(text: 'Before you '), TextSpan(text: 'pay or visit.', style: TextStyle(color: AppColors.primary))])),
        const SizedBox(height: 16),
        tip(Icons.person_search_outlined, 'Confirm who can rent out the home', 'Check the owner or agent’s identity and they have the right to rent it.'),
        tip(Icons.home_work_outlined, 'Inspect and document its condition', 'View the property in person and take clear photos or videos.'),
        tip(Icons.description_outlined, 'Get every fee and agreement in writing', 'Ask for a written tenancy agreement and a full breakdown of all costs.'),
        const PsNote('Urgency, hidden fees and requests for your OTP are warning signs.', tone: PsTone.warning, icon: Icons.error_outline_rounded),
        const SizedBox(height: 18),
        const PsSectionTitle('During an inspection'),
        const SizedBox(height: 10),
        tip(Icons.groups_outlined, 'Share visit details with someone', 'Let a friend or family member know where you’re going and when to expect you back.'),
        tip(Icons.place_outlined, 'Meet at an agreed location', 'Use a public, well-lit place and avoid going alone.'),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(color: AppColors.errorPale, borderColor: AppColors.error, onTap: () => context.push('/support'), semanticLabel: 'Report a concern', child: Row(children: [
          const Icon(Icons.flag_outlined, color: AppColors.error, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Report a concern', style: AppText.title.copyWith(color: AppColors.error)), Text('Tell us about a suspicious listing, person or request.', style: AppText.small.copyWith(color: AppColors.error))])),
          const Icon(Icons.chevron_right_rounded, color: AppColors.error),
        ]))),
        PsCard(color: AppColors.primary, onTap: () => context.push('/info/faq'), semanticLabel: 'Read the renter checklist', child: Row(children: [
          const Icon(Icons.description_outlined, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Read the renter checklist', style: AppText.title.copyWith(color: Colors.white)), Text('A simple checklist to help you stay safe.', style: AppText.small.copyWith(color: Colors.white70))])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ])),
        const SizedBox(height: 12),
        Text('These tips do not guarantee safety and are not a substitute for legal advice or independent verification.', style: AppText.caption),
        const SizedBox(height: 24),
      ]),
    );
  }
}
