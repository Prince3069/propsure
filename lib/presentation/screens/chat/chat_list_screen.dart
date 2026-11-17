import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/booking_labels.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../providers/app_providers.dart';

/// Inbox: every conversation stays attached to its property. Inspection
/// updates live in the second tab. No "Online" indicator — there is no real
/// presence tracking.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _State();
}

class _State extends ConsumerState<ChatListScreen> {
  int _tab = 0;
  String _q = '';

  String _time(DateTime t) {
    final d = relativeDays(t);
    if (d == 'today') return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return d == 'yesterday' ? 'Yesterday' : '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: uid == null
            ? PsEmpty(icon: Icons.chat_bubble_outline_rounded, title: 'Sign in to see your messages', message: 'Your conversations with agents will appear here.', actionLabel: 'Sign in', onAction: () => context.push('/auth?reason=message&redirect=/messages'))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(children: [const PropsureLogo(size: 32), const Spacer(), Text('A safer way\nto find home', textAlign: TextAlign.right, style: AppText.caption)]),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Text('Inbox', style: AppText.display)),
                Padding(
                  padding: kPagePadding,
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                    decoration: const InputDecoration(hintText: 'Find a conversation', prefixIcon: Icon(Icons.search_rounded)),
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 8), child: PsSegmented(labels: const ['Messages', 'Inspection updates'], index: _tab, onChanged: (i) => setState(() => _tab = i))),
                Expanded(child: _tab == 0 ? _messages(uid) : _inspections(uid)),
              ]),
      ),
    );
  }

  Widget _messages(String uid) {
    final async = ref.watch(userChatsProvider(uid));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => PsError(onRetry: () => ref.invalidate(userChatsProvider(uid))),
      data: (all) {
        final chats = all.where((c) => !c.isArchived).where((c) => _q.isEmpty || c.otherParticipantName(uid).toLowerCase().contains(_q) || (c.listingTitle ?? '').toLowerCase().contains(_q)).toList();
        if (chats.isEmpty) {
          return PsEmpty(icon: Icons.chat_bubble_outline_rounded, title: _q.isEmpty ? 'No messages yet' : 'No matches', message: _q.isEmpty ? 'Ask an agent about a home and the conversation will stay attached to that property.' : 'Try a different name or property.', actionLabel: _q.isEmpty ? 'Find a home' : null, onAction: () => context.go('/home'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: chats.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            if (i == chats.length) {
              return Padding(padding: const EdgeInsets.only(top: 16), child: PsCard(color: AppColors.primaryPale, borderColor: AppColors.primaryPale2, child: Row(children: [const Icon(Icons.shield_outlined, color: AppColors.primary), const SizedBox(width: 12), Expanded(child: Text('Keep inspection arrangements in one place.', style: AppText.small.copyWith(color: AppColors.text)))])));
            }
            final c = chats[i];
            final unread = c.unreadCount(uid);
            final last = c.lastMessage;
            final preview = last == null ? 'No messages yet' : (last.isDeleted ? 'Message deleted' : last.type == 'image' ? 'Photo' : last.type == 'booking' ? 'Inspection request' : (last.text ?? ''));
            return Semantics(
              button: true,
              label: '${c.otherParticipantName(uid)}, ${c.listingTitle ?? ''}. $preview${unread > 0 ? ', unread' : ''}',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => context.push('/chat/${c.id}'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 84),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      PsAvatar(url: c.otherParticipantPhoto(uid), name: c.otherParticipantName(uid), size: 56),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.otherParticipantName(uid), style: AppText.title),
                        if (c.listingTitle != null) Text(c.listingTitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.text)),
                        Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_time(c.updatedAt), style: AppText.caption),
                        const SizedBox(height: 8),
                        if (unread > 0) Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                      ]),
                    ]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _inspections(String uid) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final async = (user?.isAgent ?? false) ? ref.watch(agentBookingsProvider(uid)) : ref.watch(userBookingsProvider(uid));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => PsError(onRetry: () => ref.invalidate(userBookingsProvider(uid))),
      data: (list) {
        if (list.isEmpty) return const PsEmpty(icon: Icons.event_outlined, title: 'No inspection updates', message: 'Requests and confirmations will show up here.');
        return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
          for (final b in list.take(20))
            PsListRow(
              leading: SizedBox(width: 56, height: 56, child: PsNetImage(b.listingThumbnail, radius: BorderRadius.circular(12))),
              title: b.listingTitle,
              subtitle: '${bookingStatusLabel(b.status)} · ${formatVisit(b.dateTime)}',
              onTap: () => context.push('/booking/${b.id}'),
            ),
        ]);
      },
    );
  }
}
