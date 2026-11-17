import '../constants/listing_category.dart';

/// Nigerian naira formatting used by every price on screen.
class Money {
  static const _sym = '₦';

  /// ₦2.4m · ₦240k · ₦950 — compact form used in cards and chips.
  static String short(num v) {
    final n = v.toDouble();
    if (n >= 1000000) return '$_sym${_compact(n / 1000000, 2)}m';
    if (n >= 1000) return '$_sym${_compact(n / 1000, 1)}k';
    return '$_sym${n.round()}';
  }

  static String _compact(double x, int maxDecimals) {
    var s = x.toStringAsFixed(maxDecimals);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// ₦2,400,000 — exact form used in breakdowns and checkout.
  static String full(num v) {
    final s = v.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}$_sym$buf';
  }

  /// Parses "2,400,000", "₦2.4m", "240k" typed by a person. Returns null if
  /// it is not a clear amount (we never guess).
  static double? parse(String raw) {
    var t = raw.toLowerCase().replaceAll(RegExp(r'[₦,\s]'), '');
    if (t.isEmpty) return null;
    var mult = 1.0;
    if (t.endsWith('m')) {
      mult = 1000000;
      t = t.substring(0, t.length - 1);
    } else if (t.endsWith('k')) {
      mult = 1000;
      t = t.substring(0, t.length - 1);
    }
    final v = double.tryParse(t);
    if (v == null || v < 0) return null;
    return v * mult;
  }

  /// "₦2.4m / year", "₦45k / night", "₦85m" (sale — no period).
  static String withPeriod(num price, ListingCategory c) {
    final p = c.periodWord;
    return p.isEmpty ? short(price) : '${short(price)} / $p';
  }
}
