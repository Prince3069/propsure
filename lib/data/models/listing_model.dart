import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/listing_category.dart';

export '../../core/constants/listing_category.dart' show ListingCategory;

enum SortOrder { newest, oldest, priceAsc, priceDesc, featured }

/// verification_status lifecycle for users (identity). Set ONLY by trusted
/// backend code (Cloud Functions with an admin/reviewer claim) — never by
/// the client. Listing-level checks live in [PassportEntry].
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

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

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
  // 'exact' | 'street' | 'area' | 'approximate'. Anything that is not an
  // explicit exact pin is shown to renters as an approximate area.
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
    this.locationPrecision = 'approximate',
  });

  /// Renters only ever see an approximate area unless the agent explicitly
  /// confirmed a precise pin AND consented to showing it.
  bool get isApproximate => locationPrecision != 'exact';

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
      // Old documents without the field were area-centre fallbacks more often
      // than not, so they default to approximate (the safe reading).
      locationPrecision: map['locationPrecision'] as String? ?? 'approximate',
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

// ─── MOVE-IN CHARGES ─────────────────────────────────────────────────────────

enum ChargePeriod { oneTime, annual, monthly }

ChargePeriod chargePeriodFromString(String? s) {
  switch (s) {
    case 'annual':
      return ChargePeriod.annual;
    case 'monthly':
      return ChargePeriod.monthly;
    default:
      return ChargePeriod.oneTime;
  }
}

String chargePeriodToString(ChargePeriod p) {
  switch (p) {
    case ChargePeriod.oneTime:
      return 'one_time';
    case ChargePeriod.annual:
      return 'annual';
    case ChargePeriod.monthly:
      return 'monthly';
  }
}

/// A single charge an agent has listed. Unknown is not zero: a charge that
/// is not listed is simply not in this list (and, for rentals, the listing
/// is flagged "unconfirmed charges" unless the agent attests completeness).
class ListingCharge {
  final String type; // agency | legal | caution | service | utilities | other
  final String label;
  final double amount;
  final ChargePeriod period;
  final String recipient; // agent | landlord | management | other
  final String refundable; // yes | no | unknown
  final double? percent; // e.g. 10 for "10% of annual rent" (display only)
  final DateTime? confirmedAt;

  const ListingCharge({
    required this.type,
    required this.label,
    required this.amount,
    this.period = ChargePeriod.oneTime,
    this.recipient = 'agent',
    this.refundable = 'unknown',
    this.percent,
    this.confirmedAt,
  });

  bool get isUpfront => period != ChargePeriod.monthly;

  factory ListingCharge.fromMap(Map<String, dynamic> m) => ListingCharge(
        type: m['type'] as String? ?? 'other',
        label: m['label'] as String? ?? '',
        amount: (m['amount'] ?? 0).toDouble(),
        period: chargePeriodFromString(m['period'] as String?),
        recipient: m['recipient'] as String? ?? 'agent',
        refundable: m['refundable'] as String? ?? 'unknown',
        percent: (m['percent'] as num?)?.toDouble(),
        confirmedAt: _ts(m['confirmedAt']),
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'label': label,
        'amount': amount,
        'period': chargePeriodToString(period),
        'recipient': recipient,
        'refundable': refundable,
        if (percent != null) 'percent': percent,
        'source': 'agent',
        'confirmedAt': Timestamp.fromDate(confirmedAt ?? DateTime.now()),
      };
}

// ─── PASSPORT ────────────────────────────────────────────────────────────────

/// One scoped check on a listing's passport, each with its own date, expiry
/// and plain-language limitation. Written only by Cloud Functions.
class PassportEntry {
  final String state; // reviewed | rejected | needs_changes | none
  final DateTime? checkedAt;
  final DateTime? expiresAt;
  final String? limitation;

  const PassportEntry({this.state = 'none', this.checkedAt, this.expiresAt, this.limitation});

