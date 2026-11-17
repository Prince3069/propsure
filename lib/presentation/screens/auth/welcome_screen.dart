import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// First-use welcome. People can explore before registering.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(padding: kPagePadding, children: [
          const SizedBox(height: 12),
          const Row(children: [PropsureLogo(), Spacer(), Text('A CLEARER PATH HOME', style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: AppColors.text3, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              height: 220,
              color: AppColors.primary,
              alignment: Alignment.center,
              child: const Icon(Icons.apartment_rounded, size: 96, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 20),
          const PsHeadline('See the home.', accent: 'Know the cost.'),
          const SizedBox(height: 10),
          Text('Walkthroughs, clear move-in costs and checks you can understand.', style: AppText.bodyMuted),
          const SizedBox(height: 16),
          Row(children: [
            for (final f in const [
              (Icons.videocam_outlined, 'Video tours'),
              (Icons.receipt_long_outlined, 'Cost breakdowns'),
              (Icons.event_available_outlined, 'Fresh availability'),
            ])
              Expanded(child: Column(children: [Icon(f.$1, size: 30, color: AppColors.primary), const SizedBox(height: 6), Text(f.$2, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.text))])),
          ]),
          const SizedBox(height: 20),
          PsButton('Explore homes', trailingIcon: Icons.arrow_forward_rounded, onPressed: () => context.go('/home')),
          const SizedBox(height: 12),
          PsButton('I list properties', kind: PsButtonKind.outline, trailingIcon: Icons.arrow_forward_rounded, onPressed: () => context.go('/auth?reason=list')),
          const SizedBox(height: 8),
          Center(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Already have an account? ', style: AppText.small),
              PsLink('Sign in', onTap: () => context.go('/auth'), underline: false),
            ]),
          ),
        ]),
      ),
    );
  }
}
