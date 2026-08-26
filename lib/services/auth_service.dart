import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../data/models/user_model.dart';
import '../core/constants/app_constants.dart';

class AuthResult {
  final bool success;
  final String? uid;
  final String? error;
  const AuthResult({required this.success, this.uid, this.error});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Phone OTP ──────────────────────────────────────────────────────────────
  Future<void> sendOTP({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_phoneError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError('Could not start phone verification. Check your connection and Firebase phone-auth setup.');
    }
  }

  String _phoneError(FirebaseAuthException e) {
    switch (e.code) {
      case 'billing-not-enabled':
      case 'quota-exceeded':
      case 'internal-error':
        if ((e.message ?? '').toLowerCase().contains('billing')) {
          return 'Phone sign-in is not enabled for this Firebase project. Enable Phone Authentication and billing in Firebase Console, then try again.';
        }
        return 'Phone verification failed. Check Firebase phone-auth setup and try again.';
      case 'operation-not-allowed':
        return 'Phone sign-in is disabled. Enable Phone provider in Firebase Console > Authentication > Sign-in method.';
      case 'invalid-phone-number':
        return 'That phone number is not valid. Use a Nigerian number such as 08012345678.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'captcha-check-failed':
        return 'Security verification failed. Confirm the app domain, SHA keys, and Firebase phone-auth setup.';
      default:
        return e.message ?? 'Phone verification failed. Please try again.';
    }
  }

  Future<AuthResult> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      return AuthResult(success: true, uid: result.user?.uid);
    } on FirebaseAuthException catch (e) {
      String msg = 'Invalid code. Please try again.';
      if (e.code == 'invalid-verification-code') msg = 'Wrong code. Please check and retry.';
      if (e.code == 'session-expired')           msg = 'Code expired. Please request a new one.';
      return AuthResult(success: false, error: msg);
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  // ── Email / Password ───────────────────────────────────────────────────────
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
      return AuthResult(success: true, uid: result.user?.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _emailError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred. Please try again.');
    }
  }

  Future<AuthResult> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
      // Send email verification (optional but good practice)
      await result.user?.sendEmailVerification();
      return AuthResult(success: true, uid: result.user?.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _emailError(e));
    } catch (e) {
      return AuthResult(success: false, error: 'An unexpected error occurred. Please try again.');
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (_) {
      // Silently fail — don't reveal if email exists or not
    }
  }

  String _emailError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Create an account instead.';
      case 'wrong-password':
        return 'Incorrect password. Try again or reset your password.';
      case 'email-already-in-use':
        return 'This email is already registered. Sign in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check and try again.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────────
  Future<bool> userProfileExists(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    return doc.exists;
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchUserProfile(String uid) {
    return _db
        .collection(AppConstants.colUsers)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> createUserProfile({
    required String uid,
    required String name,
    String? email,
    required String role,
    File? avatarFile,
  }) async {
    String? photoUrl;
    if (avatarFile != null) photoUrl = await _uploadAvatar(uid, avatarFile);

    // Get phone or email from Firebase Auth
    final firebaseUser = _auth.currentUser;
    final phone = firebaseUser?.phoneNumber ?? '';
    final resolvedEmail = email ?? firebaseUser?.email ?? '';

    final user = UserModel(
      uid: uid,
      name: name,
      phone: phone,
      email: resolvedEmail.isNotEmpty ? resolvedEmail : null,
      profilePhoto: photoUrl,
      role: role,
      createdAt: DateTime.now(),
    );

    await _db.collection(AppConstants.colUsers).doc(uid).set(user.toMap());
  }

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
    String? bio,
    String? agencyName,
    File? avatarFile,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null)       updates['name'] = name;
    if (email != null)      updates['email'] = email;
    if (bio != null)        updates['bio'] = bio;
    if (agencyName != null) updates['agencyName'] = agencyName;

    if (avatarFile != null) {
      final photoUrl = await _uploadAvatar(uid, avatarFile);
      updates['profilePhoto'] = photoUrl;
    }

    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection(AppConstants.colUsers).doc(uid).update(updates);
  }

  Future<void> updateFCMToken(String uid, String token) async {
    await _db.collection(AppConstants.colUsers).doc(uid).update({'fcmToken': token});
  }

  Future<void> updateLastSeen(String uid) async {
    await _db
        .collection(AppConstants.colUsers)
        .doc(uid)
        .update({'lastSeen': FieldValue.serverTimestamp()});
  }

  Future<void> signOut() async => await _auth.signOut();

  // ── Avatar upload ──────────────────────────────────────────────────────────
  Future<String> _uploadAvatar(String uid, File file) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      file.path, minWidth: 400, minHeight: 400, quality: 75);
    final ref = _storage.ref('${AppConstants.pathUserAvatars}/$uid.jpg');
    if (compressed != null) {
      await ref.putData(compressed);
    } else {
      await ref.putFile(file);
    }
    return await ref.getDownloadURL();
  }
}
