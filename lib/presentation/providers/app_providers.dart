// lib/presentation/providers/app_providers.dart
// ignore_for_file: always_use_package_imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/area.dart';
import '../../data/models/listing_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/listing_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/verification_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/enquiry_repository.dart';
import '../../data/repositories/saved_search_repository.dart';
import '../../data/repositories/shortlist_repository.dart';
import '../../data/models/verification_request_model.dart';
import '../../services/auth_service.dart';
import '../../services/functions_service.dart';
import 'city_provider.dart';

// ── Auth ──────────────────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firebaseAuthUserProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final currentUserIdProvider = Provider<String?>(
    (ref) => ref.watch(firebaseAuthUserProvider).asData?.value?.uid);

final isSignedInProvider = Provider<bool>(
    (ref) => ref.watch(firebaseAuthUserProvider).asData?.value != null);

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authServiceProvider).watchUserProfile(uid);
});

// ── Repositories ──────────────────────────────────────────────────────────────
final listingRepositoryProvider =
    Provider<ListingRepository>((ref) => ListingRepository());
final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository());
final bookingRepositoryProvider =
    Provider<BookingRepository>((ref) => BookingRepository());
final verificationRepositoryProvider =
    Provider<VerificationRepository>((ref) => VerificationRepository());
final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => ReportRepository());
final enquiryRepositoryProvider =
    Provider<EnquiryRepository>((ref) => EnquiryRepository());
final savedSearchRepositoryProvider =
    Provider<SavedSearchRepository>((ref) => SavedSearchRepository());

final mySavedSearchesProvider =
    StreamProvider.family<List<SavedSearchModel>, String>((ref, userId) {
  final repo = ref.watch(savedSearchRepositoryProvider);
  return repo.watchMine(userId);
});

// ── Enquiries (Phase 3 — LeadRadar-facing supplier signal) ────────────────────
final agentEnquiriesProvider =
    StreamProvider.family<List<EnquiryModel>, String>((ref, agentId) {
  final repo = ref.watch(enquiryRepositoryProvider);
  return repo.watchAgentEnquiries(agentId);
});

/// Response rate over the agent's most recent enquiries — the supplier
/// -performance signal the review's dashboard section asks for. Simple
/// ratio, computed from whatever watchAgentEnquiries already streamed;
/// no separate query.
final agentResponseRateProvider =
    Provider.family<double?, String>((ref, agentId) {
  final enquiries = ref.watch(agentEnquiriesProvider(agentId)).value;
  if (enquiries == null || enquiries.isEmpty) return null;
  final responded = enquiries
      .where((e) => e.responseState == EnquiryResponseState.responded)
      .length;
  return responded / enquiries.length;
});

// ── Compare list (Phase 4 — review 3.4 "property comparison") ────────────────
class CompareListNotifier extends Notifier<List<String>> {
  static const maxCompare = 3;

  @override
  List<String> build() => [];

  bool toggle(String listingId) {
    if (state.contains(listingId)) {
      state = state.where((id) => id != listingId).toList();
      return true;
    }
    if (state.length >= maxCompare) return false;
    state = [...state, listingId];
    return true;
  }

  void clear() => state = [];
}

final compareListProvider = NotifierProvider<CompareListNotifier, List<String>>(
    CompareListNotifier.new);

// ── Paginated search results (Phase 4 — cursor pagination) ───────────────────
class SearchResultsState {
  final List<ListingModel> items;
  final bool isLoadingMore;
  final bool hasMore;
  const SearchResultsState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });
  SearchResultsState copyWith(
          {List<ListingModel>? items, bool? isLoadingMore, bool? hasMore}) =>
      SearchResultsState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
      );
}

