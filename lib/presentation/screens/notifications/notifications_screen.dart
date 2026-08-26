import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

// ─── Firestore-backed notification model ──────────────────────────────────────
class _NotifModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? route;
  final String? imageUrl;

  _NotifModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.route,
    this.imageUrl,
  });

  factory _NotifModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _NotifModel(
      id: doc.id,
      type: d['type'] as String? ?? 'general',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      isRead: d['isRead'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      route: d['route'] as String?,
      imageUrl: d['imageUrl'] as String?,
    );
  }
}

// ─── Provider — stream Firestore notifications for current user ───────────────
final _notificationsProvider = StreamProvider.autoDispose<List<_NotifModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection(AppConstants.colNotifications)
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(_NotifModel.fromFirestore).toList());
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Notifications', style: GoogleFonts.syne(fontWeight: FontWeight.w700))),
        body: EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Sign in to see notifications',
          subtitle: 'You\'ll get alerts for bookings, messages and price changes.',
          action: ElevatedButton(
            onPressed: () => context.push('/auth?redirect=/notifications'),
            child: const Text('Sign In'),
          ),
        ),
      );
    }

    final notifsAsync = ref.watch(_notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: notifsAsync.when(
          data: (notifs) {
            final unread = notifs.where((n) => !n.isRead).length;
            return Row(children: [
              Text('Notifications', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(99)),
                  child: Text('$unread new', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]);
          },
          loading: () => Text('Notifications', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
          error:   (_,__) => Text('Notifications', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        ),
        actions: [
          notifsAsync.maybeWhen(
            data: (notifs) => notifs.any((n) => !n.isRead)
                ? TextButton(
                    onPressed: () => _markAllRead(uid),
                    child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: notifsAsync.when(
        data: (notifs) {
          if (notifs.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              subtitle: "You're all caught up! We'll notify you about bookings, messages and more.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (_, i) => _NotifTile(
              notif: notifs[i],
              onTap: () {
                if (!notifs[i].isRead) _markRead(notifs[i].id);
                if (notifs[i].route != null) context.push(notifs[i].route!);
              },
            ),
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (_, __) => const _NotifSkeleton(),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _markRead(String notifId) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.colNotifications)
        .doc(notifId)
        .update({'isRead': true});
  }

  Future<void> _markAllRead(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colNotifications)
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

// ─── Notification config: type → icon / color ─────────────────────────────────
({IconData icon, Color bg, Color fg}) _notifStyle(String type) {
  switch (type) {
    case 'booking_confirmed':
    case 'booking_request':
      return (icon: Icons.calendar_today_rounded, bg: const Color(0xFFFEF3C7), fg: AppColors.gold);
    case 'new_message':
    case 'message':
      return (icon: Icons.chat_bubble_outline_rounded, bg: const Color(0xFFEFF6FF), fg: AppColors.info);
    case 'listing_verified':
    case 'verification':
      return (icon: Icons.verified_rounded, bg: AppColors.primaryPale, fg: AppColors.primary);
    case 'new_review':
    case 'review':
      return (icon: Icons.star_rounded, bg: const Color(0xFFFEF3C7), fg: AppColors.goldDark);
    case 'price_drop':
      return (icon: Icons.trending_down_rounded, bg: const Color(0xFFF0FFF4), fg: AppColors.success);
    case 'listing_expiring':
    case 'subscription_expiry':
      return (icon: Icons.timer_outlined, bg: const Color(0xFFFEE2E2), fg: AppColors.error);
    case 'inquiry':
    case 'inquiry_received':
      return (icon: Icons.contact_phone_outlined, bg: const Color(0xFFF5F3FF), fg: const Color(0xFF7C3AED));
    case 'offer':
    case 'offer_update':
      return (icon: Icons.local_offer_outlined, bg: AppColors.primaryPale, fg: AppColors.primary);
    case 'payment':
      return (icon: Icons.payment_rounded, bg: const Color(0xFFF0FFF4), fg: AppColors.success);
    default:
      return (icon: Icons.notifications_outlined, bg: AppColors.primaryPale2, fg: AppColors.primaryLight);
  }
}

class _NotifTile extends StatelessWidget {
  final _NotifModel notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = _notifStyle(notif.type);
    final now = DateTime.now();
    final diff = now.difference(notif.createdAt);
    final timeStr = diff.inMinutes < 1
        ? 'Just now'
        : diff.inHours < 1
            ? '${diff.inMinutes}m ago'
            : diff.inDays < 1
                ? '${diff.inHours}h ago'
                : diff.inDays == 1
                    ? 'Yesterday'
                    : '${diff.inDays}d ago';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: notif.isRead ? null : AppColors.primary.withOpacity(0.03),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: style.bg, shape: BoxShape.circle),
            child: Icon(style.icon, color: style.fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(notif.title,
                style: TextStyle(
                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                  fontSize: 13, color: AppColors.text))),
              if (!notif.isRead)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text(notif.body,
              style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(timeStr, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
          ])),
          if (notif.route != null)
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.text3),
        ]),
      ),
    );
  }
}

class _NotifSkeleton extends StatelessWidget {
  const _NotifSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 12, width: 140, color: AppColors.bg),
          const SizedBox(height: 7),
          Container(height: 10, color: AppColors.bg),
          const SizedBox(height: 4),
          Container(height: 10, width: 80, color: AppColors.bg),
        ])),
      ]),
    );
  }
}
