import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/area.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

/// One row of the area card: topic, what residents say, how many and when.
class AreaRow extends StatelessWidget {
  final AreaTopic topic;
  final AreaTopicSummary? summary;
  const AreaRow({super.key, required this.topic, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final has = s != null && s.count > 0;
    final lead = has ? s.leading : null;
    final headline = !has ? 'Not enough reports yet' : (lead == null ? 'Reports differ' : (kAreaHeadline[lead] ?? lead));
    final meta = !has
        ? 'Be the first to add'
        : '${s.count} ${s.count == 1 ? 'report' : 'reports'}${s.latestAt != null ? ' · latest ${monthYear(s.latestAt!)}' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PsIconCircle(topic.icon, size: 42, bg: has ? AppColors.primaryPale : AppColors.muted, fg: has ? AppColors.primary : AppColors.text3),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(topic.title, style: AppText.title)),
              if (has && s.early) const PsPill('Early reports', tone: PsTone.warning, small: true),
            ]),
            Text(headline, style: AppText.body.copyWith(color: has ? AppColors.text : AppColors.text2)),
            Text(meta, style: AppText.small),
          ]),
        ),
      ]),
    );
  }
}

/// Life around an area, from reports by people who live or work nearby.
class AreaScreen extends ConsumerWidget {
  final String city;
  final String area;
  const AreaScreen({super.key, required this.city, required this.area});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = areaKeyOf(city, area);
    final async = ref.watch(areaSummaryProvider(key));
    final signedIn = ref.watch(isSignedInProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: 'Life around $area'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(areaSummaryProvider(key))),
        data: (sum) => ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 32), children: [
          Text('Reported by people who live or work nearby. Each answer shows how many reports it rests on and when the latest came in.', style: AppText.bodyMuted),
          const SizedBox(height: 14),
          PsCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < kAreaTopics.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                AreaRow(topic: kAreaTopics[i], summary: sum?.topics[kAreaTopics[i].key]),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          const PsNote('These are residents’ own reports, not checked by Propsure. Visit the area before you decide.'),
          const SizedBox(height: 16),
          PsButton('Add what you know', kind: PsButtonKind.outline, icon: Icons.add_rounded, onPressed: () {
            final target = '/area/report?city=${Uri.encodeComponent(city)}&area=${Uri.encodeComponent(area)}';
            if (!signedIn) {
              context.push('/auth?reason=save&redirect=${Uri.encodeComponent(target)}');
            } else {
              context.push(target);
            }
          }),
        ]),
      ),
    );
  }
}

/// Short version for a listing page: the top rows and a link to the full card.
class AreaPreviewCard extends ConsumerWidget {
  final String city;
  final String area;
  const AreaPreviewCard({super.key, required this.city, required this.area});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (area.trim().isEmpty) return const SizedBox.shrink();
    final key = areaKeyOf(city, area);
    final sum = ref.watch(areaSummaryProvider(key)).asData?.value;
    final withData = kAreaTopics.where((t) => (sum?.topics[t.key]?.count ?? 0) > 0).take(3).toList();
    final target = '/area?city=${Uri.encodeComponent(city)}&area=${Uri.encodeComponent(area)}';
    return PsCard(
      onTap: () => context.push(target),
      semanticLabel: 'Life around $area',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Life around $area', style: AppText.h3)),
          const Icon(Icons.chevron_right_rounded),
        ]),
        if (withData.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('No reports yet. Power, water, flooding and more, from people who live nearby. Be the first to add what you know.', style: AppText.small))
        else
          for (final t in withData) AreaRow(topic: t, summary: sum!.topics[t.key]),
      ]),
    );
  }
}
