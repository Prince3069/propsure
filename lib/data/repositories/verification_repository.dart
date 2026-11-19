import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/verification_request_model.dart';
import '../../core/constants/app_constants.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/upload.dart';

/// Replaces VerificationScreen's old `Future.delayed(seconds: 2)` fake
/// submit. Documents go to a PRIVATE Storage path
/// (`verification/{uid}/{requestId}/...`) that storage.rules restricts to
/// the owner (write-once) and reviewers (read-only via custom claim) — no
/// one else, including other tenants, can read or list these files. The
/// Firestore document only ever stores the Storage *path*, never a public
/// download URL; a reviewer's client asks a Cloud Function
/// (`getReviewDocumentUrl`) for a short-lived signed URL when it actually
/// needs to display one.
class VerificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _col => _db.collection('verification_requests');

  /// The applicant's own most recent request, so the UI can show a real
  /// status screen ("pending review", "rejected: <reason>", "approved")
  /// instead of always showing the submission wizard.
  Stream<VerificationRequestModel?> watchLatestForUser(String uid) {
    return _col
        .where('applicantId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : VerificationRequestModel.fromFirestore(snap.docs.first));
  }

  /// Every request the applicant has made (newest first) so each check
  /// (identity, each listing's authority) can show its own status.
  Stream<List<VerificationRequestModel>> watchAllForUser(String uid) {
    return _col
        .where('applicantId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map(VerificationRequestModel.fromFirestore).toList());
  }

  Future<String> _uploadPrivate(
      XFile file, String uid, String requestId, String filename) async {
    final path = 'verification/$uid/$requestId/$filename';
    final ref = _storage.ref(path);
    final lower = filename.toLowerCase();
    final mime = lower.endsWith('.mp4')
        ? 'video/mp4'
        : lower.endsWith('.mov')
            ? 'video/quicktime'
            : lower.endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';
    await (await putPickedFile(ref, file, SettableMetadata(contentType: mime)));
    // Return the STORAGE PATH, not getDownloadURL() — this collection must
    // never contain a public URL. Reviewers fetch a signed URL server-side.
    return path;
  }

  /// Creates the request document as 'submitted' and uploads every
  /// provided document to a private path. Throws on any upload failure so
  /// the UI can show a real error instead of a fake success dialog.
  Future<String> submitVerificationRequest({
    required String uid,
    required String requestType, // 'identity' | 'agent_authority' | 'landlord_ownership' | 'property'
    String? listingId,
    XFile? selfie,
    XFile? idDocument,
    XFile? propertyDocument,
    XFile? video,
  }) async {
    final docRef = _col.doc();
    final requestId = docRef.id;

    String? selfiePath;
    String? idPath;
    String? propPath;
    String? videoPath;

    try {
      if (selfie != null) {
        selfiePath = await _uploadPrivate(selfie, uid, requestId, 'selfie.jpg');
      }
      if (idDocument != null) {
        idPath = await _uploadPrivate(idDocument, uid, requestId, 'id_document.jpg');
      }
      if (propertyDocument != null) {
        propPath = await _uploadPrivate(
            propertyDocument, uid, requestId, 'property_document.jpg');
      }
      if (video != null) {
        videoPath = await _uploadPrivate(video, uid, requestId, 'video_proof.mp4');
      }
    } catch (e) {
      throw Exception(
          'Upload failed before your request could be submitted. Nothing was sent for review — please try again.\n\nDetail: $e');
    }

    final model = VerificationRequestModel(
      id: requestId,
      applicantId: uid,
      requestType: requestType,
      listingId: listingId,
      selfiePath: selfiePath,
      idDocumentPath: idPath,
      propertyDocumentPath: propPath,
      videoPath: videoPath,
      status: VerificationRequestStatus.submitted,
      createdAt: DateTime.now(),
    );

    await docRef.set(model.toClientSubmitMap());

    // The applicant's status is read from this request document (see
    // myVerificationRequestProvider). The private users document is never
    // written for verification: its trust fields are server-owned.

    return requestId;
  }
}
