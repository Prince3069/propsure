/// Time-of-day greeting, based on the clock of the device the user is holding
/// (so it is correct in whatever city or time zone they are in; no location
/// permission is needed).
enum DayPart { morning, afternoon, evening }

DayPart dayPeriodAt(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 12) return DayPart.morning;
  if (h >= 12 && h < 17) return DayPart.afternoon;
  return DayPart.evening;
}

String greetingFor(DayPart p) {
  switch (p) {
    case DayPart.morning:
      return 'Good morning';
    case DayPart.afternoon:
      return 'Good afternoon';
    case DayPart.evening:
      return 'Good evening';
  }
}

/// First word of a display name, or null when there is no usable name.
String? firstNameOf(String? full) {
  final t = (full ?? '').trim();
  if (t.isEmpty) return null;
  final first = t.split(RegExp(r'\s+')).first;
  return first.isEmpty ? null : first;
}
