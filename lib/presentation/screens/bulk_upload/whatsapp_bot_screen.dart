import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Number of the Propsure WhatsApp assist line. Replace with the approved
/// WhatsApp Business number before launch (see DEPLOY.md).
const String kWhatsAppAssistNumber = '14155238886';

const String _format = '''For rent: 2-bedroom flat
Area: Gwarinpa, Abuja
Annual rent: ₦2,400,000
Other move-in charges: (agency fee, caution, legal)
Video attached''';

/// Assisted pilot: the agent sends a walkthrough video and details; we
/// prepare a DRAFT. Nothing goes live until the agent confirms it in the app.
class WhatsAppAssistScreen extends StatelessWidget {
  const WhatsAppAssistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget step(String n, IconData icon, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.primaryPale, child: Text(n, style: AppText.title.copyWith(color: AppColors.primary))),
              const SizedBox(height: 8),
              Icon(icon, size: 28, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: AppText.small.copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
            ]),
          ),
        );
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'List from WhatsApp'),
      body: ListView(padding: kPagePadding, children: [
        const PsHeadline('Send your video.', accent: 'Review your listing.', size: 36),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          step('1', Icons.videocam_outlined, 'Send a walkthrough + details'),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary)),
          step('2', Icons.description_outlined, 'We prepare a draft'),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary)),
          step('3', Icons.check_circle_outline_rounded, 'You confirm and publish'),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFEDE8DA), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFDDF2D0), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_format, style: AppText.body.copyWith(height: 1.5)),
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerRight, child: Text('Example message', style: AppText.caption)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        PsCard(child: Row(children: [
          const PsIconCircle(Icons.shield_outlined, size: 48),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('You stay in control', style: AppText.h3), Text('Nothing goes live without your review.', style: AppText.small)])),
        ])),
        const SizedBox(height: 16),
        PsButton('Copy message format', kind: PsButtonKind.outline, icon: Icons.copy_rounded, onPressed: () async {
          await Clipboard.setData(const ClipboardData(text: _format));
          if (context.mounted) showPsSnack(context, 'Message format copied');
        }),
        const SizedBox(height: 12),
        PsButton('Open WhatsApp', trailingIcon: Icons.arrow_forward_rounded, icon: Icons.chat_rounded, onPressed: () async {
          final ok = await launchUrl(Uri.parse('https://wa.me/$kWhatsAppAssistNumber?text=${Uri.encodeComponent('Hi Propsure, I would like to list a home.')}'), mode: LaunchMode.externalApplication);
          if (!ok && context.mounted) showPsSnack(context, 'Could not open WhatsApp.');
        }),
        const SizedBox(height: 12),
        Center(child: Text('Assisted pilot · by permission', style: AppText.caption)),
        const SizedBox(height: 8),
        Center(child: PsLink('Prefer to list in the app?', onTap: () => context.push('/listing/new'))),
        const SizedBox(height: 24),
      ]),
    );
  }
}
