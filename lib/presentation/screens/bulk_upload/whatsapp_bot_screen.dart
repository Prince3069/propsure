import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';

/// Info screen showing agents how to use the WhatsApp listing bot.
class WhatsAppBotScreen extends StatelessWidget {
  const WhatsAppBotScreen({super.key});

  // Your Twilio WhatsApp number — replace with real number after setup
  static const _whatsappNumber = '+14155238886'; // Twilio sandbox default
  static const _whatsappLink = 'https://wa.me/14155238886';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('WhatsApp Listing Bot',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📲', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('List properties via WhatsApp',
                style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 6),
            const Text(
                'Send a message to our WhatsApp number and our bot will automatically create a draft listing for you — no app needed.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 24),

        Text('How it works', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ...[
          (
            '1',
            'Register your number',
            'Your phone number must be linked to your Propsure agent account.',
            Icons.phone_outlined
          ),
          (
            '2',
            'Message our bot',
            'Send your property details to our WhatsApp number using the format below.',
            Icons.chat_bubble_outline_rounded
          ),
          (
            '3',
            'Bot creates draft',
            'Within seconds, a draft listing appears in your Propsure account.',
            Icons.auto_awesome_outlined
          ),
          (
            '4',
            'Review and publish',
            'Open the app, add photos, review details, then publish.',
            Icons.publish_rounded
          ),
        ].map((step) {
          final (num, title, desc, icon) = step;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryPale, shape: BoxShape.circle),
                  child: Center(
                      child: Text(num,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              fontSize: 15)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.text2)),
                  ])),
              Icon(icon, color: AppColors.primary, size: 20),
            ]),
          );
        }),
        const SizedBox(height: 20),

        // Message format
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('📋 Message Format',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  const text =
                      'LIST: 3 bedroom flat, Maitama, ₦2M/year, furnished, generator, AC';
                  Clipboard.setData(const ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Format copied!')));
                },
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('Copy',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700))),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text(
                    'LIST: [type], [area], [price], [beds] bedroom, [baths] bathroom, [features]',
                    style: TextStyle(
                        color: Color(0xFF25D366),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.5))),
            const SizedBox(height: 12),
            const Text('Example:',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 6),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text(
                    'LIST: 3 bedroom flat, Maitama, ₦2M/year, furnished, generator, swimming pool, AC',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 20),

        // Commands reference
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bot Commands',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.text)),
            const SizedBox(height: 12),
            ...[
              ('LIST: [details]', 'Create a new draft listing'),
              ('STATUS', 'See your active listing count'),
              ('HELP', 'Show available commands'),
            ].map((cmd) {
              final (command, desc) = cmd;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(command,
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(desc,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.text2))),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 24),

        // WhatsApp number display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF25D366).withValues(alpha: 0.3))),
          child: Column(children: [
            const Text('Our WhatsApp Number',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_whatsappNumber,
                style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF166534))),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(_whatsappLink);
                    if (await canLaunchUrl(uri)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Text('📲', style: TextStyle(fontSize: 16)),
                  label: const Text('Open in WhatsApp',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                )),
          ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}
