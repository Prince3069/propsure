import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
                color: AppColors.primaryPale2,
                borderRadius: BorderRadius.circular(130)),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppShadows.md),
              child: const Icon(Icons.home_rounded,
                  color: Colors.white, size: 43),
            ),
            const SizedBox(height: 18),
            const PropsureLogo(size: 30),
            const SizedBox(height: 10),
            const Text('Verified homes. Better moves.',
                style: TextStyle(fontSize: 13, color: AppColors.text2)),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 34,
          child: Column(children: [
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppColors.primary)),
            const SizedBox(height: 10),
            Text('Starting your Abuja property search',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
