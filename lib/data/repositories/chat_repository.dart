import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../../core/constants/app_constants.dart';

class ChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  CollectionReference get _chats => _db.collection(AppConstants.colChats);

  // ── Get or create chat ─────────────────────────────────────
  Future<String> getOrCreateChat({
    required String userId,
    required String agentId,
    required String listingId,
    required String userName,
    required String agentName,
    required String listingTitle,
    String? listingThumbnail,
    String? userPhoto,
    String? agentPhoto,
  }) async {
    // Check if chat already exists
    final existing = await _chats
        .where('participantIds', arrayContains: userId)
        .where('listingId', isEqualTo: listingId)
        .limit(1)
        .get();

    for (final doc in existing.docs) {
      final chat = ChatModel.fromFirestore(doc);
      if (chat.participantIds.contains(agentId)) {
        return doc.id;
      }
    }

    // Create new chat
    final chatId = _uuid.v4();
    final now = DateTime.now();

    await _chats.doc(chatId).set({
      'participantIds': [userId, agentId],
      'participantNames': {userId: userName, agentId: agentName},
      'participantPhotos': {userId: userPhoto, agentId: agentPhoto},
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingThumbnail': listingThumbnail,
      'lastMessage': null,
      'unreadCounts': {userId: 0, agentId: 0},
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'isArchived': false,
    });

    return chatId;
  }

  // ── Streams ────────────────────────────────────────────────
  Stream<List<ChatModel>> watchUserChats(String userId) {
    return _chats
        .where('participantIds', arrayContains: userId)
        .where('isArchived', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ChatModel.fromFirestore(d)).toList());
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection(AppConstants.colMessages)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  Stream<int> watchTotalUnreadCount(String userId) {
    return _chats
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final counts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
        total += (counts[userId] ?? 0) as int;
      }
      return total;
    });
  }

  // ── Send messages ──────────────────────────────────────────
  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required String text,
    required List<String> participantIds,
  }) async {
    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderPhoto: senderPhoto,
      type: 'text',
      text: text,
      participantIds: participantIds,
    );
  }

  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required File imageFile,
    required List<String> participantIds,
  }) async {
    final msgId = _uuid.v4();
    final ref = _storage.ref('chats/$chatId/$msgId.jpg');
    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderPhoto: senderPhoto,
      type: 'image',
      imageUrl: imageUrl,
      participantIds: participantIds,
    );
  }

  Future<void> sendBookingCard({
    required String chatId,
    required String senderId,
    required String senderName,
    required Map<String, dynamic> bookingData,
    required List<String> participantIds,
  }) async {
    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      type: 'booking',
      bookingData: bookingData,
      participantIds: participantIds,
    );
  }

  Future<void> _sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required String type,
    String? text,
    String? imageUrl,
    Map<String, dynamic>? bookingData,
    required List<String> participantIds,
  }) async {
    final msgId = _uuid.v4();
    final now = DateTime.now();
    final batch = _db.batch();

    final msgRef = _chats
        .doc(chatId)
        .collection(AppConstants.colMessages)
        .doc(msgId);

    final msgData = {
      'id': msgId,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'type': type,
      'text': text,
      'imageUrl': imageUrl,
      'bookingData': bookingData,
      'createdAt': Timestamp.fromDate(now),
      'isRead': false,
      'readBy': {senderId: true},
      'isDeleted': false,
    };

    batch.set(msgRef, msgData);

    // Update unread counts for other participants
    final unreadUpdates = <String, dynamic>{};
    for (final pid in participantIds) {
      if (pid != senderId) {
        unreadUpdates['unreadCounts.$pid'] = FieldValue.increment(1);
      }
    }

    batch.update(_chats.doc(chatId), {
      'lastMessage': msgData,
      'updatedAt': Timestamp.fromDate(now),
      ...unreadUpdates,
    });

    await batch.commit();
  }

  // ── Read receipts ──────────────────────────────────────────
  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    final batch = _db.batch();

    final unread = await _chats
        .doc(chatId)
        .collection(AppConstants.colMessages)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readBy.$userId': true,
      });
    }

    batch.update(_chats.doc(chatId), {'unreadCounts.$userId': 0});
    await batch.commit();
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _chats
        .doc(chatId)
        .collection(AppConstants.colMessages)
        .doc(messageId)
        .update({'isDeleted': true, 'text': null});
  }

  Future<void> archiveChat(String chatId) async {
    await _chats.doc(chatId).update({'isArchived': true});
  }
}
