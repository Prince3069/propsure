import 'package:cloud_firestore/cloud_firestore.dart';

/// Backs the `reports` collection — the "report, block, and moderation
/// flows" the review flagged as missing entirely. This is the reporting
/// half; a moderation QUEUE UI for admins to act on these is a proper
/// admin-tool project of its own (the review explicitly recommends a
/// separate admin app/internal tool rather than raw Firestore console
/// editing) and is out of scope here — but the data model and the ability
/// for users to actually file a report is not, and that's what this adds.
class ReportModel {
  final String id;
  final String reporterId;
  final String targetType; // 'listing' | 'agent' | 'chat' | 'message'
  final String targetId;
  final String reason;
  final String? note;
  final String status; // 'open' | 'reviewing' | 'resolved' | 'dismissed'
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.note,
    this.status = 'open',
    this.resolutionNote,
    required this.createdAt,
    this.resolvedAt,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      reporterId: d['reporterId'] ?? '',
      targetType: d['targetType'] ?? '',
      targetId: d['targetId'] ?? '',
      reason: d['reason'] ?? '',
      note: d['note'],
      status: d['status'] ?? 'open',
      resolutionNote: d['resolutionNote'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ReportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('reports');

  Future<String> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
  }) async {
    final ref = await _col.add({
      'reporterId': reporterId,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'note': note,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// A reporter can check the status of reports they've personally filed
  /// (mostly useful for a future "my reports" screen) — admins would use
  /// a separate, privileged query in the moderation-tool project.
  Stream<List<ReportModel>> watchMyReports(String reporterId) {
    return _col
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ReportModel.fromFirestore(d)).toList());
  }
}
