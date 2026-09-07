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
  String _typeFilter = 'All';
  String _selectedArea = 'All Abuja';
  String _searchCity = 'Abuja (FCT)';
  final PageController _heroController = PageController();

  static const _categories = [
    ('Flat / Apt', '🏠', 'Flat / Apartment'),
    ('Duplex', '🏘️', 'Duplex'),
    ('Self Contain', '🛏️', 'Self Contain'),
    ('Terrace', '🏗️', 'Terraced House'),
    ('Bungalow', '🏡', 'Bungalow'),
    ('Detached', '🏢', 'Detached House'),
    ('Studio', '🛋️', 'Studio'),
    ('Office', '🏣', 'Office Space'),
  ];

  // Hero carousel items
  final List<Map<String, String>> _heroItems = const [
    {
      'title': 'Find Your Dream Home',
      'subtitle': 'Verified properties across Abuja',
      'emoji': '🏡',
      'gradient': 'primary',
    },
    {
      'title': 'Rent Financing Available',
      'subtitle': 'Pay monthly, not yearly',
      'emoji': '💰',
      'gradient': 'gold',
    },
    {
      'title': 'Verified Agents',
      'subtitle': '100% identity verified',
      'emoji': '✅',
      'gradient': 'primary',
    },
  ];

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(homeFeedProvider);
      },
      child: CustomScrollView(
        slivers: [
          // ─── TOP BAR ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _TopBar(
              typeFilter: _typeFilter,
              searchCity: _searchCity,
              onTypeTap: (t) => setState(() => _typeFilter = t),
              onCityTap: _showCityPicker,
              onSearchTap: () => context.push('/search'),
            ),
          ),

          // ─── HERO CAROUSEL ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroCarousel(
              controller: _heroController,
              items: _heroItems,
            ),
          ),

          // ─── CATEGORIES ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _CategoriesSection(
              categories: _categories,
              typeFilter: _typeFilter,
            ),
          ),

          // ─── AREA CHIPS ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _AreaChipsSection(
              selected: _selectedArea,
              onChanged: (a) {
                setState(() => _selectedArea = a);
                if (a != 'All Abuja') {
                  context.push('/search?q=${Uri.encodeComponent(a)}');
                }
              },
            ),
          ),

          // ─── FEATURED SECTION ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _FeaturedSection(
              typeFilter: _typeFilter == 'All' ? null : _typeFilter,
            ),
          ),

          // ─── VERIFIED SECTION ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _VerifiedSection(
              typeFilter: _typeFilter == 'All' ? null : _typeFilter,
            ),
          ),

          // ─── CTA BANNER ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _CTABanner(),
          ),

          // ─── RECENT SECTION ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _RecentSection(
              typeFilter: _typeFilter,
              areaFilter: _selectedArea == 'All Abuja' ? null : _selectedArea,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
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

// ─── HERO CAROUSEL ──────────────────────────────────────────────────────────
class _HeroCarousel extends StatelessWidget {
  final PageController controller;
  final List<Map<String, String>> items;

