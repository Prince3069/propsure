// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/listing_model.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _typeFilter = 'All'; // All / Rent / Buy / Short Stay
  String _selectedArea = 'All Abuja';
  String _searchCity = 'Abuja (FCT)';

  static const _categories = [
    ('Flat / Apt', '🏠', 'Flat / Apartment'),
    ('Duplex', '🏘', 'Duplex'),
    ('Self Contain', '🛏', 'Self Contain'),
    ('Terrace', '🏗', 'Terraced House'),
    ('Bungalow', '🏡', 'Bungalow'),
    ('Detached', '🏢', 'Detached House'),
    ('Studio', '🛋', 'Studio'),
    ('Office', '🏣', 'Office Space'),
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(homeFeedProvider);
      },
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: _TopBar(
          typeFilter: _typeFilter,
          searchCity: _searchCity,
          onTypeTap: (t) => setState(() => _typeFilter = t),
          onCityTap: _showCityPicker,
          onSearchTap: () => context.push('/search'),
        )),
        SliverToBoxAdapter(
            child: _CategoriesSection(
          categories: _categories,
          typeFilter: _typeFilter,
        )),
        SliverToBoxAdapter(
            child: _FeaturedSection(
          typeFilter: _typeFilter == 'All' ? null : _typeFilter,
        )),
        SliverToBoxAdapter(
            child: _AreaChipsSection(
          selected: _selectedArea,
          onChanged: (a) {
            setState(() => _selectedArea = a);
            if (a != 'All Abuja') {
              context.push('/search?q=${Uri.encodeComponent(a)}');
            }
          },
        )),
        SliverToBoxAdapter(
            child: _VerifiedSection(
          typeFilter: _typeFilter == 'All' ? null : _typeFilter,
        )),
        SliverToBoxAdapter(child: _CTABanner()),
        SliverToBoxAdapter(
            child: _RecentSection(
          typeFilter: _typeFilter,
          areaFilter: _selectedArea == 'All Abuja' ? null : _selectedArea,
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CityPickerSheet(
        current: _searchCity,
        onSelected: (city) {
          setState(() => _searchCity = city);
          if (city != 'All Nigeria') {
            context.push('/search?q=${Uri.encodeComponent(city)}');
          }
        },
      ),
    );
  }
}

// ─── TOP BAR ──────────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  final String typeFilter, searchCity;
  final ValueChanged<String> onTypeTap;
  final VoidCallback onCityTap, onSearchTap;

  const _TopBar({
    required this.typeFilter,
    required this.searchCity,
    required this.onTypeTap,
    required this.onCityTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(totalUnreadProvider).value ?? 0;

    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPale,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_rounded,
                        color: AppColors.primary, size: 21),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const PropsureLogo(size: 30),
              const Spacer(),
              _HeaderIcon(
                icon: Icons.notifications_none_rounded,
                hasDot: unread > 0,
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.primaryPale2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Find your next place',
                  style: GoogleFonts.syne(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: -0.7)),
              const SizedBox(height: 4),
              const Text('Verified homes, transparent agents, better moves.',
                  style: TextStyle(fontSize: 12, color: AppColors.text2)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border2),
                  boxShadow: AppShadows.sm,
                ),
                child: Column(children: [
                  GestureDetector(
                    onTap: onCityTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 17, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text('Searching in',
                            style: TextStyle(
                                color: AppColors.text3,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(searchCity,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: AppColors.primary),
                      ]),
                    ),
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),
                  GestureDetector(
                    onTap: onSearchTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                      child: Row(children: [
                        const Icon(Icons.search_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Search area, type or price',
                                style: TextStyle(
                                    color: AppColors.text3, fontSize: 13))),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'For Rent', 'For Sale', 'Short Stay'].map((t) {
                    final selected = t == typeFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onTypeTap(t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border2),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.text2)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
          GestureDetector(
            onTap: () => context.push('/info/how-we-verify'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(children: [
                Icon(Icons.verified_user_outlined,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 9),
                Expanded(
                    child: Text('Every agent is verified before they list',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.text,
                            fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.text3, size: 19),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasDot;
  const _HeaderIcon({required this.icon, required this.onTap, this.hasDot = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.text2, size: 20),
          ),
          if (hasDot)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
        ]),
      );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasDot;
  const _NavBtn({required this.icon, this.onTap, this.hasDot = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.15))),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          if (hasDot)
            Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.gold, shape: BoxShape.circle),
                )),
        ]),
      );
}

class _NavBtnBadge extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback? onTap;
  const _NavBtnBadge({required this.icon, required this.badge, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.15))),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          if (badge > 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      );
}

