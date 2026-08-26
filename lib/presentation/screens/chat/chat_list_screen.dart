import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../../data/models/chat_model.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return const _GuestView();
    }

    final chatsAsync = ref.watch(userChatsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: AppColors.text2,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryPale2),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Keep conversations inside Propsure for a safer move.',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                if (chats.isEmpty) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    subtitle:
                        'When you contact an agent about a property, your conversations will appear here.',
                    action: TextButton(
                      onPressed: () => context.push('/search'),
                      child: const Text('Browse Properties'),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    return _ChatTile(
                      chat: chats[index],
                      userId: userId,
                    );
                  },
                );
              },
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, __) => const _ChatTileSkeleton(),
              ),
              error: (error, _) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Your messages',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 7),
              const Text(
                'Sign in to chat with agents and landlords about properties.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text2,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => context.push('/auth?redirect=/messages'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String userId;

  const _ChatTile({
    required this.chat,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final otherId = chat.participantIds.firstWhere(
      (id) => id != userId,
      orElse: () => userId,
    );
    final otherName = chat.participantNames[otherId] ?? 'Agent';
    final otherPhoto = chat.participantPhotos[otherId];
    final unread = chat.unreadCounts[userId] ?? 0;
    final lastMessage = chat.lastMessage;
    final isMe = lastMessage?.senderId == userId;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/chat/${chat.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.primaryPale2,
                    backgroundImage: otherPhoto != null && otherPhoto.isNotEmpty
                        ? NetworkImage(otherPhoto)
                        : null,
                    child: otherPhoto == null || otherPhoto.isEmpty
                        ? Text(
                            otherName.isNotEmpty
                                ? otherName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: TextStyle(
                              fontWeight: unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (lastMessage != null)
                          Text(
                            timeago.format(lastMessage.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: unread > 0
                                  ? AppColors.primary
                                  : AppColors.text3,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    if (chat.listingTitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        chat.listingTitle!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMe)
                          const Text(
                            'You: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.text3,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            lastMessage?.isDeleted == true
                                ? 'Message deleted'
                                : (lastMessage?.text ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  unread > 0 ? AppColors.text : AppColors.text3,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontStyle: lastMessage?.isDeleted == true
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.text3,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTileSkeleton extends StatelessWidget {
  const _ChatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.bg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 130,
                  color: AppColors.bg,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: double.infinity,
                  color: AppColors.bg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
