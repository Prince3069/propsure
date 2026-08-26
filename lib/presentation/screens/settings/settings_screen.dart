import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications   = true;
  bool _emailNotifications  = true;
  bool _smsNotifications    = true;
  bool _newMessages         = true;
  bool _bookingUpdates      = true;
  bool _priceDropAlerts     = true;
  bool _marketingEmails     = false;

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final user       = ref.watch(currentUserModelProvider).value;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        children: [
          if (isSignedIn && user != null) ...[
            // Account section
            _SectionHeader('Account'),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              color: AppColors.primaryPale,
              iconColor: AppColors.primary,
              title: 'Edit Profile',
              subtitle: user.name,
              onTap: () => context.push('/profile/edit'),
            ),
            _SettingsTile(
              icon: Icons.verified_outlined,
              color: AppColors.primaryPale,
              iconColor: AppColors.primary,
              title: 'Verification',
              subtitle: user.isVerified ? 'Verified ✓' : 'Get verified',
              badgeColor: user.isVerified ? AppColors.success : null,
              badgeText: user.isVerified ? 'Verified' : null,
              onTap: () => context.push('/verification'),
            ),
            _SettingsTile(
              icon: Icons.workspace_premium_outlined,
              color: const Color(0xFFFEF3C7),
              iconColor: AppColors.gold,
              title: 'Premium Plans',
              subtitle: 'Upgrade for more features',
              onTap: () => context.push('/payment/premium'),
            ),
            _SettingsTile(
              icon: Icons.home_outlined,
              color: AppColors.primaryPale,
              iconColor: AppColors.primary,
              title: 'My Listings',
              onTap: () => context.push('/profile/listings'),
            ),
            _SettingsTile(
              icon: Icons.favorite_border_rounded,
              color: const Color(0xFFFEE2E2),
              iconColor: AppColors.error,
              title: 'Saved Properties',
              onTap: () => context.push('/saved'),
            ),
            const Divider(height: 1),
          ],

          // Notifications section
          _SectionHeader('Notifications'),
          _SwitchTile(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.info,
            title: 'Push Notifications',
            subtitle: 'In-app alerts',
            value: _pushNotifications,
            onChanged: (v) => setState(() => _pushNotifications = v),
          ),
          _SwitchTile(
            icon: Icons.email_outlined,
            iconColor: AppColors.primary,
            title: 'Email Notifications',
            subtitle: 'Booking and enquiry emails',
            value: _emailNotifications,
            onChanged: (v) => setState(() => _emailNotifications = v),
          ),
          _SwitchTile(
            icon: Icons.sms_outlined,
            iconColor: const Color(0xFF059669),
            title: 'SMS Notifications',
            subtitle: 'Booking confirmations',
            value: _smsNotifications,
            onChanged: (v) => setState(() => _smsNotifications = v),
          ),
          const Divider(height: 1),

          // Alert preferences
          _SectionHeader('Alert Preferences'),
          _SwitchTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: AppColors.primary,
            title: 'New Messages',
            value: _newMessages,
            onChanged: (v) => setState(() => _newMessages = v),
          ),
          _SwitchTile(
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.gold,
            title: 'Booking Updates',
            value: _bookingUpdates,
            onChanged: (v) => setState(() => _bookingUpdates = v),
          ),
          _SwitchTile(
            icon: Icons.trending_down_rounded,
            iconColor: const Color(0xFF059669),
            title: 'Price Drop Alerts',
            subtitle: 'On saved properties',
            value: _priceDropAlerts,
            onChanged: (v) => setState(() => _priceDropAlerts = v),
          ),
          _SwitchTile(
            icon: Icons.campaign_outlined,
            iconColor: AppColors.text3,
            title: 'Marketing Emails',
            subtitle: 'Tips and promotions',
            value: _marketingEmails,
            onChanged: (v) => setState(() => _marketingEmails = v),
          ),
          const Divider(height: 1),

          // App section
          _SectionHeader('App'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            color: AppColors.primaryPale,
            iconColor: AppColors.primary,
            title: 'About Propsure',
            onTap: () => context.push('/info/about'),
          ),
          _SettingsTile(
            icon: Icons.quiz_outlined,
            color: const Color(0xFFFEF3C7),
            iconColor: AppColors.gold,
            title: 'FAQ',
            onTap: () => context.push('/info/faq'),
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            color: AppColors.primaryPale,
            iconColor: AppColors.primary,
            title: 'Safety Tips',
            onTap: () => context.push('/info/safety'),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            color: AppColors.primaryPale,
            iconColor: AppColors.primary,
            title: 'How We Verify Agents',
            onTap: () => context.push('/info/how-we-verify'),
          ),
          _SettingsTile(
            icon: Icons.support_agent_outlined,
            color: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            title: 'Contact Support',
            onTap: () => context.push('/info/contact'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            color: AppColors.bg,
            iconColor: AppColors.text2,
            title: 'Privacy Policy',
            onTap: () => context.push('/info/privacy'),
          ),
          _SettingsTile(
            icon: Icons.article_outlined,
            color: AppColors.bg,
            iconColor: AppColors.text2,
            title: 'Terms of Service',
            onTap: () => context.push('/info/terms'),
          ),
          const Divider(height: 1),

          // Danger zone
          if (isSignedIn) ...[
            _SectionHeader('Account Actions'),
            _SettingsTile(
              icon: Icons.logout_rounded,
              color: const Color(0xFFFEE2E2),
              iconColor: AppColors.error,
              title: 'Sign Out',
              titleColor: AppColors.error,
              onTap: () => _confirmSignOut(context),
            ),
            const SizedBox(height: 24),
          ] else ...[
            _SectionHeader('Account'),
            _SettingsTile(
              icon: Icons.login_rounded,
              color: AppColors.primaryPale,
              iconColor: AppColors.primary,
              title: 'Sign In / Create Account',
              onTap: () => context.push('/auth'),
            ),
            const SizedBox(height: 24),
          ],

          // Version
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Text('Propsure v1.0.0',
                style: const TextStyle(fontSize: 12, color: AppColors.text3)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
              if (mounted) context.go('/home');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
        letterSpacing: 1.2, color: AppColors.text3, height: 1)),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color, iconColor;
  final String title;
  final String? subtitle, badgeText;
  final Color? badgeColor, titleColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon, required this.color, required this.iconColor,
    required this.title, this.subtitle, this.badgeText, this.badgeColor,
    this.titleColor, this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
          color: titleColor ?? AppColors.text)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.text3))
          : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (badgeText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99)),
            child: Text(badgeText!,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: badgeColor ?? AppColors.primary)),
          ),
          const SizedBox(width: 6),
        ],
        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.text3),
      ]),
      onTap: onTap,
    ),
  );
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon, required this.iconColor, required this.title,
    this.subtitle, required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.text3))
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    ),
  );
}