// ─── CITY PICKER SHEET ────────────────────────────────────────────────────────
class _CityPickerSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  const _CityPickerSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cities = ['All Nigeria', ...AppConstants.nigeriaCities];
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Select Location',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Currently focusing on Abuja',
            style: TextStyle(fontSize: 12, color: AppColors.text3)),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: cities.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
            itemBuilder: (_, i) {
              final city = cities[i];
              final isCurrent = city == current;
              final isAbuja = city.contains('Abuja') || city == 'All Nigeria';
              return ListTile(
                dense: true,
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary
                          : (isAbuja ? AppColors.primaryPale : AppColors.bg),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.location_on_outlined,
                      color: isCurrent
                          ? Colors.white
                          : (isAbuja ? AppColors.primary : AppColors.text3),
                      size: 16),
                ),
                title: Text(city,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? AppColors.primary : AppColors.text)),
                trailing: isAbuja
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(99)),
                        child: const Text('Available',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      )
                    : (isCurrent
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary, size: 18)
                        : const Text('Coming soon',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.text3))),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(city);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── CATEGORIES — real counts from Firestore ─────────────────────────────────
class _CategoriesSection extends ConsumerWidget {
  final List<(String, String, String)> categories;
  final String typeFilter;
  const _CategoriesSection(
      {required this.categories, required this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: SectionHeader(
            title: 'Browse Categories',
            onSeeAll: () => context.push('/search')),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final (label, icon, type) = categories[i];
            // Real count from Firestore stream
            final count = ref.watch(categoryCountProvider(type)).value ?? 0;
            return GestureDetector(
              onTap: () =>
                  context.push('/search?type=${Uri.encodeComponent(type)}'),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.sm,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: AppColors.primaryPale,
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text(icon, style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(height: 7),
                    Text(label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$count listings',
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.text3)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─── FEATURED ─────────────────────────────────────────────────────────────────
class _FeaturedSection extends ConsumerWidget {
  final String? typeFilter;
  const _FeaturedSection({this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(homeFeedProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
        child: SectionHeader(
            title: 'Featured for you',
            subtitle: 'Premium verified properties',
            onSeeAll: () => context.push('/search?featured=true')),
      ),
      SizedBox(
        height: 260,
        child: listings.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) =>
                const SizedBox(width: 185, child: SkeletonCard()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (all) {
            var items = all.where((l) => l.isFeatured).toList();
            if (typeFilter != null) {
              final f = items.where((l) => l.category == typeFilter).toList();
              if (f.isNotEmpty) items = f;
            }
            final src = items.isEmpty ? all.take(6).toList() : items;
            if (src.isEmpty) return const SizedBox.shrink();
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: src.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final savedIds =
                    ref.watch(currentUserModelProvider).value?.savedListings ??
                        [];
                final uid = ref.watch(currentUserIdProvider);
                return SizedBox(
                  width: 185,
                  child: ListingCard(
                    listing: src[i],
                    onTap: () => ctx.push('/listing/${src[i].id}'),
                    isSaved: savedIds.contains(src[i].id),
                    onSaveTap: uid == null
                        ? () => ctx.push('/auth')
                        : () {
                            final repo = ref.read(listingRepositoryProvider);
                            if (savedIds.contains(src[i].id)) {
                              repo.unsaveListing(
                                  userId: uid, listingId: src[i].id);
                            } else {
                              repo.saveListing(
                                  userId: uid, listingId: src[i].id);
                            }
                          },
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ─── AREA CHIPS ───────────────────────────────────────────────────────────────
class _AreaChipsSection extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _AreaChipsSection({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
        child: SectionHeader(
            title: 'Browse by Area', onSeeAll: () => context.push('/search')),
      ),
      SizedBox(
        height: 36,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          scrollDirection: Axis.horizontal,
          itemCount: AppConstants.abujaAreas.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, i) {
            final area = AppConstants.abujaAreas[i];
            final on = area == selected;
            return GestureDetector(
              onTap: () => onChanged(area),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: on ? AppColors.primary : AppColors.border),
                ),
                child: Text(area,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? Colors.white : AppColors.text2,
                    )),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─── VERIFIED SECTION ─────────────────────────────────────────────────────────
class _VerifiedSection extends ConsumerWidget {
  final String? typeFilter;
  const _VerifiedSection({this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(homeFeedProvider);
    final cols = AppBreakpoints.gridCols(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
        child: SectionHeader(
            title: 'Verified homes',
            subtitle: 'Trusted by Propsure',
            onSeeAll: () => context.push('/search?verified=true')),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: listings.when(
          loading: () => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonCard(),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (all) {
            var items = all.where((l) => l.isVerified);
            if (typeFilter != null) {
              items = items.where((l) => l.category == typeFilter);
            }
            final src = items.take(cols * 2).toList();
            if (src.isEmpty) return const SizedBox.shrink();
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: cols == 1 ? 1.6 : 0.75),
              itemCount: src.length,
              itemBuilder: (ctx, i) {
                final savedIds =
                    ref.watch(currentUserModelProvider).value?.savedListings ??
                        [];
                final uid = ref.watch(currentUserIdProvider);
                return ListingCard(
                  listing: src[i],
                  onTap: () => ctx.push('/listing/${src[i].id}'),
                  isSaved: savedIds.contains(src[i].id),
                  onSaveTap: uid == null
                      ? () => ctx.push('/auth')
                      : () {
                          final repo = ref.read(listingRepositoryProvider);
                          if (savedIds.contains(src[i].id)) {
                            repo.unsaveListing(
                                userId: uid, listingId: src[i].id);
                          } else {
                            repo.saveListing(userId: uid, listingId: src[i].id);
                          }
                        },
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ─── CTA BANNER ───────────────────────────────────────────────────────────────
class _CTABanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
        child: GestureDetector(
          onTap: () => context.push('/listing/upload'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF12372A), AppColors.primary]),
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.add_home_rounded,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('List your property FREE',
                    style: GoogleFonts.syne(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const Text('Reach 10,000+ tenants in Abuja →',
                    style: TextStyle(fontSize: 11, color: Colors.white60)),
              ]),
            ]),
          ),
        ),
      );
}

// ─── RECENT SECTION ───────────────────────────────────────────────────────────
class _RecentSection extends ConsumerWidget {
  final String typeFilter;
  final String? areaFilter;
  const _RecentSection({required this.typeFilter, this.areaFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build a filter from the current tab + area
    final filter = ListingFilter(
      category: typeFilter == 'All' ? null : typeFilter,
      area: areaFilter,
    );
    final listingsAsync = ref.watch(filteredListingsProvider(filter));
    final cols = AppBreakpoints.gridCols(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
        child: SectionHeader(
            title: 'Recently added',
            onSeeAll: () => context.push('/search')),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: listingsAsync.when(
          loading: () => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75),
            itemCount: 6,
            itemBuilder: (_, __) => const SkeletonCard(),
          ),
          error: (e, _) => Center(
              child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('$e',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          )),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.home_outlined,
                title: 'No listings yet',
                subtitle: 'Be the first to list a property!',
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: cols == 1 ? 1.6 : 0.75),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final savedIds =
                    ref.watch(currentUserModelProvider).value?.savedListings ??
                        [];
                final uid = ref.watch(currentUserIdProvider);
                return ListingCard(
                  listing: items[i],
                  onTap: () => ctx.push('/listing/${items[i].id}'),
                  isSaved: savedIds.contains(items[i].id),
                  onSaveTap: uid == null
                      ? () => ctx.push('/auth')
                      : () {
                          final repo = ref.read(listingRepositoryProvider);
                          if (savedIds.contains(items[i].id)) {
                            repo.unsaveListing(
                                userId: uid, listingId: items[i].id);
                          } else {
                            repo.saveListing(
                                userId: uid, listingId: items[i].id);
                          }
                        },
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ─── HOME DRAWER — CarPlaza style ─────────────────────────────────────────────
class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final user = ref.watch(currentUserModelProvider).value;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppColors.surface,
      child: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary])),
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 16, 16, 20),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              backgroundImage:
                  (isSignedIn && user?.profilePhoto?.isNotEmpty == true)
                      ? NetworkImage(user!.profilePhoto!)
                      : null,
              child: (user?.profilePhoto == null || user!.profilePhoto!.isEmpty)
                  ? Text(
                      isSignedIn && user != null && user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isSignedIn && user != null
                        ? user.name
                        : 'Sign In / Register',
                    style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text(
                    isSignedIn && user != null
                        ? user.phone
                        : 'Access your account',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            )),
            IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop()),
          ]),
        ),

        Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
          const SizedBox(height: 8),
          _DrawerItem(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () {
                Navigator.pop(context);
                context.go('/home');
              }),
          _DrawerItem(
              icon: Icons.search_outlined,
              label: 'Search',
              onTap: () {
                Navigator.pop(context);
                context.go('/search');
              }),
          _DrawerItem(
              icon: Icons.add_home_outlined,
              label: 'List a Property',
              subtitle: 'Post for FREE',
              onTap: () {
                Navigator.pop(context);
                context.push('/listing/upload');
              }),
          _DrawerItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              onTap: () {
                Navigator.pop(context);
                context.go('/messages');
              }),
          _DrawerItem(
              icon: Icons.favorite_border_rounded,
              iconColor: AppColors.error,
              label: 'Saved Properties',
              onTap: () {
                Navigator.pop(context);
                context.push('/saved');
              }),
          _DrawerItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              }),
          _DrawerItem(
              icon: Icons.calendar_today_outlined,
              label: 'My Bookings',
              onTap: () {
                Navigator.pop(context);
                context.push('/bookings');
              }),
          _DrawerItem(
              icon: Icons.person_outline_rounded,
              label: 'My Profile',
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              }),

          const Divider(height: 1),

          // Premium CTA
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFD4881C), AppColors.gold]),
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Text('⭐', style: TextStyle(fontSize: 22)),
              title: Text('Go Premium Agent',
                  style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              subtitle: const Text('Get featured · More visibility',
                  style: TextStyle(fontSize: 10, color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white60),
              onTap: () {
                Navigator.pop(context);
                context.push('/payment/premium');
              },
            ),
          ),
          const Divider(height: 1),

          if (isSignedIn) ...[
            const SizedBox(height: 12),
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
                    minimumSize: const Size(double.infinity, 46)),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/auth');
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Sign In / Create Account'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46)),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ])),
      ]),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
        title: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(fontSize: 10, color: AppColors.text3))
            : null,
        trailing: const Icon(Icons.chevron_right_rounded,
            size: 16, color: AppColors.text3),
        onTap: onTap,
      );
}
