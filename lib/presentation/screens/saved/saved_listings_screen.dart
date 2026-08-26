import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class SavedListingsScreen extends ConsumerWidget {
  const SavedListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final width = MediaQuery.of(context).size.width;
    final cols = AppBreakpoints.gridCols(context);

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Saved Properties', style: GoogleFonts.syne(fontWeight: FontWeight.w700))),
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
        title: Text('Saved Properties', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        actions: [
          savedAsync.value?.isNotEmpty == true
              ? TextButton(
                  onPressed: () {},
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
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: cols == 1 ? 1.55 : 0.74,
            ),
            itemCount: listings.length,
            itemBuilder: (ctx, i) => ListingCard(
              listing: listings[i],
              onTap: () => ctx.push('/listing/${listings[i].id}'),
              isSaved: true,
              onSaveTap: () => ref.read(listingRepositoryProvider)
                  .unsaveListing(userId: userId, listingId: listings[i].id),
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
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
