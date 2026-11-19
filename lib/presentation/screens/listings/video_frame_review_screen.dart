import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/rooms.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Review the frames suggested from the agent's OWN footage. Only real frames
/// are offered (never generated rooms), each with its timestamp. Nothing is
/// published until the agent confirms.
class VideoFrameReviewScreen extends ConsumerStatefulWidget {
  final String listingId;
  const VideoFrameReviewScreen({super.key, required this.listingId});
  @override
  ConsumerState<VideoFrameReviewScreen> createState() => _State();
}

class _State extends ConsumerState<VideoFrameReviewScreen> {
  final Set<String> _chosen = {};
  final Map<String, String> _labels = {};
  String? _cover;
  String? _focus;
  bool _busy = false;
  bool _seeded = false;
  final Map<String, Future<String>> _urls = {};

  Future<String> _url(String path) => _urls.putIfAbsent(path, () => ref.read(listingRepositoryProvider).candidateUrl(path));

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _confirm(ListingModel l) async {
    setState(() => _busy = true);
    final ok = await runAction(context, () => ref.read(functionsServiceProvider).confirmVideoFrames(
          listingId: l.id,
          frameIds: _chosen.toList(),
          coverId: _cover != null && _chosen.contains(_cover) ? _cover : null,
          labels: {for (final e in _labels.entries) if (_chosen.contains(e.key) && e.value.trim().isNotEmpty) e.key: e.value.trim()},
        ), success: 'Your reviewed frames are saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }

  Future<void> _discard(ListingModel l) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove this video?'),
        content: const Text('The processed video and suggested frames will be removed from this listing. You can upload a different video.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await runAction(context, () => ref.read(functionsServiceProvider).discardVideo(l.id));
    if (ok && mounted) context.pop();
  }

  Widget _coverageNote(ListingModel l) {
    final labels = [for (final id in _chosen) _labels[id] ?? ''];
    final cov = coverageFromLabels(labels, bedrooms: l.bedrooms, bathrooms: l.bathrooms, propertyType: l.propertyType, commercial: l.category == 'commercial');
    if (cov == null) {
      return const PsNote('Name the rooms and renters can jump straight to them in the video.', icon: Icons.meeting_room_outlined);
    }
    if (cov.missing.isEmpty) return PsNote('Every area is covered: ${cov.total} of ${cov.total}.', tone: PsTone.success, icon: Icons.check_circle_outline_rounded);
    return PsNote('Not shown yet: ${cov.missing.map((m) => m.label).join(', ')}. Renters will see these as "not shown".', tone: PsTone.warning, icon: Icons.warning_amber_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(listingByIdProvider(widget.listingId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Review your video stills'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(listingByIdProvider(widget.listingId))),
        data: (l) {
          if (l == null) return const PsEmpty(icon: Icons.videocam_off_outlined, title: 'Listing not found', message: 'This listing may have been removed.');
          if (l.videoStatus == VideoStatus.uploaded || l.videoStatus == VideoStatus.validating || l.videoStatus == VideoStatus.processing) {
            return const PsEmpty(icon: Icons.hourglass_top_rounded, title: 'Processing your video', message: 'We are preparing a low-data version and suggesting frames. This can take a few minutes. You can leave this screen; we will notify you.');
          }
          if (l.videoStatus == VideoStatus.failed || l.videoStatus == VideoStatus.rejected) {
            return PsEmpty(
              icon: Icons.error_outline_rounded,
              title: 'We could not use that video',
              message: l.videoRejectionReason ?? 'Try recording again in good light, or add real photos instead.',
              actionLabel: 'Add real photos',
              onAction: () => context.push('/listing/edit/${l.id}'),
            );
          }
          if (l.videoStatus == VideoStatus.ready && l.stills.any((x) => x.source == 'video')) {
            return _ReadyLabeler(listing: l);
          }
          if (l.videoStatus != VideoStatus.needsReview) {
            return const PsEmpty(icon: Icons.check_circle_outline_rounded, title: 'Nothing to review', message: 'There are no frames waiting for your review.');
          }
          final cands = l.videoCandidates;
          if (!_seeded && cands.isNotEmpty) {
            _seeded = true;
            _focus = cands.first.id;
            _chosen.addAll(cands.take(3).map((c) => c.id));
            _cover = cands.first.id;
          }
          if (cands.isEmpty) {
            return const PsEmpty(icon: Icons.photo_camera_outlined, title: 'No clear frames found', message: 'The footage was too dark or blurry to suggest frames. Add real photos to your listing instead. We never invent images.');
          }
          final focus = cands.firstWhere((c) => c.id == _focus, orElse: () => cands.first);
          return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 24), children: [
            const PsHeadline('Real frames.', accent: 'Your choice.'),
            const SizedBox(height: 8),
            const Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22), SizedBox(width: 8), Text('Processing complete')]),
            if (l.videoCoverageWarning != null) ...[const SizedBox(height: 12), PsNote(l.videoCoverageWarning!, tone: PsTone.warning, icon: Icons.warning_amber_rounded)],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(fit: StackFit.expand, children: [
                  FutureBuilder<String>(future: _url(focus.path), builder: (_, s) => PsNetImage(s.data, semanticLabel: 'Suggested frame at ${_fmt(focus.timestampMs)}')),
                  const Positioned(left: 12, top: 12, child: PsPill('From your video', tone: PsTone.neutral, small: true)),
                  Positioned(right: 12, top: 12, child: PsPill(_fmt(focus.timestampMs), tone: PsTone.neutral, small: true)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cands.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = cands[i];
                  final on = _chosen.contains(c.id);
                  return SizedBox(
                    width: 112,
                    child: Column(children: [
                      Semantics(
                        button: true,
                        selected: on,
                        label: 'Frame at ${_fmt(c.timestampMs)}${_cover == c.id ? ', cover' : ''}',
                        child: InkWell(
                          onTap: () => setState(() { _focus = c.id; }),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Container(
                            height: 84,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: _focus == c.id ? AppColors.primary : AppColors.border, width: _focus == c.id ? 3 : 1)),
                            child: Stack(fit: StackFit.expand, children: [
                              FutureBuilder<String>(future: _url(c.path), builder: (_, s) => PsNetImage(s.data, radius: BorderRadius.circular(AppRadius.sm - 2))),
                              Positioned(right: 4, top: 4, child: InkWell(
                                onTap: () => setState(() { on ? _chosen.remove(c.id) : _chosen.add(c.id); }),
                                child: CircleAvatar(radius: 14, backgroundColor: on ? AppColors.primary : Colors.white, child: Icon(on ? Icons.check_rounded : Icons.add_rounded, size: 18, color: on ? Colors.white : AppColors.text)),
                              )),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_labels[c.id] ?? _fmt(c.timestampMs), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: _focus == c.id ? AppColors.primary : AppColors.text3, fontWeight: FontWeight.w700)),
                    ]),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('Which room is this?', style: AppText.title),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in roomChoices(bedrooms: l.bedrooms, bathrooms: l.bathrooms))
                PsChip(r, selected: (_labels[focus.id] ?? '') == r, onTap: () => setState(() { _labels[focus.id] = r; _chosen.add(focus.id); })),
            ]),
            const SizedBox(height: 12),
            PsField(
              key: ValueKey('label_${focus.id}_${_labels[focus.id] ?? ''}'),
              label: 'Or type a name (optional)',
              hint: 'Study, Store, Balcony…',
              maxLength: 24,
              initialValue: _labels[focus.id],
              onChanged: (v) => _labels[focus.id] = v,
            ),
            const SizedBox(height: 12),
            _coverageNote(l),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: PsButton(_cover == focus.id ? 'Cover frame' : 'Set as cover', icon: Icons.bookmark_rounded, onPressed: () => setState(() { _cover = focus.id; _chosen.add(focus.id); }))),
              const SizedBox(width: 12),
              Expanded(child: PsButton('Remove frame', kind: PsButtonKind.outline, icon: Icons.delete_outline_rounded, onPressed: () => setState(() { _chosen.remove(focus.id); if (_cover == focus.id) _cover = _chosen.isEmpty ? null : _chosen.first; }))),
            ]),
            const SizedBox(height: 14),
            const PsNote('Missing a room? Add a real photo. We do not invent images.'),
            const SizedBox(height: 10),
            PsListRow(icon: Icons.play_circle_outline_rounded, title: 'Original video kept for review', onTap: () => showPsSnack(context, 'Your original video stays private. Only the processed walkthrough is shown to renters.'), padding: const EdgeInsets.all(12)),
            const SizedBox(height: 14),
            PsButton('Use these frames (${_chosen.length})', loading: _busy, onPressed: (_chosen.isEmpty && l.images.isEmpty) ? null : () => _confirm(l)),
            const SizedBox(height: 8),
            Center(child: PsLink('Remove this video', underline: false, onTap: () => _discard(l))),
          ]);
        },
      ),
    );
  }
}


