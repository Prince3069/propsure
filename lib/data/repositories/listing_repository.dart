import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import '../models/listing_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/listing_category.dart';
import '../../core/utils/listing_ranking.dart';
import '../../core/utils/move_in_cost.dart';

/// Fields an owner may change directly. Mirrors firestore.rules exactly.
/// Everything trust- or payment-related (status, passport, featured,
/// availability, video state, counters) is written only by Cloud Functions.
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
  'amenities',
  'isFurnished',
  'petsAllowed',
  'parkingAvailable',
  'additionalInfo',
  'charges',
  'chargesComplete',
  'unconfirmedCharges',
  'agentName',
  'agentPhone',
  'agentPhoto',
};

class ListingPage {
  final List<ListingModel> items;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;
  const ListingPage({required this.items, required this.lastDoc, required this.hasMore});
}

class ListingRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  CollectionReference get _col => _db.collection(AppConstants.colListings);

  // ── Reads ────────────────────────────────────────────────────────────────
  Future<ListingModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? ListingModel.fromFirestore(doc) : null;
  }

  Stream<ListingModel?> watchById(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? ListingModel.fromFirestore(d) : null);

  Stream<List<ListingModel>> watchSavedListings({required String userId}) {
    return _db.collection(AppConstants.colUsers).doc(userId).snapshots().asyncMap((snap) async {
      final ids = List<String>.from((snap.data()?['savedListings'] as List?) ?? const []);
      if (ids.isEmpty) return <ListingModel>[];
      final docs = await Future.wait(ids.map((id) => _col.doc(id).get()));
      // Saved does not mean still available: paused/stale homes stay visible
      // to their savers (rules allow active + rented) but are marked in the UI.
      return docs.where((d) => d.exists).map(ListingModel.fromFirestore).toList();
    });
  }

  /// Applies the filters Firestore cannot express, to an already-fetched set.
  static List<ListingModel> applyClientFilters(List<ListingModel> input, ListingFilter f) {
    var items = input;
    if (f.minPrice != null && f.minPrice! > 0) items = items.where((l) => l.price >= f.minPrice!).toList();
    if (f.maxPrice != null) items = items.where((l) => l.price <= f.maxPrice!).toList();
    if (f.maxMoveIn != null) {
      // Budget against the KNOWN move-in subtotal. A home with unconfirmed
      // charges is still shown (never silently treated as zero or hidden) and
      // is labelled incomplete on its card.
      items = items.where((l) {
        if (!l.categoryEnum.hasMoveInCost) return l.price <= f.maxMoveIn!;
        return MoveInBreakdown.of(l).subtotal <= f.maxMoveIn!;
      }).toList();
    }
    if (f.minBedrooms != null) items = items.where((l) => l.bedrooms >= f.minBedrooms!).toList();
    if (f.mustHave.isNotEmpty) {
      items = items.where((l) {
        final have = l.amenities.map((a) => a.toLowerCase()).toSet();
        return f.mustHave.every((m) => have.contains(m.toLowerCase()));
      }).toList();
    }
    if (f.recentlyConfirmedOnly) {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      items = items.where((l) => l.availabilityConfirmedAt?.isAfter(cutoff) ?? false).toList();
    }
    if (f.query != null && f.query!.trim().isNotEmpty) {
      final q = f.query!.trim().toLowerCase();
      items = items
          .where((l) =>
              l.title.toLowerCase().contains(q) ||
              l.location.area.toLowerCase().contains(q) ||
              l.propertyType.toLowerCase().contains(q) ||
              l.location.city.toLowerCase().contains(q) ||
              l.description.toLowerCase().contains(q))
          .toList();
    }
    return items;
  }

  Query _baseQuery(ListingFilter filter) {
    // 'stale' and 'paused' homes never match, so they are absent from search.
    Query query = _col.where('status', isEqualTo: 'active');
    if (filter.area != null) query = query.where('area', isEqualTo: filter.area);
    if (filter.propertyType != null) query = query.where('propertyType', isEqualTo: filter.propertyType);
    if (filter.category != null) {
      query = query.where('category', isEqualTo: ListingCategory.fromAny(filter.category).value);
    }
    if (filter.isFeatured == true) query = query.where('isFeatured', isEqualTo: true);
    return query;
  }

  Future<ListingPage> fetchListingsPage({
    ListingFilter filter = const ListingFilter(),
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _baseQuery(filter);
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
        query = query.orderBy('createdAt', descending: true);
    }
    query = query.limit(pageSize);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snap = await query.get();
    var items = applyClientFilters(snap.docs.map(ListingModel.fromFirestore).toList(), filter);
    if (filter.sortOrder != SortOrder.priceAsc && filter.sortOrder != SortOrder.priceDesc) {
      items.sort(compareListingsByRank);
    }
    return ListingPage(
      items: items,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == pageSize,
    );
  }

  /// The agent's own inventory — every status, newest first.
  Stream<List<ListingModel>> watchAgentListings(String agentId) => _col
      .where('agentId', isEqualTo: agentId)
      .snapshots()
      .map((s) => s.docs.map(ListingModel.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// Public listings by one agent (profile page).
  Stream<List<ListingModel>> watchAgentPublicListings(String agentId) => _col
      .where('agentId', isEqualTo: agentId)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((s) => s.docs.map(ListingModel.fromFirestore).toList()..sort(compareListingsByRank));

  Stream<List<ListingModel>> watchListings({ListingFilter filter = const ListingFilter(), int limit = 40}) {
    return _baseQuery(filter).limit(limit).snapshots().map((snap) {
      var results = applyClientFilters(snap.docs.map(ListingModel.fromFirestore).toList(), filter);
      switch (filter.sortOrder) {
        case SortOrder.priceAsc:
          results.sort((a, b) => a.price.compareTo(b.price));
          break;
        case SortOrder.priceDesc:
          results.sort((a, b) => b.price.compareTo(a.price));
          break;
        default:
          results.sort(compareListingsByRank);
      }
      return results;
    });
  }

  // ── Drafts ───────────────────────────────────────────────────────────────
  /// Creates (or overwrites) a DRAFT. Nothing becomes public until
  /// FunctionsService.publishListing succeeds on the server.
  Future<String> saveDraft(ListingModel draft, {String? existingId}) async {
    final id = existingId ?? _uuid.v4();
    final map = draft.toDraftMap();
    if (existingId == null) {
      await _col.doc(id).set(map);
    } else {
      final safe = <String, dynamic>{
        for (final e in map.entries)
          if (kOwnerEditableListingFields.contains(e.key)) e.key: e.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _col.doc(id).update(safe);
    }
    return id;
  }

  Future<String> uploadImage(String path, String listingId, int index) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('A photo is no longer on your phone. Please choose it again.');
    }
    final ref = _storage.ref('listings/images/$listingId/img_${_uuid.v4().substring(0, 8)}_$index.jpg');
    TaskSnapshot snap;
    try {
      final bytes = await FlutterImageCompress.compressWithFile(path, minWidth: 1080, minHeight: 810, quality: 82);
      snap = (bytes != null && bytes.isNotEmpty)
          ? await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
          : await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    } catch (_) {
      snap = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    }
    return snap.ref.getDownloadURL();
  }

  /// Uploads the ORIGINAL walkthrough to the private, write-once path. The
  /// media worker (not the app) produces the playable versions and candidate
  /// frames. Returns the upload task so the UI can show real progress.
  UploadTask uploadOriginalVideo({required String listingId, required String ownerUid, required String path}) {
    final ext = path.toLowerCase().endsWith('.mov') ? 'mov' : 'mp4';
    final mime = ext == 'mov' ? 'video/quicktime' : 'video/mp4';
    final ref = _storage.ref('listing_originals/$listingId/${_uuid.v4()}/original.$ext');
    return ref.putFile(File(path), SettableMetadata(contentType: mime, customMetadata: {'ownerUid': ownerUid}));
  }

  Future<String> candidateUrl(String storagePath) => _storage.ref(storagePath).getDownloadURL();

  Future<void> deleteImage(String imageUrl) async {
    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (e) {
      debugPrint('Could not delete image: $e');
    }
  }

  // ── Updates ──────────────────────────────────────────────────────────────
  Future<void> updateListing(String id, Map<String, dynamic> updates) async {
    final safe = <String, dynamic>{
      for (final e in updates.entries)
        if (kOwnerEditableListingFields.contains(e.key)) e.key: e.value,
    };
    if (safe['category'] is String) safe['category'] = ListingCategory.fromAny(safe['category'] as String).value;
    safe['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).update(safe);
  }

  Future<void> deleteDraft(String id) => _col.doc(id).delete();

  // ── Saved ────────────────────────────────────────────────────────────────
  Future<void> saveListing({required String userId, required String listingId}) =>
      _db.collection(AppConstants.colUsers).doc(userId).update({'savedListings': FieldValue.arrayUnion([listingId])});

  Future<void> unsaveListing({required String userId, required String listingId}) =>
      _db.collection(AppConstants.colUsers).doc(userId).update({'savedListings': FieldValue.arrayRemove([listingId])});
}
