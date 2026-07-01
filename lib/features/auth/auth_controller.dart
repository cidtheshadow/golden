import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase/auth_service.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../firebase/notification_service.dart';
import '../../firebase/secure_storage_service.dart';
import '../../utils/error_handler.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

bool _isInvalidSessionAuthError(Object error) {
  if (error is! FirebaseAuthException) return false;

  const invalidCodes = {
    'user-disabled',
    'user-not-found',
    'invalid-user-token',
    'user-token-expired',
    'requires-recent-login',
  };

  return invalidCodes.contains(error.code);
}

final authSessionValidProvider = StreamProvider<bool>((ref) async* {
  await for (final user in FirebaseAuth.instance.idTokenChanges()) {
    if (user == null) {
      yield false;
      continue;
    }

    try {
      // Avoid forced refresh on every token change; use cached token when valid.
      await user.getIdToken(false).timeout(const Duration(seconds: 3));
      yield true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] Session validation failed type=${e.runtimeType}');
        debugPrint('[AUTH] Session validation failed error=$e');
      }

      if (_isInvalidSessionAuthError(e)) {
        await ref.read(authControllerProvider.notifier).signOut();
        yield false;
      } else {
        // Keep user signed in for transient failures (network/timeout).
        yield true;
      }
    }
  }
});

final userModelProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).getUserStream(authUser.uid);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<bool> {
  final Ref _ref;
  AuthController(this._ref) : super(false);

  AuthService get _authService => _ref.read(authServiceProvider);
  UserRepository get _userRepo => _ref.read(userRepositoryProvider);

  String? _verificationId;
  int? _resendToken;

  Future<void> verifyPhone(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    if (state) {
      debugPrint('[AuthController] verifyPhone already in progress');
      return;
    }
    state = true;
    debugPrint('[AuthController] verifyPhone started');
    try {
      // Check if phone number is already in use by another account
      final currentUser = _authService.currentUser;
      final inUse = await _userRepo.isPhoneNumberInUse(phoneNumber,
          excludeUid: currentUser?.uid);
      if (inUse) {
        state = false;
        onError('This phone number is already linked to another account.');
        return;
      }

      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[AuthController] Auto-verification completed');
          state = false;
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint(
              '[AuthController] Verification failed: ${e.code} - ${e.message}');
          state = false;
          onError(ErrorHandler.handle(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[AuthController] Code sent');
          _verificationId = verificationId;
          _resendToken = resendToken;
          state = false;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[AuthController] Auto-retrieval timeout');
          _verificationId = verificationId;
          // Make sure state is released if it got stuck
          if (state) state = false;
        },
      );
      debugPrint('[AuthController] verifyPhoneNumber returned');
    } catch (e) {
      debugPrint('[AuthController] Exception in verifyPhone: $e');
      state = false;
      onError(ErrorHandler.handle(e));
    }
  }

  Future<UserCredential?> verifyOtp(String smsCode) async {
    if (_verificationId == null) throw Exception('Verification ID is missing');
    state = true;
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Link to existing account to avoid session switch/partial logout
        return await _authService.linkWithPhoneNumber(
            _verificationId!, smsCode);
      } else {
        // Fallback to sign in (usually for new registrations)
        return await _authService.signInWithPhoneNumber(
            _verificationId!, smsCode);
      }
    } on FirebaseAuthException catch (e) {
      // These errors mean the OTP was CORRECT but the phone credential
      // couldn't be linked (already used by another account, or already linked
      // to the current account). The phone verification was still successful.
      if (e.code == 'credential-already-in-use' ||
          e.code == 'account-exists-with-different-credential' ||
          e.code == 'provider-already-linked') {
        debugPrint('[AuthController] Phone link conflict (${e.code})');
        return null; // null signals "OTP valid, linking skipped"
      }
      debugPrint(
          '[AuthController] verifyOtp FirebaseAuth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthController] verifyOtp error: $e');
      rethrow;
    } finally {
      state = false;
    }
  }

  Future<void> login(String email, String password, String role) async {
    state = true;
    try {
      if (role == 'caregiver') {
        final isWhitelisted = await _userRepo.isEmailWhitelisted(email);
        if (!isWhitelisted) {
          throw Exception('This email is not authorized as a caregiver.');
        }
      }
      final cred = await _authService.signInWithEmail(email, password);
      if (cred == null || cred.user == null) {
        throw Exception('Sign in failed. Please check your credentials.');
      }

      debugPrint('[AuthController] Login success. role=$role');

      // Update user role in Firestore so the router can detect it
      await _userRepo.updateUserProfile(cred.user!.uid, {'role': role});
      debugPrint('[AuthController] Updated Firestore role');

      // Update FCM Token
      await NotificationService().updateFCMToken(cred.user!.uid,
          collection: role == 'caregiver' ? 'servicePersonnel' : 'users');
    } catch (e) {
      debugPrint('[AuthController] login error: $e');
      rethrow;
    } finally {
      state = false;
    }
  }

  /// Creates a Firebase Auth account, then writes the user document to Firestore.
  Future<void> register(
      String name, String email, String password, String role) async {
    state = true;
    try {
      if (role == 'caregiver') {
        final isWhitelisted = await _userRepo.isEmailWhitelisted(email);
        if (!isWhitelisted) {
          throw Exception('This email is not authorized as a caregiver.');
        }
      }

      final cred = await _authService.signUpWithEmail(email, password);
      if (cred == null || cred.user == null) {
        throw Exception('Registration failed.');
      }
      final firebaseUser = cred.user!;

      // Update display name in Firebase Auth for UX
      await firebaseUser.updateDisplayName(name);

      // Write user document to Firestore
      final newUser = UserModel(
        uid: firebaseUser.uid,
        name: name,
        email: email,
        phone: '',
        address: '',
        role: role,
        emergencyContacts: [],
      );
      await _userRepo.createOrUpdateUser(newUser);

      // Send Email Verification
      await _authService.sendEmailVerification();

      // Update FCM Token
      await NotificationService().updateFCMToken(firebaseUser.uid,
          collection: role == 'caregiver' ? 'servicePersonnel' : 'users');
    } catch (e) {
      debugPrint('[AuthController] register error: $e');
      rethrow;
    } finally {
      state = false;
    }
  }

  Future<void> signInWithGoogle(String role) async {
    state = true;
    try {
      debugPrint('[AUTH] Google sign-in started, role=$role');
      final cred = await _authService.signInWithGoogle();
      if (cred == null || cred.user == null) {
        debugPrint(
            '[AUTH] Google sign-in: user cancelled (popup closed or no account selected)');
        return;
      }
      final firebaseUser = cred.user!;
      debugPrint('[AUTH] Google sign-in success — uid: ${firebaseUser.uid}');

      if (role == 'caregiver') {
        debugPrint(
            '[AUTH] Role fetch path: whitelisted_partners/${firebaseUser.email}');
        final isWhitelisted =
            await _userRepo.isEmailWhitelisted(firebaseUser.email ?? '');
        debugPrint('[AUTH] Whitelist check result: $isWhitelisted');
        if (!isWhitelisted) {
          await _authService.signOut();
          throw Exception(
              'This Google account is not authorized as a caregiver.');
        }
      }

      // Create default user doc if this is a new Google sign-in
      debugPrint('[AUTH] Role fetch path: users/${firebaseUser.uid}');
      final existing = await _ref
          .read(userRepositoryProvider)
          .getUserStream(firebaseUser.uid)
          .first;
      debugPrint('[AUTH] Role fetched: ${existing?.role ?? "(no doc yet)"}');
      if (existing == null) {
        final newUser = UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
          phone: '',
          address: '',
          role: role,
          emergencyContacts: [],
        );
        await _userRepo.createOrUpdateUser(newUser);
        debugPrint('[AUTH] Created new user doc with role: $role');
      } else if (existing.role != role) {
        await _userRepo.updateUserProfile(firebaseUser.uid, {'role': role});
        debugPrint('[AUTH] Updated existing user role to: $role');
      }

      // Update FCM Token for the user
      await NotificationService().updateFCMToken(firebaseUser.uid,
          collection: role == 'caregiver' ? 'servicePersonnel' : 'users');
      debugPrint(
          '[AUTH] Routing to: ${role == 'caregiver' ? '/partner/dashboard or /partner/register' : '/dashboard/family'}');
    } catch (e) {
      debugPrint('[AUTH ERROR] ${e.runtimeType}: $e');
      rethrow;
    } finally {
      state = false;
    }
  }

  Future<void> reloadUser() async {
    await _authService.reloadUser();
    // Trigger authState refresh
    _ref.invalidate(authStateProvider);
  }

  Future<void> sendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  Future<void> signOut() async {
    await SecureStorageService().clearSession();
    await _authService.signOut();
  }
}
