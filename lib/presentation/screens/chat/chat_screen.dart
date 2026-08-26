import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/app_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _sendingImage = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(
        () => setState(() => _hasText = _msgCtrl.text.trim().isNotEmpty));
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _markRead() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    ref
        .read(chatRepositoryProvider)
        .markMessagesAsRead(chatId: widget.chatId, userId: userId);
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final userId = ref.read(currentUserIdProvider);
    final user = ref.read(currentUserModelProvider).value;
    if (userId == null || user == null) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    final chat = ref
        .read(userChatsProvider(userId))
        .value
        ?.firstWhere((c) => c.id == widget.chatId, orElse: () => _emptyChat());
    await ref.read(chatRepositoryProvider).sendTextMessage(
          chatId: widget.chatId,
          senderId: userId,
          senderName: user.name,
          senderPhoto: user.profilePhoto,
          text: text,
          participantIds: chat?.participantIds ?? [userId],
        );

    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    final userId = ref.read(currentUserIdProvider);
    final user = ref.read(currentUserModelProvider).value;
    if (userId == null || user == null) return;

    setState(() => _sendingImage = true);
    final imgChat = ref
        .read(userChatsProvider(userId))
        .value
        ?.firstWhere((c) => c.id == widget.chatId, orElse: () => _emptyChat());
    await ref.read(chatRepositoryProvider).sendImageMessage(
          chatId: widget.chatId,
          senderId: userId,
          senderName: user.name,
          senderPhoto: user.profilePhoto,
          imageFile: File(picked.path),
          participantIds: imgChat?.participantIds ?? [userId],
        );
    setState(() => _sendingImage = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final chatAsync = ref.watch(userChatsProvider(userId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    // Get the chat object to show listing context bar
    final chat = chatAsync.value
        ?.firstWhere((c) => c.id == widget.chatId, orElse: () => _emptyChat());

    final otherId = chat?.participantIds
            .firstWhere((id) => id != userId, orElse: () => '') ??
        '';
    final otherName = chat?.participantNames[otherId] ?? 'Agent';
    final otherPhoto = chat?.participantPhotos[otherId];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _ChatAppBar(
        name: otherName, photo: otherPhoto, chatId: widget.chatId,
        agentPhone: '', // fetched from listing if needed
      ),
      body: Column(children: [
        // Listing context bar
        if (chat?.listingTitle != null)
          _ListingContextBar(
            title: chat!.listingTitle!,
            thumbnail: chat.listingThumbnail,
            listingId: chat.listingId ?? '',
          ),
        // Messages
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const _EmptyChatPlaceholder();
              }
              return ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == userId;
                  final showDate = i == messages.length - 1 ||
                      !_sameDay(
                          messages[i].createdAt, messages[i + 1].createdAt);
                  final showAvatar = !isMe &&
                      (i == 0 || messages[i - 1].senderId != msg.senderId);

                  return Column(children: [
                    if (showDate) _DateDivider(date: msg.createdAt),
                    _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      showAvatar: showAvatar,
                      senderPhoto: isMe ? null : otherPhoto,
                      senderInitial: otherName.isNotEmpty ? otherName[0] : '?',
                    ),
                  ]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
        // Input bar
        _ChatInputBar(
          controller: _msgCtrl,
          hasText: _hasText,
          sending: _sending,
          sendingImage: _sendingImage,
          onSend: _send,
          onImagePick: _sendImage,
        ),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  ChatModel _emptyChat() => ChatModel(
        id: '',
        participantIds: [],
        participantNames: {},
        participantPhotos: {},
        unreadCounts: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        listingId: '',
        isArchived: false,
      );
}

// ─── APP BAR ─────────────────────────────────────────────────────────────
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String name, chatId, agentPhone;
  final String? photo;
  const _ChatAppBar(
      {required this.name,
      this.photo,
      required this.chatId,
      required this.agentPhone});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryPale2,
          backgroundImage:
              photo != null && photo!.isNotEmpty ? NetworkImage(photo!) : null,
          child: photo == null || photo!.isEmpty
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const Text('● Online',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500)),
        ])),
      ]),
      actions: [
        if (agentPhone.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () async {
              final uri = Uri(scheme: 'tel', path: agentPhone);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {},
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: Text('Report')),
            PopupMenuItem(value: 'block', child: Text('Block')),
          ],
        ),
      ],
    );
  }
}

