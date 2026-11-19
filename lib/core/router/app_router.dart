import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/screens/auth/auth_gate_screen.dart';
import '../../presentation/screens/auth/welcome_screen.dart';
import '../../presentation/screens/shell/main_shell.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/area/area_report_screen.dart';
import '../../presentation/screens/area/area_screen.dart';
import '../../presentation/screens/safety/account_check_screen.dart';
import '../../presentation/screens/search/filters_screen.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/tours/tours_screen.dart';
import '../../presentation/screens/workspace/workspace_screen.dart';
import '../../presentation/screens/workspace/leads_screen.dart';
import '../../presentation/screens/chat/chat_list_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/listings/listing_detail_screen.dart';
import '../../presentation/screens/listings/move_in_costs_screen.dart';
import '../../presentation/screens/listings/passport_screen.dart';
import '../../presentation/screens/listings/report_screen.dart';
import '../../presentation/screens/listings/add_listing_screen.dart';
import '../../presentation/screens/listings/video_frame_review_screen.dart';
import '../../presentation/screens/bookings/bookings_screen.dart';
import '../../presentation/screens/bookings/booking_detail_screen.dart';
import '../../presentation/screens/saved/saved_listings_screen.dart';
import '../../presentation/screens/search/saved_searches_screen.dart';
import '../../presentation/screens/compare/compare_screen.dart';
import '../../presentation/screens/shortlist/shortlist_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/agent/agent_profile_screen.dart';
import '../../presentation/screens/agent/agent_listings_screen.dart';
import '../../presentation/screens/verification/verification_screen.dart';
import '../../presentation/screens/bulk_upload/bulk_upload_screen.dart';
import '../../presentation/screens/bulk_upload/whatsapp_bot_screen.dart';
import '../../presentation/screens/payment/boost_listing_screen.dart';
import '../../presentation/screens/payment/premium_screen.dart';
import '../../presentation/screens/payment/checkout_screen.dart';
import '../../presentation/screens/listings/record_guide_screen.dart';
import '../../presentation/screens/financing/rent_calculator_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/home_file/my_home_screen.dart';
import '../../presentation/screens/info/about_propsure_screen.dart';
import '../../presentation/screens/info/contact_support_screen.dart';
import '../../presentation/screens/info/support_status_screen.dart';
import '../../presentation/screens/info/faq_screen.dart';
import '../../presentation/screens/info/how_we_verify_screen.dart';
import '../../presentation/screens/info/safety_tips_screen.dart';
import '../../presentation/screens/info/legal_screen.dart';
import '../constants/app_theme.dart';
import '../widgets/ps_widgets.dart';

/// Routes that need a signed-in user. Browsing (home, search, map, tours,
/// listing pages, legal and help pages) stays open so people can explore
/// before registering; the auth screen explains why when it is needed.
const _authRoutes = <String>[
  '/listing/new',
  '/listing/edit',
  '/workspace',
  '/leads',
  '/my-listings',
  '/messages',
  '/chat/',
  '/profile',
  '/saved',
  '/bookings',
  '/booking/',
  '/notifications',
  '/verification',
  '/settings',
  '/plan',
  '/checkout',
  '/payment',
  '/bulk-import',
  '/whatsapp-assist',
  '/my-home',
  '/support',
  '/shortlist',
  '/check-account',
  '/area/report',
];

bool _needsAuth(String loc) {
  // '/listing/:id/report' needs a signed-in reporter; plain listing pages don't.
  if (RegExp(r'^/listing/[^/]+/(report|frames)$').hasMatch(loc)) return true;
  return _authRoutes.any((r) => loc == r || loc.startsWith(r));
}

