import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
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
    var index = tabs.indexWhere((t) => loc == t.path || loc.startsWith('${t.path}/'));
    if (index < 0) index = 0;

    final items = [
      for (final t in tabs)
        PsNavItem(t.item.icon, t.item.activeIcon, t.item.label, dot: t.path == '/messages' && unread > 0),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: child,
      bottomNavigationBar: PsNavBar(
        items: items,
        index: index,
        onTap: (i) => context.go(tabs[i].path),
      ),
    );
  }
}