  const _HeroCarousel({
    required this.controller,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: controller,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final isGold = item['gradient'] == 'gold';
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isGold
                  ? const LinearGradient(
                      colors: [AppColors.goldDark, AppColors.gold],
                    )
                  : const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: isGold ? AppShadows.gold : AppShadows.md,
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['emoji'] ?? '🏡',
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['title'] ?? '',
                              style: GoogleFonts.syne(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['subtitle'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Arrow indicator
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                // Page indicator dots
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      items.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            index == 0 ? 0.9 : 0.3,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
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
                        child: const Icon(
                          Icons.menu_rounded,
                          color: AppColors.primary,
                          size: 21,
                        ),
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
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search Hero ──
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find your next place',
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verified homes, transparent agents, better moves.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search container
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: onCityTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 17,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Searching in',
                                  style: TextStyle(
                                    color: AppColors.text3,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    searchCity,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 14, endIndent: 14),
                        GestureDetector(
                          onTap: onSearchTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Search area, type or price',
                                    style: TextStyle(
                                      color: AppColors.text3,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primaryDark,
                                        AppColors.primary
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'For Rent', 'For Sale', 'Short Stay']
                          .map((t) {
                        final selected = t == typeFilter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => onTypeTap(t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.15),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                                border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Trust banner ──
            GestureDetector(
              onTap: () => context.push('/info/how-we-verify'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Every agent is verified before they list',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.text3,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasDot;
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.hasDot = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
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
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
}

// ─── CATEGORIES SECTION ──────────────────────────────────────────────────────
class _CategoriesSection extends ConsumerWidget {
  final List<(String, String, String)> categories;
  final String typeFilter;
  const _CategoriesSection({
    required this.categories,
    required this.typeFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: SectionHeader(
            title: 'Browse Categories',
            onSeeAll: () => context.push('/search'),
          ),
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
              childAspectRatio: 0.85,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final (label, icon, type) = categories[i];
              final count = ref.watch(categoryCountProvider(type)).value ?? 0;
              return GestureDetector(
                onTap: () =>
                    context.push('/search?type=${Uri.encodeComponent(type)}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count listings',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── AREA CHIPS SECTION ──────────────────────────────────────────────────────
class _AreaChipsSection extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _AreaChipsSection({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
          child: SectionHeader(
            title: 'Popular Areas',
            onSeeAll: () => context.push('/search'),
          ),
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
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: on ? AppColors.primary : AppColors.border,
                    ),
                    boxShadow: on ? AppShadows.sm : null,
                  ),
                  child: Text(
                    area,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? Colors.white : AppColors.text2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── CITY PICKER SHEET ──────────────────────────────────────────────────────
class _CityPickerSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  const _CityPickerSheet({
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cities = ['All Nigeria', ...AppConstants.nigeriaCities];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Location',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Currently focusing on Abuja',
            style: TextStyle(fontSize: 12, color: AppColors.text3),
          ),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: isCurrent
                          ? Colors.white
                          : (isAbuja ? AppColors.primary : AppColors.text3),
                      size: 16,
                    ),
                  ),
                  title: Text(
                    city,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? AppColors.primary : AppColors.text,
                    ),
                  ),
                  trailing: isAbuja
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Text(
                            'Available',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : (isCurrent
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                              size: 18,
                            )
                          : const Text(
                              'Coming soon',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.text3,
                              ),
                            )),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(city);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FEATURED SECTION ────────────────────────────────────────────────────────
class _FeaturedSection extends ConsumerWidget {
  final String? typeFilter;
  const _FeaturedSection({this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(homeFeedProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
          child: SectionHeader(
            title: '⭐ Featured for you',
            subtitle: 'Premium verified properties',
            onSeeAll: () => context.push('/search?featured=true'),
          ),
        ),
        SizedBox(
          height: 270,
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
                  final savedIds = ref
                          .watch(currentUserModelProvider)
                          .value
                          ?.savedListings ??
                      [];
                  final uid = ref.watch(currentUserIdProvider);
                  return SizedBox(
                    width: 190,
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
      ],
    );
  }
}

// ─── VERIFIED SECTION ────────────────────────────────────────────────────────
class _VerifiedSection extends ConsumerWidget {
  final String? typeFilter;
  const _VerifiedSection({this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(homeFeedProvider);
    final cols = AppBreakpoints.gridCols(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
          child: SectionHeader(
            title: '✓ Verified homes',
            subtitle: 'Trusted by Propsure',
            onSeeAll: () => context.push('/search?verified=true'),
          ),
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
                childAspectRatio: 0.75,
              ),
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
                  childAspectRatio: cols == 1 ? 1.6 : 0.75,
                ),
                itemCount: src.length,
                itemBuilder: (ctx, i) {
                  final savedIds = ref
                          .watch(currentUserModelProvider)
                          .value
                          ?.savedListings ??
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
                              repo.saveListing(
                                  userId: uid, listingId: src[i].id);
                            }
                          },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
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
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.add_home_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'List your property FREE',
                      style: GoogleFonts.syne(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Reach 10,000+ tenants in Abuja →',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

// ─── RECENT SECTION ──────────────────────────────────────────────────────────
class _RecentSection extends ConsumerWidget {
  final String typeFilter;
  final String? areaFilter;
  const _RecentSection({
    required this.typeFilter,
    this.areaFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ListingFilter(
      category: typeFilter == 'All' ? null : typeFilter,
      area: areaFilter,
    );
    final listingsAsync = ref.watch(filteredListingsProvider(filter));
    final cols = AppBreakpoints.gridCols(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
          child: SectionHeader(
            title: 'Recently added',
            onSeeAll: () => context.push('/search'),
          ),
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
                childAspectRatio: 0.75,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => const SkeletonCard(),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '$e',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
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
                  childAspectRatio: cols == 1 ? 1.6 : 0.75,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final savedIds = ref
                          .watch(currentUserModelProvider)
                          .value
                          ?.savedListings ??
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
      ],
    );
  }
}
