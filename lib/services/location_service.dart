// lib/services/location_service.dart

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:logger/logger.dart';
import '../data/models/listing_model.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _logger = Logger();

  // ─── USER LOCATION ────────────────────────────────────────────────────────

  /// Request permission and get current device location
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.w('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.e('Location permissions permanently denied');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _logger.e('Error getting location: $e');
      return null;
    }
  }

  /// Get last known position (faster, less accurate)
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  /// Stream of location updates for map tracking
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update every 50 meters
      ),
    );
  }

  // ─── GEOHASHING ───────────────────────────────────────────────────────────

  /// Generate geohash from lat/lng using GeoFlutterFire Plus
  /// Precision 9 ≈ ±2.4m accuracy; we use 9 for storage
  String generateGeohash(double lat, double lng, {int precision = 9}) {
    final geoFirePoint = GeoFirePoint(GeoPoint(lat, lng));
    return geoFirePoint.geohash;
  }

  /// Create a GeoFirePoint for geospatial operations
  GeoFirePoint createGeoFirePoint(double lat, double lng) {
    return GeoFirePoint(GeoPoint(lat, lng));
  }

  /// Build the location map stored in Firestore
  /// This format works with GeoFlutterFire Plus radius queries
  Map<String, dynamic> buildLocationMap({
    required double latitude,
    required double longitude,
    required String area,
    String country = 'Nigeria',
    String state = 'FCT',
    String city = 'Abuja',
    String? street,
    String? landmark,
    required String fullAddress,
  }) {
    final geohash = generateGeohash(latitude, longitude);
    return PropertyLocation(
      latitude: latitude,
      longitude: longitude,
      geohash: geohash,
      country: country,
      state: state,
      city: city,
      area: area,
      street: landmark != null && street != null
          ? '$street, $landmark'
          : (street ?? landmark ?? ''),
      fullAddress: fullAddress,
    ).toMap();
  }

  // ─── RADIUS QUERIES ───────────────────────────────────────────────────────

  /// Query listings within radius using GeoFlutterFire Plus
  /// Returns a stream of documents within [radiusKm] km of [center]
  Stream<List<DocumentSnapshot>> getListingsWithinRadius({
    required GeoPoint center,
    required double radiusKm,
    required CollectionReference collection,
    Query Function(CollectionReference)? queryBuilder,
  }) {
    // GeoFlutterFire Plus uses 'location.geoData' as the geo field path
    return GeoCollectionReference(collection).subscribeWithin(
      center: GeoFirePoint(center),
      radiusInKm: radiusKm,
      field: 'location.geoData',
      geopointFrom: (Object? data) {
        final map = data as Map<String, dynamic>?;
        final locationData = map?['location'] as Map<String, dynamic>?;
        final geoData = locationData?['geoData'] as Map<String, dynamic>?;
        return geoData?['geopoint'] as GeoPoint? ??
            GeoPoint(
              ((locationData?['latitude'] as num?) ?? 9.0579).toDouble(),
              ((locationData?['longitude'] as num?) ?? 7.4951).toDouble(),
            );
      },
    );
  }

  /// One-time fetch of listings within radius
  Future<List<DocumentSnapshot>> fetchListingsWithinRadius({
    required GeoPoint center,
    required double radiusKm,
    required CollectionReference collection,
  }) async {
    return GeoCollectionReference(collection).fetchWithin(
      center: GeoFirePoint(center),
      radiusInKm: radiusKm,
      field: 'location.geoData',
      geopointFrom: (Object? data) {
        final map = data as Map<String, dynamic>?;
        final locationData = map?['location'] as Map<String, dynamic>?;
        final geoData = locationData?['geoData'] as Map<String, dynamic>?;
        return geoData?['geopoint'] as GeoPoint? ??
            GeoPoint(
              ((locationData?['latitude'] as num?) ?? 9.0579).toDouble(),
              ((locationData?['longitude'] as num?) ?? 7.4951).toDouble(),
            );
      },
    );
  }

  // ─── DISTANCE CALCULATION ────────────────────────────────────────────────

  /// Calculate distance in km between two coordinates using Haversine formula
  double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Also available via Geolocator (same result, different source)
  double distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000.0;
  }

  /// Human-readable distance label
  String formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()}m away';
    } else if (km < 10.0) {
      return '${km.toStringAsFixed(1)}km away';
    } else {
      return '${km.round()}km away';
    }
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  // ─── REVERSE GEOCODING ───────────────────────────────────────────────────

  /// Convert lat/lng to structured address (reverse geocoding)
  Future<GeocodedAddress?> reverseGeocode(
      double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;

      // Build human-readable address
      final parts = <String>[];
      if (placemark.subThoroughfare?.isNotEmpty == true) {
        parts.add(placemark.subThoroughfare!);
      }
      if (placemark.thoroughfare?.isNotEmpty == true) {
        parts.add(placemark.thoroughfare!);
      }
      if (placemark.subLocality?.isNotEmpty == true) {
        parts.add(placemark.subLocality!);
      }
      if (placemark.locality?.isNotEmpty == true) {
        parts.add(placemark.locality!);
      }
      if (placemark.administrativeArea?.isNotEmpty == true) {
        parts.add(placemark.administrativeArea!);
      }

      // Try to match to known Abuja areas
      final detectedArea = _detectAbujaArea(
        placemark.subLocality ?? '',
        placemark.locality ?? '',
        placemark.thoroughfare ?? '',
        placemark.subThoroughfare ?? '',
      );

      return GeocodedAddress(
        fullAddress: parts.join(', '),
        street: [placemark.subThoroughfare, placemark.thoroughfare]
            .where((s) => s?.isNotEmpty == true)
            .join(' '),
        area: detectedArea ?? placemark.subLocality ?? placemark.locality ?? '',
        city: placemark.locality ?? 'Abuja',
        state: placemark.administrativeArea ?? 'FCT',
        country: placemark.country ?? 'Nigeria',
        postalCode: placemark.postalCode,
      );
    } catch (e) {
      _logger.e('Reverse geocoding error: $e');
      return null;
    }
  }

  /// Forward geocoding: address string → coordinates
  Future<Location?> geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(
        address.contains('Abuja') ? address : '$address, Abuja, Nigeria',
      );
      return locations.isNotEmpty ? locations.first : null;
    } catch (e) {
      _logger.e('Forward geocoding error: $e');
      return null;
    }
  }

  /// Match lat/lng to known Abuja areas using bounding boxes
  String? _detectAbujaArea(
    String subLocality,
    String locality,
    String thoroughfare,
    String subThoroughfare,
  ) {
    final combined =
        '$subLocality $locality $thoroughfare $subThoroughfare'.toLowerCase();

    // Try direct match first
    for (final area in _abujaAreaKeywords.entries) {
      for (final keyword in area.value) {
        if (combined.contains(keyword.toLowerCase())) {
          return area.key;
        }
      }
    }
    return null;
  }

  static const Map<String, List<String>> _abujaAreaKeywords = {
    'Maitama': ['maitama', 'maitama district'],
    'Asokoro': ['asokoro'],
    'Wuse': ['wuse zone', 'wuse 1'],
    'Wuse 2': ['wuse 2', 'wuse ii'],
    'Garki': ['garki area 1', 'garki i', 'garki 1'],
    'Garki 2': ['garki 2', 'garki ii', 'garki area 2'],
    'Gwarinpa': ['gwarinpa', 'gwarinpa estate'],
    'Jabi': ['jabi'],
    'Life Camp': ['life camp', 'lifecamp'],
    'Utako': ['utako'],
    'Lugbe': ['lugbe'],
    'Kubwa': ['kubwa'],
    'Kuje': ['kuje'],
    'Lokogoma': ['lokogoma'],
    'Apo': ['apo resettlement', 'apo district'],
    'Katampe': ['katampe'],
    'Durumi': ['durumi'],
    'Gudu': ['gudu district'],
    'Galadimawa': ['galadimawa'],
    'Gwagwalada': ['gwagwalada'],
    'Nyanya': ['nyanya'],
    'Karu': ['karu'],
    'Wuye': ['wuye'],
    'Dawaki': ['dawaki'],
  };

  // ─── BOUNDING BOX ─────────────────────────────────────────────────────────

  /// Get approximate bounding box for a named Abuja area (for map camera)
  AreaBounds? getAreaBounds(String areaName) {
    return _areaBounds[areaName];
  }

  static const Map<String, AreaBounds> _areaBounds = {
    'Maitama': AreaBounds(9.0820, 7.4810, 9.0960, 7.5050),
    'Asokoro': AreaBounds(9.0400, 7.5000, 9.0570, 7.5220),
    'Wuse 2': AreaBounds(9.0680, 7.4720, 9.0820, 7.5020),
    'Garki': AreaBounds(9.0470, 7.4700, 9.0670, 7.5000),
    'Gwarinpa': AreaBounds(9.1100, 7.3950, 9.1450, 7.4400),
    'Jabi': AreaBounds(9.0720, 7.4350, 9.0900, 7.4700),
    'Life Camp': AreaBounds(9.0900, 7.4050, 9.1150, 7.4450),
    'Kubwa': AreaBounds(9.1450, 7.3200, 9.1950, 7.4100),
    'Lugbe': AreaBounds(8.9900, 7.3700, 9.0250, 7.4300),
  };
}

class GeocodedAddress {
  final String fullAddress;
  final String street;
  final String area;
  final String city;
  final String state;
  final String country;
  final String? postalCode;

  const GeocodedAddress({
    required this.fullAddress,
    required this.street,
    required this.area,
    required this.city,
    required this.state,
    required this.country,
    this.postalCode,
  });
}

class AreaBounds {
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  const AreaBounds(this.minLat, this.minLng, this.maxLat, this.maxLng);

  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;
}
