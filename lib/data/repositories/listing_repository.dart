import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/listing_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/listing_category.dart';
import '../../core/utils/listing_ranking.dart';

/// Fields a listing owner is allowed to change through [updateListing].
/// Trust-sensitive fields (isVerified, isFeatured, status, verification*,
/// agentId, viewCount, inquiryCount) are deliberately excluded — those are
/// only ever written by Cloud Functions with elevated privileges. This is
/// defense-in-depth on the client; the actual enforcement is in
/// firestore.rules, which will reject a write containing these fields from
/// anyone other than the trusted backend even if this allowlist is bypassed.
/// Result of one cursor-paginated fetch — see
/// ListingRepository.fetchListingsPage.
class ListingPage {
  final List<ListingModel> items;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;
  const ListingPage({required this.items, required this.lastDoc, required this.hasMore});
}

const Set<String> kOwnerEditableListingFields = {
  'title',
  'description',
  'price',
  'propertyType',
  'category',
  'bedrooms',
  'bathrooms',
  'toilets',
  'location',
  'area',
  'city',
  'images',
  'videoUrl',
  'video360Url',
  'amenities',
  'isFurnished',
  'petsAllowed',
  'parkingAvailable',
  'additionalInfo',
};

class ListingRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  CollectionReference get _col => _db.collection(AppConstants.colListings);

  // ── Single listing ────────────────────────────────────────────────────────
  Future<ListingModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ListingModel.fromFirestore(doc);
  }

  Stream<ListingModel?> watchById(String id) => _col
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? ListingModel.fromFirestore(doc) : null);

  // ── Saved listings stream ─────────────────────────────────────────────────
  Stream<List<ListingModel>> watchSavedListings({required String userId}) {
    return _db
        .collection(AppConstants.colUsers)
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) return <ListingModel>[];
      final data = userDoc.data() as Map<String, dynamic>;
      final saved = List<String>.from(data['savedListings'] ?? []);
      if (saved.isEmpty) return <ListingModel>[];
      final futures = saved.map((id) => _col.doc(id).get());
      final docs = await Future.wait(futures);
      return docs
          .where((d) => d.exists)
          .map((d) => ListingModel.fromFirestore(d))
          .toList();
    });
  }

  // ── Cursor-paginated fetch (Phase 4 — "Review Firestore query
  // scalability") ────────────────────────────────────────────────────────
  // watchListings() above is a live `.snapshots()` stream, which doesn't
  // compose with startAfterDocument in a way that stays a stream — so
  // this is a separate, one-shot `.get()` method for actual infinite
  // scroll, used by search_screen.dart's SearchResultsController.
  //
  // Caveat worth knowing: minPrice/maxPrice/minBedrooms/free-text `query`
  // still can't be expressed as Firestore `where` clauses without a
  // dedicated search index (the review's "Add search indexing" ask — a
  // real fix needs Algolia/Typesense/similar, which is a third-party
  // integration decision, not something to bolt on silently here). Those
  // filters are still applied to each fetched page after the fact, so a
  // page can come back with fewer than `pageSize` visible results. What
  // THIS fixes is the actual problem the review flagged: the app no
  // longer pulls up to 200+ full documents into memory for every single
  // query — it pulls pageSize at a time, cursoring forward.
  Future<ListingPage> fetchListingsPage({
    ListingFilter filter = const ListingFilter(),
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _col.where('status', isEqualTo: 'active');

    if (filter.area != null) query = query.where('area', isEqualTo: filter.area);
    if (filter.propertyType != null) {
      query = query.where('propertyType', isEqualTo: filter.propertyType);
    }
    if (filter.category != null) {
      query = query.where('category',
          isEqualTo: ListingCategory.fromAny(filter.category).value);
    }
    if (filter.isFeatured == true) query = query.where('isFeatured', isEqualTo: true);
    if (filter.isVerified == true) query = query.where('isVerified', isEqualTo: true);

    switch (filter.sortOrder) {
      case SortOrder.priceAsc:
        query = query.orderBy('price');
        break;
      case SortOrder.priceDesc:
        query = query.orderBy('price', descending: true);
        break;
      case SortOrder.oldest:
        query = query.orderBy('createdAt');
        break;
      default:
        // Featured-first still needs a secondary in-memory sort since
        // Firestore can't express "isFeatured desc, then createdAt desc"
        // as a single composite order without every listing having both
        // fields indexed together — orderBy('createdAt') here, the
        // featured-first re-sort happens once per page below.
        query = query.orderBy('createdAt', descending: true);
    }

    query = query.limit(pageSize);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snap = await query.get();
    var items = snap.docs.map((d) => ListingModel.fromFirestore(d)).toList();

    if (filter.minPrice != null && filter.minPrice! > 0) {
      items = items.where((l) => l.price >= filter.minPrice!).toList();
    }
    if (filter.maxPrice != null) {
      items = items.where((l) => l.price <= filter.maxPrice!).toList();
    }
    if (filter.minBedrooms != null) {
      items = items.where((l) => l.bedrooms >= filter.minBedrooms!).toList();
    }
    if (filter.query != null && filter.query!.isNotEmpty) {
      final q = filter.query!.toLowerCase();
      items = items
          .where((l) =>
              l.title.toLowerCase().contains(q) ||
              l.location.area.toLowerCase().contains(q) ||
              l.propertyType.toLowerCase().contains(q) ||
              l.description.toLowerCase().contains(q))
          .toList();
    }
    if (filter.sortOrder != SortOrder.priceAsc && filter.sortOrder != SortOrder.priceDesc) {
      // Same blended ranking as watchListings' default branch — see
      // listing_ranking.dart. Only meaningful within a single fetched
      // page (each page was already ordered by createdAt at the query
      // level for cursoring purposes), which is an acceptable trade-off:
      // true global re-ranking across pages would require pulling every
      // active listing into memory, exactly what this pagination work
      // was meant to stop doing.
      items.sort(compareListingsByRank);
    }

    return ListingPage(
      items: items,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == pageSize,
    );
  }

  // ── Agent listings ────────────────────────────────────────────────────────
  // BUG FIX: this used to hard-filter `.where('status', isEqualTo: 'active')`
  // — meaning an agent managing their OWN inventory could never see a
  // listing they'd paused or archived. An owner's management view should
  // show everything they own, active or not; it's the PUBLIC feed
  // (watchListings) that should only ever show 'active'.
  Stream<List<ListingModel>> watchAgentListings(String agentId) => _col
      .where('agentId', isEqualTo: agentId)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => ListingModel.fromFirestore(d)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  // ── Real category count ───────────────────────────────────────────────────
  Stream<int> watchCategoryCount(String propertyType) => _col
      .where('status', isEqualTo: 'active')
      .where('propertyType', isEqualTo: propertyType)
      .snapshots()
      .map((snap) => snap.docs.length);

  // ── Real total count ──────────────────────────────────────────────────────
  Stream<int> watchTotalListings() => _col
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snap) => snap.docs.length);

  // ── Main listings stream ──────────────────────────────────────────────────
  Stream<List<ListingModel>> watchListings({
    ListingFilter filter = const ListingFilter(),
    int limit = 40,
  }) {
    Query query = _col.where('status', isEqualTo: 'active');

    if (filter.area != null) {
      query = query.where('area', isEqualTo: filter.area);
    }
    if (filter.propertyType != null) {
      query = query.where('propertyType', isEqualTo: filter.propertyType);
    }
    if (filter.category != null) {
      // Defensive normalization — even if a caller constructed the filter
      // with a legacy label or route slug instead of going through
      // ListingFilter.withCategory, the query still matches what's
      // actually stored in Firestore.
      query = query.where('category',
          isEqualTo: ListingCategory.fromAny(filter.category).value);
    }
    if (filter.isFeatured == true) {
      query = query.where('isFeatured', isEqualTo: true);
    }
    if (filter.isVerified == true) {
      query = query.where('isVerified', isEqualTo: true);
    }

    return query.limit(limit).snapshots().map((snap) {
      var results =
          snap.docs.map((d) => ListingModel.fromFirestore(d)).toList();

      if (filter.minPrice != null && filter.minPrice! > 0) {
        results = results.where((l) => l.price >= filter.minPrice!).toList();
      }
      if (filter.maxPrice != null) {
        results = results.where((l) => l.price <= filter.maxPrice!).toList();
      }
      if (filter.minBedrooms != null) {
        results =
            results.where((l) => l.bedrooms >= filter.minBedrooms!).toList();
      }
      if (filter.query != null && filter.query!.isNotEmpty) {
        final q = filter.query!.toLowerCase();
        results = results
            .where((l) =>
                l.title.toLowerCase().contains(q) ||
                l.location.area.toLowerCase().contains(q) ||
                l.propertyType.toLowerCase().contains(q) ||
                l.location.city.toLowerCase().contains(q) ||
                l.description.toLowerCase().contains(q))
            .toList();
      }

      switch (filter.sortOrder) {
        case SortOrder.priceAsc:
          results.sort((a, b) => a.price.compareTo(b.price));
          break;
        case SortOrder.priceDesc:
          results.sort((a, b) => b.price.compareTo(a.price));
          break;
        default:
          // Phase 4: blended freshness + completeness + verification +
          // featured score, replacing the old "featured always wins,
          // then just newest" comparator — see listing_ranking.dart.
          results.sort(compareListingsByRank);
      }

      return results;
    });
  }

  // ── Create listing with XFile support ────────────────────────────────────
  Future<String> createListing({
    required String agentId,
    required String agentName,
    required String agentPhone,
    String? agentPhoto,
    required PropertyLocation location,
    required String title,
    required String description,
    required double price,
    required String propertyType,
    required String category,
    required int bedrooms,
    required int bathrooms,
    required int toilets,
    required List<String> localImagePaths, // XFile paths
    String? localVideoPath,
    String? local360VideoPath,
    List<String> amenities = const [],
    bool isFurnished = false,
    bool petsAllowed = false,
    bool parkingAvailable = false,
    String? additionalInfo,
    void Function(double)? onProgress,
  }) async {
    final id = _uuid.v4();

    // ── Step 1: Upload images to Firebase Storage ─────────────────────────
    final imageUrls = <String>[];
    final totalMedia = localImagePaths.length +
        (localVideoPath != null ? 1 : 0) +
        (local360VideoPath != null ? 1 : 0);

    for (int i = 0; i < localImagePaths.length; i++) {
      try {
        final url = await _uploadImage(localImagePaths[i], id, i);
        imageUrls.add(url);
        onProgress?.call((i + 1) / totalMedia);
      } catch (e) {
        throw Exception(
            'Failed to upload photo ${i + 1} of ${localImagePaths.length}. '
            'Check your internet connection and try again.\n\nDetail: $e');
      }
    }

    String? videoUrl;
    String? video360Url;
    if (localVideoPath != null) {
      videoUrl = await _uploadVideo(localVideoPath, id, 'main');
      onProgress?.call(0.9);
    }
    if (local360VideoPath != null) {
      video360Url = await _uploadVideo(local360VideoPath, id, '360');
      onProgress?.call(0.95);
    }

    // ── Step 2: Save to Firestore ─────────────────────────────────────────
    final listing = ListingModel(
      id: id,
      title: title,
      description: description,
      price: price,
      propertyType: propertyType,
      category: ListingCategory.fromAny(category).value,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      toilets: toilets,
      location: location,
      images: imageUrls,
      videoUrl: videoUrl,
      video360Url: video360Url,
      agentId: agentId,
      agentName: agentName,
      agentPhone: agentPhone,
      agentPhoto: agentPhoto,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      amenities: amenities,
      isFurnished: isFurnished,
      petsAllowed: petsAllowed,
      parkingAvailable: parkingAvailable,
      additionalInfo: additionalInfo,
      status: 'active',
    );

    try {
      final batch = _db.batch();
      batch.set(_col.doc(id), listing.toMap());
      batch.update(
        _db.collection(AppConstants.colUsers).doc(agentId),
        {'totalListings': FieldValue.increment(1)},
      );
      await batch.commit();
    } catch (e) {
      throw Exception('Photos uploaded but failed to save listing details. '
          'Please contact support.\n\nDetail: $e');
    }

    onProgress?.call(1.0);
    return id;
  }

  // ─── UPLOAD A SINGLE IMAGE (NEW - FOR EDIT) ─────────────────────────────
  Future<String> uploadImage(String path, String listingId, int index) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Photo file missing from device storage.');
    }

    final storageRef =
        _storage.ref('listings/images/$listingId/img_$index.jpg');

    TaskSnapshot snapshot;

    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 1080,
        minHeight: 810,
        quality: 82,
      );
      if (compressed != null && compressed.isNotEmpty) {
        snapshot = await storageRef.putData(
          compressed,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        snapshot = await storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
    } catch (_) {
      snapshot = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    return await snapshot.ref.getDownloadURL();
  }

  // ─── DELETE AN IMAGE FROM STORAGE (NEW - FOR EDIT) ──────────────────────
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Image might already be deleted or URL invalid - ignore
      debugPrint('Could not delete image: $e');
    }
  }

  // ── Update / Delete ───────────────────────────────────────────────────────
  /// Generic map update, restricted to [kOwnerEditableListingFields].
  /// A previous version accepted ANY map and wrote it straight to
  /// Firestore, which meant a compromised or modified client could set
  /// `isVerified`, `isFeatured`, `status`, or `agentId` directly. The real
  /// enforcement is in firestore.rules (a security rule is the only thing
  /// that can't be bypassed by editing the app); this allowlist is a second,
  /// client-side layer so a mistake in a screen doesn't even attempt it.
  Future<void> updateListing(String id, Map<String, dynamic> updates) async {
    final safe = <String, dynamic>{};
    for (final entry in updates.entries) {
      if (kOwnerEditableListingFields.contains(entry.key)) {
        safe[entry.key] = entry.value;
      }
    }
    if (safe.containsKey('category') && safe['category'] is String) {
      safe['category'] = ListingCategory.fromAny(safe['category'] as String).value;
    }
    safe['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).update(safe);
  }

  /// Status transitions that are safe for an owner to trigger themselves
  /// (pausing/republishing their own listing). Moving to 'active' from a
  /// moderation-pending state, or setting isVerified/isFeatured, must go
  /// through a Cloud Function — firestore.rules blocks a direct write from
  /// here for anything except this owner-safe subset.
  // Status transitions that are safe for an owner to trigger themselves
  // (pausing/republishing their own listing). Moving to 'active' from a
  // moderation-pending state, or setting isVerified/isFeatured, must go
  // through a Cloud Function — firestore.rules blocks a direct write from
  // here for anything except this owner-safe subset. 'archived' is handled
  // by archiveListing()/restoreListing() below, not this generic method,
  // since archiving also needs to stamp archivedAt/archivedBy.
  static const _ownerAllowedStatuses = {'active', 'paused', 'rented'};

  Future<void> updateStatus(String id, String status) async {
    if (!_ownerAllowedStatuses.contains(status)) {
      throw Exception(
          'Status "$status" must be set by an authorized reviewer, not the client.');
    }
    await _col
        .doc(id)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Soft delete — replaces the old permanent `deleteListing` as the
  /// default action from the UI. The review specifically flagged hard
  /// deletion as risky: it removes auditability, breaks any chat/booking
  /// that still references the listing, and can't be undone if it was a
  /// mistake. Archived listings are excluded from every public query
  /// (they never match `status == 'active'`) but keep existing, so an
  /// owner can restore one, and existing chats/bookings that reference it
  /// don't suddenly point at nothing.
  Future<void> archiveListing(String id, String ownerId) async {
    await _col.doc(id).update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': ownerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restoreListing(String id) async {
    await _col.doc(id).update({
      'status': 'active',
      'archivedAt': null,
      'archivedBy': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// TRUE permanent removal — kept for the rare privacy/legal-takedown
  /// case the review calls out as the one legitimate reason to still hard
  /// -delete. Not exposed as the primary "Delete" action anymore.
  Future<void> deleteListingPermanently(String id, String agentId) async =>
      deleteListing(id, agentId);

  Future<void> deleteListing(String id, String agentId) async {
    final batch = _db.batch();
    batch.delete(_col.doc(id));
    batch.update(
      _db.collection(AppConstants.colUsers).doc(agentId),
      {'totalListings': FieldValue.increment(-1)},
    );
    await batch.commit();
  }

  // ── Save / Unsave ─────────────────────────────────────────────────────────
  Future<void> saveListing(
      {required String userId, required String listingId}) async {
    await _db.collection(AppConstants.colUsers).doc(userId).update({
      'savedListings': FieldValue.arrayUnion([listingId])
    });
  }

  Future<void> unsaveListing(
      {required String userId, required String listingId}) async {
    await _db.collection(AppConstants.colUsers).doc(userId).update({
      'savedListings': FieldValue.arrayRemove([listingId])
    });
  }

  // ── View count ────────────────────────────────────────────────────────────
  // DEDUPLICATION FIX: this was never actually called from anywhere in the
  // app (view counts were simply dead — always 0). Wiring it up naively
  // from ListingDetailScreen's build/initState would immediately hit the
  // exact problem the review warned about — "do not blindly increment a
  // listing view every time a detail screen rebuilds." A `viewedBy`
  // subcollection keyed by viewer ID means a second visit from the same
  // person (or a rebuild) is a harmless duplicate write to a doc that
  // already exists, not a second increment.
  Future<void> incrementViewOnce(String listingId, String viewerId) async {
    final viewRef = _col.doc(listingId).collection('viewedBy').doc(viewerId);
    final existing = await viewRef.get();
    if (existing.exists) return; // already counted for this viewer
    final batch = _db.batch();
    batch.set(viewRef, {'viewedAt': FieldValue.serverTimestamp()});
    batch.update(_col.doc(listingId), {'viewCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> incrementView(String id) async {
    await _col.doc(id).update({'viewCount': FieldValue.increment(1)});
  }

  // ── Upload helpers (XFile compatible) ────────────────────────────────────
  Future<String> _uploadImage(String path, String listingId, int index) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Photo file missing from device storage. '
          'Please re-select your photos and try again.');
    }

    final storageRef =
        _storage.ref('listings/images/$listingId/img_$index.jpg');

    TaskSnapshot snapshot;

    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 1080,
        minHeight: 810,
        quality: 82,
      );
      if (compressed != null && compressed.isNotEmpty) {
        snapshot = await storageRef.putData(
          compressed,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        snapshot = await storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
    } catch (_) {
      snapshot = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    return await snapshot.ref.getDownloadURL();
  }

  Future<String> _uploadVideo(
      String path, String listingId, String type) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Video file missing from device storage.');
    }
    final storageRef =
        _storage.ref('listings/videos/$listingId/video_$type.mp4');
    final snapshot = await storageRef.putFile(
      file,
      SettableMetadata(contentType: 'video/mp4'),
    );
    return await snapshot.ref.getDownloadURL();
  }
}
