import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/rooms.dart';
import '../../../core/widgets/common_widgets.dart';

String chapterTime(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Tappable room chapters. [activeIndex] highlights the one being played.
class ChapterChips extends StatelessWidget {
  final List<TourChapter> chapters;
  final int? activeIndex;
  final ValueChanged<TourChapter> onTap;
  final bool dark; // on a black player background
  const ChapterChips({super.key, required this.chapters, required this.onTap, this.activeIndex, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < chapters.length; i++) ...[
          Semantics(
            button: true,
            selected: i == activeIndex,
            label: '${chapters[i].label}, ${chapterTime(chapters[i].startMs)}',
            excludeSemantics: true,
            child: Material(
              color: i == activeIndex ? AppColors.primary : (dark ? const Color(0x33FFFFFF) : AppColors.card),
              shape: StadiumBorder(side: BorderSide(color: i == activeIndex ? AppColors.primary : (dark ? const Color(0x55FFFFFF) : AppColors.border))),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onTap(chapters[i]),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(chapters[i].label, style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: i == activeIndex || dark ? Colors.white : AppColors.text)),
                      const SizedBox(width: 8),
                      Text(chapterTime(chapters[i].startMs), style: AppText.small.copyWith(color: i == activeIndex || dark ? const Color(0xCCFFFFFF) : AppColors.text3)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }
}

/// "What the video shows": what is shown and what is not, plainly.
class CoverageCard extends StatelessWidget {
  final VideoCoverage coverage;
  const CoverageCard({super.key, required this.coverage});

  @override
  Widget build(BuildContext context) {
    final all = coverage.shownCount == coverage.total;
    return PsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('What the video shows', style: AppText.h3)),
          PsPill(all ? 'All ${coverage.total} areas' : '${coverage.shownCount} of ${coverage.total} areas', tone: all ? PsTone.success : PsTone.warning, small: true),
        ]),
        const SizedBox(height: 10),
        Wrap(runSpacing: 10, children: [
          for (final item in coverage.items)
            SizedBox(
              width: 170,
              child: Row(children: [
                Icon(item.shown ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, size: 22, color: item.shown ? AppColors.primary : AppColors.text3),
                const SizedBox(width: 8),
                Flexible(child: Text(item.shown ? item.label : '${item.label} (not shown)', style: AppText.body.copyWith(color: item.shown ? AppColors.text : AppColors.text2))),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        Text('Based on the rooms the agent named in the video. Ask the agent about anything not shown.', style: AppText.small),
      ]),
    );
  }
}
