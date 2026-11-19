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

  /// Every spelling of this category that may exist in Firestore. Older
  /// documents stored the display label ("For Rent"), so server-side
  /// searches must match all of these, not just [value].
  List<String> get storedVariants {
    switch (this) {
      case ListingCategory.rent:
        return const ['for_rent', 'For Rent', 'Rent', 'rent'];
      case ListingCategory.sale:
        return const ['for_sale', 'For Sale', 'Sale', 'sale'];
      case ListingCategory.shortStay:
        return const ['short_stay', 'Short Stay', 'Short stay', 'short-stay'];
      case ListingCategory.commercial:
        return const ['commercial', 'Commercial'];
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

  /// The period shown next to a price. Derived from the category everywhere:
  /// rent and commercial are annual, short stays are nightly, and a sale
  /// price is a one-off amount with no period at all.
  String get priceSuffix {
    switch (this) {
      case ListingCategory.rent:
      case ListingCategory.commercial:
        return '/yr';
      case ListingCategory.shortStay:
        return '/night';
      case ListingCategory.sale:
        return '';
    }
  }

  /// "year" / "night" / "" — the long form used in the redesigned cards.
  String get periodWord {
    switch (this) {
      case ListingCategory.rent:
      case ListingCategory.commercial:
        return 'year';
      case ListingCategory.shortStay:
        return 'night';
      case ListingCategory.sale:
        return '';
    }
  }

  /// Annual-rent style categories that have a move-in cost (agency, legal,
  /// caution…). Sale and nightly stays do not get an "annual rent" total.
  bool get hasMoveInCost =>
      this == ListingCategory.rent || this == ListingCategory.commercial;

  /// Short label for filter chips: Rent / Sale / Short stay / Commercial.
  String get chipLabel {
    switch (this) {
      case ListingCategory.rent:
        return 'Rent';
      case ListingCategory.sale:
        return 'Sale';
      case ListingCategory.shortStay:
        return 'Short stay';
      case ListingCategory.commercial:
        return 'Commercial';
    }
  }

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
