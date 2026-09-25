import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../providers/app_providers.dart';

/// Side-by-side comparison of up to 3 listings the user has added from
/// listing_detail_screen.dart's compare action. Review 3.4: "Add compare,
/// shareable listing links, and a structured shortlist." Sharing already
/// existed (_shareListing); this adds the compare half.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(compareListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Compare Properties', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        actions: [
          if (ids.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(compareListProvider.notifier).clear(),
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: ids.isEmpty
          ? EmptyState(
              icon: Icons.compare_arrows_rounded,
              title: 'Nothing to compare yet',
              subtitle: 'Open a couple of listings and tap "Add to Compare" to see them side by side.',
              action: ElevatedButton(
                onPressed: () => context.push('/search'),
                child: const Text('Browse Listings'),
              ),
            )
          : _CompareTable(listingIds: ids),
    );
  }
}

class _CompareTable extends ConsumerWidget {
  final List<String> listingIds;
  const _CompareTable({required this.listingIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = listingIds
        .map((id) => ref.watch(listingByIdProvider(id)).value)
        .toList();

    if (listings.any((l) => l == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = listings.cast<ListingModel>();

    final rows = <_CompareRow>[
      _CompareRow('Price', items.map((l) => l.formattedPriceWithPeriod).toList()),
      _CompareRow('Type', items.map((l) => l.propertyType).toList()),
      _CompareRow('Category', items.map((l) => l.categoryEnum.label).toList()),
      _CompareRow('Bedrooms', items.map((l) => '${l.bedrooms}').toList()),
      _CompareRow('Bathrooms', items.map((l) => '${l.bathrooms}').toList()),
      _CompareRow('Area', items.map((l) => l.location.area).toList()),
      _CompareRow('Verified', items.map((l) => l.verificationStatus == VerificationStatus.approved ? '✓ Yes' : '—').toList()),
      _CompareRow('Featured', items.map((l) => l.isFeatured ? '⭐ Yes' : '—').toList()),
      _CompareRow('Furnished', items.map((l) => l.isFurnished ? 'Yes' : 'No').toList()),
      _CompareRow('Amenities', items.map((l) => l.amenities.isEmpty ? '—' : l.amenities.join(', ')).toList()),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Table(
        border: TableBorder.all(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
        columnWidths: {
          0: const FixedColumnWidth(90),
          for (int i = 0; i < items.length; i++) i + 1: const FixedColumnWidth(140),
        },
        children: [
          // Header: thumbnail + title + remove button per column
          TableRow(
            decoration: const BoxDecoration(color: AppColors.surface),
            children: [
              const SizedBox(height: 130),
              for (final l in items)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 70,
                        width: double.infinity,
                        child: l.images.isNotEmpty
                            ? Image.network(l.images.first, fit: BoxFit.cover)
                            : Container(color: AppColors.bg, child: const Icon(Icons.home_outlined)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Wrap(children: [
                      TextButton(
                        onPressed: () => GoRouter.of(context).push('/listing/${l.id}'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('View', style: TextStyle(fontSize: 10)),
                      ),
                      TextButton(
                        onPressed: () => ref.read(compareListProvider.notifier).toggle(l.id),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('Remove', style: TextStyle(fontSize: 10, color: AppColors.error)),
                      ),
                    ]),
                  ]),
                ),
            ],
          ),
          for (final row in rows)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(row.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3)),
              ),
              for (final value in row.values)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(value, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                ),
            ]),
        ],
      ),
    );
  }
}

class _CompareRow {
  final String label;
  final List<String> values;
  const _CompareRow(this.label, this.values);
}
