import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/rooms.dart';
import '../../../core/utils/save_media.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';
import 'go_live.dart';
import 'tour_score.dart';

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
              actionLabel: 'See how to film a tour',
              onAction: () => context.push('/listing/record-guide'),
            );
          }
          if (l.videoStatus == VideoStatus.ready && l.stills.any((x) => x.source == 'video')) {
            return _ReadyLabeler(listing: l);
          }
          if (l.videoStatus != VideoStatus.needsReview) {
            return const PsEmpty(icon: Icons.check_circle_outline_rounded, title: 'Nothing to review', message: 'There are no frames waiting for your review.');
          }
          if (l.videoCandidates.isEmpty) {
            return const PsEmpty(icon: Icons.photo_camera_outlined, title: 'No clear frames found', message: 'The footage was too dark or blurry to suggest frames. Add real photos to your listing instead. We never invent images.');
          }
          return _ReviewBody(listing: l, onDiscard: () => _discard(l));
        },
      ),
    );
  }
}

String _fmtMs(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Frames grouped by the space they show (living room, kitchen…). Each space has
/// a wide frame and other views of it. The agent chooses, names, removes and
/// saves frames; nothing is published until they confirm.
class _ReviewBody extends ConsumerStatefulWidget {
  final ListingModel listing;
  final VoidCallback onDiscard;
  const _ReviewBody({required this.listing, required this.onDiscard});
  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  final Set<String> _chosen = {};
  final Set<String> _removed = {};
  final Map<int, String> _room = {}; // scene -> room name
  final Map<String, String> _detail = {}; // frame id -> detail (Oven, Sink…)
  String? _cover;
  bool _busy = false;
  bool _saving = false;
  bool _privacy = false;
  final Map<String, Future<String>> _urls = {};

  @override
  void initState() {
    super.initState();
    final cands = widget.listing.videoCandidates;
    // Start with the main (wide) view of every space chosen.
    _chosen.addAll(cands.where((c) => c.role == 'wide').map((c) => c.id));
    if (_chosen.isEmpty) _chosen.addAll(cands.take(3).map((c) => c.id));
    final firstChosen = cands.where((c) => _chosen.contains(c.id));
    _cover = firstChosen.isEmpty ? null : firstChosen.first.id;
  }

  Future<String> _url(String path) => _urls.putIfAbsent(path, () => ref.read(listingRepositoryProvider).candidateUrl(path));

  List<VideoCandidate> get _live => widget.listing.videoCandidates.where((c) => !_removed.contains(c.id)).toList();

  String _labelFor(VideoCandidate c) {
    final room = (_room[c.scene] ?? '').trim();
    if (room.isEmpty) return '';
    final d = (_detail[c.id] ?? '').trim();
    final full = d.isEmpty ? room : '$room · $d';
    return full.length > 32 ? full.substring(0, 32) : full;
  }

  Future<void> _preview(VideoCandidate c) async {
    final url = await _url(c.path);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: InteractiveViewer(minScale: 1, maxScale: 4, child: Image.network(url, fit: BoxFit.contain))),
          Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: Text('From your video at ${_fmtMs(c.timestampMs)}. Pinch to zoom.', style: AppText.caption)),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
          ])),
        ]),
      ),
    );
  }

  Future<void> _pickDetail(VideoCandidate c) async {
    final room = (_room[c.scene] ?? '').trim();
    final choices = detailChoices(roomKindOf(room));
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (s) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(room.isEmpty ? 'What does this view show?' : 'What does this view of the $room show?', style: AppText.title),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in choices) PsChip(d, selected: _detail[c.id] == d, onTap: () => Navigator.pop(s, d)),
            PsChip('No detail', selected: (_detail[c.id] ?? '').isEmpty, onTap: () => Navigator.pop(s, '')),
          ]),
        ]),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (picked.isEmpty) { _detail.remove(c.id); } else { _detail[c.id] = picked; _chosen.add(c.id); }
    });
  }

  Future<void> _saveToPhone() async {
    final ids = _chosen.where((id) => !_removed.contains(id)).toList();
    if (ids.isEmpty) { showPsSnack(context, 'Choose at least one frame to save.'); return; }
    setState(() => _saving = true);
    try {
      final byId = {for (final c in widget.listing.videoCandidates) c.id: c};
      final urls = <String>[];
      for (final id in ids) { final c = byId[id]; if (c != null) urls.add(await _url(c.path)); }
      await saveImagesToPhone(urls);
    } catch (e) {
      if (mounted) showPsSnack(context, 'We could not save the frames. Check your connection and try again.', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _confirm() async {
    final l = widget.listing;
    final ids = _chosen.where((id) => !_removed.contains(id)).toList();
    setState(() => _busy = true);
    final ok = await runAction(context, () => ref.read(functionsServiceProvider).confirmVideoFrames(
          listingId: l.id,
          frameIds: ids,
          coverId: _cover != null && ids.contains(_cover) ? _cover : null,
          labels: {
            for (final c in l.videoCandidates)
              if (ids.contains(c.id) && _labelFor(c).isNotEmpty) c.id: _labelFor(c),
          },
          privacyConfirmed: _privacy,
        ), success: 'Your frames are saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    // Confirming only attaches the frames. A draft still has to go live.
    if (l.isDraft) {
      final live = await askAndGoLive(context, ref, l.id, title: 'Frames saved. Go live now?');
      if (!mounted) return;
      if (!live) showPsSnack(context, 'Saved as a draft. Tap Publish on My listings when you are ready.');
    }
    if (mounted) context.pop();
  }

  Widget _coverageNote(ListingModel l) {
    final labels = [for (final c in _live) if (_chosen.contains(c.id)) _labelFor(c)];
    final sc = TourScore.fromLabels(labels, l);
    if (sc == null) {
      return const PsNote('Name each space and renters can jump straight to it in the video.', icon: Icons.meeting_room_outlined);
    }
    return TourScoreNote(listing: l, score: sc);
  }

  Widget _issuesCard(ListingModel l) {
    if (l.videoIssues.isEmpty) {
      return const PsNote('Good recording: steady, well lit and long enough.', tone: PsTone.success, icon: Icons.thumb_up_alt_outlined);
    }
    return PsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How your recording did', style: AppText.title),
        const SizedBox(height: 4),
        Text('Fix these next time (or film those parts again) so renters see every room clearly.', style: AppText.caption),
        const SizedBox(height: 10),
        for (final i in l.videoIssues) Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.flag_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('${_fmtMs(i.fromMs)} to ${_fmtMs(i.toMs)}: ${i.tip}', style: AppText.small)),
          ]),
        ),
        PsLink('How to film a perfect tour', onTap: () => context.push('/listing/record-guide')),
      ]),
    );
  }

  Widget _tile(VideoCandidate c) {
    final on = _chosen.contains(c.id);
    final isCover = _cover == c.id;
    return SizedBox(
      width: 148,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          button: true,
          selected: on,
          label: 'Frame at ${_fmtMs(c.timestampMs)}${isCover ? ', cover' : ''}. Tap to enlarge.',
          child: InkWell(
            onTap: () => _preview(c),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: on ? AppColors.primary : AppColors.border, width: on ? 3 : 1)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(fit: StackFit.expand, children: [
                  FutureBuilder<String>(future: _url(c.path), builder: (_, s) => PsNetImage(s.data, radius: BorderRadius.circular(AppRadius.sm - 2))),
                  Positioned(right: 4, top: 4, child: InkWell(
                    onTap: () => setState(() { on ? _chosen.remove(c.id) : _chosen.add(c.id); if (!_chosen.contains(c.id) && _cover == c.id) _cover = null; }),
                    child: CircleAvatar(radius: 15, backgroundColor: on ? AppColors.primary : Colors.white, child: Icon(on ? Icons.check_rounded : Icons.add_rounded, size: 18, color: on ? Colors.white : AppColors.text)),
                  )),
                  if (isCover) const Positioned(left: 6, top: 6, child: PsPill('Cover', tone: PsTone.neutral, small: true)),
                  Positioned(left: 6, bottom: 6, child: PsPill(_fmtMs(c.timestampMs), tone: PsTone.neutral, small: true)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _pickDetail(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text((_detail[c.id] ?? '').isEmpty ? (c.role == 'wide' ? 'Wide view · tap to name' : 'Tap to name this view') : _detail[c.id]!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ),
        Row(children: [
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Use as cover', onPressed: () => setState(() { _cover = c.id; _chosen.add(c.id); }), icon: Icon(isCover ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20, color: AppColors.primary)),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Delete this frame', onPressed: () => setState(() { _removed.add(c.id); _chosen.remove(c.id); if (_cover == c.id) _cover = null; }), icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.text3)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final live = _live;
    final scenes = <int, List<VideoCandidate>>{};
    for (final c in live) { scenes.putIfAbsent(c.scene, () => []).add(c); }
    final keys = scenes.keys.toList()..sort();
    final chosenCount = _chosen.where((id) => !_removed.contains(id)).length;
    final choices = roomChoices(bedrooms: l.bedrooms, bathrooms: l.bathrooms);
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 24), children: [
      const PsHeadline('Real frames.', accent: 'Your choice.'),
      const SizedBox(height: 8),
      const Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22), SizedBox(width: 8), Text('Processing complete')]),
      const SizedBox(height: 12),
      PsNote('Frames are grouped by space. Tap one to enlarge it. Lightly brightened and steadied. Nothing added.', icon: Icons.auto_fix_high_rounded),
      if (l.videoNeedsCheck) ...[const SizedBox(height: 12), const PsNote('This video needs a quick check by our team. You can still choose your frames now.', icon: Icons.fact_check_outlined)],
      if (l.videoCoverageWarning != null) ...[const SizedBox(height: 12), PsNote(l.videoCoverageWarning!, tone: PsTone.warning, icon: Icons.warning_amber_rounded)],
      const SizedBox(height: 12),
      _issuesCard(l),
      const SizedBox(height: 16),
      for (var n = 0; n < keys.length; n++) ...[
        PsCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Space ${n + 1}${(_room[keys[n]] ?? '').isNotEmpty ? ' · ${_room[keys[n]]}' : ''}', style: AppText.title)),
              PsPill('${_fmtMs(scenes[keys[n]]!.first.timestampMs)} to ${_fmtMs(scenes[keys[n]]!.last.timestampMs)}', tone: PsTone.neutral, small: true),
            ]),
            const SizedBox(height: 4),
            Text('Which room is this?', style: AppText.caption),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in choices) PsChip(r, selected: (_room[keys[n]] ?? '') == r, onTap: () => setState(() { _room[keys[n]] = (_room[keys[n]] == r) ? '' : r; })),
            ]),
            const SizedBox(height: 10),
            PsField(
              key: ValueKey('room_${keys[n]}_${_room[keys[n]] ?? ''}'),
              label: 'Or type a name (optional)',
              hint: 'Study, Store, Balcony…',
              maxLength: 20,
              initialValue: _room[keys[n]],
              onChanged: (v) => _room[keys[n]] = v,
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 6, children: [for (final c in scenes[keys[n]]!) _tile(c)]),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (keys.isEmpty) const PsNote('You removed every frame. Choose a frame from your video again, or add real photos to your listing.', tone: PsTone.warning, icon: Icons.warning_amber_rounded),
      _coverageNote(l),
      const SizedBox(height: 12),
      const PsNote('Missing a room? Add a real photo. We do not invent images.'),
      const SizedBox(height: 10),
      PsListRow(icon: Icons.play_circle_outline_rounded, title: 'How to film a perfect tour', onTap: () => context.push('/listing/record-guide'), padding: const EdgeInsets.all(12)),
      const SizedBox(height: 14),
      PsCheckTile('No faces, number plates or documents are visible in the frames I chose', value: _privacy, onChanged: (v) => setState(() => _privacy = v)),
      const SizedBox(height: 4),
      Text('If a frame shows any of these, delete it with the bin icon.', style: AppText.caption),
      const SizedBox(height: 12),
      PsButton('Save chosen frames to my phone', kind: PsButtonKind.outline, icon: Icons.download_rounded, loading: _saving, onPressed: chosenCount == 0 ? null : _saveToPhone),
      const SizedBox(height: 10),
      PsButton(l.isDraft ? 'Use these frames ($chosenCount) and publish' : 'Use these frames ($chosenCount)', loading: _busy, onPressed: (!_privacy || (chosenCount == 0 && l.images.isEmpty)) ? null : _confirm),
      const SizedBox(height: 8),
      Center(child: PsLink('Remove this video', underline: false, onTap: widget.onDiscard)),
    ]);
  }
}


