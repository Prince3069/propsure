/// Plain-language inspection status. A request is not a confirmed visit.
String bookingStatusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'Requested';
    case 'confirmed':
      return 'Confirmed';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'rejected':
      return 'Declined';
    default:
      return s;
  }
}

String formatVisit(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}, $h$m ${d.hour < 12 ? 'am' : 'pm'}';
}