class SearchResultsController
    extends Notifier<Map<ListingFilter, AsyncValue<SearchResultsState>>> {
  final Map<ListingFilter, DocumentSnapshot?> _lastDocs = {};

  @override
  Map<ListingFilter, AsyncValue<SearchResultsState>> build() => {};

  Future<void> ensureLoaded(ListingFilter filter) async {
    if (state.containsKey(filter)) return;
    state = {...state, filter: const AsyncValue.loading()};
    try {
      final repo = ref.read(listingRepositoryProvider);
      final page = await repo.fetchListingsPage(filter: filter, pageSize: 20);
      _lastDocs[filter] = page.lastDoc;
      state = {
        ...state,
        filter: AsyncValue.data(
            SearchResultsState(items: page.items, hasMore: page.hasMore)),
      };
    } catch (e, st) {
      state = {...state, filter: AsyncValue.error(e, st)};
    }
  }

  Future<void> loadMore(ListingFilter filter) async {
    final current = state[filter]?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = {
      ...state,
      filter: AsyncValue.data(current.copyWith(isLoadingMore: true))
    };
    try {
      final repo = ref.read(listingRepositoryProvider);
      final page = await repo.fetchListingsPage(
          filter: filter, pageSize: 20, startAfter: _lastDocs[filter]);
      _lastDocs[filter] = page.lastDoc ?? _lastDocs[filter];
      state = {
        ...state,
        filter: AsyncValue.data(current.copyWith(
          items: [...current.items, ...page.items],
          isLoadingMore: false,
          hasMore: page.hasMore,
        )),
      };
    } catch (e) {
      state = {
        ...state,
        filter: AsyncValue.data(current.copyWith(isLoadingMore: false))
      };
    }
  }

  Future<void> refresh(ListingFilter filter) async {
    _lastDocs.remove(filter);
    state = Map.of(state)..remove(filter);
    await ensureLoaded(filter);
  }
}

final searchResultsControllerProvider = NotifierProvider<
        SearchResultsController,
        Map<ListingFilter, AsyncValue<SearchResultsState>>>(
    SearchResultsController.new);

// ── Verification status ──────────────────────────────────────────────────────
final myVerificationRequestProvider =
    StreamProvider<VerificationRequestModel?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(verificationRepositoryProvider).watchLatestForUser(uid);
});

final myVerificationRequestsProvider = StreamProvider<List<VerificationRequestModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(verificationRepositoryProvider).watchAllForUser(uid);
});

// ── Filter State — NotifierProvider works on all riverpod versions ────────────
class FilterNotifier extends Notifier<ListingFilter> {
  @override
  ListingFilter build() => const ListingFilter();
  // ignore: use_setters_to_change_properties
  void set(ListingFilter f) => state = f;
  void reset() => state = const ListingFilter();
}

final listingFilterProvider =
    NotifierProvider<FilterNotifier, ListingFilter>(FilterNotifier.new);

// ── Home Feed ─────────────────────────────────────────────────────────────────
final homeFeedProvider = StreamProvider<List<ListingModel>>((ref) {
  final repo = ref.watch(listingRepositoryProvider);
  return repo.watchListings(filter: const ListingFilter(), limit: 40);
});

// ── Featured ──────────────────────────────────────────────────────────────────
final featuredListingsProvider = StreamProvider<List<ListingModel>>((ref) {
  final repo = ref.watch(listingRepositoryProvider);
  return repo.watchListings(
      filter: const ListingFilter(isFeatured: true), limit: 8);
});

// ── Filtered ──────────────────────────────────────────────────────────────────
final filteredListingsProvider =
    StreamProvider.family<List<ListingModel>, ListingFilter>((ref, filter) {
  final repo = ref.watch(listingRepositoryProvider);
  // Search is scoped to the city the user picked unless the filter says otherwise.
  final eff = filter.city == null ? filter.copyWith(city: ref.watch(selectedCityProvider)) : filter;
  return repo.watchListings(filter: eff, limit: 30);
});

// ── Single listing ────────────────────────────────────────────────────────────
final listingByIdProvider =
    StreamProvider.family<ListingModel?, String>((ref, id) {
  final repo = ref.watch(listingRepositoryProvider);
  return repo.watchById(id);
});

// ── Agent listings ────────────────────────────────────────────────────────────
final agentListingsProvider =
    StreamProvider.family<List<ListingModel>, String>((ref, agentId) {
  final repo = ref.watch(listingRepositoryProvider);
  return repo.watchAgentListings(agentId);
});

// ── Saved listings ────────────────────────────────────────────────────────────
final savedListingsProvider =
    StreamProvider.family<List<ListingModel>, String>((ref, userId) {
  final repo = ref.watch(listingRepositoryProvider);
  return repo.watchSavedListings(userId: userId);
});

// ── Shortlists ────────────────────────────────────────────────────────────────
final shortlistRepositoryProvider = Provider<ShortlistRepository>((ref) => ShortlistRepository());
final myShortlistsProvider = StreamProvider<List<ShortlistModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(shortlistRepositoryProvider).watchMine(uid);
});
final shortlistProvider = StreamProvider.family<ShortlistModel?, String>(
    (ref, id) => ref.watch(shortlistRepositoryProvider).watch(id));