  bool get isCurrent =>
      state == 'reviewed' && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory PassportEntry.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const PassportEntry();
    return PassportEntry(
      state: m['state'] as String? ?? 'none',
      checkedAt: _ts(m['checkedAt']),
      expiresAt: _ts(m['expiresAt']),
      limitation: m['limitation'] as String?,
    );
  }
}

/// A still taken from the agent's own video, with provenance.
class ListingStill {
  final String url;
  final String source; // video | photo
  final int? timestampMs;
  final String? label;
  const ListingStill({required this.url, this.source = 'photo', this.timestampMs, this.label});

  factory ListingStill.fromMap(Map<String, dynamic> m) => ListingStill(
        url: m['url'] as String? ?? '',
        source: m['source'] as String? ?? 'photo',
        timestampMs: (m['timestampMs'] as num?)?.toInt(),
        label: m['label'] as String?,
      );
}

/// A candidate frame awaiting the agent's review (private storage path).
class VideoCandidate {
  final String id;
  final String path;
  final int timestampMs;
  /// Which space of the walk-through this frame belongs to (0, 1, 2…).
  final int scene;
  /// `wide` (the main view of the space) or `detail` (another view of it).
  final String role;
  const VideoCandidate({required this.id, required this.path, required this.timestampMs, this.scene = 0, this.role = 'wide'});

  factory VideoCandidate.fromMap(Map<String, dynamic> m) => VideoCandidate(
        id: m['id'] as String? ?? '',
        path: m['path'] as String? ?? '',
        timestampMs: (m['timestampMs'] as num?)?.toInt() ?? 0,
        scene: (m['scene'] as num?)?.toInt() ?? 0,
        role: m['role'] as String? ?? 'wide',
      );
}

/// Something to film again, with the moment it happens in the video.
class VideoIssue {
  final String type; // dark | bright | fast | short
  final int fromMs;
  final int toMs;
  final String tip;
  const VideoIssue({required this.type, required this.fromMs, required this.toMs, required this.tip});

  factory VideoIssue.fromMap(Map<String, dynamic> m) => VideoIssue(
        type: m['type'] as String? ?? '',
        fromMs: (m['fromMs'] as num?)?.toInt() ?? 0,
        toMs: (m['toMs'] as num?)?.toInt() ?? 0,
        tip: m['tip'] as String? ?? '',
      );
}

/// Where a walkthrough video is in the pipeline.
enum VideoStatus { none, uploaded, validating, processing, needsReview, ready, failed, rejected }

VideoStatus videoStatusFromString(String? s) {
  switch (s) {
    case 'uploaded':
      return VideoStatus.uploaded;
    case 'validating':
      return VideoStatus.validating;
    case 'processing':
      return VideoStatus.processing;
    case 'needs_review':
      return VideoStatus.needsReview;
    case 'ready':
      return VideoStatus.ready;
    case 'failed':
      return VideoStatus.failed;
    case 'rejected':
      return VideoStatus.rejected;
    default:
      return VideoStatus.none;
  }
}

