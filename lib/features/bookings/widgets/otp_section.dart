import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/booking_model.dart';
import '../../../core/providers/otp_provider.dart';
import '../../../core/widgets/otp_input_field.dart';

const Duration _istOffset = Duration(hours: 5, minutes: 30);

DateTime _toIst(DateTime value) => value.toUtc().add(_istOffset);

bool _isSameIstDate(DateTime a, DateTime b) {
  final aIst = _toIst(a);
  final bIst = _toIst(b);
  return aIst.year == bIst.year &&
      aIst.month == bIst.month &&
      aIst.day == bIst.day;
}

class FamilyOtpSection extends ConsumerStatefulWidget {
  final BookingModel booking;

  const FamilyOtpSection({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<FamilyOtpSection> createState() => _FamilyOtpSectionState();
}

class _FamilyOtpSectionState extends ConsumerState<FamilyOtpSection> {
  bool _isBookingDay() {
    return _isSameIstDate(widget.booking.date, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final otpState = ref.watch(otpProvider);
    final isBookingDay = _isBookingDay();
    final otpForCurrentBooking = otpState.generatedForBookingId == booking.id;

    if (!isBookingDay && booking.status == 'confirmed') {
      return const _InfoCard(
        color: Colors.orange,
        text: 'OTP will be available on the day of your service',
      );
    }

    if (booking.status == 'confirmed' && isBookingDay) {
      return _ActionOtpCard(
        title: 'Start OTP',
        subtitle: 'Generate and share this 6-digit OTP with your caregiver.',
        otpDisplay: otpForCurrentBooking ? otpState.generatedStartOtp : null,
        buttonLabel: 'Generate Start OTP',
        isLoading: otpState.isLoading,
        error: otpState.error,
        onPressed: () async {
          await ref.read(otpProvider.notifier).generateStartOtp(booking.id);
        },
      );
    }

    if (booking.status == 'in_progress' ||
        booking.status == 'completion_requested') {
      return _ActionOtpCard(
        title: 'Completion OTP',
        subtitle:
            'Generate and share this OTP with your caregiver to complete service.',
        otpDisplay:
            otpForCurrentBooking ? otpState.generatedCompletionOtp : null,
        buttonLabel: 'Generate Completion OTP',
        isLoading: otpState.isLoading,
        error: otpState.error,
        onPressed: () async {
          await ref
              .read(otpProvider.notifier)
              .generateCompletionOtp(booking.id);
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class CaregiverOtpSection extends ConsumerWidget {
  final BookingModel booking;

  const CaregiverOtpSection({
    super.key,
    required this.booking,
  });

  bool _isBookingDay() {
    return _isSameIstDate(booking.date, DateTime.now());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otpState = ref.watch(otpProvider);
    final isBookingDay = _isBookingDay();

    if (!isBookingDay && booking.status == 'confirmed') {
      return const _InfoCard(
        color: Colors.orange,
        text: 'Start OTP can be generated on booking day only.',
      );
    }

    if (booking.status == 'confirmed' && isBookingDay) {
      return _OtpEntryCard(
        title: 'Enter Start OTP',
        subtitle: 'Ask the family for the 6-digit OTP to begin service.',
        isLoading: otpState.isLoading,
        error: otpState.error,
        onCompleted: (otp) async {
          final success = await ref.read(otpProvider.notifier).verifyStartOtp(
                booking.id,
                otp,
              );
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Service started successfully.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
    }

    if (booking.status == 'in_progress' ||
        booking.status == 'completion_requested') {
      return _OtpEntryCard(
        title: 'Enter Completion OTP',
        subtitle:
            'Ask the family for the 6-digit OTP. You can enter it anytime while service is in progress.',
        isLoading: otpState.isLoading,
        error: otpState.error,
        onCompleted: (otp) async {
          final success = await ref
              .read(otpProvider.notifier)
              .verifyCompletionOtp(booking.id, otp);
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Service completed successfully.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _InfoCard extends StatelessWidget {
  final Color color;
  final String text;

  const _InfoCard({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpEntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLoading;
  final String? error;
  final ValueChanged<String> onCompleted;

  const _OtpEntryCard({
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.error,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final errorText = error ?? '';

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              OtpInputField(onCompleted: onCompleted),
            if (errorText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                errorText,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionOtpCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? otpDisplay;
  final String buttonLabel;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onPressed;

  const _ActionOtpCard({
    required this.title,
    required this.subtitle,
    required this.otpDisplay,
    required this.buttonLabel,
    required this.isLoading,
    required this.error,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final otp = otpDisplay ?? '';
    final errorText = error ?? '';

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            if (otp.isNotEmpty)
              Center(
                child: Text(
                  otp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
              ),
            if (otp.isNotEmpty && title == 'Completion OTP') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFE65100),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: Sharing this completion OTP will end care right now.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        try {
                          await onPressed();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to complete this action: $e',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(otp.isEmpty ? buttonLabel : 'Regenerate OTP'),
              ),
            ),
            if (errorText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                errorText,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
