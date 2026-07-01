import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OtpAction {
  generateStart,
  verifyStart,
  generateCompletion,
  verifyCompletion,
}

class OtpState {
  final bool isLoading;
  final String? error;
  final bool success;
  final String? generatedStartOtp;
  final String? generatedCompletionOtp;
  final String? generatedForBookingId;

  const OtpState({
    this.isLoading = false,
    this.error,
    this.success = false,
    this.generatedStartOtp,
    this.generatedCompletionOtp,
    this.generatedForBookingId,
  });

  OtpState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
    String? generatedStartOtp,
    String? generatedCompletionOtp,
    String? generatedForBookingId,
  }) {
    return OtpState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
      generatedStartOtp: generatedStartOtp ?? this.generatedStartOtp,
      generatedCompletionOtp:
          generatedCompletionOtp ?? this.generatedCompletionOtp,
      generatedForBookingId:
          generatedForBookingId ?? this.generatedForBookingId,
    );
  }
}

class OtpNotifier extends StateNotifier<OtpState> {
  OtpNotifier() : super(const OtpState());

  Future<void> _ensureCallableAuth() async {
    final auth = FirebaseAuth.instance;
    User? user = auth.currentUser;
    if (user == null) {
      try {
        user = await auth.authStateChanges().first.timeout(
              const Duration(seconds: 2),
            );
      } catch (_) {
        // Fall through.
      }
    }

    if (user == null) {
      throw Exception('Session expired. Please sign in again.');
    }

    await user.getIdToken(true);
  }

  Future<bool> generateStartOtp(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _ensureCallableAuth();
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateStartOtp')
          .call({'bookingId': bookingId});
      final data = Map<String, dynamic>.from(result.data as Map);
      final otp = (data['otp'] as String?)?.trim();
      state = state.copyWith(
        isLoading: false,
        success: true,
        generatedStartOtp: otp,
        generatedCompletionOtp: null,
        generatedForBookingId: bookingId,
      );
      return true;
    } on FirebaseFunctionsException catch (error) {
      final message = error.code == 'unauthenticated'
          ? 'Session expired. Please sign in again.'
          : (error.message ?? 'Failed to generate start OTP');
      state = state.copyWith(
        isLoading: false,
        error: message,
        generatedStartOtp: null,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to generate start OTP. Please try again.',
        generatedStartOtp: null,
      );
      return false;
    }
  }

  Future<bool> verifyStartOtp(String bookingId, String otp) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _ensureCallableAuth();
      await FirebaseFunctions.instance.httpsCallable('verifyStartOtp').call({
        'bookingId': bookingId,
        'otp': otp.trim(),
      });
      state = state.copyWith(
        isLoading: false,
        success: true,
        generatedStartOtp: null,
      );
      return true;
    } on FirebaseFunctionsException catch (error) {
      final message = error.code == 'unauthenticated'
          ? 'Session expired. Please sign in again.'
          : (error.message ?? 'Incorrect start OTP');
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to verify start OTP. Please try again.',
      );
      return false;
    }
  }

  Future<bool> generateCompletionOtp(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _ensureCallableAuth();
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateCompletionOtp')
          .call({'bookingId': bookingId});
      final data = Map<String, dynamic>.from(result.data as Map);
      final otp = (data['otp'] as String?)?.trim();
      state = state.copyWith(
        isLoading: false,
        success: true,
        generatedStartOtp: null,
        generatedCompletionOtp: otp,
        generatedForBookingId: bookingId,
      );
      return true;
    } on FirebaseFunctionsException catch (error) {
      final message = error.code == 'unauthenticated'
          ? 'Session expired. Please sign in again.'
          : (error.message ?? 'Failed to generate completion OTP');
      state = state.copyWith(
        isLoading: false,
        error: message,
        generatedCompletionOtp: null,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to generate completion OTP. Please try again.',
        generatedCompletionOtp: null,
      );
      return false;
    }
  }

  Future<bool> verifyCompletionOtp(String bookingId, String otp) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _ensureCallableAuth();
      await FirebaseFunctions.instance
          .httpsCallable('verifyCompletionOtp')
          .call({
        'bookingId': bookingId,
        'otp': otp.trim(),
      });
      state = state.copyWith(
        isLoading: false,
        success: true,
        generatedCompletionOtp: null,
      );
      return true;
    } on FirebaseFunctionsException catch (error) {
      final message = error.code == 'unauthenticated'
          ? 'Session expired. Please sign in again.'
          : (error.message ?? 'Incorrect completion OTP');
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to verify completion OTP. Please try again.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final otpProvider = StateNotifierProvider.autoDispose<OtpNotifier, OtpState>(
  (ref) => OtpNotifier(),
);
