import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

// ─── Unread notifications count ──────────────────────────────────────────
final _unreadNotifCountProvider =
    StreamProvider.family<int, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return const _GuestProfile();
    final userAsync = ref.watch(currentUserModelProvider);
    return userAsync.when(
      data: (user) =>
          user == null ? const _GuestProfile() : _SignedInProfile(user: user),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const _GuestProfile(),
    );
  }
}

// ─── GUEST PROFILE ────────────────────────────────────────────────────────
class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.syne(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 44,
                    color: AppColors.text3,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Your Profile',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to access your profile, save properties, track bookings and message agents.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/auth?redirect=/profile'),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      'Sign In / Create Account',
                      style: GoogleFonts.syne(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const Divider(),
                const SizedBox(height: 18),
                Text(
                  'Or continue browsing',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GuestTile(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      onTap: () => context.go('/search'),
                    ),
                    const SizedBox(width: 12),
                    _GuestTile(
                      icon: Icons.map_outlined,
                      label: 'Map',
                      onTap: () => context.go('/map'),
                    ),
                    const SizedBox(width: 12),
                    _GuestTile(
                      icon: Icons.home_outlined,
                      label: 'Home',
                      onTap: () => context.go('/home'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GuestTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SIGNED IN PROFILE ───────────────────────────────────────────────────
class _SignedInProfile extends ConsumerWidget {
  final dynamic user;

  const _SignedInProfile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAgent = user.role == AppConstants.roleAgent ||
        user.role == AppConstants.roleLandlord;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _ProfileHeader(user: user)),
          SliverToBoxAdapter(child: _ProfileBody(user: user, isAgent: isAgent)),
        ],
      ),
    );
  }
}

// ─── PROFILE HEADER ──────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final dynamic user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final isAgent = user.role == AppConstants.roleAgent ||
        user.role == AppConstants.roleLandlord;
    final isPremium = user.isPremium == true;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 14,
        16,
        18,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──
              Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryPale2,
                    backgroundImage: user.profilePhoto != null &&
                            user.profilePhoto.isNotEmpty
                        ? NetworkImage(user.profilePhoto)
                        : null,
                    child:
                        user.profilePhoto == null || user.profilePhoto.isEmpty
                            ? Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 32,
                                ),
                              )
                            : null,
                  ),
                  // Verified badge
                  if (user.isVerified == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  // Premium badge
                  if (isPremium)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.goldDark, AppColors.gold],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Text(
                          '⭐',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: GoogleFonts.syne(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.goldDark, AppColors.gold],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      user.phone,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.text2),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: AppColors.primaryPale2),
                          ),
                          child: Text(
                            _roleLabel(user.role),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (user.isVerified == true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    color: Colors.white, size: 9),
                                SizedBox(width: 3),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.text2, size: 20),
                onPressed: () => context.push('/profile/edit'),
              ),
            ],
          ),
          // ── Stats ──
          if (isAgent) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBox('${user.totalListings ?? 0}', 'Listings'),
                const SizedBox(width: 8),
                _StatBox(
                  user.rating != null ? user.rating!.toStringAsFixed(1) : '—',
                  'Rating',
                ),
                const SizedBox(width: 8),
                _StatBox('${user.reviewCount ?? 0}', 'Reviews'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case AppConstants.roleAgent:
        return 'Property Agent';
      case AppConstants.roleLandlord:
        return 'Landlord';
      default:
        return 'Tenant';
    }
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;

  const _StatBox(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.primaryPale,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.primaryPale2),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: AppColors.text2),
              ),
            ],
          ),
        ),
      );
}

// ─── PROFILE BODY ─────────────────────────────────────────────────────────
class _ProfileBody extends ConsumerWidget {
  final dynamic user;
  final bool isAgent;

