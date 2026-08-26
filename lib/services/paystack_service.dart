import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';

/// ALL Paystack secret key operations happen in Cloud Functions.
/// This service only:
///   1. Creates a payment record in Firestore (pending)
///   2. Calls our Cloud Function to initialise the transaction
///   3. Gives the Flutter app a checkout URL to open in WebView
///   4. Verifies completion by calling our Cloud Function (never Paystack directly)
///
/// The Paystack SECRET KEY never touches the Flutter app.
/// ONLY the PUBLIC KEY is used client-side (for the WebView form).
class PaystackService {
  static final _db = FirebaseFirestore.instance;

  // ── PUBLIC KEY only — safe to be in app ──────────────────────────────────
  // Replace with your live public key. This is NOT secret.
  // For test: 'pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  // For live: 'pk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  // ⚠️  Replace with your live Paystack public key from https://dashboard.paystack.com
  // This is the PUBLIC key — safe to ship in the app. Never put the SECRET key here.
  static const String publicKey = 'pk_live_689c8cfad7a1370ed22403fafade7263ecff8e76';

  // ── Cloud Function base URL ───────────────────────────────────────────────
  // After deploying Cloud Functions, replace with your project's URL
  // e.g. 'https://us-central1-propsure-app.cloudfunctions.net'
  // Cloud Functions base URL — your deployed project
  static const String _functionsBaseUrl =
      'https://us-central1-propsure-d8f44.cloudfunctions.net';

  /// Initialise a payment. Returns a checkout URL to open in WebView.
  /// The secret key call happens entirely in the Cloud Function.
  static Future<PaystackInitResult> initPayment({
    required String userId,
    required String userEmail,
    required int amountKobo, // Paystack uses kobo (multiply NGN by 100)
    required String
        type, // 'boost' | 'premium' | 'inspection_fee' | 'reservation'
    required Map<String, dynamic> metadata,
  }) async {
    try {
      // 1. Create idempotent reference
      final reference = 'propsure_${const Uuid().v4().replaceAll('-', '')}';

      // 2. Save pending transaction to Firestore for audit trail
      await _db.collection(AppConstants.colTransactions).doc(reference).set({
        'reference': reference,
        'userId': userId,
        'userEmail': userEmail,
        'amountKobo': amountKobo,
        'amountNGN': amountKobo / 100,
        'type': type,
        'metadata': metadata,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Call Cloud Function to get checkout URL (secret key lives there)
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/initializePaystackTransaction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken', // Authenticated call
        },
        body: jsonEncode({
          'reference': reference,
          'email': userEmail,
          'amount': amountKobo,
          'metadata': metadata,
          'callbackUrl': 'https://propsure.africa/payment/callback',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Payment initiation failed: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PaystackInitResult(
        success: true,
        checkoutUrl: data['authorization_url'] as String,
        reference: reference,
      );
    } catch (e) {
      return PaystackInitResult(success: false, error: e.toString());
    }
  }

  /// Verify a completed payment. Calls Cloud Function — never Paystack directly.
  static Future<PaystackVerifyResult> verifyPayment(String reference) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/verifyPaystackTransaction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'reference': reference}),
      );

      if (response.statusCode != 200) {
        throw Exception('Verification failed: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PaystackVerifyResult(
        success: data['status'] == 'success',
        reference: reference,
        type: data['type'] as String? ?? '',
        metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      return PaystackVerifyResult(success: false, error: e.toString());
    }
  }

  /// Stream a transaction document — UI listens for status changes
  /// (Cloud Function updates this after webhook confirmation)
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
