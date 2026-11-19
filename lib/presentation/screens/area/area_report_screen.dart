import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/area.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Add what you know about an area: fixed answers, all optional, at least one.
class AreaReportScreen extends ConsumerStatefulWidget {
  final String city;
  final String area;
  const AreaReportScreen({super.key, required this.city, required this.area});
  @override
  ConsumerState<AreaReportScreen> createState() => _AreaReportState();
}

class _AreaReportState extends ConsumerState<AreaReportScreen> {
  final Map<String, String> _answers = {};
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(functionsServiceProvider).submitAreaReport(city: widget.city, area: widget.area, answers: Map<String, String>.from(_answers)),
      success: 'Thank you. Your report is added.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.canPop() ? context.pop() : context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Add what you know'),
      body: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 32), children: [
        Text('About ${widget.area}. Takes about 20 seconds. Only share what you have seen yourself.', style: AppText.bodyMuted),
        const SizedBox(height: 8),
        for (final t in kAreaTopics) ...[
          const SizedBox(height: 18),
          Text(t.question, style: AppText.title),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in t.options)
              PsChip(o.label, selected: _answers[t.key] == o.value, onTap: () => setState(() {
                    if (_answers[t.key] == o.value) {
                      _answers.remove(t.key);
                    } else {
                      _answers[t.key] = o.value;
                    }
                  })),
          ]),
        ],
        const SizedBox(height: 22),
        const PsNote('Your name is not shown. Each report is dated, and a newer report from you replaces your older one. You cannot report on an area where you have a home listed.'),
        const SizedBox(height: 16),
        PsButton('Submit report', loading: _busy, onPressed: _answers.isEmpty ? null : _submit),
      ]),
    );
  }
}
