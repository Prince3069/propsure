import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// How to film a home so renters see every room clearly. Plain advice only; it
/// works the same on a phone and in the browser.
class RecordGuideScreen extends StatelessWidget {
  const RecordGuideScreen({super.key});

  static const _before = [
    'Switch on every light and open all curtains. Film in daylight if you can (10am to 4pm).',
    'Wipe your phone camera lens with a clean cloth.',
    'Tidy up and put away personal items, documents and anything private.',
    'Switch on Do Not Disturb so a call does not interrupt the tour.',
    'Charge your phone and clear some storage. A 2 minute tour uses little space.',
  ];

  static const _moving = [
    'Walk slowly, about one step per second. Fast walking blurs the picture.',
    'Hold the phone with two hands at chest height and keep it level.',
    'Turn slowly. A full turn of a room should take 8 to 10 seconds.',
    'Stop for 2 to 3 seconds on each important thing: the cooker, the sink, the wardrobe, the shower.',
    'Do not zoom. Walk closer instead, so the picture stays sharp.',
    'Do not film into a bright window. Stand with the window beside or behind you.',
  ];

  static const _order = [
    ('Outside', 'Start at the gate or front of the building. Show the compound and parking.'),
    ('Living room', 'Stand in the doorway, turn slowly to show the whole room, then the windows and ceiling.'),
    ('Dining area', 'One slow turn, then pause on the table space.'),
    ('Kitchen', 'Wide view first. Then the gas cooker, the oven, the sink and the cabinets, 3 seconds each.'),
    ('Each bedroom', 'Wide view, then the wardrobe and the windows. Say "Bedroom 1" out loud so you can find it later.'),
    ('Each bathroom', 'Show the shower or bath, the toilet and the sink.'),
    ('Finish', 'End with the compound, balcony or the front of the house.'),
  ];

  static const _avoid = [
    'People, children, number plates and personal documents in view.',
    'Filming in the dark or with only one light on.',
    'Going fast between rooms. Walk through each door slowly.',
    'Very long videos. Keep it to 1 to 3 minutes. The limit is 3 minutes.',
  ];

  Widget _list(List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: AppText.body)),
              ]),
            ),
        ],
      );

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PsCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.h3),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: 'Film a perfect tour', onBack: () => context.canPop() ? context.pop() : context.go('/home')),
      body: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 32), children: [
        const PsHeadline('Film it once.', accent: 'Film it well.'),
        const SizedBox(height: 8),
        Text('A clear, steady video gets more enquiries. Follow these steps with your own phone. No special equipment needed.', style: AppText.bodyMuted),
        const SizedBox(height: 16),
        _section('Before you start', _list(_before)),
        _section('How to move', _list(_moving)),
        _section(
          'What to film, in order',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < _order.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 13, backgroundColor: AppColors.primary, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_order[i].$1, style: AppText.title),
                    Text(_order[i].$2, style: AppText.small),
                  ])),
                ]),
              ),
          ]),
        ),
        _section('Avoid', _list(_avoid)),
        const PsNote('What Propsure does with your video: we lightly brighten it, reduce noise and steady it. We never add rooms, furniture or anything that is not there, and your original stays private. We check the result and tell you what to film again.', icon: Icons.auto_fix_high_rounded),
        const SizedBox(height: 16),
        PsButton('Got it', onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
      ]),
    );
  }
}
