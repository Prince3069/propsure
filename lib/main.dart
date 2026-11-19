import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/utils/responsive.dart';
import 'firebase_options.dart';

void main() async {
  // Clean web addresses (/listing/abc) instead of /#/listing/abc, so shared
  // links and the sitemap work. No effect on phones.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await Hive.openBox('user_box');
  await Hive.openBox('settings_box');

  runApp(const ProviderScope(child: PropsureApp()));
}

class PropsureApp extends ConsumerWidget {
  const PropsureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Propsure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(), // Fixed: Added () to call the function
      themeMode: ThemeMode.light,
      routerConfig: router,
      // Wide windows (website): centre the app and cap its width.
      builder: (context, child) => ColoredBox(
        color: AppColors.surface,
        child: ContentFrame(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
