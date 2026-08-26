import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/listing_model.dart';
import '../../core/constants/app_constants.dart';

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

  // ── Agent listings ────────────────────────────────────────────────────────
  Stream<List<ListingModel>> watchAgentListings(String agentId) => _col
      .where('agentId', isEqualTo: agentId)
      .where('status', isEqualTo: 'active')
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
      query = query.where('category', isEqualTo: filter.category);
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
          results.sort((a, b) {
            if (a.isFeatured && !b.isFeatured) return -1;
            if (!a.isFeatured && b.isFeatured) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
      }

      return results;
    });
  }

  // ── Create listing ────────────────────────────────────────────────────────
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
    required List<String> localImagePaths,
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
        // Re-throw with clearer message so user sees what went wrong
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
      category: category,
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
      // Increment agent's listing count
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

  // ── Update / Delete ───────────────────────────────────────────────────────
  Future<void> updateListing(String id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).update(updates);
  }

  Future<void> updateStatus(String id, String status) async {
    await _col
        .doc(id)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

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
  Future<void> incrementView(String id) async {
    await _col.doc(id).update({'viewCount': FieldValue.increment(1)});
  }

  // ── Upload helpers ────────────────────────────────────────────────────────
  Future<String> _uploadImage(String path, String listingId, int index) async {
    // Verify the file actually exists on the device
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Photo file missing from device storage. '
          'Please re-select your photos and try again.');
    }

    final storageRef =
        _storage.ref('listings/images/$listingId/img_$index.jpg');

    TaskSnapshot snapshot;

    // Try compressed upload first, fall back to raw if it fails
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
        // Compression returned null — upload original
        snapshot = await storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
    } catch (_) {
      // Compression crashed — upload original file directly
      snapshot = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    // Get download URL from the completed upload snapshot
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