/// For a video that is already published: name the rooms on its stills.
class _ReadyLabeler extends ConsumerStatefulWidget {
  final ListingModel listing;
  const _ReadyLabeler({required this.listing});
  @override
  ConsumerState<_ReadyLabeler> createState() => _ReadyLabelerState();
}

class _ReadyLabelerState extends ConsumerState<_ReadyLabeler> {
  late final Map<String, String> _labels = {for (final s in widget.listing.stills.where((x) => x.source == 'video')) s.url: s.label ?? ''};
  bool _busy = false;

  String _fmt(int? ms) {
    if (ms == null) return '';
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runAction(context, () => ref.read(functionsServiceProvider).updateStillLabels(listingId: widget.listing.id, labels: Map<String, String>.from(_labels)), success: 'Room names saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final stills = l.stills.where((s) => s.source == 'video').toList();
    final cov = coverageFromLabels(_labels.values.toList(), bedrooms: l.bedrooms, bathrooms: l.bathrooms, propertyType: l.propertyType, commercial: l.category == 'commercial');
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 24), children: [
      const PsHeadline('Name the rooms.', accent: 'Renters jump to them.'),
      const SizedBox(height: 8),
      Text('Pick the room each still shows. Renters get tappable chapters in your video, and a list of what it shows.', style: AppText.bodyMuted),
      const SizedBox(height: 16),
      for (final s in stills) ...[
        PsCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: AspectRatio(aspectRatio: 16 / 9, child: PsNetImage(s.url, semanticLabel: 'Still from your video at ${_fmt(s.timestampMs)}'))),
            const SizedBox(height: 10),
            Text('${_labels[s.url]!.isEmpty ? 'Not named' : _labels[s.url]!}${s.timestampMs != null ? ' · ${_fmt(s.timestampMs)}' : ''}', style: AppText.title),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in roomChoices(bedrooms: l.bedrooms, bathrooms: l.bathrooms))
                PsChip(r, selected: _labels[s.url] == r, onTap: () => setState(() => _labels[s.url] = _labels[s.url] == r ? '' : r)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (cov != null && cov.missing.isNotEmpty) PsNote('Not shown yet: ${cov.missing.map((m) => m.label).join(', ')}. Renters will see these as "not shown".', tone: PsTone.warning, icon: Icons.warning_amber_rounded),
      const SizedBox(height: 14),
      PsButton('Save room names', loading: _busy, onPressed: _save),
    ]);
  }
}
