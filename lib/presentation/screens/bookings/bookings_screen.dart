import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../../data/repositories/booking_repository.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final user = ref.watch(currentUserModelProvider).value;
    final isAgent = user?.role == AppConstants.roleAgent || user?.role == AppConstants.roleLandlord;
    return DefaultTabController(
      length: isAgent ? 2 : 1,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text('My bookings', style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
          bottom: isAgent
              ? const TabBar(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  tabs: [Tab(text: 'My Requests'), Tab(text: 'Incoming')],
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.text3,
                )
              : null,
        ),
        body: isAgent
            ? TabBarView(children: [
                _BookingList(userId: userId, isAgentView: false),
                _BookingList(userId: userId, isAgentView: true),
              ])
            : _BookingList(userId: userId, isAgentView: false),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  final String userId;
  final bool isAgentView;
  const _BookingList({required this.userId, required this.isAgentView});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = isAgentView ? ref.watch(agentBookingsProvider(userId)) : ref.watch(userBookingsProvider(userId));
    return stream.when(
      data: (bookings) {
        final typed = bookings.cast<BookingModel>();
        if (typed.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_today_outlined,
            title: isAgentView ? 'No incoming requests' : 'No bookings yet',
            subtitle: isAgentView ? 'Inspection requests from tenants will show here.' : 'Book an inspection from any property listing.',
            action: isAgentView
                ? null
                : TextButton(onPressed: () => context.push('/search'), child: const Text('Browse Properties')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          itemCount: typed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _BookingCard(booking: typed[i], isAgentView: isAgentView),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isAgentView;
  const _BookingCard({required this.booking, required this.isAgentView});
  @override
  Widget build(BuildContext context) {
    final configs = {
      'pending': (AppColors.statusPending, const Color(0xFFFEF3C7), Icons.schedule_rounded),
      'confirmed': (AppColors.success, const Color(0xFFDCFCE7), Icons.check_circle_outline_rounded),
      'completed': (AppColors.text2, AppColors.bg, Icons.flag_outlined),
      'cancelled': (AppColors.error, const Color(0xFFFEE2E2), Icons.cancel_outlined),
      'rejected': (AppColors.error, const Color(0xFFFEE2E2), Icons.block_outlined),
    };
    final (fg, bg, icon) = configs[booking.status] ?? (AppColors.text3, AppColors.bg, Icons.help_outline_rounded);
    final dt = booking.dateTime;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final dateStr = '${dt.day} ${months[dt.month - 1]} · $h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
    return GestureDetector(
      onTap: () => context.push('/booking/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.primaryPale, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.home_work_outlined, color: AppColors.primary, size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Text(booking.listingTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 12, color: fg),
                  const SizedBox(width: 4),
                  Text(booking.status.toUpperCase(), style: TextStyle(color: fg, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .3)),
                ])),
          ]),
          const SizedBox(height: 13),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 7),
                Expanded(child: Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600))),
              ])),
          const SizedBox(height: 9),
          Row(children: [
            const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.text3),
            const SizedBox(width: 5),
            Expanded(child: Text(isAgentView ? booking.userName : booking.agentName, style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(timeago.format(booking.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.text3)),
          ]),
          if (booking.message != null && booking.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(booking.message!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.text3, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          const Align(alignment: Alignment.centerRight, child: Text('View details →', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w800))),
        ]),
      ),
    );
  }
}