class _RouterNotifier extends ChangeNotifier {
  bool isSignedIn = FirebaseAuth.instance.currentUser != null;
  bool isAgent = (Hive.box('settings_box').get('lastRoleAgent', defaultValue: false) as bool) && FirebaseAuth.instance.currentUser != null;
  _RouterNotifier(Ref ref) {
    ref.listen(firebaseAuthUserProvider, (_, next) {
      // Until Firebase reports, trust the synchronous currentUser above.
      if (!next.hasValue) return;
      final v = next.asData?.value != null;
      if (v != isSignedIn) {
        isSignedIn = v;
        if (!v) {
          isAgent = false;
          Hive.box('settings_box').put('lastRoleAgent', false);
        }
        notifyListeners();
      }
    }, fireImmediately: true);
    // The role arrives a moment after sign-in. When it changes the router
    // re-checks the current page, so an agent is moved from the renter
    // Discover page to their Workspace instead of seeing two home screens.
    ref.listen(currentUserModelProvider, (_, next) {
      if (!next.hasValue) return;
      final loaded = next.asData?.value;
      if (loaded == null && isSignedIn) return; // profile not loaded yet
      final v = loaded?.isAgent ?? false;
      // Remember the role so the next cold start opens the right home at once.
      if (loaded != null) Hive.box('settings_box').put('lastRoleAgent', v);
      if (v != isAgent) {
        isAgent = v;
        notifyListeners();
      }
    }, fireImmediately: true);
  }
}

