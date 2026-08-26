// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _routes = [
    '/home',
    '/search',
    '/listing/upload',
    '/messages',
    '/profile'
  ];
  static const _authRequired = {'/listing/upload', '/messages', '/profile'};

  int _idx(BuildContext ctx) {
    final loc = GoRouterState.of(ctx).matchedLocation;
    for (int i = 0; i < _routes.length; i++) {
      if (loc.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  void _tap(BuildContext ctx, WidgetRef ref, int i) {
    if (_authRequired.contains(_routes[i]) && !ref.read(isSignedInProvider)) {
      ctx.push('/auth?redirect=${Uri.encodeComponent(_routes[i])}');
      return;
    }
    ctx.go(_routes[i]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _idx(context);
    final unread = ref.watch(totalUnreadProvider).value ?? 0;
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);

    if (isDesktop || isTablet) {
      return _WideLayout(
        idx: idx,
        onTap: (i) => _tap(context, ref, i),
        unread: unread,
        isDesktop: isDesktop,
        child: child,
      );
    }

    return Scaffold(
      drawer: const _PropsureDrawer(),
      body: child,
      bottomNavigationBar: _BottomNav(
          idx: idx, unread: unread, onTap: (i) => _tap(context, ref, i)),
    );
  }
}

// ─── BOTTOM NAV (Mobile) ───────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int idx;
  final int unread;
  final ValueChanged<int> onTap;
  const _BottomNav(
      {required this.idx, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                  icon: Icons.home_outlined,
                  selIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: idx == 0,
                  onTap: () => onTap(0)),
              _NavItem(
                  icon: Icons.search_outlined,
                  selIcon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: idx == 1,
                  onTap: () => onTap(1)),
              // Centre POST button
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 26),
                        ),
                      ]),
                ),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                selIcon: Icons.chat_bubble_rounded,
                label: 'Chats',
                isSelected: idx == 3,
                badge: unread,
                onTap: () => onTap(3),
              ),
              _NavItem(
                  icon: Icons.person_outline_rounded,
                  selIcon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: idx == 4,
                  onTap: () => onTap(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, selIcon;
  final String label;
  final bool isSelected;
  final int badge;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.selIcon,
      required this.label,
      required this.isSelected,
      this.badge = 0,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(alignment: Alignment.center, children: [
            Icon(isSelected ? selIcon : icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.text3),
            if (badge > 0)
              Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: Center(
                        child: Text('$badge',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800))),
                  )),
          ]),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.text3,
              )),
        ]),
      ),
    );
  }
}

