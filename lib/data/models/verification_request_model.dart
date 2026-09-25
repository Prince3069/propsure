import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the `verification_requests` collection. This collection is what
/// replaces the old VerificationScreen behaviour of waiting 2 seconds and
/// showing a fake success dialog — every field here is required by the
/// review's "Implement the verification workflow for real" section.
///
/// Lifecycle: draft -> submitted -> under_review -> approved | rejected | needs_changes
/// (expired is set by a scheduled Cloud Function once verificationExpiresAt passes)
enum VerificationRequestStatus {
  draft,
  submitted,
  underReview,
  approved,
  rejected,
  needsChanges,
  expired,
}

VerificationRequestStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'submitted':
      return VerificationRequestStatus.submitted;
    case 'under_review':
      return VerificationRequestStatus.underReview;
    case 'approved':
      return VerificationRequestStatus.approved;
    case 'rejected':
      return VerificationRequestStatus.rejected;
    case 'needs_changes':
      return VerificationRequestStatus.needsChanges;
    case 'expired':
      return VerificationRequestStatus.expired;
    default:
      return VerificationRequestStatus.draft;
  }
}

String _statusToString(VerificationRequestStatus s) {
  switch (s) {
    case VerificationRequestStatus.draft:
      return 'draft';
    case VerificationRequestStatus.submitted:
      return 'submitted';
    case VerificationRequestStatus.underReview:
      return 'under_review';
    case VerificationRequestStatus.approved:
      return 'approved';
    case VerificationRequestStatus.rejected:
      return 'rejected';
    case VerificationRequestStatus.needsChanges:
      return 'needs_changes';
    case VerificationRequestStatus.expired:
      return 'expired';
  }
}

/// 'identity' | 'agent_authority' | 'landlord_ownership' | 'property'
class VerificationRequestModel {
  final String id;
  final String applicantId;
  final String requestType;
  final String? listingId; // set only for requestType == 'property'

  // Private Storage paths (NOT public download URLs). A Cloud Function
  // issues short-lived signed URLs to reviewers only — see
  // functions/index.js `getReviewDocumentUrl`. Tenants and other users
  // never get a URL to these paths; firestore.rules and storage.rules both
  // block direct client reads.
  final String? selfiePath;
  final String? idDocumentPath;
  final String? propertyDocumentPath;
  final String? videoPath;

  final VerificationRequestStatus status;
  final String? reviewerId;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Append-only audit trail: [{by, action, at, note}]. Written only by
  /// the Cloud Functions that move this request through its lifecycle.
  final List<Map<String, dynamic>> auditHistory;

  const VerificationRequestModel({
    required this.id,
    required this.applicantId,
    required this.requestType,
    this.listingId,
    this.selfiePath,
    this.idDocumentPath,
    this.propertyDocumentPath,
    this.videoPath,
    this.status = VerificationRequestStatus.draft,
    this.reviewerId,
    this.reviewedAt,
    this.rejectionReason,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
    this.auditHistory = const [],
  });

  bool get isPending =>
      status == VerificationRequestStatus.submitted ||
      status == VerificationRequestStatus.underReview;
  bool get isApproved => status == VerificationRequestStatus.approved;
  bool get isRejected =>
      status == VerificationRequestStatus.rejected ||
      status == VerificationRequestStatus.needsChanges;

  factory VerificationRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VerificationRequestModel(
      id: doc.id,
      applicantId: data['applicantId'] ?? '',
      requestType: data['requestType'] ?? 'identity',
      listingId: data['listingId'],
      selfiePath: data['selfiePath'],
      idDocumentPath: data['idDocumentPath'],
      propertyDocumentPath: data['propertyDocumentPath'],
      videoPath: data['videoPath'],
      status: _statusFromString(data['status'] as String?),
      reviewerId: data['reviewerId'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      auditHistory: (data['auditHistory'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  /// Fields the CLIENT is allowed to write when creating/submitting a
  /// request. status/reviewerId/reviewedAt/rejectionReason/expiresAt/
  /// auditHistory are set only by Cloud Functions — enforced in
  /// firestore.rules, which reject a client create/update containing them
  /// unless they're exactly the allowed initial values (draft/submitted).
  Map<String, dynamic> toClientSubmitMap() => {
        'applicantId': applicantId,
        'requestType': requestType,
        if (listingId != null) 'listingId': listingId,
        if (selfiePath != null) 'selfiePath': selfiePath,
        if (idDocumentPath != null) 'idDocumentPath': idDocumentPath,
        if (propertyDocumentPath != null)
          'propertyDocumentPath': propertyDocumentPath,
        if (videoPath != null) 'videoPath': videoPath,
        'status': _statusToString(status),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
