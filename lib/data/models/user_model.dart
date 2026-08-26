import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String? email;
  final String? profilePhoto;
  final String role; // tenant, agent, landlord, admin
  final bool isVerified;
  final bool isPhoneVerified;
  final double? rating;
  final int reviewCount;
  final int totalListings;
  final String? bio;
  final String? agencyName;
  final List<String> savedListings;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final String? fcmToken;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    this.profilePhoto,
    required this.role,
    this.isVerified = false,
    this.isPhoneVerified = true,
    this.rating,
    this.reviewCount = 0,
    this.totalListings = 0,
    this.bio,
    this.agencyName,
    this.savedListings = const [],
    required this.createdAt,
    this.lastSeen,
    this.fcmToken,
  });

  bool get isAgent => role == 'agent' || role == 'landlord';
  bool get isAdmin => role == 'admin';
  String get displayName => name.isNotEmpty ? name : 'User';
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      profilePhoto: data['profilePhoto'],
      role: data['role'] ?? 'tenant',
      isVerified: data['isVerified'] ?? false,
      isPhoneVerified: data['isPhoneVerified'] ?? true,
      rating: data['rating']?.toDouble(),
      reviewCount: (data['reviewCount'] ?? 0).toInt(),
      totalListings: (data['totalListings'] ?? 0).toInt(),
      bio: data['bio'],
      agencyName: data['agencyName'],
      savedListings: List<String>.from(data['savedListings'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'profilePhoto': profilePhoto,
        'role': role,
        'isVerified': isVerified,
        'isPhoneVerified': isPhoneVerified,
        'rating': rating,
        'reviewCount': reviewCount,
        'totalListings': totalListings,
        'bio': bio,
        'agencyName': agencyName,
        'savedListings': savedListings,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
        'fcmToken': fcmToken,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? profilePhoto,
    String? bio,
    String? agencyName,
    List<String>? savedListings,
    double? rating,
    int? reviewCount,
    int? totalListings,
    bool? isVerified,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      role: role,
      isVerified: isVerified ?? this.isVerified,
      isPhoneVerified: isPhoneVerified,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      totalListings: totalListings ?? this.totalListings,
      bio: bio ?? this.bio,
      agencyName: agencyName ?? this.agencyName,
      savedListings: savedListings ?? this.savedListings,
      createdAt: createdAt,
      lastSeen: lastSeen,
    );
  }
}
