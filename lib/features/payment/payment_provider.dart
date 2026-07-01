import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/secure_storage_service.dart';
import 'payment_service.dart';

enum PaymentState { idle, loading, success, failed }

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, AsyncValue<PaymentState>>((ref) {
  return PaymentNotifier(ref);
});

class PaymentNotifier extends StateNotifier<AsyncValue<PaymentState>> {
  PaymentNotifier(this.ref) : super(const AsyncData(PaymentState.idle));

  final Ref ref;
  final SecureStorageService _secureStorage = SecureStorageService();
  String? _currentTransactionId;
  String? _currentOrderId;
  String? _boundBookingId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bookingSub;

  static const _kPendingBookingId = 'payment_pending_booking_id';
  static const _kPendingTransactionId = 'payment_pending_transaction_id';
  static const _kPendingOrderId = 'payment_pending_order_id';

  Future<void> _persistPendingContext({
    required String bookingId,
    required String transactionId,
    required String orderId,
  }) async {
    await _secureStorage.write(_kPendingBookingId, bookingId);
    await _secureStorage.write(_kPendingTransactionId, transactionId);
    await _secureStorage.write(_kPendingOrderId, orderId);
  }

  Future<void> _clearPendingContext() async {
    await _secureStorage.delete(_kPendingBookingId);
    await _secureStorage.delete(_kPendingTransactionId);
    await _secureStorage.delete(_kPendingOrderId);
  }

