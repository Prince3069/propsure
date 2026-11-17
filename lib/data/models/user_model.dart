import 'package:cloud_firestore/cloud_firestore.dart';
import 'listing_model.dart' show VerificationStatus, verificationStatusFromString, verificationStatusToString;

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
  // Written by paystackWebhook (functions/index.js) once a premium
  // subscription payment succeeds — never by the client. Read-only here.
  final String? premiumPlan; // 'agent_pro' | 'agent_elite' | null
  final DateTime? premiumExpiresAt;

  // ── Trust / verification metadata ──
  // Written ONLY by Cloud Functions (an admin/reviewer custom claim) after
  // a verification_requests document is approved. Never written by the
  // Flutter client — enforced in firestore.rules. `isVerified` above is
  // kept for backward-compatible queries/UI but is derived from this.
  final VerificationStatus verificationStatus;
  final String? verificationType; // 'identity' | 'agent_authority' | 'landlord_ownership'
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final DateTime? verificationExpiresAt;

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
    this.premiumPlan,
    this.premiumExpiresAt,
    this.verificationStatus = VerificationStatus.none,
    this.verificationType,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationExpiresAt,
  });

  bool get isAgent => role == 'agent' || role == 'landlord';
  bool get isAdmin => role == 'admin';
  bool get isPremium =>
      premiumPlan != null && (premiumExpiresAt?.isAfter(DateTime.now()) ?? false);
  String get displayName => name.isNotEmpty ? name : 'User';
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final vStatus = verificationStatusFromString(data['verificationStatus'] as String?);
    final vExpires = (data['verificationExpiresAt'] as Timestamp?)?.toDate();
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      profilePhoto: data['profilePhoto'],
      role: data['role'] ?? 'tenant',
      // Derived: only "approved" and not expired counts as verified.
      // Falls back to the legacy boolean if verificationStatus was never
      // set (documents written before this workflow existed).
      isVerified: vStatus == VerificationStatus.approved
          ? !(vExpires?.isBefore(DateTime.now()) ?? false)
          : (data['isVerified'] ?? false) && vStatus == VerificationStatus.none,
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
      premiumPlan: data['premiumPlan'],
      premiumExpiresAt: (data['premiumExpiresAt'] as Timestamp?)?.toDate(),
      verificationStatus: vStatus,
      verificationType: data['verificationType'] as String?,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      verifiedBy: data['verifiedBy'] as String?,
      verificationExpiresAt: vExpires,
    );
  }

  /// The ONLY map a client may write when creating its own profile. Trust,
  /// payment and counter fields are server-owned (firestore.rules rejects
  /// them on create), so they are deliberately absent.
  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'profilePhoto': profilePhoto,
        'role': role,
        'isPhoneVerified': isPhoneVerified,
        'bio': bio,
        'agencyName': agencyName,
        'savedListings': savedListings,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastSeen': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
      };

  /// Read-only snapshot (tests, caching). Never write this to Firestore.
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
        'premiumPlan': premiumPlan,
        'premiumExpiresAt': premiumExpiresAt != null ? Timestamp.fromDate(premiumExpiresAt!) : null,
        'verificationStatus': verificationStatusToString(verificationStatus),
        'verificationType': verificationType,
        'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
        'verifiedBy': verifiedBy,
        'verificationExpiresAt':
            verificationExpiresAt != null ? Timestamp.fromDate(verificationExpiresAt!) : null,
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
      verificationStatus: verificationStatus,
      verificationType: verificationType,
      verifiedAt: verifiedAt,
      verifiedBy: verifiedBy,
      verificationExpiresAt: verificationExpiresAt,
    );
  }
}


/// Public, server-written mirror of an agent (public_profiles/{uid}).
/// Identity checks live here — never on the private users document.
class PublicProfile {
  final String uid;
  final String name;
  final String? photo;
  final String? agencyName;
  final String? bio;
  final String role;
  final int activeListings;
  final VerificationStatus identity;
  final DateTime? identityCheckedAt;
  final DateTime? identityExpiresAt;
  final DateTime? memberSince;

  const PublicProfile({
    required this.uid,
    required this.name,
    this.photo,
    this.agencyName,
    this.bio,
    this.role = 'agent',
    this.activeListings = 0,
    this.identity = VerificationStatus.none,
    this.identityCheckedAt,
    this.identityExpiresAt,
    this.memberSince,
  });

  bool get identityReviewed =>
      identity == VerificationStatus.approved &&
      !(identityExpiresAt?.isBefore(DateTime.now()) ?? false);

  factory PublicProfile.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    DateTime? t(dynamic v) => v is Timestamp ? v.toDate() : null;
    return PublicProfile(
      uid: doc.id,
      name: d['name'] ?? 'Agent',
      photo: d['photo'] ?? d['profilePhoto'],
      agencyName: d['agencyName'],
      bio: d['bio'],
      role: d['role'] ?? 'agent',
      activeListings: (d['liveListings'] ?? 0).toInt(),
      identity: d['identityChecked'] == true ? VerificationStatus.approved : VerificationStatus.none,
      identityCheckedAt: t(d['identityCheckedAt']),
      identityExpiresAt: t(d['identityExpiresAt']),
      memberSince: t(d['memberSince']),
    );
  }
}