// ─── LISTING CONTEXT BAR ─────────────────────────────────────────────────
class _ListingContextBar extends StatelessWidget {
  final String title, listingId;
  final String? thumbnail;
  const _ListingContextBar(
      {required this.title, this.thumbnail, required this.listingId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: const BoxDecoration(
        color: AppColors.primaryPale,
        border: Border(
            top: BorderSide(color: AppColors.primaryPale2),
            bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 38,
            height: 38,
            child: thumbnail != null && thumbnail!.isNotEmpty
                ? CachedNetworkImage(imageUrl: thumbnail!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.primaryPale2,
                    child: const Icon(Icons.home_outlined,
                        size: 20, color: AppColors.primary)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const Text('Property enquiry',
              style: TextStyle(fontSize: 10, color: AppColors.primary)),
        ])),
        GestureDetector(
          onTap: () => context.push('/listing/$listingId'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8)),
            child: const Text('View',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─── MESSAGE BUBBLE ──────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe, showAvatar;
  final String? senderPhoto;
  final String senderInitial;
  const _MessageBubble(
      {required this.message,
      required this.isMe,
      required this.showAvatar,
      this.senderPhoto,
      required this.senderInitial});

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('🚫 Message deleted',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.text3,
                    fontStyle: FontStyle.italic)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryPale2,
                backgroundImage: senderPhoto != null && senderPhoto!.isNotEmpty
                    ? NetworkImage(senderPhoto!)
                    : null,
                child: senderPhoto == null || senderPhoto!.isEmpty
                    ? Text(senderInitial,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800))
                    : null,
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showOptions(context),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.type == 'image')
                    _ImageBubble(imageUrl: message.imageUrl ?? '', isMe: isMe)
                  else
                    _TextBubble(text: message.text ?? '', isMe: isMe),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmtTime(message.createdAt),
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.text3),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.done_all_rounded,
                            size: 12,
                            color: message.isRead
                                ? AppColors.info
                                : AppColors.text3),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text ?? ''));
                Navigator.pop(context);
              }),
          if (message.senderId == message.senderId)
            ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                title: const Text('Delete',
                    style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TextBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  const _TextBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        border: isMe ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              color: isMe ? Colors.white : AppColors.text,
              height: 1.45)),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final String imageUrl;
  final bool isMe;
  const _ImageBubble({required this.imageUrl, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onTap: () => _showFullImage(context),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 200,
          height: 160,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
              width: 200,
              height: 160,
              color: AppColors.bg,
              child: const Center(child: CircularProgressIndicator())),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
            child: InteractiveViewer(
                child: CachedNetworkImage(
                    imageUrl: imageUrl, fit: BoxFit.contain))),
      ),
      fullscreenDialog: true,
    ));
  }
}

// ─── DATE DIVIDER ────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final label = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : '${date.day} ${months[date.month - 1]} ${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3)),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

// ─── EMPTY PLACEHOLDER ───────────────────────────────────────────────────
class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
              color: AppColors.primaryPale, shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 36, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text('Start the conversation',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Say hello and ask about the property',
            style: TextStyle(fontSize: 13, color: AppColors.text3)),
      ]),
    );
  }
}

// ─── CHAT INPUT BAR ──────────────────────────────────────────────────────
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText, sending, sendingImage;
  final VoidCallback onSend, onImagePick;
  const _ChatInputBar(
      {required this.controller,
      required this.hasText,
      required this.sending,
      required this.sendingImage,
      required this.onSend,
      required this.onImagePick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          10, 8, 10, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Attach image
        GestureDetector(
          onTap: sendingImage ? null : onImagePick,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
            child: sendingImage
                ? const Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : const Icon(Icons.attach_file_rounded,
                    size: 18, color: AppColors.text2),
          ),
        ),
        const SizedBox(width: 8),
        // Text input
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 110),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border2),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Type a message…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: (sending || !hasText) ? null : onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasText ? AppColors.primary : AppColors.bg,
              shape: BoxShape.circle,
              border: Border.all(
                  color: hasText ? AppColors.primary : AppColors.border),
            ),
            child: sending
                ? const Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)))
                : Icon(Icons.send_rounded,
                    size: 17, color: hasText ? Colors.white : AppColors.text3),
          ),
        ),
      ]),
    );
  }
}
