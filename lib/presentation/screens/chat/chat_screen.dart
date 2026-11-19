import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/booking_labels.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Conversation. The property stays pinned with price and a way back; a
/// structured inspection request lives here, and the safety reminder is always
/// visible. Attachments are images only and private to the two participants.
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});
  @override
  ConsumerState<ChatScreen> createState() => _State();
}

class _State extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _draftApplied = false;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatModel? _chat(String uid) {
    final chats = ref.read(userChatsProvider(uid)).asData?.value ?? const [];
    for (final c in chats) {
      if (c.id == widget.chatId) return c;
    }
    return null;
  }

  Future<void> _send(ChatModel chat, String uid, String name, String? photo) async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await runAction(context, () => ref.read(chatRepositoryProvider).sendTextMessage(
          chatId: chat.id, senderId: uid, senderName: name, senderPhoto: photo, text: t, participantIds: chat.participantIds));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _text.clear();
  }

  Future<void> _attach(ChatModel chat, String uid, String name, String? photo) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (x == null || !mounted) return;
    await runAction(context, () => ref.read(chatRepositoryProvider).sendImageMessage(
          chatId: chat.id, senderId: uid, senderName: name, senderPhoto: photo, imageFile: x, participantIds: chat.participantIds));
  }

  Future<void> _requestInspection(ChatModel chat, String uid) async {
    final user = ref.read(currentUserModelProvider).asData?.value;
    if (user == null || chat.listingId == null) return;
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 60)), helpText: 'Choose a day to visit');
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 11, minute: 0), helpText: 'Choose a time');
    if (t == null || !mounted) return;
    final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final agentId = chat.otherParticipantId(uid);
    await runAction(context, () async {
      final id = await ref.read(bookingRepositoryProvider).createBooking(
            listingId: chat.listingId!,
            agentId: agentId,
            userId: uid,
            userName: user.displayName,
            userPhone: user.phone,
            listingTitle: chat.listingTitle ?? 'Home',
            dateTime: when,
            listingThumbnail: chat.listingThumbnail,
            agentName: chat.otherParticipantName(uid),
          );
      await ref.read(chatRepositoryProvider).sendBookingCard(
            chatId: chat.id, senderId: uid, senderName: user.displayName,
            bookingData: {'bookingId': id, 'dateTime': when.toIso8601String(), 'status': 'pending'},
            participantIds: chat.participantIds);
    }, success: 'Inspection requested. It is not confirmed until the agent accepts.');
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final user = ref.watch(currentUserModelProvider).asData?.value;
    if (uid == null) return const Scaffold(body: PsEmpty(icon: Icons.lock_outline_rounded, title: 'Sign in to continue', message: 'Conversations are private to the people in them.'));
    ref.watch(userChatsProvider(uid));
    final chat = _chat(uid);
    final msgs = ref.watch(chatMessagesProvider(widget.chatId));
    if (chat == null) {
      return Scaffold(appBar: const PsTopBar(), body: ref.watch(userChatsProvider(uid)).isLoading ? const Center(child: CircularProgressIndicator()) : const PsEmpty(icon: Icons.chat_bubble_outline_rounded, title: 'Conversation not found', message: 'It may have been archived.'));
    }
    if (!_draftApplied) {
      _draftApplied = true;
      final d = GoRouterState.of(context).uri.queryParameters['draft'];
      if (d != null && d.isNotEmpty) _text.text = d;
    }
    final otherId = chat.otherParticipantId(uid);
    final other = ref.watch(publicProfileProvider(otherId)).asData?.value;
    final blocked = chat.blockedBy.isNotEmpty;
    ref.read(chatRepositoryProvider).markMessagesAsRead(chatId: chat.id, userId: uid).catchError((_) {});

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(children: [
              PsIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/messages')),
              PsAvatar(url: chat.otherParticipantPhoto(uid), name: chat.otherParticipantName(uid), size: 44),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chat.otherParticipantName(uid), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title),
                if (other?.identityReviewed ?? false) Row(children: [const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary), const SizedBox(width: 4), Text('Agent ID checked', style: AppText.caption)]),
              ])),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) async {
                  final repo = ref.read(chatRepositoryProvider);
                  if (v == 'report' && chat.listingId != null) context.push('/listing/${chat.listingId}/report');
                  if (v == 'block') await runAction(context, () => chat.isBlockedBy(uid) ? repo.unblockChat(chat.id, uid) : repo.blockChat(chat.id, uid));
                  if (v == 'mute') await runAction(context, () => chat.isMutedBy(uid) ? repo.unmuteChat(chat.id, uid) : repo.muteChat(chat.id, uid));
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'report', child: Text('Report this listing')),
                  PopupMenuItem(value: 'mute', child: Text(chat.isMutedBy(uid) ? 'Unmute' : 'Mute')),
                  PopupMenuItem(value: 'block', child: Text(chat.isBlockedBy(uid) ? 'Unblock' : 'Block')),
                ],
              ),
            ]),
          ),
          if (chat.listingId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ref.watch(listingByIdProvider(chat.listingId!)).maybeWhen(
                    data: (l) => PsCard(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        SizedBox(width: 72, height: 56, child: PsNetImage(l?.coverUrl ?? chat.listingThumbnail, radius: BorderRadius.circular(10))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(chat.listingTitle ?? l?.title ?? 'Home', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label),
                          if (l != null) Text(l.priceLabel, style: AppText.title.copyWith(color: AppColors.primary)),
                        ])),
                        PsButton('View', expand: false, kind: PsButtonKind.ghost, onPressed: () => context.push('/listing/${chat.listingId}')),
                      ]),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
            ),
          Expanded(
            child: msgs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(chatMessagesProvider(widget.chatId))),
              data: (list) {
                if (list.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Ask about availability, the full move-in cost or a viewing time.', textAlign: TextAlign.center, style: AppText.bodyMuted)));
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _Bubble(m: list[list.length - 1 - i], mine: list[list.length - 1 - i].senderId == uid, listingId: chat.listingId),
                );
              },
            ),
          ),
          if (chat.listingId != null && !blocked)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: PsButton('Request inspection', kind: PsButtonKind.outline, icon: Icons.event_outlined, trailingIcon: Icons.chevron_right_rounded, onPressed: () => _requestInspection(chat, uid))),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(children: [const Icon(Icons.shield_outlined, size: 18, color: AppColors.text2), const SizedBox(width: 8), Expanded(child: Text('Do not pay rent before independent checks.', style: AppText.caption))]),
          ),
          if (blocked)
            Padding(padding: const EdgeInsets.all(16), child: Text(chat.isBlockedBy(uid) ? 'You blocked this conversation. Unblock it from the menu to reply.' : 'You can no longer reply here.', style: AppText.small))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Ask about this home…',
                      suffixIcon: PsIconButton(icon: Icons.attach_file_rounded, tooltip: 'Attach a photo', onPressed: () => _attach(chat, uid, user?.displayName ?? 'Me', user?.profilePhoto)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _send(chat, uid, user?.displayName ?? 'Me', user?.profilePhoto),
                    child: SizedBox(width: 56, height: 56, child: Semantics(button: true, label: 'Send', child: _sending ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white))),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool mine;
  final String? listingId;
  const _Bubble({required this.m, required this.mine, this.listingId});

  @override
  Widget build(BuildContext context) {
    final time = '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
    Widget body;
    if (m.isDeleted) {
      body = Text('Message deleted', style: AppText.small.copyWith(fontStyle: FontStyle.italic, color: mine ? Colors.white70 : AppColors.text3));
    } else if (m.type == 'image' && m.imageUrl != null) {
      body = ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 220, height: 160, child: PsNetImage(m.imageUrl, semanticLabel: 'Photo sent in chat')));
    } else if (m.type == 'booking') {
      final when = DateTime.tryParse('${m.bookingData?['dateTime']}');
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.event_outlined, size: 20, color: mine ? Colors.white : AppColors.primary), const SizedBox(width: 8), Text('Inspection requested', style: AppText.label.copyWith(color: mine ? Colors.white : AppColors.text))]),
        if (when != null) Text(formatVisit(when), style: AppText.small.copyWith(color: mine ? Colors.white70 : AppColors.text2)),
        Text('Not confirmed until the agent accepts.', style: AppText.caption.copyWith(color: mine ? Colors.white70 : AppColors.text3)),
      ]);
    } else {
      body = Text(m.text ?? '', style: AppText.body.copyWith(color: mine ? Colors.white : AppColors.text));
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.card,
          border: mine ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Align(alignment: Alignment.centerLeft, child: body),
          const SizedBox(height: 2),
          Text(time, style: AppText.caption.copyWith(fontSize: 11.5, color: mine ? Colors.white70 : AppColors.text3)),
        ]),
      ),
    );
  }
}
