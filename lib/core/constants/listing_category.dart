// Canonical listing category. This is the ONLY thing that should ever be
// persisted to Firestore for a listing's category. UI labels are derived
// from `.label` and must never be written back to the database — that
// mismatch (storing "For Rent" instead of "for_rent") was the #1 data
// -integrity bug flagged in the Propsure code review: it broke Firestore
// equality filters, price-period formatting, and category counts.
enum ListingCategory {
  rent,
  sale,
  shortStay,
  commercial;

  /// The machine value persisted to Firestore. Stable — never rename.
  String get value {
    switch (this) {
      case ListingCategory.rent:
        return 'for_rent';
      case ListingCategory.sale:
        return 'for_sale';
      case ListingCategory.shortStay:
        return 'short_stay';
      case ListingCategory.commercial:
        return 'commercial';
    }
  }

  /// Human-readable label for UI only.
  String get label {
    switch (this) {
      case ListingCategory.rent:
        return 'For Rent';
      case ListingCategory.sale:
        return 'For Sale';
      case ListingCategory.shortStay:
        return 'Short Stay';
      case ListingCategory.commercial:
        return 'Commercial';
    }
  }

  /// The suffix used when formatting a price for this category.
  String get priceSuffix => this == ListingCategory.shortStay ? '/night' : '/yr';

  /// Every selectable category, in the order they should appear in dropdowns.
  static const List<ListingCategory> selectable = [
    ListingCategory.rent,
    ListingCategory.sale,
    ListingCategory.shortStay,
    ListingCategory.commercial,
  ];

  /// Parses ANY historical representation of a category — canonical machine
  /// values, legacy UI labels ("For Rent"), old route-param slugs
  /// ("short-stay"), even case/whitespace variants — into the canonical
  /// enum. This is what makes existing Firestore documents (written before
  /// this fix, some containing "For Rent" as a literal value) keep working
  /// without a hard migration being required before deploy. Run the
  /// one-time migration script anyway so new documents are written cleanly.
  static ListingCategory fromAny(String? raw, {ListingCategory fallback = ListingCategory.rent}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final v = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (v) {
      case 'for_rent':
      case 'rent':
        return ListingCategory.rent;
      case 'for_sale':
      case 'sale':
        return ListingCategory.sale;
      case 'short_stay':
      case 'shortstay':
        return ListingCategory.shortStay;
      case 'commercial':
        return ListingCategory.commercial;
      default:
        return fallback;
    }
  }

  /// Convenience for search/route params that still use hyphenated slugs
  /// (e.g. `/search?category=short-stay` links already in the drawer).
  String get routeSlug {
    switch (this) {
      case ListingCategory.rent:
        return 'rent';
      case ListingCategory.sale:
        return 'sale';
      case ListingCategory.shortStay:
        return 'short-stay';
      case ListingCategory.commercial:
        return 'commercial';
    }
  }
}
