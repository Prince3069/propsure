import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class BookingModel {
  final String id;
  final String listingId;
  final String listingTitle;
  final String? listingThumbnail;
  final String userId;
  final String userName;
  final String userPhone;
  final String? userPhoto;
  final String agentId;
  final String agentName;
  final String agentPhone;
  final String? agentPhoto;
  final DateTime dateTime;
  final String status;
  final String? message;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRated;

  const BookingModel({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    this.listingThumbnail,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.userPhoto,
    required this.agentId,
    required this.agentName,
    required this.agentPhone,
    this.agentPhoto,
    required this.dateTime,
    required this.status,
    this.message,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.isRated = false,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      listingId: d['listingId'] ?? '',
      listingTitle: d['listingTitle'] ?? '',
      listingThumbnail: d['listingThumbnail'],
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userPhone: d['userPhone'] ?? '',
      userPhoto: d['userPhoto'],
      agentId: d['agentId'] ?? '',
      agentName: d['agentName'] ?? '',
      agentPhone: d['agentPhone'] ?? '',
      agentPhoto: d['agentPhoto'],
      dateTime: (d['dateTime'] as Timestamp).toDate(),
      status: d['status'] ?? AppConstants.bookingPending,
      message: d['message'],
      rejectionReason: d['rejectionReason'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: (d['updatedAt'] as Timestamp).toDate(),
      isRated: d['isRated'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'listingId': listingId,
        'listingTitle': listingTitle,
        'listingThumbnail': listingThumbnail,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'userPhoto': userPhoto,
        'agentId': agentId,
        'agentName': agentName,
        'agentPhone': agentPhone,
        'agentPhoto': agentPhoto,
        'dateTime': Timestamp.fromDate(dateTime),
        'status': status,
        'message': message,
        'rejectionReason': rejectionReason,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'isRated': isRated,
      };

  BookingModel copyWith({String? status, String? rejectionReason}) =>
      BookingModel(
        id: id,
        listingId: listingId,
        listingTitle: listingTitle,
        listingThumbnail: listingThumbnail,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        userPhoto: userPhoto,
        agentId: agentId,
        agentName: agentName,
        agentPhone: agentPhone,
        agentPhoto: agentPhoto,
        dateTime: dateTime,
        status: status ?? this.status,
        message: message,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        isRated: isRated,
      );
}

class BookingRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection(AppConstants.colBookings);

  Future<String> createBooking({
    required String listingId,
    required String agentId,
    required String userId,
    required String userName,
    required String userPhone,
    required String listingTitle,
    required DateTime dateTime,
    String? message,
    String? listingThumbnail,
    String? agentName,
    String? agentPhone,
  }) async {
    final now = DateTime.now();
    final ref = _col.doc();
    await ref.set({
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingThumbnail': listingThumbnail ?? '',
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'agentId': agentId,
      'agentName': agentName ?? '',
      'agentPhone': agentPhone ?? '',
      'dateTime': Timestamp.fromDate(dateTime),
      'status': AppConstants.bookingPending,
      'message': message ?? '',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'isRated': false,
    });
    return ref.id;
  }

  Stream<List<BookingModel>> watchUserBookings(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromFirestore(d)).toList());
  }

  Stream<List<BookingModel>> watchAgentBookings(String agentId) {
    return _col
        .where('agentId', isEqualTo: agentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromFirestore(d)).toList());
  }

  Stream<int> watchAgentPendingCount(String agentId) {
    return _col
        .where('agentId', isEqualTo: agentId)
        .where('status', isEqualTo: AppConstants.bookingPending)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<BookingModel?> getBookingById(String bookingId) async {
    final doc = await _col.doc(bookingId).get();
    if (!doc.exists) return null;
    return BookingModel.fromFirestore(doc);
  }

  Future<void> confirmBooking(String bookingId) async {
    await _col.doc(bookingId).update({
      'status': AppConstants.bookingConfirmed,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> rejectBooking(String bookingId, {String? reason}) async {
    await _col.doc(bookingId).update({
      'status': AppConstants.bookingRejected,
      'rejectionReason': reason ?? '',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> cancelBooking(String bookingId) async {
    await _col.doc(bookingId).update({
      'status': AppConstants.bookingCancelled,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> completeBooking(String bookingId) async {
    await _col.doc(bookingId).update({
      'status': AppConstants.bookingCompleted,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
