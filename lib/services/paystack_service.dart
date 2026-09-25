import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// ALL Paystack secret key operations happen in Cloud Functions.
///
/// FIX (this round): the previous version assumed every response body was
/// JSON and passed it straight through — so a 404 (function not
/// deployed, wrong region, etc.) returned raw HTML, and that HTML ended
/// up rendered directly in a red error box in the UI. This version
/// checks the status code and content type BEFORE trying to parse
/// anything, and always surfaces a plain, human sentence — the real
/// error still gets logged (via debugPrint) for you to see in
/// `flutter logs` / Logcat while debugging, it just never reaches the
/// end user's screen verbatim.
class PaystackService {
  static final _db = FirebaseFirestore.instance;

  // ── PUBLIC KEY only — safe to be in app ──────────────────────────────────
  static const String publicKey =
      'pk_live_689c8cfad7a1370ed22403fafade7263ecff8e76';

  // ── Cloud Functions base URL ───────────────────────────────────────────────
  // If you're still seeing "page not found" errors after this fix,
  // this URL — specifically the region (us-central1) — is the first
  // thing to double check against what Firebase Console → Functions
  // actually shows for initializePaystackTransaction.
  static const String _functionsBaseUrl =
      'https://us-central1-propsure-d8f44.cloudfunctions.net';

  /// Parses an HTTP response defensively. Returns the decoded JSON map on
  /// success, or throws a PaystackException with a message that's always
  /// safe to show a user — never the raw body.
  static Map<String, dynamic> _parseOrThrow(
      http.Response response, String action) {
    final contentType = response.headers['content-type'] ?? '';

    if (response.statusCode == 404) {
      // This is almost always: the Cloud Function isn't deployed, is in
      // a different region than _functionsBaseUrl assumes, or the name
      // doesn't match exactly. Logging the real cause for the developer,
      // not the user.
      // ignore: avoid_print
      print('[Paystack] 404 from $action — check Firebase Console → '
          'Functions: is the function deployed, and in which region?');
      throw PaystackException(
          'We couldn\'t reach the payment service right now. Please try again in a moment, or contact support if this keeps happening.');
    }

    if (!contentType.contains('application/json')) {
      // ignore: avoid_print
      print('[Paystack] Non-JSON response from $action (status '
          '${response.statusCode}): ${response.body.substring(0, response.body.length.clamp(0, 300))}');
      throw PaystackException(
          'Something went wrong starting your payment. Please try again — if it persists, contact support.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      // ignore: avoid_print
      print('[Paystack] Malformed JSON from $action: $e');
      throw PaystackException(
          'Something went wrong on our end. Please try again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // The function DID respond with real JSON (good — it's deployed and
      // reachable), but reported a real failure. `error` is written by
      // our own Cloud Function code, so it's already meant to be
      // user-safe (e.g. "You can only boost your own listing.").
      throw PaystackException((data['error'] as String?) ??
          'Payment could not be started. Please try again.');
    }

    return data;
  }

  static Future<PaystackInitResult> initPayment({
    required String userId,
    required String userEmail,
    required String planId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        return const PaystackInitResult(
            success: false, error: 'Please sign in again and retry.');
      }

      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/initializePaystackTransaction'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'planId': planId,
              'metadata': metadata,
              'callbackUrl': 'https://propsure.africa/payment/callback',
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _parseOrThrow(response, 'initializePaystackTransaction');

      return PaystackInitResult(
        success: true,
        checkoutUrl: data['authorization_url'] as String,
        reference: data['reference'] as String,
      );
    } on PaystackException catch (e) {
      return PaystackInitResult(success: false, error: e.message);
    } catch (e) {
      // ignore: avoid_print
      print('[Paystack] Unexpected error in initPayment: $e');
      return const PaystackInitResult(
          success: false,
          error:
              'Couldn\'t start payment — check your connection and try again.');
    }
  }

  static Future<PaystackVerifyResult> verifyPayment(String reference) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/verifyPaystackTransaction'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'reference': reference}),
          )
          .timeout(const Duration(seconds: 20));

      final data = _parseOrThrow(response, 'verifyPaystackTransaction');

      return PaystackVerifyResult(
        success: data['status'] == 'success',
        reference: reference,
        type: data['type'] as String? ?? '',
        metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      );
    } on PaystackException catch (e) {
      return PaystackVerifyResult(success: false, error: e.message);
    } catch (e) {
      // ignore: avoid_print
      print('[Paystack] Unexpected error in verifyPayment: $e');
      return const PaystackVerifyResult(
          success: false,
          error:
              'Couldn\'t confirm payment status. Please check My Bookings/Listings in a minute.');
    }
  }

  static Stream<TransactionStatus> watchTransaction(String reference) {
    return _db
        .collection(AppConstants.colTransactions)
        .doc(reference)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return TransactionStatus.pending;
      final status = snap.data()?['status'] as String? ?? 'pending';
      switch (status) {
        case 'success':
          return TransactionStatus.success;
        case 'failed':
          return TransactionStatus.failed;
        case 'abandoned':
          return TransactionStatus.abandoned;
        default:
          return TransactionStatus.pending;
      }
    });
  }
}

/// Thrown only with messages that are always safe to render to a user.
class PaystackException implements Exception {
  final String message;
  const PaystackException(this.message);
  @override
  String toString() => message;
}

enum TransactionStatus { pending, success, failed, abandoned }

class PaystackInitResult {
  final bool success;
  final String? checkoutUrl;
  final String? reference;
  final String? error;
  const PaystackInitResult(
      {required this.success, this.checkoutUrl, this.reference, this.error});
}

class PaystackVerifyResult {
  final bool success;
  final String? reference;
  final String? type;
  final Map<String, dynamic>? metadata;
  final String? error;
  const PaystackVerifyResult(
      {required this.success,
      this.reference,
      this.type,
      this.metadata,
      this.error});
}
