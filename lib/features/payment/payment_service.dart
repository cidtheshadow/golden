import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_environment.dart';
import 'payment_service_stub.dart'
    if (dart.library.js_interop) 'razorpay_web.dart'
    if (dart.library.io) 'razorpay_mobile.dart';

abstract class PaymentCheckoutService {
  void initialize();
  void dispose();

  Future<void> openCheckout({
    required String keyId,
    required String orderId,
    required int amount,
    required String userEmail,
    required String userName,
    required String userPhone,
    required String description,
    required void Function(String paymentId, String orderId, String signature)
        onSuccess,
    required void Function(String errorMessage) onFailure,
  });
}

class PaymentService {
  PaymentService({PaymentCheckoutService? checkoutService})
      : _checkoutService = checkoutService ?? getPaymentCheckoutService();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final PaymentCheckoutService _checkoutService;

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

  bool _isLikelyAppCheckFailure(FirebaseFunctionsException e) {
    final message = (e.message ?? '').toLowerCase();
    final details = '${e.details ?? ''}'.toLowerCase();
    final payload = '$message $details';

    return payload.contains('app check') ||
        payload.contains('appcheck') ||
        payload.contains('recaptcha') ||
        payload.contains('attestation');
  }

  Future<void> _ensureCallableAuth() async {
    final auth = FirebaseAuth.instance;
    User? user = auth.currentUser;

    if (user == null) {
      try {
        user = await auth.authStateChanges().first.timeout(
              const Duration(seconds: 2),
            );
      } catch (_) {
        // Fall through to explicit unauthenticated error below.
      }
    }

    if (user == null) {
      throw Exception('Session expired. Please sign in again.');
    }

    try {
      await user.getIdToken(false).timeout(const Duration(seconds: 3));
    } catch (e) {
      if (_isInvalidSessionAuthError(e)) {
        await auth.signOut();
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  void initialize() => _checkoutService.initialize();

  void dispose() => _checkoutService.dispose();

  Future<Map<String, dynamic>> createOrder({
    required String bookingId,
  }) async {
    try {
      await _ensureCallableAuth();
      if (kDebugMode) {
        debugPrint('[PAYMENT] Creating payment order');
      }
      final callable = _functions.httpsCallable('createRazorpayOrder');
      final result = await callable.call({
        'bookingId': bookingId,
        'keyMode': AppEnvironment.isProduction ? 'live' : 'test',
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (kDebugMode) {
        debugPrint('[PAYMENT] Order created successfully');
      }
      return data;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        if (_isLikelyAppCheckFailure(e)) {
          throw Exception(
              'Security validation failed. Please refresh and try again.');
        }
        throw Exception('Session expired. Please sign in again.');
      }
      if (kDebugMode) {
        debugPrint('[PAYMENT ERROR] ${e.code}: ${e.message}');
      }
      rethrow;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            '[PAYMENT ERROR] createOrder non-firebase type=${e.runtimeType}');
        debugPrint('[PAYMENT ERROR] createOrder non-firebase message=$e');
        debugPrint('[PAYMENT ERROR] createOrder non-firebase stack=$st');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String transactionId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      await _ensureCallableAuth();
      if (kDebugMode) {
        debugPrint('[PAYMENT] Verifying payment signature');
      }
      final callable = _functions.httpsCallable('verifyRazorpayPayment');
      final result = await callable.call({
        'transactionId': transactionId,
        'paymentId': paymentId,
        'orderId': orderId,
        'signature': signature,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        if (_isLikelyAppCheckFailure(e)) {
          throw Exception(
              'Security validation failed. Please refresh and try again.');
        }
        throw Exception('Session expired. Please sign in again.');
      }
      if (kDebugMode) {
        debugPrint('[PAYMENT ERROR] ${e.code}: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> openCheckout({
    required String keyId,
    required String orderId,
    required int amount,
    required String userEmail,
    required String userName,
    required String userPhone,
    required String description,
    required void Function(String paymentId, String orderId, String signature)
        onSuccess,
    required void Function(String errorMessage) onFailure,
  }) {
    return _checkoutService.openCheckout(
      keyId: keyId,
      orderId: orderId,
      amount: amount,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
      description: description,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final service = PaymentService();
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});
