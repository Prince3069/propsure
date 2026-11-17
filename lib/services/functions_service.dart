import 'package:cloud_functions/cloud_functions.dart';

/// Thin, typed wrapper over every callable Cloud Function. Screens never
/// build payloads by hand, and every failure becomes a plain-language
/// [AppException] — never a raw Firebase error string.
class AppException implements Exception {
  final String message;
  final String? code;
  const AppException(this.message, [this.code]);
  @override
  String toString() => message;
}

/// One purchasable item from the server catalog (getPricing). Prices are
/// whole naira; the server is the only source of truth for the amount.
class PriceOption {
  final String id;
  final int amountNaira;
  final int days;
  const PriceOption({required this.id, required this.amountNaira, required this.days});
  factory PriceOption.fromMap(Map<String, dynamic> m) => PriceOption(
        id: m['id'] as String? ?? '',
        amountNaira: (m['amountNGN'] ?? 0).round(),
        days: (m['days'] ?? 0).toInt(),
      );
}

class PricingInfo {
  final int freeLimit;
  final int proLimit;
  final PriceOption? agentPro; // fixed 30-day access, not recurring
  final List<PriceOption> boosts;
  const PricingInfo({required this.freeLimit, required this.proLimit, this.agentPro, required this.boosts});

  factory PricingInfo.fromMap(Map<String, dynamic> m) {
    final limits = (m['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pro = m['agentPro'];
    return PricingInfo(
      freeLimit: (limits['free'] ?? 3).toInt(),
      proLimit: (limits['pro'] ?? 20).toInt(),
      agentPro: pro is Map ? PriceOption.fromMap(Map<String, dynamic>.from(pro)) : null,
      boosts: ((m['boosts'] as List?) ?? const []).map((e) => PriceOption.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class FunctionsService {
  final FirebaseFunctions _fn;
  FunctionsService({FirebaseFunctions? fn}) : _fn = fn ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? payload]) async {
    try {
      final res = await _fn.httpsCallable(name).call<dynamic>(payload ?? <String, dynamic>{});
      final d = res.data;
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AppException(_friendly(e), e.code);
    } catch (_) {
      throw const AppException('Something went wrong. Check your connection and try again.');
    }
  }

  static String _friendly(FirebaseFunctionsException e) {
    // Server messages are already written for people (see functions/lib/*).
    if (e.message != null && e.message!.isNotEmpty && e.code != 'internal' && e.code != 'unknown') {
      return e.message!;
    }
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in to continue.';
      case 'permission-denied':
        return "You don't have permission to do that.";
      case 'unavailable':
      case 'deadline-exceeded':
        return 'We could not reach Propsure. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<PricingInfo> getPricing() async => PricingInfo.fromMap(await _call('getPricing'));

  /// Publishes a draft. The server enforces the live-listing limit, media
  /// readiness and stamps the availability confirmation.
  Future<void> publishListing(String listingId) =>
      _call('publishListing', {'listingId': listingId, 'availabilityConfirmed': true});

  Future<void> confirmAvailability(String listingId) => _call('confirmAvailability', {'listingId': listingId});

  /// status: paused | rented | archived  (and 'active' via [publishListing]).
  Future<void> setListingStatus(String listingId, String status) =>
      _call('setListingStatus', {'listingId': listingId, 'status': status});

  Future<void> confirmVideoFrames({
    required String listingId,
    required List<String> frameIds,
    String? coverId,
    Map<String, String> labels = const {},
  }) =>
      _call('confirmVideoFrames', {'listingId': listingId, 'frameIds': frameIds, 'coverId': coverId, 'labels': labels});

  Future<void> discardVideo(String listingId) => _call('discardVideo', {'listingId': listingId});

  /// kind: report | support | feedback; returns the reference shown to the user.
  Future<String> createSupportRequest({
    required String kind,
    required String topic,
    String subject = '',
    required String message,
    String? reason,
    String? listingId,
    List<String> evidencePaths = const [],
  }) async {
    final r = await _call('createSupportRequest', {
      'kind': kind,
      'topic': topic,
      'subject': subject,
      'message': message,
      if (reason != null) 'reason': reason,
      if (listingId != null) 'listingId': listingId,
      'evidencePaths': evidencePaths,
    });
    return (r['reference'] as String?) ?? '';
  }

  /// Returns the invite link for an existing shortlist the caller owns.
  Future<String> createShortlistInvite(String shortlistId) async {
    final r = await _call('createShortlistInvite', {'shortlistId': shortlistId});
    return (r['url'] as String?) ?? '';
  }

  /// Returns the id of the shortlist that was joined.
  Future<String> joinShortlist(String code) async {
    final r = await _call('joinShortlist', {'code': code});
    return (r['shortlistId'] as String?) ?? '';
  }

  Future<Map<String, dynamic>> claimFounderPromo() => _call('claimFounderPromo');
}