String _initialLocation() {
  final box = Hive.box('settings_box');
  final signedIn = FirebaseAuth.instance.currentUser != null;
  if (signedIn && (box.get('lastRoleAgent', defaultValue: false) as bool)) return '/workspace';
  return (box.get('welcomeSeen', defaultValue: false) as bool) || signedIn ? '/home' : '/welcome';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: _initialLocation(),
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/welcome') Hive.box('settings_box').put('welcomeSeen', true);
      if (_needsAuth(loc) && !notifier.isSignedIn) {
        return '/auth?redirect=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (notifier.isSignedIn && loc == '/auth') {
        return state.uri.queryParameters['redirect'] ?? (notifier.isAgent ? '/workspace' : '/home');
      }
      // One home per role: agents land on their Workspace. They can still
      // browse as a renter from Account ("/home?as=renter"), which is left alone.
      if (loc == '/home' && notifier.isSignedIn && notifier.isAgent && state.uri.queryParameters['as'] != 'renter') {
        return '/workspace';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/auth',
        builder: (_, s) => AuthGateScreen(
          redirectAfter: s.uri.queryParameters['redirect'],
          reason: s.uri.queryParameters['reason'],
        ),
      ),

      // Shell: renter = Discover/Tours/Saved/Inbox/Account,
      //        agent  = Workspace/Listings/Leads/Inbox/Account.
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/tours', builder: (_, __) => const ToursScreen()),
          GoRoute(path: '/saved', builder: (_, __) => const SavedListingsScreen()),
          GoRoute(path: '/messages', builder: (_, __) => const ChatListScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/workspace', builder: (_, __) => const WorkspaceScreen()),
          GoRoute(path: '/my-listings', builder: (_, __) => const AgentListingsScreen()),
          GoRoute(path: '/leads', builder: (_, __) => const LeadsScreen()),
        ],
      ),

      // Search and Map are views inside Discover; they keep the filter state.
      GoRoute(
        path: '/search',
        builder: (_, s) => SearchScreen(
          initialQuery: s.uri.queryParameters['q'],
          initialCategory: s.uri.queryParameters['category'],
          initialType: s.uri.queryParameters['type'],
        ),
      ),
      GoRoute(path: '/search/filters', builder: (_, __) => const FiltersScreen()),
      GoRoute(path: '/payment/callback', builder: (_, s) => PaymentCallbackScreen(reference: s.uri.queryParameters['reference'] ?? s.uri.queryParameters['trxref'])),
      GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
      GoRoute(path: '/check-account', builder: (_, s) => AccountCheckScreen(listingId: s.uri.queryParameters['listing'])),
      GoRoute(
        path: '/area',
        builder: (_, s) => AreaScreen(city: s.uri.queryParameters['city'] ?? '', area: s.uri.queryParameters['area'] ?? ''),
      ),
      GoRoute(
        path: '/area/report',
        builder: (_, s) => AreaReportScreen(city: s.uri.queryParameters['city'] ?? '', area: s.uri.queryParameters['area'] ?? ''),
      ),

      // Listing
      GoRoute(path: '/listing/new', builder: (_, __) => const AddListingScreen()),
      GoRoute(path: '/listing/record-guide', builder: (_, __) => const RecordGuideScreen()),
      GoRoute(
        path: '/listing/edit/:id',
        builder: (_, s) => AddListingScreen(editListingId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/listing/:id/costs',
        builder: (_, s) => MoveInCostsScreen(listingId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/listing/:id/passport',
        builder: (_, s) => PassportScreen(listingId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/listing/:id/report',
        builder: (_, s) => ReportConcernScreen(listingId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/listing/:id/frames',
        builder: (_, s) => VideoFrameReviewScreen(listingId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/listing/:id/edit',
        redirect: (_, s) => '/listing/edit/${s.pathParameters['id']}',
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (_, s) => ListingDetailScreen(listingId: s.pathParameters['id']!),
      ),

      // People & messaging
      GoRoute(path: '/agent/:id', builder: (_, s) => AgentProfileScreen(agentId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(chatId: s.pathParameters['id']!)),
      GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
      GoRoute(path: '/booking/:id', builder: (_, s) => BookingDetailScreen(bookingId: s.pathParameters['id']!)),

      // Deciding & sharing
      GoRoute(path: '/saved-searches', builder: (_, __) => const SavedSearchesScreen()),
      GoRoute(path: '/compare', builder: (_, __) => const CompareScreen()),
      GoRoute(path: '/shortlist/:id', builder: (_, s) => ShortlistScreen(shortlistId: s.pathParameters['id']!)),
      GoRoute(path: '/my-home', builder: (_, __) => const MyHomeScreen()),
      GoRoute(path: '/rent-planner', builder: (_, __) => const RentPlannerScreen()),

      // Account
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/verification', builder: (_, __) => const VerificationScreen()),

      // Agent tools
      GoRoute(path: '/bulk-import', builder: (_, __) => const BulkImportScreen()),
      GoRoute(path: '/whatsapp-assist', builder: (_, __) => const WhatsAppAssistScreen()),
      GoRoute(path: '/plan', builder: (_, __) => const AgentPlanScreen()),
      GoRoute(path: '/payment/boost/:id', builder: (_, s) => BoostListingScreen(listingId: s.pathParameters['id']!)),
      GoRoute(
        path: '/checkout',
        builder: (_, s) => CheckoutScreen(
          planId: s.uri.queryParameters['plan'] ?? '',
          listingId: s.uri.queryParameters['listing'],
          label: s.uri.queryParameters['label'] ?? 'Propsure tools',
          amountNaira: int.tryParse(s.uri.queryParameters['amount'] ?? '') ?? 0,
        ),
      ),

      // Help, trust & legal (all open without signing in)
      GoRoute(path: '/info/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/info/faq', builder: (_, __) => const FaqScreen()),
      GoRoute(path: '/info/how-checks-work', builder: (_, __) => const HowChecksWorkScreen()),
      GoRoute(path: '/info/safety', builder: (_, __) => const SafetyScreen()),
      GoRoute(path: '/support', builder: (_, s) => SupportScreen(topic: s.uri.queryParameters['topic'])),
      GoRoute(path: '/support/status', builder: (_, __) => const SupportStatusScreen()),
      GoRoute(path: '/legal/privacy', builder: (_, __) => const LegalScreen(kind: LegalKind.privacy)),
      GoRoute(path: '/legal/terms', builder: (_, __) => const LegalScreen(kind: LegalKind.terms)),

      // Old links keep working.
      GoRoute(path: '/profile/listings', redirect: (_, __) => '/my-listings'),
      GoRoute(path: '/info/how-we-verify', redirect: (_, __) => '/info/how-checks-work'),
      GoRoute(path: '/info/contact', redirect: (_, __) => '/support'),
      GoRoute(path: '/rent-calculator', redirect: (_, __) => '/rent-planner'),
      GoRoute(path: '/payment/premium', redirect: (_, __) => '/plan'),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.surface,
      body: PsError(
        message: 'That page is not available.',
        onRetry: () => context.go('/home'),
      ),
    ),
  );
});