// ─── SLIDE-OUT DRAWER ─────────────────────────────────────────────────────
class _PropsureDrawer extends ConsumerWidget {
  const _PropsureDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final user = ref.watch(currentUserModelProvider).value;
    final isAgent = user?.role == AppConstants.roleAgent ||
        user?.role == AppConstants.roleLandlord;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppColors.surface,
      child: Column(children: [
        Container(
          color: AppColors.primaryPale,
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 14, 12, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const PropsureLogo(size: 28),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.text2, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primary,
                child: isSignedIn && user != null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'P',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17))
                    : const Icon(Icons.person_outline_rounded,
                        color: Colors.white, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      isSignedIn && user != null
                          ? user.name
                          : 'Welcome to Propsure',
                      style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text),
                    ),
                    Text(
                      isSignedIn && user != null
                          ? user.phone
                          : 'Find verified homes in Abuja',
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.text2),
                    ),
                  ])),
            ]),
          ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _DrawerSection('NAVIGATION', [
              _DrawerItem(
                  icon: Icons.home_outlined,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'Home',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/home');
                  }),
              _DrawerItem(
                  icon: Icons.search_outlined,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'Search',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/search');
                  }),
              _DrawerItem(
                  icon: Icons.add_home_outlined,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'List a Property',
                  subtitle: 'Post for free',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/listing/upload');
                  }),
              _DrawerItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'Messages',
                  badge: '3',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/messages');
                  }),
              _DrawerItem(
                  icon: Icons.favorite_border_rounded,
                  color: const Color(0xFFFEE2E2),
                  iconColor: AppColors.error,
                  label: 'Saved Properties',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/saved');
                  }),
              _DrawerItem(
                  icon: Icons.notifications_outlined,
                  color: const Color(0xFFEFF6FF),
                  iconColor: AppColors.info,
                  label: 'Notifications',
                  badge: '5',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/notifications');
                  }),
            ]),
            const Divider(height: 1),
            _DrawerSection('ACCOUNT', [
              _DrawerItem(
                  icon: Icons.person_outline_rounded,
                  color: AppColors.bg,
                  iconColor: AppColors.text2,
                  label: 'My Profile',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/profile');
                  }),
              _DrawerItem(
                  icon: Icons.calendar_today_outlined,
                  color: const Color(0xFFFEF3C7),
                  iconColor: AppColors.gold,
                  label: 'My Bookings',
                  subtitle: 'Inspection requests',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/bookings');
                  }),
              if (isAgent)
                _DrawerItem(
                    icon: Icons.home_outlined,
                    color: AppColors.primaryPale2,
                    iconColor: AppColors.primary,
                    label: 'My Listings',
                    subtitle: 'Manage properties',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/search');
                    }),
            ]),
            // Premium CTA
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined,
                    color: Colors.white, size: 22),
                title: Text('Go Premium Agent',
                    style: GoogleFonts.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                subtitle: const Text('Get featured · More visibility',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white60),
                onTap: () => Navigator.pop(context),
              ),
            ),
            const Divider(height: 1),
            _DrawerSection('BROWSE', [
              _DrawerItem(
                  icon: Icons.home_outlined,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'Houses for Rent',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/search?category=rent');
                  }),
              _DrawerItem(
                  icon: Icons.apartment_outlined,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'Houses for Sale',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/search?category=sale');
                  }),
              _DrawerItem(
                  icon: Icons.hotel_outlined,
                  color: const Color(0xFFEFF6FF),
                  iconColor: AppColors.info,
                  label: 'Short Stays',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/search?category=short-stay');
                  }),
              _DrawerItem(
                  icon: Icons.business_outlined,
                  color: AppColors.bg,
                  iconColor: AppColors.text2,
                  label: 'Commercial Spaces',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/search?category=commercial');
                  }),
              _DrawerItem(
                  icon: Icons.badge_outlined,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'Agent Directory',
                  subtitle: 'Find verified agents',
                  onTap: () => Navigator.pop(context)),
            ]),
            const Divider(height: 1),
            _DrawerSection('SUPPORT & INFO', [
              _DrawerItem(
                  icon: Icons.verified_user_outlined,
                  color: AppColors.primaryPale2,
                  iconColor: AppColors.primary,
                  label: 'How We Verify Agents',
                  subtitle: '5-step process',
                  onTap: () => Navigator.pop(context)),
              _DrawerItem(
                  icon: Icons.security_outlined,
                  color: const Color(0xFFFEF3C7),
                  iconColor: AppColors.gold,
                  label: 'Safety Tips',
                  onTap: () => Navigator.pop(context)),
              _DrawerItem(
                  icon: Icons.help_outline_rounded,
                  color: const Color(0xFFEFF6FF),
                  iconColor: AppColors.info,
                  label: 'FAQ',
                  onTap: () => Navigator.pop(context)),
              _DrawerItem(
                  icon: Icons.chat_outlined,
                  color: AppColors.bg,
                  iconColor: AppColors.text2,
                  label: 'Contact Us',
                  onTap: () => Navigator.pop(context)),
              _DrawerItem(
                  icon: Icons.info_outline_rounded,
                  color: AppColors.bg,
                  iconColor: AppColors.text2,
                  label: 'About Propsure',
                  onTap: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16),
            if (isSignedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/home');
                  },
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.error, size: 18),
                  label: const Text('Sign Out',
                      style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  final List<Widget> items;
  const _DrawerSection(this.label, this.items);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.text3,
                letterSpacing: 0.8)),
      ),
      ...items,
    ]);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color color, iconColor;
  final String label;
  final String? subtitle, badge;
  final VoidCallback onTap;
  const _DrawerItem(
      {required this.icon,
      required this.color,
      required this.iconColor,
      required this.label,
      this.subtitle,
      this.badge,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(fontSize: 10, color: AppColors.text3))
          : null,
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(99)),
              child: Text(badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            )
          : const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.text3),
      onTap: onTap,
    );
  }
}

