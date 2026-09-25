import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String? listingId;
  final String? listingTitle;
  final String? listingThumbnail;
  final ChatMessage? lastMessage;
  final Map<String, int> unreadCounts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  // Any participant can block the conversation for themselves — this is
  // the "block" half of the review's "report, block, and moderation
  // flows" item. Blocking is self-directed: if my uid is in blockedBy, I
  // won't be shown the input bar and can't send further messages; it
  // doesn't hide me from the other participant (a true mutual/hidden
  // block would need a Cloud Function to filter chat lists, which is a
  // reasonable Phase 3 addition once there's real abuse data to act on).
  final List<String> blockedBy;
  // Muting is purely a client-side notification preference — no security
  // implication, so it's fine for the client to set this directly.
  final List<String> mutedBy;

  const ChatModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantPhotos,
    this.listingId,
    this.listingTitle,
    this.listingThumbnail,
    this.lastMessage,
    required this.unreadCounts,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.blockedBy = const [],
    this.mutedBy = const [],
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames:
          Map<String, String>.from(data['participantNames'] ?? {}),
      participantPhotos:
          Map<String, String?>.from(data['participantPhotos'] ?? {}),
      listingId: data['listingId'],
      listingTitle: data['listingTitle'],
      listingThumbnail: data['listingThumbnail'],
      lastMessage: data['lastMessage'] != null
          ? ChatMessage.fromMap(data['lastMessage'])
          : null,
      unreadCounts: Map<String, int>.from((data['unreadCounts'] ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt()))),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isArchived: data['isArchived'] ?? false,
      blockedBy: List<String>.from(data['blockedBy'] ?? []),
      mutedBy: List<String>.from(data['mutedBy'] ?? []),
    );
  }

  bool isBlockedBy(String uid) => blockedBy.contains(uid);
  bool isMutedBy(String uid) => mutedBy.contains(uid);

  String otherParticipantId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => '');

  String otherParticipantName(String myId) {
    final otherId = otherParticipantId(myId);
    return participantNames[otherId] ?? 'Unknown';
  }

  String? otherParticipantPhoto(String myId) {
    final otherId = otherParticipantId(myId);
    return participantPhotos[otherId];
  }

  int unreadCount(String myId) => unreadCounts[myId] ?? 0;
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String type; // text, image, system, booking
  final String? text;
  final String? imageUrl;
  final Map<String, dynamic>? bookingData;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, bool> readBy;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.type,
    this.text,
    this.imageUrl,
    this.bookingData,
    required this.createdAt,
    this.isRead = false,
    this.readBy = const {},
    this.isDeleted = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhoto: map['senderPhoto'],
      type: map['type'] ?? 'text',
      text: map['text'],
      imageUrl: map['imageUrl'],
      bookingData: map['bookingData'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      readBy: Map<String, bool>.from(map['readBy'] ?? {}),
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage.fromMap({...data, 'id': doc.id});
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'type': type,
        'text': text,
        'imageUrl': imageUrl,
        'bookingData': bookingData,
        'createdAt': Timestamp.fromDate(createdAt),
        'isRead': isRead,
        'readBy': readBy,
        'isDeleted': isDeleted,
      };
}