// ─── LISTING ─────────────────────────────────────────────────────────────────

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
  final String? videoUrl; // 720p derivative
  final String? videoLowUrl; // 360p derivative (low-data)
  final String? posterUrl;
  final int? videoDurationSec;
  final VideoStatus videoStatus;
  final String? videoRejectionReason;
  final List<VideoCandidate> videoCandidates;
  final List<VideoIssue> videoIssues;
  final bool videoSteadied;
  final bool videoNeedsCheck;
  final String? videoCoverageWarning;
  final List<ListingStill> stills;
  final String? video360Url; // legacy field — never shown; no 360 support
  final String agentId;
  final String agentName;
  final String agentPhone;
  final String? agentPhoto;
  final bool isVerified; // legacy; the passport is the source of truth
  final bool isFeatured;
  final DateTime? featuredUntil;
  final bool safetyHold;
  final String status; // draft | active | paused | rented | stale | archived
  final String category; // for_rent | for_sale | short_stay | commercial

  // Trust metadata (legacy fields kept for old documents)
  final VerificationStatus verificationStatus;
  final String? verificationType;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final DateTime? verificationExpiresAt;

  // Costs
  final List<ListingCharge> charges;
  final bool chargesComplete;
  final List<String> unconfirmedCharges;

  // Freshness
  final DateTime? availabilityConfirmedAt;
  final String? availabilityConfirmedBy; // agent | inspection | propsure
  final bool needsRefresh;

  // Passport
  final PassportEntry authority;
  final PassportEntry titleReview; // title review (separate check)

  final DateTime createdAt;
  final DateTime? publishedAt;
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
    this.videoLowUrl,
    this.posterUrl,
    this.videoDurationSec,
    this.videoStatus = VideoStatus.none,
    this.videoRejectionReason,
    this.videoCandidates = const [],
    this.videoIssues = const [],
    this.videoSteadied = false,
    this.videoNeedsCheck = false,
    this.videoCoverageWarning,
    this.stills = const [],
    this.video360Url,
    required this.agentId,
    required this.agentName,
    required this.agentPhone,
    this.agentPhoto,
    this.isVerified = false,
    this.isFeatured = false,
    this.featuredUntil,
    this.safetyHold = false,
    this.status = 'draft',
    this.category = 'for_rent',
    this.verificationStatus = VerificationStatus.none,
    this.verificationType,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationExpiresAt,
    this.charges = const [],
    this.chargesComplete = false,
    this.unconfirmedCharges = const [],
    this.availabilityConfirmedAt,
    this.availabilityConfirmedBy,
    this.needsRefresh = false,
    this.authority = const PassportEntry(),
    this.titleReview = const PassportEntry(),
    required this.createdAt,
    this.publishedAt,
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
    final passport = (data['passport'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ListingModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      propertyType: data['propertyType'] ?? '',
      bedrooms: (data['bedrooms'] ?? 0).toInt(),
      bathrooms: (data['bathrooms'] ?? 0).toInt(),
      toilets: (data['toilets'] ?? 0).toInt(),
      location: PropertyLocation.fromMap((data['location'] as Map<String, dynamic>?) ?? {}),
      images: List<String>.from(data['images'] ?? []),
      videoUrl: data['videoUrl'],
      videoLowUrl: data['videoLowUrl'],
      posterUrl: data['posterUrl'],
      videoDurationSec: (data['videoDurationSec'] as num?)?.toInt(),
      videoStatus: videoStatusFromString(data['videoStatus'] as String?),
      videoRejectionReason: data['videoRejectionReason'] as String?,
      videoCandidates: ((data['videoCandidates'] as List?) ?? const [])
          .map((e) => VideoCandidate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      // The media worker stores this as true/false; older data may hold text.
      videoIssues: ((data['videoIssues'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => VideoIssue.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      videoSteadied: data['videoSteadied'] == true,
      videoNeedsCheck: data['videoNeedsCheck'] == true,
      videoCoverageWarning: data['videoCoverageWarning'] is String
          ? data['videoCoverageWarning'] as String
          : (data['videoCoverageWarning'] == true ? 'This video may not show every room. You can add more photos or record again.' : null),
      stills: ((data['stills'] as List?) ?? const [])
          .map((e) => ListingStill.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      video360Url: data['video360Url'],
      agentId: data['agentId'] ?? '',
      agentName: data['agentName'] ?? '',
      agentPhone: data['agentPhone'] ?? '',
      agentPhoto: data['agentPhoto'],
      // Never a bare label: only an approved, unexpired legacy check counts.
      category: ListingCategory.fromAny(data['category'] as String?).value,
      verificationStatus: verificationStatusFromString(data['verificationStatus'] as String?),
      verificationType: data['verificationType'] as String?,
      verifiedAt: _ts(data['verifiedAt']),
      verifiedBy: data['verifiedBy'] as String?,
      verificationExpiresAt: _ts(data['verificationExpiresAt']),
      isVerified: verificationStatusFromString(data['verificationStatus'] as String?) ==
              VerificationStatus.approved &&
          !(_ts(data['verificationExpiresAt'])?.isBefore(DateTime.now()) ?? false),
      isFeatured: data['isFeatured'] ?? false,
      featuredUntil: _ts(data['featuredUntil']),
      safetyHold: data['safetyHold'] ?? false,
      status: data['status'] ?? 'active',
      charges: ((data['charges'] as List?) ?? const [])
          .map((e) => ListingCharge.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      chargesComplete: data['chargesComplete'] ?? false,
      unconfirmedCharges: List<String>.from(data['unconfirmedCharges'] ?? const []),
      availabilityConfirmedAt: _ts(data['availabilityConfirmedAt']),
      availabilityConfirmedBy: data['availabilityConfirmedBy'] as String?,
      needsRefresh: data['needsRefresh'] ?? false,
      authority: PassportEntry.fromMap((passport['authority'] as Map?)?.cast<String, dynamic>()),
      titleReview: PassportEntry.fromMap((passport['title'] as Map?)?.cast<String, dynamic>()),
      createdAt: _ts(data['createdAt']) ?? DateTime.now(),
      publishedAt: _ts(data['publishedAt']),
      updatedAt: _ts(data['updatedAt']),
      expiresAt: _ts(data['expiresAt']),
      viewCount: (data['viewCount'] ?? 0).toInt(),
      inquiryCount: (data['inquiryCount'] ?? 0).toInt(),
      amenities: List<String>.from(data['amenities'] ?? []),
      isFurnished: data['isFurnished'] ?? false,
      petsAllowed: data['petsAllowed'] ?? false,
      parkingAvailable: data['parkingAvailable'] ?? false,
      additionalInfo: data['additionalInfo'],
    );
  }

  /// The ONLY map a client may write when creating a listing. It is a draft:
  /// status, featuring, passport, availability and counters are not here
  /// because firestore.rules reject them and Cloud Functions own them.
  Map<String, dynamic> toDraftMap() => {
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
        'agentId': agentId,
        'agentName': agentName,
        'agentPhone': agentPhone,
        'agentPhoto': agentPhoto,
        'status': 'draft',
        'category': ListingCategory.fromAny(category).value,
        'charges': charges.map((c) => c.toMap()).toList(),
        'chargesComplete': chargesComplete,
        'unconfirmedCharges': unconfirmedCharges,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'viewCount': 0,
        'inquiryCount': 0,
        'amenities': amenities,
        'isFurnished': isFurnished,
        'petsAllowed': petsAllowed,
        'parkingAvailable': parkingAvailable,
        'additionalInfo': additionalInfo,
      };

  ListingCategory get categoryEnum => ListingCategory.fromAny(category);
  bool get isActive => status == 'active';
  bool get isDraft => status == 'draft';
  bool get isLive => status == 'active' || status == 'stale';

  /// "₦2.4m / year", "₦45k / night", "₦85m" — period always derived.
  String get priceLabel {
    final p = categoryEnum.periodWord;
    return p.isEmpty ? _short(price) : '${_short(price)} / $p';
  }

  // Compact form kept here for the legacy getters below.
  static String _short(double n) {
    String c(double x, int d) {
      var s = x.toStringAsFixed(d);
      if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      return s;
    }

    if (n >= 1000000) return '₦${c(n / 1000000, 2)}m';
    if (n >= 1000) return '₦${c(n / 1000, 1)}k';
    return '₦${n.round()}';
  }

  // Legacy getters (older call sites).
  String get formattedPrice => _short(price);
  String get formattedPriceWithPeriod => '$formattedPrice${categoryEnum.priceSuffix}';

  /// A paid placement is "Sponsored" only while it is live and not under a
  /// safety hold. Payment never changes any check.
  bool get isSponsored =>
      isFeatured && !safetyHold && (featuredUntil == null || featuredUntil!.isAfter(DateTime.now()));

  /// Cover image: reviewed poster/still first, then the first photo.
  String? get coverUrl => images.isNotEmpty ? images.first : posterUrl;
  bool get hasVideo => videoUrl != null && videoStatus == VideoStatus.ready;
}

/// A single filter model. One text field (`query`), one place for every
/// filter, and an honest count of what is active.
class ListingFilter {
  final String? query;
  final String? area;
  final String? propertyType;
  final String? category; // canonical ListingCategory.value, or null = any
  final int? minBedrooms;
  final double? minPrice;
  final double? maxPrice;
  final double? maxMoveIn; // total move-in budget
  final String? city; // client-side city scope (canonical name), null = everywhere
  final bool budgetIsMoveIn; // true = budget applies to move-in total
  final List<String> mustHave; // amenity labels
  final bool recentlyConfirmedOnly;
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
    this.maxMoveIn,
    this.city,
    this.budgetIsMoveIn = true,
    this.mustHave = const [],
    this.recentlyConfirmedOnly = false,
    this.isVerified,
    this.isFeatured,
    this.sortOrder = SortOrder.newest,
  });

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
      category: category == null ? null : ListingCategory.fromAny(category).value,
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
    double? maxMoveIn,
    String? city,
    bool clearCity = false,
    bool? budgetIsMoveIn,
    List<String>? mustHave,
    bool? recentlyConfirmedOnly,
    bool? isVerified,
    bool? isFeatured,
    SortOrder? sortOrder,
    bool clearQuery = false,
    bool clearArea = false,
    bool clearType = false,
    bool clearCategory = false,
    bool clearBeds = false,
    bool clearPrice = false,
    bool clearMoveIn = false,
    bool clearVerified = false,
  }) {
    return ListingFilter(
      query: clearQuery ? null : (query ?? this.query),
      area: clearArea ? null : (area ?? this.area),
      propertyType: clearType ? null : (propertyType ?? this.propertyType),
      category: clearCategory
          ? null
          : (category != null ? ListingCategory.fromAny(category).value : this.category),
      minBedrooms: clearBeds ? null : (minBedrooms ?? this.minBedrooms),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      maxMoveIn: clearMoveIn ? null : (maxMoveIn ?? this.maxMoveIn),
      city: clearCity ? null : (city ?? this.city),
      budgetIsMoveIn: budgetIsMoveIn ?? this.budgetIsMoveIn,
      mustHave: mustHave ?? this.mustHave,
      recentlyConfirmedOnly: recentlyConfirmedOnly ?? this.recentlyConfirmedOnly,
      isVerified: clearVerified ? null : (isVerified ?? this.isVerified),
      isFeatured: isFeatured ?? this.isFeatured,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// A completely empty filter (clear-all means this, not "most of it").
  static const ListingFilter empty = ListingFilter();

  int get activeFilterCount {
    int c = 0;
    if (query != null && query!.isNotEmpty) c++;
    if (area != null) c++;
    if (propertyType != null) c++;
    if (category != null) c++;
    if (minBedrooms != null) c++;
    if (minPrice != null || maxPrice != null || maxMoveIn != null) c++;
    if (mustHave.isNotEmpty) c++;
    if (recentlyConfirmedOnly) c++;
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
          other.maxMoveIn == maxMoveIn &&
          other.city == city &&
          other.budgetIsMoveIn == budgetIsMoveIn &&
          _listEq(other.mustHave, mustHave) &&
          other.recentlyConfirmedOnly == recentlyConfirmedOnly &&
          other.isVerified == isVerified &&
          other.isFeatured == isFeatured &&
          other.sortOrder == sortOrder;

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(query, area, propertyType, category, minBedrooms, minPrice,
      maxPrice, maxMoveIn, city, budgetIsMoveIn, Object.hashAll(mustHave), recentlyConfirmedOnly,
      isVerified, isFeatured, sortOrder);
}
