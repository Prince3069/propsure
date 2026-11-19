import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/city_provider.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../../core/utils/upload.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _agency = TextEditingController();
  final _bio = TextEditingController();
  String _city = 'Abuja';
  String _role = 'tenant';
  XFile? _photo;
  bool _loaded = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _agency, _bio]) { c.dispose(); }
    super.dispose();
  }

  static String _roleName(String r) => r == 'agent' ? 'Agent' : r == 'landlord' ? 'Landlord' : 'Renter';

  String _maskPhone(String p) {
    if (p.length < 8) return p;
    return '${p.substring(0, p.length - 7)} *** ${p.substring(p.length - 4)}';
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (x != null) setState(() => _photo = x);
  }

  Future<void> _changeRole() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Text('Account type', style: AppText.h3),
        for (final r in const ['tenant', 'agent', 'landlord']) ListTile(title: Text(_roleName(r)), trailing: _role == r ? const Icon(Icons.check_rounded, color: AppColors.primary) : null, onTap: () => Navigator.pop(c, r)),
        const SizedBox(height: 8),
      ])),
    );
    if (r != null) setState(() => _role = r);
  }

  Future<void> _save() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    if (_name.text.trim().length < 2) { setState(() => _error = 'Enter your full name.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authServiceProvider).updateUserProfile(
            uid: uid,
            name: _name.text.trim(),
            email: _email.text.trim(),
            bio: _bio.text.trim(),
            agencyName: _agency.text.trim(),
            city: _city,
            role: _role,
            avatarXFile: _photo,
          );
      if (!mounted) return;
      showPsSnack(context, 'Profile saved');
      context.pop();
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'We could not save your changes. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    if (user != null && !_loaded) {
      _loaded = true;
      _name.text = user.name;
      _email.text = user.email ?? '';
      _agency.text = user.agencyName ?? '';
      _bio.text = user.bio ?? '';
      _role = ['tenant', 'agent', 'landlord'].contains(user.role) ? user.role : 'tenant';
    }
    final isPro = _role != 'tenant';
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Edit profile'),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: kPagePadding, children: [
              Center(child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  _photo != null
                      ? ClipOval(child: XFileImage(_photo!, width: 112, height: 112))
                      : PsAvatar(url: user.profilePhoto, name: user.name, size: 112),
                  Positioned(right: -2, bottom: -2, child: Semantics(button: true, label: 'Change photo', child: InkWell(onTap: _pickPhoto, customBorder: const CircleBorder(), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 3)), child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 20))))),
                ]),
                const SizedBox(height: 8),
                PsLink('Change photo', onTap: _pickPhoto, underline: false),
              ])),
              const SizedBox(height: 16),
              PsField(label: 'Full name', controller: _name, textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              PsField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              PsCard(child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Phone', style: AppText.small), const SizedBox(height: 2), Text(_maskPhone(user.phone), style: AppText.title)])),
                if (user.isPhoneVerified) const PsPill('Confirmed', icon: Icons.check_circle_rounded, tone: PsTone.success),
              ])),
              const SizedBox(height: 12),
              PsDropdown<String>(label: 'City', value: _city, items: {for (final o in ref.watch(cityOptionsProvider)) if (o.open) o.name, _city}.toList(), itemLabel: (s) => s, onChanged: (v) => setState(() => _city = v ?? _city)),
              const SizedBox(height: 8),
              const PsNote('Your contact details are not shown publicly by default.', icon: Icons.info_outline_rounded),
              if (isPro) ...[
                const SizedBox(height: 12),
                PsField(label: 'Agency or business name (optional)', controller: _agency),
                const SizedBox(height: 12),
                PsField(label: 'About you', controller: _bio, maxLines: 4, maxLength: 300),
              ],
              const SizedBox(height: 12),
              PsCard(onTap: _changeRole, semanticLabel: 'Change account type', child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Account type', style: AppText.small), const SizedBox(height: 2), Text(_roleName(_role), style: AppText.h3)])),
                PsLink('Change', chevron: true, onTap: _changeRole, underline: false),
              ])),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600))),
              const SizedBox(height: 16),
              PsButton('Save changes', loading: _busy, onPressed: _save),
              const SizedBox(height: 24),
            ]),
    );
  }
}
