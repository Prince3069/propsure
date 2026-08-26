import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_theme.dart';
import '../../providers/app_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  File? _avatarFile;
  bool _loading = false;
  bool _init = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _bioCtrl.dispose(); _agencyCtrl.dispose();
    super.dispose();
  }

  void _initFrom(dynamic user) {
    if (_init) return;
    _init = true;
    _nameCtrl.text = user.name ?? '';
    _emailCtrl.text = user.email ?? '';
    _bioCtrl.text = user.bio ?? '';
    _agencyCtrl.text = user.agencyName ?? '';
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _save(dynamic user) async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await ref.read(authServiceProvider).updateUserProfile(
      uid: user.uid,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      agencyName: _agencyCtrl.text.trim(),
      avatarFile: _avatarFile,
    );
    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        actions: [
          userAsync.whenOrNull(data: (user) => TextButton(
            onPressed: _loading ? null : () => _save(user),
            child: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14)),
          )) ?? const SizedBox.shrink(),
          const SizedBox(width: 8),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          _initFrom(user);
          final isAgent = user.role == 'agent' || user.role == 'landlord';

          return ListView(padding: const EdgeInsets.all(20), children: [
            // Avatar picker
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: AppColors.primaryPale2,
                    backgroundImage: _avatarFile != null
                        ? FileImage(_avatarFile!) as ImageProvider
                        : (user.profilePhoto != null && user.profilePhoto!.isNotEmpty
                            ? NetworkImage(user.profilePhoto!) : null),
                    child: _avatarFile == null && (user.profilePhoto == null || user.profilePhoto!.isEmpty)
                        ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary, fontSize: 38, fontWeight: FontWeight.w800))
                        : null,
                  ),
                  Positioned(bottom: 3, right: 3,
                    child: Container(width: 30, height: 30,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15))),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('Tap to change photo',
              style: const TextStyle(fontSize: 12, color: AppColors.text3))),
            const SizedBox(height: 28),

            _SectLabel('FULL NAME*'),
            _Field(ctrl: _nameCtrl, icon: Icons.person_outline, hint: 'Your full name'),
            const SizedBox(height: 14),

            _SectLabel('EMAIL'),
            _Field(ctrl: _emailCtrl, icon: Icons.email_outlined, hint: 'your@email.com', type: TextInputType.emailAddress),
            const SizedBox(height: 14),

            _SectLabel('BIO'),
            _Field(ctrl: _bioCtrl, icon: Icons.info_outline, hint: 'Tell people about yourself…', maxLines: 3, maxLength: 300),
            const SizedBox(height: 14),

            if (isAgent) ...[
              _SectLabel('AGENCY / COMPANY NAME'),
              _Field(ctrl: _agencyCtrl, icon: Icons.business_outlined, hint: 'e.g. Propsure Realty Ltd'),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _save(user),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save Changes', style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 15)),
              )),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load profile')),
      ),
    );
  }
}

class _SectLabel extends StatelessWidget {
  final String text;
  const _SectLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.text3, letterSpacing: 0.6)));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final IconData icon;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? type;
  const _Field({required this.ctrl, required this.icon, required this.hint, this.maxLines = 1, this.maxLength, this.type});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
    decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 14), child: Icon(icon, size: 18, color: AppColors.text2)),
      const SizedBox(width: 10),
      Expanded(child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: type,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: hint, border: InputBorder.none,
          enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          filled: false, fillColor: Colors.transparent,
        ),
        style: const TextStyle(fontSize: 13),
      )),
    ]),
  );
}
