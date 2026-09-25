import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/listing_category.dart';

export '../../core/constants/listing_category.dart' show ListingCategory;

enum SortOrder { newest, oldest, priceAsc, priceDesc, featured }

/// verification_status lifecycle for both users and listings.
/// Set ONLY by trusted backend code (Cloud Functions with an admin/reviewer
/// custom claim) — never write these client-side. See Firestore rules.
enum VerificationStatus { none, pending, approved, rejected, expired }

VerificationStatus verificationStatusFromString(String? raw) {
  switch (raw) {
    case 'pending':
      return VerificationStatus.pending;
    case 'approved':
      return VerificationStatus.approved;
    case 'rejected':
      return VerificationStatus.rejected;
    case 'expired':
      return VerificationStatus.expired;
    default:
      return VerificationStatus.none;
  }
}

String verificationStatusToString(VerificationStatus s) => s.name;

class PropertyLocation {
  final double latitude;
  final double longitude;
  final String geohash;
  final String country;
  final String state;
  final String city;
  final String area;
  final String street;
  final String fullAddress;
  final Map<String, dynamic>? geoData;
  // 'exact' | 'street' | 'area' | 'approximate'. Set to 'approximate'
  // whenever the coordinates came from an area-center fallback rather than
  // a pin the user actually placed — the review flagged that the app was
  // presenting area-center coordinates as if they were the precise
  // property location. Defaults to 'exact' for backward compatibility with
  // documents written before this field existed (most were pin-selected).
  final String locationPrecision;

  const PropertyLocation({
    required this.latitude,
    required this.longitude,
    required this.geohash,
    this.country = 'Nigeria',
    this.state = 'FCT',
    this.city = 'Abuja',
    required this.area,
    this.street = '',
    required this.fullAddress,
    this.geoData,
    this.locationPrecision = 'exact',
  });

  factory PropertyLocation.fromMap(Map<String, dynamic> map) {
    return PropertyLocation(
      latitude: (map['latitude'] ?? 9.0765).toDouble(),
      longitude: (map['longitude'] ?? 7.3986).toDouble(),
      geohash: map['geohash'] ?? '',
      country: map['country'] ?? 'Nigeria',
      state: map['state'] ?? 'FCT',
      city: map['city'] ?? 'Abuja',
      area: map['area'] ?? '',
      street: map['street'] ?? '',
      fullAddress: map['fullAddress'] ?? '',
      geoData: map['geoData'],
      locationPrecision: map['locationPrecision'] as String? ?? 'exact',
    );
  }

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'geohash': geohash,
        'country': country,
        'state': state,
        'city': city,
        'area': area,
        'street': street,
        'fullAddress': fullAddress,
        'geoData': geoData,
        'locationPrecision': locationPrecision,
      };
}

class ListingModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final String propertyType;
  final int bedrooms;
  final int bathrooms;
  final int toilets;
  final PropertyLocation location;
  final List<String> images;
  final String? videoUrl;
  final String? video360Url;
  final String agentId;
  final String agentName;
  final String agentPhone;
  final String? agentPhoto;
  final bool isVerified;
  final bool isFeatured;
  final String status;
  final String category; // canonical value, e.g. for_rent, for_sale, short_stay, commercial

  // ── Trust / verification metadata (2.2 of the review) ──
  // `isVerified` above is kept for backward-compatible reads/queries, but is
  // now DERIVED from verificationStatus rather than an independent flag.
  // These fields are written ONLY by Cloud Functions — enforced in
  // firestore.rules — never by the Flutter client.
  final VerificationStatus verificationStatus;
  final String? verificationType; // e.g. 'ownership', 'agent_authority'
  final DateTime? verifiedAt;
  final String? verifiedBy; // reviewer uid
  final DateTime? verificationExpiresAt;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final int viewCount;
  final int inquiryCount;
  final List<String> amenities;
  final bool isFurnished;
  final bool petsAllowed;
  final bool parkingAvailable;
  final String? additionalInfo;

  const ListingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.propertyType,
    required this.bedrooms,
    required this.bathrooms,
    required this.toilets,
    required this.location,
    required this.images,
    this.videoUrl,
    this.video360Url,
    required this.agentId,
    required this.agentName,
    required this.agentPhone,
    this.agentPhoto,
    this.isVerified = false,
    this.isFeatured = false,
    this.status = 'active',
    this.category = 'for_rent',
    this.verificationStatus = VerificationStatus.none,
    this.verificationType,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationExpiresAt,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.viewCount = 0,
    this.inquiryCount = 0,
    this.amenities = const [],
    this.isFurnished = false,
    this.petsAllowed = false,
    this.parkingAvailable = false,
    this.additionalInfo,
  });

  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ListingModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      propertyType: data['propertyType'] ?? '',
      bedrooms: (data['bedrooms'] ?? 0).toInt(),
      bathrooms: (data['bathrooms'] ?? 0).toInt(),
      toilets: (data['toilets'] ?? 0).toInt(),
      location: PropertyLocation.fromMap(
          (data['location'] as Map<String, dynamic>?) ?? {}),
      images: List<String>.from(data['images'] ?? []),
      videoUrl: data['videoUrl'],
      video360Url: data['video360Url'],
      agentId: data['agentId'] ?? '',
      agentName: data['agentName'] ?? '',
      agentPhone: data['agentPhone'] ?? '',
      agentPhoto: data['agentPhoto'],
      // Legacy documents may still contain "For Rent" / "Short Stay" etc.
      // Normalize on every read so old data keeps working while the
      // one-time migration script (see /migrations) catches up.
      category: ListingCategory.fromAny(data['category'] as String?).value,
      verificationStatus:
          verificationStatusFromString(data['verificationStatus'] as String?),
      verificationType: data['verificationType'] as String?,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      verifiedBy: data['verifiedBy'] as String?,
      verificationExpiresAt:
          (data['verificationExpiresAt'] as Timestamp?)?.toDate(),
      // Derived: only "approved" and not expired counts as verified.
      isVerified: verificationStatusFromString(
                  data['verificationStatus'] as String?) ==
              VerificationStatus.approved &&
          !((data['verificationExpiresAt'] as Timestamp?)
                  ?.toDate()
                  .isBefore(DateTime.now()) ??
              false),
      isFeatured: data['isFeatured'] ?? false,
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      viewCount: (data['viewCount'] ?? 0).toInt(),
      inquiryCount: (data['inquiryCount'] ?? 0).toInt(),
      amenities: List<String>.from(data['amenities'] ?? []),
      isFurnished: data['isFurnished'] ?? false,
      petsAllowed: data['petsAllowed'] ?? false,
      parkingAvailable: data['parkingAvailable'] ?? false,
      additionalInfo: data['additionalInfo'],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'price': price,
        'propertyType': propertyType,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'toilets': toilets,
        'location': location.toMap(),
        'area': location.area,
        'city': location.city,
        'images': images,
        'videoUrl': videoUrl,
        'video360Url': video360Url,
        'agentId': agentId,
        'agentName': agentName,
        'agentPhone': agentPhone,
        'agentPhoto': agentPhoto,
        'isVerified': isVerified,
        'isFeatured': isFeatured,
        'status': status,
        // Defensive normalization: even if a caller somehow passes a legacy
        // label, only the canonical machine value is ever persisted.
        'category': ListingCategory.fromAny(category).value,
        'verificationStatus': verificationStatusToString(verificationStatus),
        'verificationType': verificationType,
        'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
        'verifiedBy': verifiedBy,
        'verificationExpiresAt': verificationExpiresAt != null
            ? Timestamp.fromDate(verificationExpiresAt!)
            : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'viewCount': viewCount,
        'inquiryCount': inquiryCount,
        'amenities': amenities,
        'isFurnished': isFurnished,
        'petsAllowed': petsAllowed,
        'parkingAvailable': parkingAvailable,
        'additionalInfo': additionalInfo,
      };

  String get formattedPrice {
    if (price >= 1000000) {
      final m = price / 1000000;
      return '₦${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}M';
    }
    if (price >= 1000) return '₦${(price / 1000).toInt()}k';
    return '₦${price.toInt()}';
  }

  ListingCategory get categoryEnum => ListingCategory.fromAny(category);

  String get formattedPriceWithPeriod =>
      '$formattedPrice${categoryEnum.priceSuffix}';

  bool get isActive => status == 'active';
}

