// lib/presentation/providers/app_providers.dart
// ignore_for_file: always_use_package_imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/listing_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/listing_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/booking_repository.dart';
import '../../services/auth_service.dart';

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
  return repo.watchListings(filter: filter, limit: 30);
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

// ── Real category counts ──────────────────────────────────────────────────────
final categoryCountProvider =
    StreamProvider.family<int, String>((ref, propertyType) {
  final repo = ref.watch(listingRepositoryProvider);
  return repo.watchCategoryCount(propertyType);
});

final totalListingsCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(listingRepositoryProvider);
  return repo.watchTotalListings();
});

// ── Upload ────────────────────────────────────────────────────────────────────
class UploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final String? uploadedId;

  const UploadState({
    this.isUploading = false,
    this.progress = 0,
    this.error,
    this.uploadedId,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    String? uploadedId,
  }) =>
      UploadState(
        isUploading: isUploading ?? this.isUploading,
        progress: progress ?? this.progress,
        error: error,
        uploadedId: uploadedId ?? this.uploadedId,
      );
}

class UploadNotifier extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  Future<String?> uploadListing({
    required Map<String, dynamic> data,
    required List<String> imagePaths,
    String? videoPath,
    String? video360Path,
  }) async {
    final user = ref.read(currentUserModelProvider).value;
    if (user == null) return null;

    state = state.copyWith(isUploading: true, progress: 0);

    try {
      final repo = ref.read(listingRepositoryProvider);
      final id = await repo.createListing(
        agentId: user.uid,
        agentName: user.name,
        agentPhone: user.phone,
        agentPhoto: user.profilePhoto,
        location: data['location'] as PropertyLocation,
        title: data['title'] as String,
        description: data['description'] as String,
        price: data['price'] as double,
        propertyType: data['propertyType'] as String,
        category: data['category'] as String,
        bedrooms: data['bedrooms'] as int,
        bathrooms: data['bathrooms'] as int,
        toilets: data['toilets'] as int,
        localImagePaths: imagePaths,
        localVideoPath: videoPath,
        local360VideoPath: video360Path,
        amenities: (data['amenities'] as List?)?.cast<String>() ?? [],
        isFurnished: data['isFurnished'] as bool? ?? false,
        petsAllowed: data['petsAllowed'] as bool? ?? false,
        parkingAvailable: data['parkingAvailable'] as bool? ?? false,
        additionalInfo: data['additionalInfo'] as String?,
        onProgress: (p) => state = state.copyWith(progress: p),
      );
      state = state.copyWith(isUploading: false, progress: 1.0, uploadedId: id);
      return id;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return null;
    }
  }

  void reset() => state = const UploadState();
}

final uploadProvider =
    NotifierProvider<UploadNotifier, UploadState>(UploadNotifier.new);

final listingUploadProvider = uploadProvider;

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
final userByIdProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) async {
  final auth = ref.watch(authServiceProvider);
  return auth.getUserProfile(uid);
});
