import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  AdminService._();
  static final instance = AdminService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  User? get currentUser => _auth.currentUser;

  Future<bool> _readPasswordResetRequiredClaim() async {
    final token = await _auth.currentUser?.getIdTokenResult(true);
    return token?.claims?['passwordResetRequired'] == true;
  }

  Future<Map<String, dynamic>> _call(
    String name, {
    Map<String, dynamic>? data,
  }) async {
    final callable = _functions.httpsCallable(name);
    try {
      final result = await callable.call(data ?? const <String, dynamic>{});
      return Map<String, dynamic>.from(result.data as Map? ?? const {});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated' || e.code == 'permission-denied') {
        await _auth.currentUser?.getIdToken(true);
        final result = await callable.call(data ?? const <String, dynamic>{});
        return Map<String, dynamic>.from(result.data as Map? ?? const {});
      }
      rethrow;
    }
  }

  Future<bool> signIn(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    // Force-refresh token before the admin callable verification.
    await credential.user?.getIdToken(true);

    // Validate admin access via callable (server-side Admin SDK) so the web
    // app does not depend on client Firestore rules for admin_role_users.
    try {
      final authz = await getAdminAuthz();
      final requiresPasswordChange = authz['requiresPasswordChange'] == true;
      if (requiresPasswordChange) {
        return true;
      }
      return await _readPasswordResetRequiredClaim();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        await _auth.signOut();
        throw Exception('Not authorized as admin');
      }
      throw Exception(e.message ?? 'Admin verification failed');
    }
  }

  Future<bool> isPasswordChangeRequired() async {
    if (_auth.currentUser == null) {
      return false;
    }
    try {
      final authz = await getAdminAuthz();
      if (authz['requiresPasswordChange'] == true) {
        return true;
      }
    } on FirebaseFunctionsException catch (_) {
      // Fall back to token claims when backend call is blocked or unavailable.
    }
    return _readPasswordResetRequiredClaim();
  }

  Future<void> setInitialPassword(String newPassword) async {
    await _call('adminSetInitialPassword', data: {
      'newPassword': newPassword,
    });
    await _auth.currentUser?.getIdToken(true);
  }

  Future<void> signOut() => _auth.signOut();

  Future<Map<String, dynamic>> getStats() async {
    return _call('adminGetStats');
  }

  Future<Map<String, dynamic>> listUsers({
    String? role,
    String? userId,
    int limit = 20,
    String? startAfter,
  }) async {
    return _call('adminListUsers', data: {
      'role': role,
      'userId': userId,
      'limit': limit,
      'startAfter': startAfter,
    });
  }

  Future<Map<String, dynamic>> listBookings({
    String? status,
    String? bookingId,
    String? userId,
    String? servicePersonnelId,
    int limit = 20,
    String? startAfter,
  }) async {
    return _call('adminListBookings', data: {
      'status': status,
      'bookingId': bookingId,
      'userId': userId,
      'servicePersonnelId': servicePersonnelId,
      'limit': limit,
      'startAfter': startAfter,
    });
  }

  Future<Map<String, dynamic>> getServices() async {
    return _call('adminGetPricing');
  }

  Future<void> createService(Map<String, dynamic> payload) async {
    await _call('adminCreateService', data: {'service': payload});
  }

  Future<void> deleteService(String serviceId) async {
    await _call('adminDeleteService', data: {'serviceId': serviceId});
  }

  Future<Map<String, dynamic>> listTransactions({
    String? transactionId,
    String? bookingId,
    String? userId,
    String? servicePersonnelId,
    int limit = 20,
    String? startAfter,
  }) async {
    return _call('adminListTransactions', data: {
      'transactionId': transactionId,
      'bookingId': bookingId,
      'userId': userId,
      'servicePersonnelId': servicePersonnelId,
      'limit': limit,
      'startAfter': startAfter,
    });
  }

  Future<void> updateTransaction(
      String transactionId, Map<String, dynamic> updates) async {
    await _call('adminUpdateTransaction',
        data: {'transactionId': transactionId, 'updates': updates});
  }

  Future<Map<String, dynamic>> listServicePersonnel({
    int limit = 50,
    String? startAfter,
  }) async {
    return _call('adminListServicePersonnel', data: {
      'limit': limit,
      'startAfter': startAfter,
    });
  }

  Future<Map<String, dynamic>> listPartners({
    int limit = 100,
    String? startAfter,
  }) async {
    return _call('adminListPartners', data: {
      'limit': limit,
      'startAfter': startAfter,
    });
  }

  Future<void> upsertPartner(String email, bool isActive) async {
    await _call('adminUpsertPartner',
        data: {'email': email, 'isActive': isActive});
  }

  Future<void> deletePartner(String email) async {
    await _call('adminDeletePartner', data: {'email': email});
  }

  Future<Map<String, dynamic>> listAdmins({int limit = 100}) async {
    return _call('adminListAdmins', data: {'limit': limit});
  }

  Future<Map<String, dynamic>> getAdminAuthz() async {
    return _call('adminGetAdminAuthz');
  }

  Future<Map<String, dynamic>> listAuditLogs({
    int limit = 100,
    String? startAfterId,
  }) async {
    return _call('adminListAuditLogs', data: {
      'limit': limit,
      'startAfterId': startAfterId,
    });
  }

  Future<Map<String, dynamic>> grantAdminRole({
    String? email,
    String? uid,
    String adminType = 'secondary',
  }) async {
    return _call('grantAdminRole', data: {
      'email': email,
      'uid': uid,
      'adminType': adminType,
    });
  }

  Future<void> removeAdmin(String email) async {
    await _call('adminRemoveAdmin', data: {'email': email});
  }

  Future<Map<String, dynamic>> uploadEntityImage({
    required String entityType,
    required String entityId,
    required List<int> bytes,
    required String contentType,
    String? fileName,
  }) async {
    return _call('adminUploadEntityImage', data: {
      'entityType': entityType,
      'entityId': entityId,
      'contentType': contentType,
      'fileName': fileName,
      'dataBase64': base64Encode(bytes),
    });
  }

  Future<void> updateServicePersonnel(
      String personnelId, Map<String, dynamic> updates) async {
    await _call('adminUpdateServicePersonnel',
        data: {'personnelId': personnelId, 'updates': updates});
  }

  Future<void> deleteServicePersonnel(String personnelId) async {
    await _call('adminDeleteServicePersonnel',
        data: {'personnelId': personnelId});
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _call('adminUpdateUser',
        data: {'userId': userId, 'updates': updates});
  }

  Future<void> deleteUser(String userId) async {
    await _call('adminDeleteUser', data: {'userId': userId});
  }

  Future<void> upsertUser(String userId, Map<String, dynamic> payload) async {
    await _call('adminUpsertUser', data: {'userId': userId, 'data': payload});
  }

  Future<void> updateBooking(
      String bookingId, Map<String, dynamic> updates) async {
    await _call('adminUpdateBooking',
        data: {'bookingId': bookingId, 'updates': updates});
  }

  Future<void> reassignCaregiver(
      String bookingId, String newCaregiverId, String reason) async {
    await _call('adminReassignCaregiver', data: {
      'bookingId': bookingId,
      'newCaregiverId': newCaregiverId,
      'reason': reason,
    });
  }

  Future<void> approveCaregiver(String caregiverId, bool approved) async {
    await _call('adminApproveCaregiver', data: {
      'caregiverId': caregiverId,
      'approved': approved,
    });
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    await _call('adminCancelBooking', data: {
      'bookingId': bookingId,
      'reason': reason,
      'issueRefund': true,
    });
  }

  Future<void> updatePricing(
      String serviceId, Map<String, dynamic> updates) async {
    await _call('adminUpdatePricing', data: {
      'serviceId': serviceId,
      'updates': updates,
    });
  }

  Future<void> updatePlatformFee(double feePercent) async {
    await _call('adminUpdatePlatformFee', data: {'feePercent': feePercent});
  }

  Future<void> broadcastNotification({
    required String title,
    required String body,
    String? targetRole,
  }) async {
    await _call('adminBroadcastNotification', data: {
      'title': title,
      'body': body,
      'targetRole': targetRole,
    });
  }
}