// ── Server callables & pricing ────────────────────────────────────────────────
final functionsServiceProvider = Provider<FunctionsService>((ref) => FunctionsService());

/// Prices and limits come from the server catalog — never hard-coded in the app.
final pricingProvider = FutureProvider<PricingInfo>((ref) => ref.watch(functionsServiceProvider).getPricing());

// ── Public agent profile (server-written mirror) ──────────────────────────────
final publicProfileProvider = StreamProvider.family<PublicProfile?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('public_profiles')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? PublicProfile.fromFirestore(d) : null);
});

/// A role-aware flag: true when the signed-in user manages listings.
final isAgentProvider = Provider<bool>((ref) => ref.watch(currentUserModelProvider).asData?.value?.isAgent ?? false);

// ── Founder promo (first 100 agents free) ─────────────────────────────────────
// Live "how many spots left" — reads the single promotions/founderProgram
// doc (public read-only per firestore.rules; every write happens inside
// claimFounderPromo's transaction via the Admin SDK). Doc not existing
// yet just means nobody has claimed a slot — treated as fully open.
final founderPromoStatusProvider =
    StreamProvider<({int claimed, int total, bool active})>((ref) {
  return FirebaseFirestore.instance
      .collection('promotions')
      .doc('founderProgram')
      .snapshots()
      .map((snap) {
    final d = snap.data();
    final claimed = (d?['slotsClaimed'] as num?)?.toInt() ?? 0;
    final total = (d?['slotsTotal'] as num?)?.toInt() ?? 100;
    final active = d?['active'] as bool? ?? false; // off until the founder enables it
    return (claimed: claimed, total: total, active: active);
  });
});

// ── Chat ──────────────────────────────────────────────────────────────────────
final userChatsProvider =
    StreamProvider.family<List<ChatModel>, String>((ref, userId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchUserChats(userId);
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchMessages(chatId);
});

final totalUnreadProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(0);
  return ref.watch(chatRepositoryProvider).watchTotalUnreadCount(uid);
});

// ── Notifications unread count ────────────────────────────────────────────────
final notificationsUnreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection(AppConstants.colNotifications)
      .where('userId', isEqualTo: uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

// ── Bookings ──────────────────────────────────────────────────────────────────
final userBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, userId) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.watchUserBookings(userId);
});

final agentBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, agentId) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.watchAgentBookings(agentId);
});

final agentPendingCountProvider =
    StreamProvider.family<int, String>((ref, agentId) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.watchAgentPendingCount(agentId);
});

// ── User by ID ────────────────────────────────────────────────────────────────
// Other people's data comes from the public mirror only. Private user
// documents are readable by their owner (and reviewers) alone.


// ── Public app settings (editable from the Firebase console) ─────────────────
/// Document `public_config/app`, for example { whatsappAssistNumber: "2348012345678" }.
final appConfigProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .doc('public_config/app')
      .snapshots()
      .map((s) => s.data() ?? const <String, dynamic>{});
});

/// Default Propsure WhatsApp line (08107286686). It is built into the app, so
/// WhatsApp works with no setup. To change the number without a new build,
/// set `whatsappAssistNumber` in Firestore `public_config/app`; that value
/// wins when it exists.
const String kWhatsAppAssistNumber = '2348107286686';

/// The WhatsApp number as digits only (country code first).
final whatsappAssistNumberProvider = Provider<String?>((ref) {
  final raw = ref.watch(appConfigProvider).asData?.value['whatsappAssistNumber'];
  return normalizeWhatsAppNumber(raw?.toString()) ?? normalizeWhatsAppNumber(kWhatsAppAssistNumber);
});

/// "+234 801 234 5678", "08012345678" and "2348012345678" all become
/// "2348012345678". Returns null when the value cannot be a phone number.
String? normalizeWhatsAppNumber(String? raw) {
  if (raw == null) return null;
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('0') && d.length == 11) d = '234${d.substring(1)}';
  return d.length >= 10 && d.length <= 15 ? d : null;
}


// ── Life around the home ──────────────────────────────────────────────────────
/// Public summary of resident reports for one area (document id = area key).
final areaSummaryProvider = StreamProvider.family<AreaSummary?, String>((ref, key) {
  return FirebaseFirestore.instance
      .collection('area_summaries')
      .doc(key)
      .snapshots()
      .map((d) => d.exists ? AreaSummary.fromDoc(d) : null);
});

/// Banks for the account-name check (cached for the session).
final banksProvider = FutureProvider<List<BankOption>>((ref) => ref.watch(functionsServiceProvider).listBanks());
