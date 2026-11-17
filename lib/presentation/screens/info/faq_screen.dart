import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override
  State<FaqScreen> createState() => _FaqState();
}

class _Q {
  final String group, q, a;
  const _Q(this.group, this.q, this.a);
}

const _all = [
  _Q('Renting', 'What does ID checked mean?', 'The agent’s identity was reviewed. It does not prove ownership or guarantee a home.'),
  _Q('Renting', 'Why show a move-in total?', 'Rent is only part of what you pay up front. We add the fees the agent lists so you can compare homes fairly. If a fee is unknown, we say so instead of guessing.'),
  _Q('Renting', 'Can I inspect before paying?', 'Yes. Always inspect in person before you pay anything. Never pay rent or a deposit through Propsure; payments here are only for agent tools.'),
  _Q('Listing', 'How do I report a listing?', 'Open the listing and choose Report a concern. We review every report and tell you the outcome.'),
  _Q('Listing', 'What does “confirmed” availability mean?', 'The agent told us the home was still available on that date. Ask the agent before arranging a visit if it is not recent.'),
  _Q('Payments', 'What do paid plans buy?', 'Agent tools and promoted placement, clearly labelled Sponsored. Payment never buys verification and does not guarantee enquiries.'),
  _Q('Payments', 'Does Agent Pro renew automatically?', 'No. It is a fixed 30-day pass. You choose whether to buy again.'),
  _Q('Renting', 'Can I pause search alerts?', 'Yes. Open Search alerts from your account and switch an alert off, or turn off Search alerts in Settings.'),
];

class _FaqState extends State<FaqScreen> {
  String _group = 'Renting';
  String _search = '';
  int? _open = 0;

  @override
  Widget build(BuildContext context) {
    final list = _all.where((q) => _search.isEmpty ? q.group == _group : (q.q + q.a).toLowerCase().contains(_search.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(backLabel: 'Back'),
      body: ListView(padding: kPagePadding, children: [
        const PsHeadline('Questions,', accent: 'answered.', size: 36),
        const SizedBox(height: 16),
        PsField(label: '', hint: 'Search help', prefix: const Icon(Icons.search_rounded), onChanged: (v) => setState(() { _search = v.trim(); _open = null; })),
        const SizedBox(height: 12),
        if (_search.isEmpty) Wrap(spacing: 8, children: [for (final g in const ['Renting', 'Listing', 'Payments']) PsChip(g, selected: _group == g, onTap: () => setState(() { _group = g; _open = null; }))]),
        const SizedBox(height: 12),
        if (list.isEmpty) Text('No answers match that search.', style: AppText.bodyMuted),
        for (var i = 0; i < list.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: PsCard(
          onTap: () => setState(() => _open = _open == i ? null : i),
          semanticLabel: list[i].q,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(list[i].q, style: AppText.h3)), Icon(_open == i ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded)]),
            if (_open == i) Padding(padding: const EdgeInsets.only(top: 8), child: Text(list[i].a, style: AppText.body)),
          ]),
        )),
        const SizedBox(height: 8),
        PsCard(color: AppColors.primaryPale, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Still need help?', style: AppText.title), Text('Our team is here to assist you.', style: AppText.small)]))]),
          const SizedBox(height: 12),
          PsButton('Contact support', onPressed: () => context.push('/support')),
        ])),
        const SizedBox(height: 24),
      ]),
    );
  }
}