  const _ProfileBody({required this.user, required this.isAgent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = user.isPremium == true;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Premium CTA ──
          if (!isPremium)
            GestureDetector(
              onTap: () => context.push('/payment/premium'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.goldDark, AppColors.gold],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.gold,
                ),
                child: Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Go Premium Agent',
                            style: GoogleFonts.syne(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Get featured · More visibility',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white60),
                  ],
                ),
              ),
            ),
          if (!isPremium) const SizedBox(height: 10),

          // ── Get Verified CTA ──
          if (user.isVerified != true && isAgent) ...[
            GestureDetector(
              onTap: () => context.push('/verification'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.sm,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: Colors.white, size: 25),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get Verified Agent Badge',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Build trust · Get more inquiries',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ─── MY ACTIVITY ──
          _MenuSection('MY ACTIVITY', [
            _MenuItem(
              Icons.home_outlined,
              AppColors.primaryPale2,
              AppColors.primary,
              'My Listings',
              badge: (user.totalListings ?? 0) > 0
                  ? '${user.totalListings}'
                  : null,
              onTap: () => context.push('/profile/listings'),
            ),
            _MenuItem(
              Icons.favorite_border_rounded,
              const Color(0xFFFEE2E2),
              AppColors.error,
              'Saved Properties',
              onTap: () => context.push('/saved'),
            ),
            Consumer(
              builder: (ctx, ref2, _) {
                final uid = ref2.watch(currentUserIdProvider);
                final pendingCount = uid != null
                    ? (ref2.watch(agentPendingCountProvider(uid)).value ?? 0)
                    : 0;
                return _MenuItem(
                  Icons.calendar_today_outlined,
                  const Color(0xFFFEF3C7),
                  AppColors.gold,
                  'Inspection Bookings',
                  badge: pendingCount > 0 ? '$pendingCount' : null,
                  onTap: () => context.push('/bookings'),
                );
              },
            ),
            Consumer(
              builder: (ctx, ref2, _) {
                final unread = ref2.watch(totalUnreadProvider).value ?? 0;
                return _MenuItem(
                  Icons.chat_bubble_outline_rounded,
                  AppColors.primaryPale2,
                  AppColors.primary,
                  'Messages',
                  badge: unread > 0 ? '$unread' : null,
                  onTap: () => context.go('/messages'),
                );
              },
            ),
          ]),
          const SizedBox(height: 10),

          // ─── ACCOUNT ──
          _MenuSection('ACCOUNT', [
            _MenuItem(
              Icons.verified_user_outlined,
              AppColors.primaryPale2,
              AppColors.primary,
              'Verification Status',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: user.isVerified == true
                      ? AppColors.primaryPale
                      : AppColors.bg,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  user.isVerified == true ? 'VERIFIED' : 'UNVERIFIED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: user.isVerified == true
                        ? AppColors.primary
                        : AppColors.text3,
                  ),
                ),
              ),
              onTap: () => context.push('/verification'),
            ),
            Consumer(
              builder: (ctx, ref2, _) {
                final uid = ref2.watch(currentUserIdProvider);
                final unreadNotifs = uid != null
                    ? ref2.watch(_unreadNotifCountProvider(uid)).value ?? 0
                    : 0;
                return _MenuItem(
                  Icons.notifications_outlined,
                  const Color(0xFFEFF6FF),
                  AppColors.info,
                  'Notifications',
                  badge: unreadNotifs > 0 ? '$unreadNotifs' : null,
                  onTap: () => context.push('/notifications'),
                );
              },
            ),
            _MenuItem(
              Icons.settings_outlined,
              AppColors.bg,
              AppColors.text2,
              'Settings',
              onTap: () => context.push('/settings'),
            ),
          ]),
          const SizedBox(height: 10),

          // ─── SUPPORT ──
          _MenuSection('SUPPORT & INFO', [
            _MenuItem(
              Icons.verified_user_outlined,
              AppColors.primaryPale2,
              AppColors.primary,
              'How We Verify Agents',
              onTap: () => context.push('/info/how-we-verify'),
            ),
            _MenuItem(
              Icons.security_outlined,
              const Color(0xFFFEF3C7),
              AppColors.gold,
              'Safety Tips',
              onTap: () => context.push('/info/safety'),
            ),
            _MenuItem(
              Icons.help_outline_rounded,
              const Color(0xFFEFF6FF),
              AppColors.info,
              'FAQ & Help',
              onTap: () => context.push('/info/faq'),
            ),
            _MenuItem(
              Icons.info_outline_rounded,
              AppColors.bg,
              AppColors.text2,
              'About Propsure',
              onTap: () => context.push('/info/about'),
            ),
          ]),
          const SizedBox(height: 14),

          // ─── SIGN OUT ──
          GestureDetector(
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/home');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFEE2E2)),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFFFF5F5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Sign Out',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── MENU SECTION ─────────────────────────────────────────────────────────
class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _MenuSection(this.title, this.items);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 7),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.text3,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: items
                  .asMap()
                  .entries
                  .map(
                    (e) => Column(
                      children: [
                        e.value,
                        if (e.key < items.length - 1)
                          const Divider(height: 1, indent: 58),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
}

// ─── MENU ITEM ────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color bgColor, iconColor;
  final String label;
  final String? badge;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem(
    this.icon,
    this.bgColor,
    this.iconColor,
    this.label, {
    this.badge,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            if (badge != null && badge!.isNotEmpty && badge != '0')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (trailing != null)
              trailing!
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.text3,
              ),
          ],
        ),
      ),
    );
  }
}
