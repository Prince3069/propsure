import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_model.dart';
import '../../core/constants/listing_category.dart';

/// A saved search is just a frozen `ListingFilter` plus notification
/// preferences. The matching Cloud Function (`checkSavedSearches` in
/// functions/index.js) runs on a schedule, re-applies each saved filter
/// against listings created since it last ran, and writes a real
/// `notifications` document for any match — reusing the notification
/// pipeline that already exists rather than inventing a second one.
class SavedSearchModel {
  final String id;
  final String userId;
  final String label; // user-facing name, e.g. "3-bed in Wuse under 2M"
  final String? query;
  final String? area;
  final String? propertyType;
  final String? category; // canonical ListingCategory.value
  final int? minBedrooms;
  final double? minPrice;
  final double? maxPrice;
  final bool alertsEnabled;
  final DateTime createdAt;
  final DateTime? lastMatchedAt;

  const SavedSearchModel({
    required this.id,
    required this.userId,
    required this.label,
    this.query,
    this.area,
    this.propertyType,
    this.category,
    this.minBedrooms,
    this.minPrice,
    this.maxPrice,
    this.alertsEnabled = true,
    required this.createdAt,
    this.lastMatchedAt,
  });

  factory SavedSearchModel.fromFilter({
    required String userId,
    required String label,
    required ListingFilter filter,
    bool alertsEnabled = true,
  }) =>
      SavedSearchModel(
        id: '',
        userId: userId,
        label: label,
        query: filter.query,
        area: filter.area,
        propertyType: filter.propertyType,
        category: filter.category,
        minBedrooms: filter.minBedrooms,
        minPrice: filter.minPrice,
        maxPrice: filter.maxPrice,
        alertsEnabled: alertsEnabled,
        createdAt: DateTime.now(),
      );

  ListingFilter toFilter() => ListingFilter.withCategory(
        query: query,
        area: area,
        propertyType: propertyType,
        category: category,
        minBedrooms: minBedrooms,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

  factory SavedSearchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SavedSearchModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      label: d['label'] ?? 'Saved search',
      query: d['query'],
      area: d['area'],
      propertyType: d['propertyType'],
      category: d['category'],
      minBedrooms: (d['minBedrooms'] as num?)?.toInt(),
      minPrice: (d['minPrice'] as num?)?.toDouble(),
      maxPrice: (d['maxPrice'] as num?)?.toDouble(),
      alertsEnabled: d['alertsEnabled'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMatchedAt: (d['lastMatchedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'label': label,
        'query': query,
        'area': area,
        'propertyType': propertyType,
        'category': category != null ? ListingCategory.fromAny(category).value : null,
        'minBedrooms': minBedrooms,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'alertsEnabled': alertsEnabled,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMatchedAt': lastMatchedAt != null ? Timestamp.fromDate(lastMatchedAt!) : null,
      };
}

class SavedSearchRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('saved_searches');

  Future<String> save(SavedSearchModel search) async {
    final ref = await _col.add(search.toMap());
    return ref.id;
  }

  Stream<List<SavedSearchModel>> watchMine(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => SavedSearchModel.fromFirestore(d)).toList());
  }

  Future<void> setAlertsEnabled(String id, bool enabled) async {
    await _col.doc(id).update({'alertsEnabled': enabled});
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
