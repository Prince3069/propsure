import 'package:cloud_firestore/cloud_firestore.dart';

class ShortlistModel {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final List<String> listingIds;
  // notes[listingId][uid] = text. Notes are private to members (rules).
  final Map<String, Map<String, String>> notes;
  const ShortlistModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    this.memberNames = const {},
    this.listingIds = const [],
    this.notes = const {},
  });

  factory ShortlistModel.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    final rawNotes = (d['notes'] as Map?) ?? const {};
    return ShortlistModel(
      id: doc.id,
      name: d['name'] ?? 'Our shortlist',
      ownerId: d['ownerId'] ?? '',
      memberIds: List<String>.from(d['memberIds'] ?? const []),
      memberNames: ((d['memberNames'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
      listingIds: List<String>.from(d['listingIds'] ?? const []),
      notes: rawNotes.map((k, v) => MapEntry('$k', ((v as Map?) ?? const {}).map((a, b) => MapEntry('$a', '$b')))),
    );
  }
}

class ShortlistRepository {
  final _col = FirebaseFirestore.instance.collection('shortlists');

  Stream<List<ShortlistModel>> watchMine(String uid) => _col
      .where('memberIds', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(ShortlistModel.fromFirestore).toList());

  Stream<ShortlistModel?> watch(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? ShortlistModel.fromFirestore(d) : null);

  Future<String> create({required String uid, required String ownerName, String name = 'Our shortlist', List<String> listingIds = const []}) async {
    final ref = _col.doc();
    await ref.set({
      'name': name,
      'ownerId': uid,
      'memberIds': [uid],
      'memberNames': {uid: ownerName},
      'listingIds': listingIds,
      'notes': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> addListing(String id, String listingId) =>
      _col.doc(id).update({'listingIds': FieldValue.arrayUnion([listingId]), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> removeListing(String id, String listingId) =>
      _col.doc(id).update({'listingIds': FieldValue.arrayRemove([listingId]), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> setNote(String id, String listingId, String uid, String text) => _col.doc(id).update({
        'notes.$listingId.$uid': text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
