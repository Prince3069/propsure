import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ps_widgets.dart';
import '../../providers/app_providers.dart';

/// Role-aware bottom navigation.
///   Renter: Discover · Tours · Saved · Inbox · Account
///   Agent:  Workspace · Listings · Leads · Inbox · Account
/// Switching role changes the work surface; it never grants privileged access
/// (listing and payment permissions are enforced by rules and Cloud Functions).
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _renter = [
    (path: '/home', item: PsNavItem(Icons.home_outlined, Icons.home_rounded, 'Discover')),
    (path: '/tours', item: PsNavItem(Icons.play_circle_outline_rounded, Icons.play_circle_rounded, 'Tours')),
    (path: '/saved', item: PsNavItem(Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Saved')),
    (path: '/messages', item: PsNavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Inbox')),
    (path: '/profile', item: PsNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Account')),
  ];

  static const _agent = [
    (path: '/workspace', item: PsNavItem(Icons.home_outlined, Icons.home_rounded, 'Workspace')),
    (path: '/my-listings', item: PsNavItem(Icons.article_outlined, Icons.article_rounded, 'Listings')),
    (path: '/leads', item: PsNavItem(Icons.groups_outlined, Icons.groups_rounded, 'Leads')),
    (path: '/messages', item: PsNavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Inbox')),
    (path: '/profile', item: PsNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Account')),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final isAgent = user?.isAgent ?? false;
    final tabs = isAgent ? _agent : _renter;
    final unread = ref.watch(totalUnreadProvider).asData?.value ?? 0;

    final loc = GoRouterState.of(context).matchedLocation;
    // A page that is not one of this role's tabs (for example an agent
    // browsing as a renter) highlights no tab instead of "Workspace".
    final index = tabs.indexWhere((t) => loc == t.path || loc.startsWith('${t.path}/'));

    final items = [
      for (final t in tabs)
        PsNavItem(t.item.icon, t.item.activeIcon, t.item.label, dot: t.path == '/messages' && unread > 0),
    ];

    void go(int i) => context.go(tabs[i].path);
    switch (Responsive.of(context)) {
      case ScreenSize.compact:
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: child,
          bottomNavigationBar: PsNavBar(items: items, index: index, onTap: go),
        );
      case ScreenSize.medium:
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Row(children: [
            _Rail(items: items, index: index, onTap: go),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(child: child),
          ]),
        );
      case ScreenSize.expanded:
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Column(children: [
            _TopNav(items: items, index: index, onTap: go, onBell: () => context.push('/notifications')),
            Expanded(child: child),
          ]),
        );
    }
  }
}

/// Tablet / small window: vertical rail with the same tabs.
class _Rail extends StatelessWidget {
  final List<PsNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  const _Rail({required this.items, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: NavigationRail(
        backgroundColor: AppColors.card,
        selectedIndex: index < 0 ? null : index,
        onDestinationSelected: onTap,
        labelType: NavigationRailLabelType.all,
        indicatorColor: AppColors.primaryPale,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        selectedLabelTextStyle: AppText.small.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: AppText.small,
        leading: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Icon(Icons.home_work_outlined, color: AppColors.primary, size: 30)),
        destinations: [
          for (final it in items)
            NavigationRailDestination(
              icon: Badge(isLabelVisible: it.dot, backgroundColor: AppColors.gold, smallSize: 9, child: Icon(it.icon)),
              selectedIcon: Badge(isLabelVisible: it.dot, backgroundColor: AppColors.gold, smallSize: 9, child: Icon(it.activeIcon)),
              label: Text(it.label),
            ),
        ],
      ),
    );
  }
}

/// Desktop: logo, tabs and notifications across the top.
class _TopNav extends StatelessWidget {
  final List<PsNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onBell;
  const _TopNav({required this.items, required this.index, required this.onTap, required this.onBell});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: ContentFrame(
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(children: [
                const Icon(Icons.home_work_outlined, color: AppColors.primary, size: 30),
                const SizedBox(width: 8),
                Text('Propsure', style: AppText.h2.copyWith(color: AppColors.primary, fontSize: 24)),
                const SizedBox(width: 36),
                for (var i = 0; i < items.length; i++)
                  Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].label,
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onTap(i),
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: i == index ? AppColors.primaryPale : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(i == index ? items[i].activeIcon : items[i].icon, size: 20, color: i == index ? AppColors.primary : AppColors.text2),
                          const SizedBox(width: 8),
                          Text(items[i].label, style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: i == index ? AppColors.primary : AppColors.text2)),
                          if (items[i].dot) ...[const SizedBox(width: 6), Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle))],
                        ]),
                      ),
                    ),
                  ),
                const Spacer(),
                PsIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onPressed: onBell),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