/// For a video that is already published: name the rooms, delete a frame, and
/// save the frames or the video to the phone.
class _ReadyLabeler extends ConsumerStatefulWidget {
  final ListingModel listing;
  const _ReadyLabeler({required this.listing});
  @override
  ConsumerState<_ReadyLabeler> createState() => _ReadyLabelerState();
}

class _ReadyLabelerState extends ConsumerState<_ReadyLabeler> {
  late final Map<String, String> _labels = {for (final s in widget.listing.stills.where((x) => x.source == 'video')) s.url: s.label ?? ''};
  final Set<String> _deleted = {};
  bool _busy = false;
  bool _saving = false;

  String _fmt(int? ms) => ms == null ? '' : _fmtMs(ms);

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runAction(context, () => ref.read(functionsServiceProvider).updateStillLabels(listingId: widget.listing.id, labels: Map<String, String>.from(_labels)), success: 'Room names saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }

  Future<void> _delete(ListingStill s) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this frame?'),
        content: const Text('It is removed from your listing. Your video is not affected.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await runAction(context, () => ref.read(functionsServiceProvider).deleteStill(listingId: widget.listing.id, url: s.url), success: 'Frame deleted.');
    if (ok && mounted) setState(() { _deleted.add(s.url); _labels.remove(s.url); });
  }

  Future<void> _saveFrames(List<ListingStill> stills) async {
    setState(() => _saving = true);
    try {
      await saveImagesToPhone([for (final s in stills) s.url]);
    } catch (_) {
      if (mounted) showPsSnack(context, 'We could not save the frames. Check your connection and try again.', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveVideo(String url) async {
    setState(() => _saving = true);
    try {
      await saveVideoToPhone(url);
    } catch (_) {
      if (mounted) showPsSnack(context, 'We could not save the video. Check your connection and try again.', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final stills = l.stills.where((s) => s.source == 'video' && !_deleted.contains(s.url)).toList();
    final cov = coverageFromLabels(_labels.values.toList(), bedrooms: l.bedrooms, bathrooms: l.bathrooms, propertyType: l.propertyType, commercial: l.category == 'commercial');
    final room0 = (String label) => baseRoomLabel(label);
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 24), children: [
      const PsHeadline('Name the rooms.', accent: 'Renters jump to them.'),
      const SizedBox(height: 8),
      Text('Pick the room each still shows. Renters get tappable chapters in your video, and a list of what it shows.', style: AppText.bodyMuted),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: PsButton('Save frames', kind: PsButtonKind.outline, icon: Icons.download_rounded, loading: _saving, onPressed: stills.isEmpty ? null : () => _saveFrames(stills))),
        if (l.videoUrl != null) ...[
          const SizedBox(width: 12),
          Expanded(child: PsButton('Save video', kind: PsButtonKind.outline, icon: Icons.video_file_outlined, loading: _saving, onPressed: () => _saveVideo(l.videoUrl!))),
        ],
      ]),
      const SizedBox(height: 16),
      for (final s in stills) ...[
        PsCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: AspectRatio(aspectRatio: 16 / 9, child: PsNetImage(s.url, semanticLabel: 'Still from your video at ${_fmt(s.timestampMs)}'))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text('${(_labels[s.url] ?? '').isEmpty ? 'Not named' : _labels[s.url]!}${s.timestampMs != null ? ' · ${_fmt(s.timestampMs)}' : ''}', style: AppText.title)),
              IconButton(tooltip: 'Delete this frame', onPressed: () => _delete(s), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.text3)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in roomChoices(bedrooms: l.bedrooms, bathrooms: l.bathrooms))
                PsChip(r, selected: room0(_labels[s.url] ?? '') == r, onTap: () => setState(() {
                  final cur = _labels[s.url] ?? '';
                  final detail = cur.contains('·') ? cur.substring(cur.indexOf('·') + 1).trim() : '';
                  _labels[s.url] = room0(cur) == r ? '' : (detail.isEmpty ? r : '$r · $detail');
                })),
            ]),
            if (room0(_labels[s.url] ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in detailChoices(roomKindOf(room0(_labels[s.url]!))))
                  PsChip(d, selected: (_labels[s.url] ?? '').endsWith('· $d'), onTap: () => setState(() {
                    final base = room0(_labels[s.url]!);
                    _labels[s.url] = (_labels[s.url] ?? '').endsWith('· $d') ? base : '$base · $d';
                  })),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (cov != null) TourScoreNote(listing: l, score: TourScore(cov.shownCount, cov.total, [for (final m in cov.missing) m.label])),
      const SizedBox(height: 14),
      PsButton('Save room names', loading: _busy, onPressed: _save),
    ]);
  }
}
