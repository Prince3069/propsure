import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Asks the agent to confirm the home is available today, then publishes it.
/// Used from My listings and straight after frames are confirmed, so a draft
/// with a reviewed video can go live in one more tap.
Future<bool> askAndGoLive(BuildContext context, WidgetRef ref, String listingId, {String title = 'Go live?'}) async {
  var ok = false;
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Renters will see this home and the date you confirm it is available.'),
        CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: ok, onChanged: (v) => set(() => ok = v ?? false), title: const Text('This home is available today.')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not yet')),
        TextButton(onPressed: ok ? () => Navigator.pop(c, true) : null, child: const Text('Go live')),
      ],
    )),
  );
  if (go != true || !context.mounted) return false;
  return runAction(context, () => ref.read(functionsServiceProvider).publishListing(listingId), success: 'Your home is live.');
}
