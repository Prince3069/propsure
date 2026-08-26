class AppConstants {
  static const String appName = 'Propsure';
  static const String appTagline =
      "Nigeria's Most Trusted Property Rental Platform";

  // Collections
  static const String colUsers = 'users';
  static const String colListings = 'listings';
  static const String colChats = 'chats';
  static const String colMessages = 'messages';
  static const String colBookings = 'bookings';
  static const String colReviews = 'reviews';
  static const String colNotifications = 'notifications';
  static const String colTransactions = 'transactions';

  // Storage
  static const String storeListingImages = 'listings/images';
  static const String storeListingVideos = 'listings/videos';
  static const String storeUserAvatars = 'users/avatars';

  // Storage path aliases (used in listing_repository.dart)
  static const String pathListingImages = storeListingImages;
  static const String pathListingVideos = storeListingVideos;
  static const String pathUserAvatars = storeUserAvatars;

  // Roles
  static const String roleTenant = 'tenant';
  static const String roleAgent = 'agent';
  static const String roleLandlord = 'landlord';
  static const String roleAdmin = 'admin';

  // Listing status
  static const String statusActive = 'active';
  static const String statusRented = 'rented';
  static const String statusPending = 'pending';
  static const String statusExpired = 'expired';

  // Booking status
  static const String bookingPending = 'pending';
  static const String bookingConfirmed = 'confirmed';
  static const String bookingCompleted = 'completed';
  static const String bookingCancelled = 'cancelled';
  static const String bookingRejected = 'rejected';

  // Listing categories
  static const List<String> listingCategories = [
    'For Rent',
    'For Sale',
    'Short Stay',
    'Commercial',
  ];

  // Property types
  static const List<Map<String, String>> propertyTypes = [
    {'label': 'Flat / Apartment', 'icon': '🏠'},
    {'label': 'Duplex', 'icon': '🏘'},
    {'label': 'Self Contain', 'icon': '🛏'},
    {'label': 'Terraced House', 'icon': '🏗'},
    {'label': 'Bungalow', 'icon': '🏡'},
    {'label': 'Detached House', 'icon': '🏢'},
    {'label': 'Studio', 'icon': '🛋'},
    {'label': 'Office Space', 'icon': '🏣'},
    {'label': 'Shop', 'icon': '🏪'},
    {'label': 'Warehouse', 'icon': '🏭'},
  ];

  // Amenities
  static const List<String> amenities = [
    'Generator',
    'Borehole / Water',
    'Security / CCTV',
    'Swimming Pool',
    'Gym',
    'Air Conditioning',
    'Fitted Kitchen',
    'Balcony',
    'Garden',
    'Elevator / Lift',
    'Wardrobe',
    'Tiled Floors',
    'POP Ceiling',
    'Prepaid Meter',
    'Parking Space',
    'Internet / Fiber',
    'Perimeter Fence',
    'Boys Quarter',
  ];

  // Nigerian states
  static const List<String> nigeriaCities = [
    'Abuja (FCT)',
    'Lagos',
    'Port Harcourt',
    'Kano',
    'Ibadan',
    'Benin City',
    'Enugu',
    'Owerri',
    'Kaduna',
    'Calabar',
    'Uyo',
    'Jos',
    'Warri',
    'Asaba',
    'Abeokuta',
  ];

  // Abuja areas
  static const List<String> abujaAreas = [
    'All Abuja',
    'Wuse',
    'Wuse 2',
    'Maitama',
    'Asokoro',
    'Garki',
    'Garki 2',
    'Jabi',
    'Utako',
    'Gwarinpa',
    'Kubwa',
    'Lugbe',
    'Galadimawa',
    'Lokogoma',
    'Apo',
    'Durumi',
    'Gudu',
    'Kado',
    'Life Camp',
    'Guzape',
    'Katampe',
    'Wuye',
    'Mpape',
    'Bwari',
    'Gwagwalada',
    'Central Business District',
  ];

  // Price ranges
  static const List<Map<String, dynamic>> priceRanges = [
    {'label': 'Any price', 'min': 0, 'max': 0},
    {'label': 'Under ₦500k', 'min': 0, 'max': 500000},
    {'label': '₦500k – ₦1M', 'min': 500000, 'max': 1000000},
    {'label': '₦1M – ₦2M', 'min': 1000000, 'max': 2000000},
    {'label': '₦2M – ₦5M', 'min': 2000000, 'max': 5000000},
    {'label': '₦5M – ₦10M', 'min': 5000000, 'max': 10000000},
    {'label': 'Above ₦10M', 'min': 10000000, 'max': 999999999},
  ];

  // Abuja default location
  static const double abujaLat = 9.0765;
  static const double abujaLng = 7.3986;
  static const double defaultMapZoom = 12.0;
  static const double defaultSearchRadius = 5.0;

  // Pagination
  static const int pageSize = 20;
  static const int mapLimit = 100;
  static const int msgPageSize = 30;
}
