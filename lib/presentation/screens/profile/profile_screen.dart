import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static String roleLabel(String r) => r == 'agent' ? 'Agent account' : r == 'landlord' ? 'Landlord account' : 'Renter account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final user = ref.watch(currentUserModelProvider).asData?.value;
    if (!signedIn) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(child: ListView(padding: kPagePadding, children: [
          Text('Account', style: AppText.h1.copyWith(fontSize: 34, color: AppColors.primary)),
          const SizedBox(height: 16),
          PsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sign in to Propsure', style: AppText.h3),
            const SizedBox(height: 6),
            Text('Save homes, book inspections and message agents.', style: AppText.small),
            const SizedBox(height: 14),
            PsButton('Sign in or create account', onPressed: () => context.push('/auth?redirect=/profile')),
          ])),
          const SizedBox(height: 12),
          PsRowGroup([
            PsListRow(icon: Icons.help_outline_rounded, title: 'Help & safety', onTap: () => context.push('/info/safety')),
            PsListRow(icon: Icons.settings_outlined, title: 'Settings', onTap: () => context.push('/settings')),
          ]),
        ])),
      );
    }
    final isAgent = user?.role == 'agent' || user?.role == 'landlord';
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
        Text('Account', style: AppText.h1.copyWith(fontSize: 34, color: AppColors.primary)),
        const SizedBox(height: 14),
        Row(children: [
          PsAvatar(url: user?.profilePhoto, name: user?.name ?? '', size: 80),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((user == null || user.name.trim().isEmpty) ? 'Your account' : user.name.trim().split(' ').first, style: AppText.h2),
            Text(roleLabel(user?.role ?? 'tenant'), style: AppText.bodyMuted),
          ])),
          PsLink('Edit profile', onTap: () => context.push('/profile/edit'), chevron: true),
        ]),
        const SizedBox(height: 16),
        PsRowGroup([
          PsListRow(icon: Icons.groups_outlined, title: isAgent ? 'Open agent workspace' : 'Switch to agent workspace', onTap: () => context.go(isAgent ? '/workspace' : '/profile/edit')),
        ]),
        const SizedBox(height: 12),
        PsRowGroup([
          PsListRow(icon: Icons.event_outlined, title: 'My inspections', onTap: () => context.push('/bookings')),
          PsListRow(icon: Icons.bookmark_border_rounded, title: 'Saved homes', onTap: () => context.go('/saved')),
          PsListRow(icon: Icons.notifications_none_rounded, title: 'Search alerts', onTap: () => context.push('/saved-searches')),
          PsListRow(icon: Icons.home_outlined, title: 'My home', onTap: () => context.push('/my-home')),
        ]),
        const SizedBox(height: 12),
        PsRowGroup([
          PsListRow(icon: Icons.shield_outlined, title: 'Verification', onTap: () => context.push('/verification')),
          PsListRow(icon: Icons.help_outline_rounded, title: 'Help & safety', onTap: () => context.push('/info/safety')),
          PsListRow(icon: Icons.settings_outlined, title: 'Settings', onTap: () => context.push('/settings')),
        ]),
        if (!isAgent) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primaryPale, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(children: [
              const PsIconCircle(Icons.home_work_outlined, size: 64),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('List a property', style: AppText.h3.copyWith(color: AppColors.primary)),
                Text('Landlord or agent? Start with a video.', style: AppText.small),
                const SizedBox(height: 8),
                PsButton('Get started', expand: false, onPressed: () => context.push('/whatsapp-assist')),
              ])),
            ]),
          ),
        ],
      ])),
    );
  }
}
