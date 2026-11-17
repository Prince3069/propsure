import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Optional, private post-move file: checklist, contacts, a reminder the user
/// chooses and notes. Nothing is imported from landlords and no rent
/// payments are implied. Stored at users/{uid}/home/file (owner-only rules).
class MyHomeScreen extends ConsumerStatefulWidget {
  const MyHomeScreen({super.key});
  @override
  ConsumerState<MyHomeScreen> createState() => _State();
}

class _State extends ConsumerState<MyHomeScreen> {
  DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = ref.read(currentUserIdProvider);
    return uid == null ? null : FirebaseFirestore.instance.collection('users').doc(uid).collection('home').doc('file');
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final r = _ref;
    if (r == null) return;
    await runAction(context, () => r.set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
  }

  static const _checklist = ['Photograph every room and any damage', 'Test taps, sockets and locks', 'Record the meter readings', 'Keep a copy of your signed agreement', 'Save the landlord and agent phone numbers'];

  Future<String?> _ask(String title, String label, {String hint = ''}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: PsField(label: label, controller: c, hint: hint, maxLines: 3),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _ref;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(),
      body: r == null
          ? const PsEmpty(icon: Icons.lock_outline_rounded, title: 'Sign in to use My home', message: 'Your home file is private to your account.')
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: r.snapshots(),
              builder: (context, snap) {
                final d = snap.data?.data() ?? const <String, dynamic>{};
                final done = List<int>.from(d['checklistDone'] ?? const []);
                final contacts = List<String>.from(d['contacts'] ?? const []);
                final notes = List<String>.from(d['notes'] ?? const []);
                final reminder = (d['reminderAt'] as Timestamp?)?.toDate();
                return ListView(padding: kPagePadding, children: [
                  Text('My home', style: AppText.display),
                  const SizedBox(height: 6),
                  const Align(alignment: Alignment.centerLeft, child: PsPill('Private', tone: PsTone.neutral, icon: Icons.lock_outline_rounded)),
                  const SizedBox(height: 14),
                  const PsHeadline('Your housing details,', accent: 'in one place.', size: 30),
                  const SizedBox(height: 16),
                  PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Move-in checklist', style: AppText.title),
                    Text('Record condition before settling in', style: AppText.caption),
                    for (var i = 0; i < _checklist.length; i++)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: done.contains(i),
                        title: Text(_checklist[i], style: AppText.body),
                        onChanged: (v) => _save({'checklistDone': v == true ? [...done, i] : done.where((x) => x != i).toList()}),
                      ),
                  ])),
                  const SizedBox(height: 12),
                  PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Contacts', style: AppText.title),
                    Text('Landlord, agent and useful numbers', style: AppText.caption),
                    for (final c in contacts) Padding(padding: const EdgeInsets.only(top: 8), child: Text(c, style: AppText.body)),
                    PsLink('Add a contact', underline: false, onTap: () async {
                      final v = await _ask('Add a contact', 'Name and number', hint: 'e.g. Landlord – 0801 234 5678');
                      if (v != null && v.isNotEmpty) _save({'contacts': [...contacts, v]});
                    }),
                  ])),
                  const SizedBox(height: 12),
                  PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Renewal reminder', style: AppText.title),
                    Text(reminder == null ? 'Choose your own date' : 'Reminder date: ${reminder.day}/${reminder.month}/${reminder.year}', style: AppText.caption),
                    PsLink(reminder == null ? 'Set a date' : 'Change date', underline: false, onTap: () async {
                      final now = DateTime.now();
                      final p = await showDatePicker(context: context, initialDate: reminder ?? now.add(const Duration(days: 300)), firstDate: now, lastDate: now.add(const Duration(days: 3650)));
                      if (p != null) _save({'reminderAt': Timestamp.fromDate(p)});
                    }),
                    Text('This is a note to yourself. Propsure does not contact your landlord or collect rent.', style: AppText.caption),
                  ])),
                  const SizedBox(height: 12),
                  PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Notes and issues', style: AppText.title),
                    for (final n in notes) Padding(padding: const EdgeInsets.only(top: 8), child: Text('• $n', style: AppText.body)),
                    PsLink('Add a note or issue', underline: false, onTap: () async {
                      final v = await _ask('Add a note or issue', 'Note');
                      if (v != null && v.isNotEmpty) _save({'notes': [...notes, v]});
                    }),
                  ])),
                  const SizedBox(height: 12),
                  const PsNote('Document copies are not available yet. Keep your agreement and receipts somewhere you control.', icon: Icons.folder_open_outlined),
                  const SizedBox(height: 24),
                ]);
              },
            ),
    );
  }
}
