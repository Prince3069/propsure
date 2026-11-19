import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class _Notif {
  final String id, type, title, body;
  final bool isRead;
  final DateTime createdAt;
  final String? route;
  _Notif(this.id, this.type, this.title, this.body, this.isRead, this.createdAt, this.route);

  factory _Notif.from(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    return _Notif(
      doc.id,
      d['type'] as String? ?? 'general',
      d['title'] as String? ?? '',
      d['body'] as String? ?? '',
      d['isRead'] as bool? ?? false,
      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      d['route'] as String?,
    );
  }

  String? get target {
    if (route != null && route!.startsWith('/')) return route;
    if (type.startsWith('support')) return '/support/status';
    if (type.startsWith('booking') || type.startsWith('inspection')) return '/bookings';
    return null;
  }

  (IconData, bool) get icon {
    if (type == 'availability_refresh') return (Icons.sync_rounded, true);
    if (type == 'saved_search_match') return (Icons.search_rounded, false);
    if (type.startsWith('booking') || type.startsWith('inspection')) return (Icons.event_available_outlined, false);
    return (Icons.person_outline_rounded, false);
  }
}

final _notificationsProvider = StreamProvider.autoDispose<List<_Notif>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(_Notif.from).toList());
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _time(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _markAllRead(WidgetRef ref, List<_Notif> list) async {
    final unread = list.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(FirebaseFirestore.instance.collection('notifications').doc(n.id), {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isSignedInProvider)) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const PsTopBar(title: 'Notifications'),
        body: PsEmpty(icon: Icons.notifications_none_rounded, title: 'Sign in to see notifications', message: 'Updates about your inspections, searches and reports appear here.', actionLabel: 'Sign in', onAction: () => context.push('/auth?redirect=/notifications')),
      );
    }
    final async = ref.watch(_notificationsProvider);
    final now = DateTime.now();
    bool isToday(DateTime t) => t.year == now.year && t.month == now.month && t.day == now.day;

    Widget tile(_Notif n) {
      final (icon, warm) = n.icon;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PsCard(
          onTap: () async {
            if (!n.isRead) {
              try { await FirebaseFirestore.instance.collection('notifications').doc(n.id).update({'isRead': true}); } catch (_) {}
            }
            final t = n.target;
            if (t != null && context.mounted) context.push(t);
          },
          semanticLabel: n.title,
          child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: warm ? AppColors.warningPale : AppColors.primaryPale, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: warm ? AppColors.goldDark : AppColors.primary, size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(n.title, style: AppText.title.copyWith(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800))),
                if (!n.isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                Text(_time(n.createdAt), style: AppText.caption),
              ]),
              const SizedBox(height: 2),
              Text(n.body, style: AppText.small, maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.text2),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(_notificationsProvider)),
          data: (list) {
            final today = list.where((n) => isToday(n.createdAt)).toList();
            final earlier = list.where((n) => !isToday(n.createdAt)).toList();
            return ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text('Notifications', style: AppText.h1.copyWith(fontSize: 34))),
                if (list.any((n) => !n.isRead)) PsLink('Mark read', onTap: () => _markAllRead(ref, list)),
              ]),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const PsEmpty(icon: Icons.notifications_none_rounded, title: 'Nothing new', message: 'We will tell you here when something changes.'),
              if (today.isNotEmpty) ...[const PsSectionTitle('Today'), const SizedBox(height: 10), ...today.map(tile)],
              if (earlier.isNotEmpty) ...[const SizedBox(height: 8), const PsSectionTitle('Earlier'), const SizedBox(height: 10), ...earlier.map(tile)],
              const SizedBox(height: 8),
              PsRowGroup([PsListRow(icon: Icons.settings_outlined, title: 'Manage notification preferences', onTap: () => context.push('/settings'))]),
            ]);
          },
        ),
      ),
    );
  }
}