// ─── WIDE LAYOUT (Tablet + Desktop) ──────────────────────────────────────
class _WideLayout extends ConsumerWidget {
  final int idx;
  final ValueChanged<int> onTap;
  final int unread;
  final bool isDesktop;
  final Widget child;
  const _WideLayout(
      {required this.idx,
      required this.onTap,
      required this.unread,
      required this.isDesktop,
      required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final user = ref.watch(currentUserModelProvider).value;
    final isAgent = user?.role == AppConstants.roleAgent ||
        user?.role == AppConstants.roleLandlord;

    return Scaffold(
      body: Row(children: [
        if (isDesktop)
          _DesktopSidebar(
              idx: idx,
              onTap: onTap,
              unread: unread,
              isSignedIn: isSignedIn,
              isAgent: isAgent)
        else
          _TabletRail(idx: idx, onTap: onTap, unread: unread),
        const VerticalDivider(width: 1, color: AppColors.border),
        Expanded(child: child),
      ]),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  final int unread;
  final bool isSignedIn, isAgent;
  const _DesktopSidebar(
      {required this.idx,
      required this.onTap,
      required this.unread,
      required this.isSignedIn,
      required this.isAgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: AppColors.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Logo
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          child: Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9)),
                child: const Center(
                    child: Text('🏡', style: TextStyle(fontSize: 18)))),
            const SizedBox(width: 9),
            Text('Propsure',
                style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.4)),
          ]),
        ),
        const Divider(height: 1),
        const SizedBox(height: 6),
        _SideItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: idx == 0,
            onTap: () => onTap(0)),
        _SideItem(
            icon: Icons.search_rounded,
            label: 'Search',
            selected: idx == 1,
            onTap: () => onTap(1)),
        _SideItem(
            icon: Icons.chat_bubble_rounded,
            label: 'Messages',
            selected: idx == 3,
            badge: unread,
            onTap: () => onTap(3)),
        _SideItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            selected: idx == 4,
            onTap: () => onTap(4)),
        const Spacer(),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: ElevatedButton.icon(
            onPressed: () => context.push('/listing/upload'),
            icon: const Icon(Icons.add_home_outlined, size: 18),
            label: const Text('List Property'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46)),
          ),
        ),
        if (!isSignedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/auth'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42)),
            ),
          ),
      ]),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _SideItem(
      {required this.icon,
      required this.label,
      required this.selected,
      this.badge = 0,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.text2),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected ? AppColors.primary : AppColors.text2))),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(99)),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _TabletRail extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  final int unread;
  const _TabletRail(
      {required this.idx, required this.onTap, required this.unread});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: idx > 3 ? idx - 1 : idx, // skip POST slot
      onDestinationSelected: (i) => onTap(i >= 2 ? i + 1 : i),
      labelType: NavigationRailLabelType.selected,
      backgroundColor: AppColors.surface,
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: const IconThemeData(color: AppColors.text3),
      selectedLabelTextStyle: const TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
      leading: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9)),
            child: const Center(
                child: Text('🏡', style: TextStyle(fontSize: 18)))),
      ),
      destinations: [
        const NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Home')),
        const NavigationRailDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: Text('Search')),
        NavigationRailDestination(
          icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline_rounded)),
          selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_rounded)),
          label: const Text('Chats'),
        ),
        const NavigationRailDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: Text('Profile')),
      ],
    );
  }
}
