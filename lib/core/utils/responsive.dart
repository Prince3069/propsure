import 'package:flutter/material.dart';

/// One set of breakpoints for phone, tablet and desktop/web.
///   compact  < 600   phone: bottom navigation, single column
///   medium   600–1023 tablet / small window: navigation rail
///   expanded >= 1024  desktop: top navigation bar, multi-column
enum ScreenSize { compact, medium, expanded }

class Responsive {
  static const double mediumMin = 600;
  static const double expandedMin = 1024;

  /// Widest the app content grows; wider windows get side margins.
  static const double maxContentWidth = 1200;

  static ScreenSize of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize fromWidth(double w) {
    if (w >= expandedMin) return ScreenSize.expanded;
    if (w >= mediumMin) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  static bool isCompact(BuildContext c) => of(c) == ScreenSize.compact;
  static bool isExpanded(BuildContext c) => of(c) == ScreenSize.expanded;

  /// Grid column count for card grids at the given available width.
  static int columnsFor(double width, {double minTile = 320, int max = 4}) {
    final n = (width / minTile).floor();
    return n < 1 ? 1 : (n > max ? max : n);
  }
}

/// Centres its child and caps the width on large windows. On phones it is a
/// no-op, so mobile layouts are unchanged.
class ContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentFrame({super.key, required this.child, this.maxWidth = Responsive.maxContentWidth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
