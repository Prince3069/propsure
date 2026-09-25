import 'package:cloud_firestore/cloud_firestore.dart';

/// The booking model only ever captured a date/time viewing request. The
/// review is explicit that "not every property interaction is a viewing"
/// — a general question, a call-back request, or a budget/timing check
/// all need somewhere to live that isn't forced into a fake booking slot.
/// This also happens to be exactly the kind of structured signal a lead
/// -generation product (LeadRadar) needs: enquiry type, budget, timing,
/// and whether/how fast the agent actually responded.
enum EnquiryType { general, viewingRequest, callRequest, applicationRequest }

String enquiryTypeToString(EnquiryType t) => t.name;
EnquiryType enquiryTypeFromString(String? s) {
  switch (s) {
    case 'viewingRequest':
      return EnquiryType.viewingRequest;
    case 'callRequest':
      return EnquiryType.callRequest;
    case 'applicationRequest':
      return EnquiryType.applicationRequest;
    default:
      return EnquiryType.general;
  }
}

enum EnquiryResponseState { awaitingResponse, responded, closed }

String _responseStateToString(EnquiryResponseState s) => s.name;
EnquiryResponseState _responseStateFromString(String? s) {
  switch (s) {
    case 'responded':
      return EnquiryResponseState.responded;
    case 'closed':
      return EnquiryResponseState.closed;
    default:
      return EnquiryResponseState.awaitingResponse;
  }
}

class EnquiryModel {
  final String id;
  final String listingId;
  final String listingTitle;
  final String enquirerId;
  final String enquirerName;
  final String enquirerPhone;
  final String agentId;
  final EnquiryType type;
  final String? budgetRange;
  final String? preferredTiming;
  final String preferredContactChannel; // 'chat' | 'call' | 'whatsapp'
  final String? message;
  final EnquiryResponseState responseState;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const EnquiryModel({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.enquirerId,
    required this.enquirerName,
    required this.enquirerPhone,
    required this.agentId,
    required this.type,
    this.budgetRange,
    this.preferredTiming,
    this.preferredContactChannel = 'chat',
    this.message,
    this.responseState = EnquiryResponseState.awaitingResponse,
    required this.createdAt,
    this.respondedAt,
  });

  /// Minutes between the enquiry landing and the agent responding — the
  /// literal "response time" signal the review (and LeadRadar) wants.
  /// Null until responded.
  int? get responseMinutes =>
      respondedAt == null ? null : respondedAt!.difference(createdAt).inMinutes;

  factory EnquiryModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EnquiryModel(
      id: doc.id,
      listingId: d['listingId'] ?? '',
      listingTitle: d['listingTitle'] ?? '',
      enquirerId: d['enquirerId'] ?? '',
      enquirerName: d['enquirerName'] ?? '',
      enquirerPhone: d['enquirerPhone'] ?? '',
      agentId: d['agentId'] ?? '',
      type: enquiryTypeFromString(d['type'] as String?),
      budgetRange: d['budgetRange'],
      preferredTiming: d['preferredTiming'],
      preferredContactChannel: d['preferredContactChannel'] ?? 'chat',
      message: d['message'],
      responseState: _responseStateFromString(d['responseState'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'listingId': listingId,
        'listingTitle': listingTitle,
        'enquirerId': enquirerId,
        'enquirerName': enquirerName,
        'enquirerPhone': enquirerPhone,
        'agentId': agentId,
        'type': enquiryTypeToString(type),
        'budgetRange': budgetRange,
        'preferredTiming': preferredTiming,
        'preferredContactChannel': preferredContactChannel,
        'message': message,
        'responseState': _responseStateToString(responseState),
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      };
}

class EnquiryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('enquiries');

  Future<String> submitEnquiry(EnquiryModel enquiry) async {
    final ref = await _col.add(enquiry.toMap());
    return ref.id;
  }

  Stream<List<EnquiryModel>> watchAgentEnquiries(String agentId) {
    return _col
        .where('agentId', isEqualTo: agentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => EnquiryModel.fromFirestore(d)).toList());
  }

  /// The agent's response-rate signal: fraction of their enquiries marked
  /// responded within the lookback window. Computed client-side from the
  /// same stream rather than a separate aggregate — fine at this scale;
  /// worth moving server-side once volume grows (Phase 4 territory,
  /// alongside the cursor-pagination work already deferred there).
  Future<void> markResponded(String enquiryId) async {
    await _col.doc(enquiryId).update({
      'responseState': 'responded',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closeEnquiry(String enquiryId) async {
    await _col.doc(enquiryId).update({'responseState': 'closed'});
  }
}
