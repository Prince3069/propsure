import 'package:cloud_firestore/cloud_firestore.dart';

enum SortOrder { newest, oldest, priceAsc, priceDesc, featured }

enum ListingCategory { forRent, forSale, shortStay }

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
  final String category; // for_rent, for_sale, short_stay
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
      isVerified: data['isVerified'] ?? false,
      isFeatured: data['isFeatured'] ?? false,
      status: data['status'] ?? 'active',
      category: data['category'] ?? 'for_rent',
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
        'category': category,
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

  String get formattedPriceWithPeriod {
    final suffix = category == 'short_stay' ? '/night' : '/yr';
    return '${formattedPrice}$suffix';
  }

  bool get isActive => status == 'active';
}

class ListingFilter {
  final String? query; // text search: matches title, area, propertyType
  final String? area;
  final String? state;
  final String? propertyType;
  final String? category;
  final int? minBedrooms;
  final double? minPrice;
  final double? maxPrice;
  final bool? isVerified;
  final bool? isFeatured;
  final String? searchQuery;
  final SortOrder sortOrder;

  const ListingFilter({
    this.query,
    this.area,
    this.state,
    this.propertyType,
    this.category,
    this.minBedrooms,
    this.minPrice,
    this.maxPrice,
    this.isVerified,
    this.isFeatured,
    this.searchQuery,
    this.sortOrder = SortOrder.newest,
  });

  ListingFilter copyWith({
    String? query,
    String? area,
    String? state,
    String? propertyType,
    String? category,
    int? minBedrooms,
    double? minPrice,
    double? maxPrice,
    bool? isVerified,
    bool? isFeatured,
    String? searchQuery,
    SortOrder? sortOrder,
    bool clearArea = false,
    bool clearType = false,
    bool clearBeds = false,
    bool clearPrice = false,
    bool clearVerified = false,
  }) {
    return ListingFilter(
      area: clearArea ? null : (area ?? this.area),
      state: state ?? this.state,
      propertyType: clearType ? null : (propertyType ?? this.propertyType),
      category: category ?? this.category,
      minBedrooms: clearBeds ? null : (minBedrooms ?? this.minBedrooms),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      isVerified: clearVerified ? null : (isVerified ?? this.isVerified),
      isFeatured: isFeatured ?? this.isFeatured,
      searchQuery: searchQuery ?? this.searchQuery,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  int get activeFilterCount {
    int c = 0;
    if (area != null) c++;
    if (propertyType != null) c++;
    if (minBedrooms != null) c++;
    if (minPrice != null || maxPrice != null) c++;
    if (isVerified == true) c++;
    return c;
  }

  @override
  bool operator ==(Object other) =>
      other is ListingFilter &&
      other.area == area &&
      other.state == state &&
      other.propertyType == propertyType &&
      other.category == category &&
      other.minBedrooms == minBedrooms &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.isVerified == isVerified &&
      other.isFeatured == isFeatured &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(area, state, propertyType, category,
      minBedrooms, minPrice, maxPrice, isVerified, isFeatured, sortOrder);
}
