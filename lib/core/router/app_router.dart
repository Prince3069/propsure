import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/screens/auth/auth_gate_screen.dart';
import '../../presentation/screens/shell/main_shell.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/chat/chat_list_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/listings/listing_detail_screen.dart';
import '../../presentation/screens/listings/upload_listing_screen.dart';
import '../../presentation/screens/bookings/bookings_screen.dart';
import '../../presentation/screens/bookings/booking_detail_screen.dart';
import '../../presentation/screens/saved/saved_listings_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/agent/agent_profile_screen.dart';
import '../../presentation/screens/verification/verification_screen.dart';
import '../../presentation/screens/payment/boost_listing_screen.dart';
import '../../presentation/screens/payment/premium_screen.dart';
import '../../presentation/screens/financing/rent_calculator_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/info/about_propsure_screen.dart';
import '../../presentation/screens/info/faq_screen.dart';
import '../../presentation/screens/info/safety_tips_screen.dart';
import '../../presentation/screens/info/how_we_verify_screen.dart';
import '../../presentation/screens/info/contact_screen.dart';
import '../constants/app_theme.dart';

class _RouterNotifier extends ChangeNotifier {
  bool isSignedIn = false;

  _RouterNotifier(Ref ref) {
    ref.listen(firebaseAuthUserProvider, (_, next) {
      final newValue = next.asData?.value != null;
      if (newValue != isSignedIn) {
        isSignedIn = newValue;
        notifyListeners();
      }
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuth = notifier.isSignedIn;
      final loc = state.matchedLocation;

      const authRoutes = [
        '/listing/upload',
        '/messages',
        '/profile',
        '/saved',
        '/bookings',
        '/notifications',
        '/profile/edit',
        '/profile/listings',
        '/payment',
        '/verification',
        '/settings',
      ];

      if (authRoutes.any((r) => loc.startsWith(r)) && !isAuth) {
        return '/auth?redirect=${Uri.encodeComponent(loc)}';
      }
      if (loc.startsWith('/chat/') && !isAuth) {
        return '/auth?redirect=${Uri.encodeComponent(loc)}';
      }
      if (isAuth && loc.startsWith('/auth')) return '/home';
      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/auth',
        builder: (_, state) => AuthGateScreen(
          redirectAfter: state.uri.queryParameters['redirect'],
        ),
      ),

      // ── Main shell (bottom nav) ───────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/search',
            builder: (_, state) => SearchScreen(
              initialQuery: state.uri.queryParameters['q'],
              initialCategory: state.uri.queryParameters['category'],
              initialType: state.uri.queryParameters['type'],
            ),
          ),
          GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          GoRoute(
              path: '/messages', builder: (_, __) => const ChatListScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ── Listings ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/listing/upload',
        builder: (_, __) => const UploadListingScreen(),
      ),
      GoRoute(
        path: '/listing/:id/edit',
        builder: (_, state) =>
            UploadListingScreen(editListingId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (_, state) =>
            ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),

      // ── Agent profile ─────────────────────────────────────────────────────
      GoRoute(
        path: '/agent/:agentId',
        builder: (_, state) =>
            AgentProfileScreen(agentId: state.pathParameters['agentId']!),
      ),

      // ── Chat ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) =>
            ChatScreen(chatId: state.pathParameters['chatId']!),
      ),

      // ── Bookings ──────────────────────────────────────────────────────────
      GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
      GoRoute(
        path: '/booking/:id',
        builder: (_, state) =>
            BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),

      // ── Misc ──────────────────────────────────────────────────────────────
      GoRoute(path: '/saved', builder: (_, __) => const SavedListingsScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(
          path: '/profile/listings',
          builder: (_, __) => const SavedListingsScreen()),

      // ── Verification ──────────────────────────────────────────────────────
      GoRoute(
          path: '/verification',
          builder: (_, __) => const VerificationScreen()),

      // ── Payments ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/payment/boost/:listingId',
        builder: (_, state) =>
            BoostListingScreen(listingId: state.pathParameters['listingId']!),
      ),
      GoRoute(
          path: '/payment/premium', builder: (_, __) => const PremiumScreen()),

      // ── Tools ─────────────────────────────────────────────────────────────
      GoRoute(
          path: '/rent-calculator',
          builder: (_, __) => const RentCalculatorScreen()),

      // ── Settings ──────────────────────────────────────────────────────────
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),

      // ── Info / static pages ───────────────────────────────────────────────
      GoRoute(
          path: '/info/about', builder: (_, __) => const AboutPropsureScreen()),
      GoRoute(path: '/info/faq', builder: (_, __) => const FAQScreen()),
      GoRoute(
          path: '/info/safety', builder: (_, __) => const SafetyTipsScreen()),
      GoRoute(
          path: '/info/how-we-verify',
          builder: (_, __) => const HowWeVerifyScreen()),
      GoRoute(path: '/info/contact', builder: (_, __) => const ContactScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 56, color: AppColors.error),
          const SizedBox(height: 14),
          Text('Page not found',
              style: Theme.of(context).textTheme.headlineMedium),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go Home'),
          ),
        ]),
      ),
    ),
  );
});
