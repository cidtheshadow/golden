import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as google;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final google.GoogleSignIn _googleSignIn = google.GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return await _auth.signInWithPopup(googleProvider);
    } else {
      final google.GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final google.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      return await _auth.signInWithCredential(credential);
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    debugPrint('[PhoneAuth] Starting verifyPhoneNumber');
    debugPrint('[PhoneAuth] Platform: ${kIsWeb ? "Web" : "Native"}');

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) {
        debugPrint('[PhoneAuth] verificationCompleted (auto-resolved)');
        verificationCompleted(credential);
      },
      verificationFailed: (e) {
        debugPrint(
          '[PhoneAuth] verificationFailed: code=${e.code} msg=${e.message}',
        );
        verificationFailed(e);
      },
      codeSent: (verificationId, resendToken) {
        debugPrint('[PhoneAuth] codeSent');
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        debugPrint('[PhoneAuth] codeAutoRetrievalTimeout');
        codeAutoRetrievalTimeout(verificationId);
      },
      timeout: const Duration(seconds: 60),
    );
    debugPrint('[PhoneAuth] verifyPhoneNumber call returned');
  }

  Future<UserCredential?> signInWithPhoneNumber(
    String verificationId,
    String smsCode,
  ) async {
    final AuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<UserCredential?> linkWithPhoneNumber(
    String verificationId,
    String smsCode,
  ) async {
    final AuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in to link phone number');
    return await user.linkWithCredential(credential);
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      // Ignore Google sign-out errors if session already expired
    }
    await _auth.signOut();
  }
}
