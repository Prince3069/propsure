import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

/// Notification toggles are saved to the user's `preferences` map. Low-data
/// and autoplay are device settings (local only).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  final _box = Hive.box('settings_box');
  Map<String, dynamic> _prefs = {};
  bool _seeded = false;

  bool _p(String k, bool d) => (_prefs[k] as bool?) ?? d;

  Future<void> _setPref(String k, bool v) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) { context.push('/auth?redirect=/settings'); return; }
    final next = {..._prefs, k: v};
    setState(() => _prefs = next);
    try {
      await ref.read(authServiceProvider).updateUserProfile(uid: uid, preferences: next);
    } catch (_) {
      if (mounted) showPsSnack(context, 'Could not save that setting.');
    }
  }

  Future<void> _sheet(String title, String message) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.h3), const SizedBox(height: 8), Text(message, style: AppText.body)]))),
      );

  Future<void> _autoplay() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Text('Autoplay tours', style: AppText.h3),
        for (final o in const [('wifi', 'Wi-Fi only'), ('never', 'Never')])
          ListTile(title: Text(o.$2), trailing: (_box.get('autoplay', defaultValue: 'wifi') == o.$1) ? const Icon(Icons.check_rounded, color: AppColors.primary) : null, onTap: () => Navigator.pop(c, o.$1)),
        const SizedBox(height: 8),
      ])),
    );
    if (v != null) setState(() => _box.put('autoplay', v));
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in with your phone number.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out'))],
      ),
    );
    if (ok != true) return;
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    if (user != null && !_seeded) {
      _seeded = true;
      // UserModel does not expose preferences; they are read once here.
      ref.read(authServiceProvider).getPreferences(user.uid).then((m) { if (mounted) setState(() => _prefs = m); });
    }
    final signedIn = ref.watch(isSignedInProvider);
    final autoplay = _box.get('autoplay', defaultValue: 'wifi') == 'never' ? 'Never' : 'Wi-Fi only';

    Widget head(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 8), child: Text(t, style: AppText.title.copyWith(color: AppColors.text2)));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Settings'),
      body: ListView(padding: kPagePadding, children: [
        head('Notifications'),
        PsRowGroup([
          PsToggleRow(icon: Icons.mail_outline_rounded, title: 'Messages', value: _p('messages', true), onChanged: (v) => _setPref('messages', v)),
          PsToggleRow(icon: Icons.notifications_none_rounded, title: 'Inspection updates', value: _p('inspections', true), onChanged: (v) => _setPref('inspections', v)),
          PsToggleRow(icon: Icons.search_rounded, title: 'Search alerts', value: _p('searchAlerts', true), onChanged: (v) => _setPref('searchAlerts', v)),
          PsToggleRow(icon: Icons.campaign_outlined, title: 'Marketing messages', value: _p('marketing', false), onChanged: (v) => _setPref('marketing', v)),
        ]),
        const Padding(padding: EdgeInsets.only(top: 8), child: PsNote('Push notifications are not switched on yet. Search alerts appear in your notifications. Your other choices are saved for when push is available.', icon: Icons.info_outline_rounded)),
        head('Video & data'),
        PsRowGroup([
          PsToggleRow(icon: Icons.signal_cellular_alt_rounded, title: 'Low-data mode', value: _box.get('lowData', defaultValue: true) as bool, onChanged: (v) => setState(() => _box.put('lowData', v))),
          PsListRow(icon: Icons.play_arrow_outlined, title: 'Autoplay tours', trailing: Text(autoplay, style: AppText.small), onTap: _autoplay),
        ]),
        head('Privacy & account'),
        PsRowGroup([
          PsListRow(icon: Icons.person_outline_rounded, title: 'Blocked accounts', onTap: () => _sheet('Blocked accounts', 'Blocking is not available yet. If someone is bothering you, report a concern from the listing or chat.')),
          PsListRow(icon: Icons.verified_user_outlined, title: 'Manage permissions', onTap: () => _sheet('Manage permissions', 'Camera, photos, notifications and location are controlled in your phone settings, under Propsure.')),
          if (signedIn) PsListRow(icon: Icons.delete_outline_rounded, title: 'Delete account', onTap: () => context.push('/support?topic=account_payment')),
        ]),
        const SizedBox(height: 12),
        PsRowGroup([
          PsListRow(icon: Icons.description_outlined, title: 'Terms & privacy', onTap: () => context.push('/legal/terms')),
          if (signedIn) PsListRow(icon: Icons.logout_rounded, title: 'Sign out', titleColor: AppColors.error, onTap: _signOut),
        ]),
        const SizedBox(height: 24),
      ]),
    );
  }
}
