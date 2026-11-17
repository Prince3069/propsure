import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Explains each check separately. Nothing here says a home is "verified".
class HowChecksWorkScreen extends StatelessWidget {
  const HowChecksWorkScreen({super.key});

  void _detail(BuildContext c, String title, String body) => showModalBottomSheet<void>(
        context: c,
        backgroundColor: AppColors.card,
        isScrollControlled: true,
        builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.h2), const SizedBox(height: 10), Text(body, style: AppText.body), const SizedBox(height: 16)]))),
      );

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String t, String s, String detail, {bool grey = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PsCard(color: grey ? AppColors.primaryPale2 : null, onTap: () => _detail(context, t, detail), semanticLabel: t, child: Row(children: [
            PsIconCircle(icon, size: 56),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.h3), if (s.isNotEmpty) Text(s, style: AppText.small)])),
            const Icon(Icons.chevron_right_rounded),
          ])),
        );
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(backLabel: 'Back'),
      body: ListView(padding: kPagePadding, children: [
        Text('Understand the checks', style: AppText.title.copyWith(color: AppColors.primary)),
        const SizedBox(height: 8),
        const PsHeadline('Trust should be', accent: 'specific.', size: 38),
        const SizedBox(height: 16),
        row(Icons.shield_outlined, 'Agent identity', 'Who the agent is', 'We review a government ID and a selfie to confirm who the person is. This does not prove they own or may rent out any property.'),
        row(Icons.description_outlined, 'Listing authority', 'Their permission to market this home', 'For a specific listing, the agent shows a document from the owner. It covers that listing only and does not prove title.'),
        row(Icons.schedule_rounded, 'Fresh availability', 'When availability was last confirmed', 'Agents confirm availability from time to time. Every home shows the date. Homes not confirmed for a while are marked and eventually hidden from search.'),
        row(Icons.article_outlined, 'Title review is a separate check', '', 'Title review is done separately by our team and is not part of identity or authority. Unless a passport says title was reviewed, it was not.', grey: true),
        const SizedBox(height: 4),
        const PsNote('A checked identity is not a guarantee of ownership or condition.', icon: Icons.info_outline_rounded),
        const SizedBox(height: 16),
        PsButton('Browse homes and open a passport', kind: PsButtonKind.outline, trailingIcon: Icons.arrow_forward_rounded, onPressed: () => context.push('/search')),
        const SizedBox(height: 24),
      ]),
    );
  }
}
