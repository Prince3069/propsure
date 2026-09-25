import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/app_providers.dart';

enum _SavedSort { recentlySaved, priceLowHigh, priceHighLow }

class SavedListingsScreen extends ConsumerStatefulWidget {
  const SavedListingsScreen({super.key});
  @override
  ConsumerState<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends ConsumerState<SavedListingsScreen> {
  _SavedSort _sort = _SavedSort.recentlySaved;

  // Fixes the "Sort" button that previously had `onPressed: () {}` — was
  // visible whenever there were saved listings, but tapping it did
  // nothing. watchSavedListings() doesn't carry a "when saved" timestamp
  // (it just resolves the saved-listing IDs to their documents), so
  // "recently saved" here approximates to the listing's own createdAt —
  // newest listings first. Price sort is exact.
  List<ListingModel> _sorted(List<ListingModel> listings) {
    final copy = [...listings];
    switch (_sort) {
      case _SavedSort.priceLowHigh:
        copy.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SavedSort.priceHighLow:
        copy.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SavedSort.recentlySaved:
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return copy;
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort by', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ),
          for (final entry in const {
            'Recently added': _SavedSort.recentlySaved,
            'Price: Low to High': _SavedSort.priceLowHigh,
            'Price: High to Low': _SavedSort.priceHighLow,
          }.entries)
            ListTile(
              title: Text(entry.key),
              trailing: _sort == entry.value ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _sort = entry.value);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final cols = AppBreakpoints.gridCols(context);

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Saved Properties', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
        body: EmptyState(
          icon: Icons.bookmark_outline_rounded,
          title: 'Your saved properties',
          subtitle: 'Sign in to save properties and access them anytime.',
          action: ElevatedButton(
            onPressed: () => context.push('/auth?redirect=/saved'),
            child: const Text('Sign In'),
          ),
        ),
      );
    }

    final savedAsync = ref.watch(savedListingsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Saved Properties', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        actions: [
          savedAsync.value?.isNotEmpty == true
              ? TextButton(
                  onPressed: _showSortSheet,
                  child: const Text('Sort', style: TextStyle(fontSize: 13)),
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: savedAsync.when(
        data: (listings) {
          if (listings.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_outline_rounded,
              title: 'Nothing saved yet',
              subtitle: 'Tap the 🔖 icon on any listing to save it here.',
              action: TextButton(
                onPressed: () => context.push('/search'),
                child: const Text('Browse Properties'),
              ),
            );
          }
          final sorted = _sorted(listings);
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: cols == 1 ? 1.55 : 0.74,
            ),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) => ListingCard(
              listing: sorted[i],
              onTap: () => ctx.push('/listing/${sorted[i].id}'),
              isSaved: true,
              onSaveTap: () => ref.read(listingRepositoryProvider)
                  .unsaveListing(userId: userId, listingId: sorted[i].id),
            ),
          );
        },
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.74),
          itemCount: 4,
          itemBuilder: (_, __) => const SkeletonCard(),
        ),
        // Friendly failure state instead of the raw exception.
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Couldn\'t load your saved properties right now.',
                style: TextStyle(fontSize: 13, color: AppColors.text3)),
          ),
        ),
      ),
    );
  }
}