  Future<void> bindBooking(String bookingId) async {
    if (_boundBookingId == bookingId && _bookingSub != null) {
      return;
    }

    await _bookingSub?.cancel();
    _boundBookingId = bookingId;

    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final paymentStatus =
          (data['paymentStatus'] as String? ?? '').toLowerCase();
      final bookingStatus = (data['status'] as String? ?? '').toLowerCase();
      final bookingTransactionId = data['transactionId'] as String?;

      if (bookingTransactionId != null && bookingTransactionId.isNotEmpty) {
        _currentTransactionId = bookingTransactionId;
        await _secureStorage.write(
            _kPendingTransactionId, bookingTransactionId);
      }

      if (paymentStatus == 'paid' || paymentStatus == 'captured') {
        state = const AsyncData(PaymentState.success);
        await _clearPendingContext();
        return;
      }

      if (paymentStatus == 'failed' ||
          paymentStatus == 'refund_failed' ||
          bookingStatus == 'expired' ||
          bookingStatus == 'cancelled') {
        state = const AsyncData(PaymentState.failed);
        await _clearPendingContext();
        return;
      }

      if (paymentStatus == 'pending_payment' ||
          paymentStatus == 'pending' ||
          paymentStatus == 'initiated' ||
          paymentStatus == 'payment_initiated' ||
          bookingStatus == 'pending_payment') {
        state = const AsyncData(PaymentState.loading);
      }
    });
  }

  Future<void> recoverPendingContext({required String bookingId}) async {
    await bindBooking(bookingId);

    final storedBookingId = await _secureStorage.read(_kPendingBookingId);
    final storedTx = await _secureStorage.read(_kPendingTransactionId);
    final storedOrder = await _secureStorage.read(_kPendingOrderId);

    if (storedBookingId == bookingId) {
      if (storedTx != null && storedTx.isNotEmpty) {
        _currentTransactionId = storedTx;
      }
      if (storedOrder != null && storedOrder.isNotEmpty) {
        _currentOrderId = storedOrder;
      }
    }

    try {
      final bookingSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (!bookingSnap.exists) {
        return;
      }

      final booking = bookingSnap.data() ?? <String, dynamic>{};
      final txId = booking['transactionId'] as String?;
      final paymentStatus =
          (booking['paymentStatus'] as String? ?? '').toLowerCase();

      if (txId != null && txId.isNotEmpty) {
        _currentTransactionId = txId;
        await _secureStorage.write(_kPendingBookingId, bookingId);
        await _secureStorage.write(_kPendingTransactionId, txId);
      }

      if (paymentStatus == 'paid' || paymentStatus == 'captured') {
        state = const AsyncData(PaymentState.success);
        await _clearPendingContext();
      } else if (paymentStatus == 'pending_payment' ||
          paymentStatus == 'pending' ||
          paymentStatus == 'initiated') {
        state = const AsyncData(PaymentState.loading);
      }
    } catch (e) {
      debugPrint('[PAYMENT ERROR] recoverPendingContext: $e');
    }
  }

  Future<void> initiatePayment({
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    required String description,
    required FutureOr<void> Function(
      String paymentId,
      String orderId,
      String signature,
    ) onSuccess,
    required void Function(String error) onFailure,
  }) async {
    state = const AsyncLoading();
    try {
      await bindBooking(bookingId);
      final service = ref.read(paymentServiceProvider);
      final orderData = await service.createOrder(
        bookingId: bookingId,
      );

      _currentTransactionId = orderData['transactionId'] as String;
      _currentOrderId = orderData['orderId'] as String;
      await _persistPendingContext(
        bookingId: bookingId,
        transactionId: _currentTransactionId!,
        orderId: _currentOrderId!,
      );
      final keyId = orderData['keyId'] as String;
      final amountInPaise = (orderData['amount'] as num).toInt();

      await service.openCheckout(
        keyId: keyId,
        orderId: _currentOrderId!,
        amount: amountInPaise,
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        description: description,
        onSuccess: (paymentId, orderId, signature) {
          try {
            final maybeFuture = onSuccess(paymentId, orderId, signature);
            if (maybeFuture is Future) {
              maybeFuture.catchError((error, stackTrace) {
                debugPrint(
                    '[PAYMENT ERROR] onSuccess callback async error: $error');
                state = AsyncError(error, stackTrace);
                onFailure(
                  'Payment succeeded but verification failed. Please retry from booking details.',
                );
              });
            }
          } catch (error, stackTrace) {
            debugPrint('[PAYMENT ERROR] onSuccess callback sync error: $error');
            state = AsyncError(error, stackTrace);
            onFailure(
              'Payment succeeded but verification failed. Please retry from booking details.',
            );
          }
        },
        onFailure: (error) {
          state = const AsyncData(PaymentState.failed);
          onFailure(error);
        },
      );

      state = const AsyncData(PaymentState.loading);
    } catch (e, st) {
      debugPrint('[PAYMENT ERROR] initiatePayment: $e');
      state = AsyncError(e, st);
      final msg = e.toString().toLowerCase();
      final isAppCheckFailure = msg.contains('app check') ||
          msg.contains('appcheck') ||
          msg.contains('recaptcha');

      if (isAppCheckFailure) {
        onFailure('Security validation failed. Please refresh and try again.');
      } else if (msg.contains('configured in test mode')) {
        onFailure(
            'Payment server is in test mode. Please contact support to enable live payments.');
      } else if (msg.contains('configured in live mode for a testing build')) {
        onFailure(
            'Payment server is in live mode for testing build. Please switch to production app.');
      } else if (e is FirebaseFunctionsException &&
          e.code == 'unauthenticated') {
        onFailure('Session expired. Please sign in again.');
      } else if (msg.contains('session expired')) {
        onFailure('Session expired. Please sign in again.');
      } else {
        onFailure(e.toString());
      }
    }
  }

  Future<void> completePayment({
    required String bookingId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    await recoverPendingContext(bookingId: bookingId);

    if (_currentTransactionId == null || _currentTransactionId!.isEmpty) {
      state = const AsyncData(PaymentState.failed);
      return;
    }

    try {
      final service = ref.read(paymentServiceProvider);
      final result = await service.verifyPayment(
        transactionId: _currentTransactionId!,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      );
      final success = result['success'] == true;
      state = AsyncData(
        success ? PaymentState.success : PaymentState.failed,
      );
      if (success) {
        await _clearPendingContext();
      }
      debugPrint('[PAYMENT] Verification: $success');
    } catch (e, st) {
      debugPrint('[PAYMENT ERROR] completePayment: $e');
      state = AsyncError(e, st);
    }
  }

  Future<void> reset() async {
    await _bookingSub?.cancel();
    _bookingSub = null;
    _boundBookingId = null;
    _currentTransactionId = null;
    _currentOrderId = null;
    await _clearPendingContext();
    state = const AsyncData(PaymentState.idle);
  }
}
