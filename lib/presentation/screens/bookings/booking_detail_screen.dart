import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../../data/repositories/booking_repository.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});
  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _loading = false;

  Future<void> _updateStatus(String action) async {
    setState(() => _loading = true);
    final repo = ref.read(bookingRepositoryProvider);
    switch (action) {
      case 'confirm':
        await repo.confirmBooking(widget.bookingId);
        break;
      case 'reject':
        await _rejectWithReason();
        return;
      case 'cancel':
        await repo.cancelBooking(widget.bookingId);
        break;
      case 'complete':
        await repo.completeBooking(widget.bookingId);
        break;
    }
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking $action successfully!')));
      context.pop();
    }
  }

  Future<void> _rejectWithReason() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reason for rejection'),
        content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Optional reason…')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason != null) {
      await ref
          .read(bookingRepositoryProvider)
          .rejectBooking(widget.bookingId, reason: reason);
      setState(() => _loading = false);
      if (mounted) {
        context.pop();
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).value;
    final isAgent = user?.role == AppConstants.roleAgent ||
        user?.role == AppConstants.roleLandlord;

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<BookingModel?>(
        future: ref
            .read(bookingRepositoryProvider)
            .getBookingById(widget.bookingId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final booking = snap.data;
          if (booking == null) {
            return const Center(child: Text('Booking not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status banner
                    _StatusBanner(status: booking.status),
                    const SizedBox(height: 16),

                    // Listing info
                    _InfoCard(children: [
                      _InfoRow('Property', booking.listingTitle),
                      _InfoRow('Booking ID',
                          '#${booking.id.substring(0, 8).toUpperCase()}'),
                    ]),
                    const SizedBox(height: 12),

                    // Date & time
                    _InfoCard(title: '📅 Inspection Details', children: [
                      _InfoRow('Date', _formatDate(booking.dateTime)),
                      _InfoRow('Time', _formatTime(booking.dateTime)),
                      if (booking.message != null &&
                          booking.message!.isNotEmpty)
                        _InfoRow('Message', booking.message!),
                    ]),
                    const SizedBox(height: 12),

                    // Tenant info
                    _InfoCard(
                        title: isAgent ? '👤 Tenant' : '🏡 Agent',
                        children: [
                          _InfoRow('Name',
                              isAgent ? booking.userName : booking.agentName),
                          _InfoRow('Phone',
                              isAgent ? booking.userPhone : booking.agentPhone),
                        ]),
                    const SizedBox(height: 12),

                    // Rejection reason
                    if (booking.rejectionReason != null &&
                        booking.rejectionReason!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Rejection Reason',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                      fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(booking.rejectionReason!,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.text2)),
                            ]),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Actions
                    _ActionButtons(
                      booking: booking,
                      isAgent: isAgent,
                      loading: _loading,
                      onAction: _updateStatus,
                      onCall: () async {
                        final phone =
                            isAgent ? booking.userPhone : booking.agentPhone;
                        final uri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                      onChat: () => context.push('/messages'),
                      onViewListing: () =>
                          context.push('/listing/${booking.listingId}'),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
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
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final configs = {
      'pending': (
        AppColors.statusPending,
        const Color(0xFFFEF3C7),
        '⏳',
        'Awaiting Confirmation'
      ),
      'confirmed': (
        AppColors.success,
        const Color(0xFFDCFCE7),
        '✅',
        'Inspection Confirmed'
      ),
      'completed': (
        AppColors.text2,
        AppColors.bg,
        '🏁',
        'Inspection Completed'
      ),
      'cancelled': (
        AppColors.error,
        const Color(0xFFFEE2E2),
        '❌',
        'Booking Cancelled'
      ),
      'rejected': (
        AppColors.error,
        const Color(0xFFFEE2E2),
        '🚫',
        'Booking Rejected'
      ),
    };
    final (fg, bg, icon, label) =
        configs[status] ?? (AppColors.text3, AppColors.bg, '❓', 'Unknown');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.2))),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.7),
                  letterSpacing: 0.5)),
          Text(label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
        ]),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _InfoCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.text)),
          const Divider(height: 16),
        ],
        ...children,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.text3,
                    fontWeight: FontWeight.w500))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text))),
      ]),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final dynamic booking;
  final bool isAgent, loading;
  final ValueChanged<String> onAction;
  final VoidCallback onCall, onChat, onViewListing;
  const _ActionButtons(
      {required this.booking,
      required this.isAgent,
      required this.loading,
      required this.onAction,
      required this.onCall,
      required this.onChat,
      required this.onViewListing});

  @override
  Widget build(BuildContext context) {
    final status = booking.status as String;

    return Column(children: [
      // View Listing & Contact row
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
          onPressed: onViewListing,
          icon: const Icon(Icons.home_outlined, size: 16),
          label: const Text('View Property'),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12)),
        )),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton.icon(
          onPressed: onCall,
          icon: const Icon(Icons.call_rounded, size: 16),
          label: Text(isAgent ? 'Call Tenant' : 'Call Agent'),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12)),
        )),
      ]),
      const SizedBox(height: 10),

      // Status-based actions
      if (isAgent && status == AppConstants.bookingPending) ...[
        Row(children: [
          Expanded(
              child: OutlinedButton(
            onPressed: loading ? null : () => onAction('reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('Reject',
                style: TextStyle(fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: ElevatedButton(
            onPressed: loading ? null : () => onAction('confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Confirm',
                    style: GoogleFonts.syne(
                        fontWeight: FontWeight.w800, color: Colors.white)),
          )),
        ]),
      ] else if (isAgent && status == AppConstants.bookingConfirmed) ...[
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : () => onAction('complete'),
              child: const Text('Mark as Completed'),
            )),
      ] else if (!isAgent &&
          (status == AppConstants.bookingPending ||
              status == AppConstants.bookingConfirmed)) ...[
        SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: loading ? null : () => onAction('cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Cancel Booking',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )),
      ],
    ]);
  }
}