/// A single filter model. The old version had BOTH `query` and `searchQuery`
/// (the repository read `filter.query`, screens wrote either one), and
/// `copyWith()` silently dropped whichever text-search field it carried —
/// editing one filter could wipe the user's current search text. There is
/// now exactly one text-search field: `query`. There was also a dead
/// `state` field that was accepted by the model but never applied by the
/// repository query — removed per the review's "apply it or remove it"
/// guidance, since nothing in the app currently supports state-level
/// filtering (Propsure is Abuja-only for now).
class ListingFilter {
  final String? query; // text search: matches title, area, propertyType, description
  final String? area;
  final String? propertyType;
  final String? category; // canonical ListingCategory.value, or null = any
  final int? minBedrooms;
  final double? minPrice;
  final double? maxPrice;
  final bool? isVerified;
  final bool? isFeatured;
  final SortOrder sortOrder;

  const ListingFilter({
    this.query,
    this.area,
    this.propertyType,
    this.category,
    this.minBedrooms,
    this.minPrice,
    this.maxPrice,
    this.isVerified,
    this.isFeatured,
    this.sortOrder = SortOrder.newest,
  });

  /// Normalizes whatever category string comes in (route slug, legacy
  /// label, canonical value) to the canonical value before it's stored on
  /// the filter, so the repository query is always exact-matching against
  /// what's actually in Firestore.
  factory ListingFilter.withCategory({
    String? query,
    String? area,
    String? propertyType,
    String? category,
    int? minBedrooms,
    double? minPrice,
    double? maxPrice,
    bool? isVerified,
    bool? isFeatured,
    SortOrder sortOrder = SortOrder.newest,
  }) {
    return ListingFilter(
      query: query,
      area: area,
      propertyType: propertyType,
      category:
          category == null ? null : ListingCategory.fromAny(category).value,
      minBedrooms: minBedrooms,
      minPrice: minPrice,
      maxPrice: maxPrice,
      isVerified: isVerified,
      isFeatured: isFeatured,
      sortOrder: sortOrder,
    );
  }

  ListingFilter copyWith({
    String? query,
    String? area,
    String? propertyType,
    String? category,
    int? minBedrooms,
    double? minPrice,
    double? maxPrice,
    bool? isVerified,
    bool? isFeatured,
    SortOrder? sortOrder,
    bool clearQuery = false,
    bool clearArea = false,
    bool clearType = false,
    bool clearCategory = false,
    bool clearBeds = false,
    bool clearPrice = false,
    bool clearVerified = false,
  }) {
    return ListingFilter(
      query: clearQuery ? null : (query ?? this.query),
      area: clearArea ? null : (area ?? this.area),
      propertyType: clearType ? null : (propertyType ?? this.propertyType),
      category: clearCategory
          ? null
          : (category != null
              ? ListingCategory.fromAny(category).value
              : this.category),
      minBedrooms: clearBeds ? null : (minBedrooms ?? this.minBedrooms),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      isVerified: clearVerified ? null : (isVerified ?? this.isVerified),
      isFeatured: isFeatured ?? this.isFeatured,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Counts every field that actually affects the result set — the old
  /// version omitted category, isFeatured, and the text query entirely,
  /// so the "N filters active" chip in Search under-counted.
  int get activeFilterCount {
    int c = 0;
    if (query != null && query!.isNotEmpty) c++;
    if (area != null) c++;
    if (propertyType != null) c++;
    if (category != null) c++;
    if (minBedrooms != null) c++;
    if (minPrice != null || maxPrice != null) c++;
    if (isVerified == true) c++;
    if (isFeatured == true) c++;
    return c;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingFilter &&
          other.query == query &&
          other.area == area &&
          other.propertyType == propertyType &&
          other.category == category &&
          other.minBedrooms == minBedrooms &&
          other.minPrice == minPrice &&
          other.maxPrice == maxPrice &&
          other.isVerified == isVerified &&
          other.isFeatured == isFeatured &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(query, area, propertyType, category,
      minBedrooms, minPrice, maxPrice, isVerified, isFeatured, sortOrder);
}
