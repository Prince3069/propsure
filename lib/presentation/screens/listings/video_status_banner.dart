import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/app_providers.dart';

/// Live video status for one home. It listens to the listing, so it moves from
/// "Uploading" to "Ready to review" on its own, with no need to reopen the screen.
class VideoStatusBanner extends ConsumerWidget {
  final String listingId;
  const VideoStatusBanner({super.key, required this.listingId});

  static const _steps = ['Uploaded', 'Processing', 'Review', 'Live'];

  int _stepOf(VideoStatus s) {
    switch (s) {
      case VideoStatus.uploaded:
      case VideoStatus.validating:
        return 0;
      case VideoStatus.processing:
        return 1;
      case VideoStatus.needsReview:
        return 2;
      case VideoStatus.ready:
        return 3;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(listingByIdProvider(listingId)).value;
    if (l == null || l.videoStatus == VideoStatus.none) return const SizedBox.shrink();
    final step = _stepOf(l.videoStatus);
    if (step < 0) {
      final failed = l.videoStatus == VideoStatus.failed;
      final msg = failed
          ? (l.videoRejectionReason ?? 'We could not process that video. Try again or add photos.')
          : 'We could not use that video: ${l.videoRejectionReason ?? 'it did not meet the rules'}. Videos must be 5 seconds to 3 minutes.';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PsNote(msg, tone: PsTone.warning, icon: Icons.error_outline_rounded),
          const SizedBox(height: 6),
          PsLink('How to film a perfect tour', onTap: () => context.push('/listing/record-guide')),
        ]),
      );
    }
    final text = switch (l.videoStatus) {
      VideoStatus.uploaded || VideoStatus.validating => 'Video received. We are checking it.',
      VideoStatus.processing => 'We are preparing your video and picking frames. This takes a few minutes. You can leave this screen.',
      VideoStatus.needsReview => 'Your video is ready. Review the suggested frames before they are shown.',
      _ => 'Your video is live.',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var i = 0; i < _steps.length; i++) ...[
              Expanded(
                child: Column(children: [
                  Container(height: 5, decoration: BoxDecoration(color: i <= step ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 4),
                  Text(_steps[i], style: AppText.caption.copyWith(fontWeight: i == step ? FontWeight.w800 : FontWeight.w500, color: i <= step ? AppColors.text : AppColors.text3)),
                ]),
              ),
              if (i < _steps.length - 1) const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 10),
          Text(text, style: AppText.body),
          if (l.videoStatus == VideoStatus.needsReview) ...[
            if (l.videoNeedsCheck) ...[
              const SizedBox(height: 8),
              const PsNote('This video needs a quick check by our team. You can still review your frames now.', icon: Icons.fact_check_outlined),
            ],
            const SizedBox(height: 10),
            PsButton('Review frames', onPressed: () => context.push('/listing/${l.id}/frames')),
          ],
        ]),
      ),
    );
  }
}
