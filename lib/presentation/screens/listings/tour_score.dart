import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/rooms.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';

/// How completely a video tour shows the home, worked out from the room names
/// on its stills. Same rule the renter sees, so agents learn what renters see.
class TourScore {
  final int shown;
  final int total;
  final List<String> missing;
  const TourScore(this.shown, this.total, this.missing);

  bool get complete => total > 0 && missing.isEmpty;
  String get grade => complete ? 'Complete' : (total > 0 && shown * 10 >= total * 7 ? 'Good' : 'Needs work');

  static TourScore? of(ListingModel l) => fromLabels([for (final s in l.stills.where((x) => x.source == 'video')) s.label ?? ''], l);

  static TourScore? fromLabels(List<String> labels, ListingModel l) {
    final cov = coverageFromLabels(labels, bedrooms: l.bedrooms, bathrooms: l.bathrooms, propertyType: l.propertyType, commercial: l.category == 'commercial');
    if (cov == null) return null;
    return TourScore(cov.shownCount, cov.total, [for (final m in cov.missing) m.label]);
  }
}

/// A short, friendly card that tells the agent what to film next.
class TourScoreNote extends StatelessWidget {
  final ListingModel listing;
  final TourScore? score;
  const TourScoreNote({super.key, required this.listing, this.score});

  @override
  Widget build(BuildContext context) {
    final sc = score ?? TourScore.of(listing);
    if (sc == null) return const SizedBox.shrink();
    if (sc.complete) {
      return PsNote('Tour: Complete. Every area is shown (${sc.shown} of ${sc.total}).', tone: PsTone.success, icon: Icons.check_circle_outline_rounded);
    }
    final tip = sc.missing.length == 1 ? 'Film or add a photo of the ${sc.missing.first.toLowerCase()}.' : 'Film or add photos of: ${sc.missing.join(', ')}.';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PsNote('Tour: ${sc.grade}. ${sc.shown} of ${sc.total} areas shown. $tip Renters see missing areas as "not shown".', tone: PsTone.warning, icon: Icons.flag_outlined),
      const SizedBox(height: 4),
      PsLink('How to film a perfect tour', onTap: () => context.push('/listing/record-guide')),
    ]);
  }
}
