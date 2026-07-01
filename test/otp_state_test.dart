import 'package:flutter_test/flutter_test.dart';
import 'package:golden_care_app/core/providers/otp_provider.dart';

void main() {
  group('OtpState', () {
    test('copyWith preserves existing values when args are null', () {
      const initial = OtpState(
        isLoading: true,
        error: 'x',
        success: true,
        generatedStartOtp: '123456',
        generatedCompletionOtp: '654321',
        generatedForBookingId: 'booking-1',
      );

      final updated = initial.copyWith();

      expect(updated.isLoading, isTrue);
      expect(updated.error, isNull);
      expect(updated.success, isTrue);
      expect(updated.generatedStartOtp, '123456');
      expect(updated.generatedCompletionOtp, '654321');
      expect(updated.generatedForBookingId, 'booking-1');
    });

    test('copyWith updates generated OTP values', () {
      const initial = OtpState();

      final updated = initial.copyWith(
        generatedStartOtp: '111222',
        generatedCompletionOtp: '333444',
        generatedForBookingId: 'booking-2',
        success: true,
      );

      expect(updated.generatedStartOtp, '111222');
      expect(updated.generatedCompletionOtp, '333444');
      expect(updated.generatedForBookingId, 'booking-2');
      expect(updated.success, isTrue);
    });
  });
}
