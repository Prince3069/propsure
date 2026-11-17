import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String t, String s, String route) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PsCard(onTap: () => context.push(route), semanticLabel: t, child: Row(children: [
            PsIconCircle(icon, size: 48),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.title), Text(s, style: AppText.small)])),
            const Icon(Icons.chevron_right_rounded),
          ])),
        );
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: 'About Propsure', action: const PropsureLogo()),
      body: ListView(padding: kPagePadding, children: [
        const PsHeadline('A clearer way', accent: 'to find home.', size: 36),
        const SizedBox(height: 8),
        Text('Built for renters, landlords and agents who want fewer surprises.', style: AppText.bodyMuted),
        const SizedBox(height: 16),
        row(Icons.play_circle_outline_rounded, 'See real walkthroughs', 'Explore actual properties, inside and out.', '/tours'),
        row(Icons.receipt_long_outlined, 'Understand the full move-in cost', 'See rent, fees and other upfront costs.', '/rent-planner'),
        row(Icons.verified_user_outlined, 'Know exactly what was checked', 'View key property details and checks.', '/info/how-checks-work'),
        PsCard(color: AppColors.primaryPale, child: Row(children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Starting with Abuja', style: AppText.title), Text('One area at a time. Quality before quantity.', style: AppText.small)])),
        ])),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: PsButton('Meet our trust process', kind: PsButtonKind.outline, onPressed: () => context.push('/info/how-checks-work'))),
          const SizedBox(width: 12),
          Expanded(child: PsButton('Contact us', onPressed: () => context.push('/support'))),
        ]),
        const SizedBox(height: 16),
        Center(child: Wrap(spacing: 16, children: [PsLink('Privacy', onTap: () => context.push('/legal/privacy')), PsLink('Terms', onTap: () => context.push('/legal/terms'))])),
        const SizedBox(height: 8),
        Center(child: Text('A Prince Dev Labs product', style: AppText.caption)),
        const SizedBox(height: 24),
      ]),
    );
  }
}
