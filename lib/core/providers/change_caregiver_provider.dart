import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangeCaregiverState {
  final bool isLoading;
  final bool success;
  final String? error;

  const ChangeCaregiverState({
    this.isLoading = false,
    this.success = false,
    this.error,
  });

  ChangeCaregiverState copyWith({
    bool? isLoading,
    bool? success,
    String? error,
  }) {
    return ChangeCaregiverState(
      isLoading: isLoading ?? this.isLoading,
      success: success ?? this.success,
      error: error,
    );
  }
}

class ChangeCaregiverNotifier extends StateNotifier<ChangeCaregiverState> {
  ChangeCaregiverNotifier() : super(const ChangeCaregiverState());

  Future<bool> changeCaregiver({
    required String bookingId,
    required String newCaregiverId,
    String reason = '',
  }) async {
    state = state.copyWith(isLoading: true, success: false, error: null);

    try {
      await FirebaseFunctions.instance.httpsCallable('changeCaregiver').call({
        'bookingId': bookingId,
        'newCaregiverId': newCaregiverId,
        'reason': reason,
      });

      state = state.copyWith(isLoading: false, success: true, error: null);
      return true;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
        isLoading: false,
        success: false,
        error: e.message ?? 'Failed to change caregiver',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        success: false,
        error: e.toString(),
      );
      return false;
    }
  }
}

final changeCaregiverProvider = StateNotifierProvider.autoDispose<
    ChangeCaregiverNotifier, ChangeCaregiverState>(
  (ref) => ChangeCaregiverNotifier(),
);
