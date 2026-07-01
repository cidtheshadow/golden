import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../firebase/firestore_service.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirestoreService());
});

class UserRepository {
  final FirestoreService _firestoreService;

  UserRepository(this._firestoreService);

  Future<void> createOrUpdateUser(UserModel user) =>
      _firestoreService.createOrUpdateUser(user);

  Stream<UserModel?> getUserStream(String uid) =>
      _firestoreService.getUserStream(uid);

  Future<void> updateEmergencyContacts(
          String uid, List<Map<String, dynamic>> contacts) =>
      _firestoreService.updateEmergencyContacts(uid, contacts);

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) =>
      _firestoreService.updateUserProfile(uid, data);

  Future<bool> isPhoneNumberInUse(String phoneNumber, {String? excludeUid}) =>
      _firestoreService.isPhoneNumberInUse(phoneNumber, excludeUid: excludeUid);

  Future<void> requestAccountDeletion() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserAccount',
      );
      await callable.call<Map<String, dynamic>>({});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        final message = (e.message ?? '').toLowerCase();
        if (message.contains('re-authenticate')) {
          throw Exception(
            'For security, please sign out and sign in again before deleting your account.',
          );
        }
        throw Exception(
          'You have active bookings. Complete or cancel them before deleting your account.',
        );
      }
      if (e.code == 'unauthenticated') {
        throw Exception('Session expired. Please log in again.');
      }
      if (e.code == 'permission-denied') {
        throw Exception(
            'This account is not eligible for self-service deletion.');
      }
      throw Exception(e.message ?? 'Unable to delete your account right now.');
    } catch (e) {
      throw Exception('Unable to delete your account right now.');
    }
  }

  // From Android parity:
  Future<bool> isEmailWhitelisted(String rawEmail) async {
    final normalizedEmail = rawEmail.trim().toLowerCase();

    // Primary path: rely on backend callable so admin-side active/enabled logic
    // remains the source of truth across all clients.
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'checkWhitelistStatus',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'email': normalizedEmail,
      });
      final data = Map<String, dynamic>.from(result.data);
      if (data['isWhitelisted'] is bool) {
        return data['isWhitelisted'] as bool;
      }
    } catch (e) {
      debugPrint('Callable whitelist check failed, using fallback: $e');
    }

    try {
      final email = rawEmail.trim();
      final db = FirebaseFirestore.instance;

      bool isEnabled(Map<String, dynamic>? data) {
        if (data == null) return true;

        bool? parseBool(dynamic value) {
          if (value is bool) return value;
          if (value is String) {
            final normalized = value.trim().toLowerCase();
            if (normalized == 'true') return true;
            if (normalized == 'false') return false;
          }
          return null;
        }

        final active = parseBool(data['isActive']);
        if (active != null) return active;

        final enabled = parseBool(data['isEnabled']);
        if (enabled != null) return enabled;

        return true;
      }

      var doc = await db.collection('whitelisted_partners').doc(email).get();
      if (doc.exists && isEnabled(doc.data())) {
        return true;
      }

      final lowerEmail = email.toLowerCase();
      if (email != lowerEmail) {
        doc = await db.collection('whitelisted_partners').doc(lowerEmail).get();
        if (doc.exists && isEnabled(doc.data())) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking whitelist: $e');
      return false;
    }
  }
}
