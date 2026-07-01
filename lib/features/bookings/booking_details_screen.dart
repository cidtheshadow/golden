import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../../firebase/firestore_service.dart';
import '../auth/auth_controller.dart';
import '../caregivers/components/caregiver_card_detailed.dart';
import 'widgets/otp_section.dart';
import '../../models/service_personnel_model.dart';
import '../../utils/error_handler.dart';
import '../payment/payment_provider.dart';

class BookingDetailsScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final bool cancelOnBack;

  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
    this.cancelOnBack = false,
  });

  @override
  ConsumerState<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  bool _showLoadingOverlay = false;
  bool _isPaymentInitiating = false;
  String _loadingOverlayMessage = 'Please wait...';

  void _showBlockingLoader(String message) {
    if (!mounted) return;
    setState(() {
      _loadingOverlayMessage = message;
      _showLoadingOverlay = true;
    });
  }

  void _hideBlockingLoader() {
    if (!mounted) return;
    setState(() => _showLoadingOverlay = false);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(authSessionValidProvider);
    if (sessionAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (sessionAsync.valueOrNull != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/auth/login?mode=signin&role=family');
        }
      });

      return const Scaffold(
        body: Center(child: Text('Session expired. Redirecting to login...')),
      );
    }

    final bookingAsync = ref.watch(bookingStreamProvider(widget.bookingId));
    final paymentAsync = ref.watch(paymentProvider);
    final isPaymentLoading = paymentAsync.isLoading;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        final current = ref.read(paymentProvider).valueOrNull;

        // If a payment is actively loading (actual async work), show a loading overlay then pop immediately.
        if (paymentAsync.isLoading) {
          _showBlockingLoader('Processing payment...');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pop();
          });
          return;
        }

        // After a successful payment, disable back navigation.
        if (current == PaymentState.success) return;

        // If this details screen was opened as part of the booking flow, cancel
        // the pending booking on back and return to the booking start.
        final bookingId = widget.bookingId;
        if (widget.cancelOnBack && bookingId.isNotEmpty) {
          _showBlockingLoader('Cancelling booking...');
          () async {
            try {
              await ref
                  .read(bookingRepositoryProvider)
                  .cancelBooking(bookingId);
            } catch (e) {
              debugPrint('[BOOKING] cancel on back failed: $e');
            }
            if (!mounted) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              try {
                context.go('/book');
              } catch (e) {
                Navigator.of(context).pop();
              }
            });
          }();
          return;
        }

        // Otherwise perform a normal pop/back navigation.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (context.canPop()) {
            try {
              context.pop();
            } catch (e) {
              Navigator.of(context).maybePop();
            }
          } else {
            try {
              context.go('/bookings');
            } catch (e) {
              Navigator.of(context).maybePop();
            }
          }
        });
        return;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Booking Details'),
              backgroundColor: Colors.white,
              foregroundColor: GCColors.foreground,
              elevation: 0,
              automaticallyImplyLeading:
                  paymentAsync.valueOrNull != PaymentState.success,
            ),
            body: SafeArea(
              child: bookingAsync.when(
                data: (booking) {
                  if (booking == null) {
                    return const Center(child: Text('Booking not found'));
                  }

                  if (_isPendingPayment(booking)) {
                    ref
                        .read(paymentProvider.notifier)
                        .recoverPendingContext(bookingId: booking.id);
                  }

                  final isCustomer =
                      booking.userId == ref.read(authStateProvider).value?.uid;
                  final isCaregiver = booking.servicePersonnelId ==
                      ref.read(authStateProvider).value?.uid;
                  final isActive = booking.status == 'upcoming' ||
                      booking.status == 'confirmed' ||
                      booking.status == 'in_progress' ||
                      booking.status == 'completion_requested';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(GCSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusSection(booking),
                        if (_isPendingPayment(booking)) ...[
                          const SizedBox(height: 16),
                          _buildRetryPaymentCard(
                            context,
                            ref,
                            booking,
                            isPaymentLoading: isPaymentLoading,
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildDetailsCard(booking),
                        if (isCustomer && isActive) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context
                                  .push('/change-caregiver/${booking.id}'),
                              icon: booking.servicePersonnelId == null
                                  ? const Icon(Icons.person_add_rounded)
                                  : const Icon(Icons.swap_horiz_rounded),
                              label: Text(booking.servicePersonnelId == null
                                  ? 'Assign Caregiver'
                                  : 'Change Caregiver'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (isCustomer && isActive)
                          FamilyOtpSection(booking: booking),
                        if (isCaregiver && isActive)
                          CaregiverOtpSection(booking: booking),
                        if (isCustomer && _canCancel(booking)) ...[
                          const SizedBox(height: 24),
                          _buildCancelSection(context, ref, booking),
                        ],
                        if (isCustomer && booking.status == 'completed') ...[
                          const SizedBox(height: 24),
                          _buildReviewSection(context, ref, booking),
                        ],
                        if (booking.servicePersonnelId != null) ...[
                          const SizedBox(height: 16),
                          _buildCaregiverSection(
                              ref, booking.servicePersonnelId!),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ),
          if (_showLoadingOverlay)
            Positioned.fill(
              child: Container(
                color: Color.fromRGBO(255, 255, 255, 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFB8860B),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _loadingOverlayMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BookingModel booking) {
    final colors = {
      'upcoming': GCColors.primary,
      'confirmed': GCColors.accent,
      'pending_payment': const Color(0xFFB8860B),
      'in_progress': GCColors.goldDark,
      'completed': GCColors.goldDark,
      'cancelled': GCColors.destructive,
      'caregiver_noshow': GCColors.destructive,
      'refund_initiated': const Color(0xFF1565C0),
      'refunded': const Color(0xFF2E7D32),
      'expired': GCColors.destructive,
    };
    final color = colors[booking.status] ?? GCColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${_getStatusLabel(booking.status)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  _getStatusDescription(booking),
                  style: GCTypography.bodySmall
                      .copyWith(color: color.withAlpha(204)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isPendingPayment(BookingModel booking) {
    return booking.status == 'pending_payment' ||
        booking.paymentStatus == 'pending_payment';
  }

  bool _canCancel(BookingModel booking) {
    return booking.status == 'confirmed' || booking.status == 'pending_payment';
  }

  String _getStatusDescription(BookingModel booking) {
    switch (booking.status.toLowerCase()) {
      case 'pending_payment':
        return 'Awaiting payment to confirm booking.';
      case 'upcoming':
        return 'Service is scheduled.';
      case 'confirmed':
        return 'Caregiver assigned and booking confirmed.';
      case 'in_progress':
      case 'inprogress':
        return 'Service is currently in progress.';
      case 'completed':
        return 'Service completed successfully.';
      case 'cancelled':
        final refund = booking.refundAmountDisplay;
        if (refund != null && refund > 0) {
          return 'Cancelled. INR ${refund.toStringAsFixed(2)} refund initiated.';
        }
        return 'This booking has been cancelled.';
      case 'caregiver_noshow':
        return 'Caregiver did not arrive. Full refund issued.';
      case 'refund_initiated':
        return 'Refund processing (5-7 business days).';
      case 'refunded':
        return 'Refund completed successfully.';
      case 'expired':
        return 'Booking expired due to incomplete payment.';
      default:
        return 'Booking is being processed.';
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return 'Payment Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'upcoming':
        return 'Upcoming';
      case 'in_progress':
      case 'inprogress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'caregiver_noshow':
        return 'Caregiver No-Show';
      case 'refund_initiated':
        return 'Refund Initiated';
      case 'refunded':
        return 'Refunded';
      case 'expired':
        return 'Expired';
      default:
        return status.toUpperCase();
    }
  }

  String _formatPaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'captured':
        return 'Paid';
      case 'pending_payment':
        return 'Pending';
      case 'refunded':
        return 'Refunded';
      case 'refund_initiated':
        return 'Refund Initiated';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  Widget _buildDetailsCard(BookingModel booking) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GCSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service Information', style: GCTypography.headlineSmall),
            const Divider(height: 32),
            _infoRow(Icons.medical_services_outlined, 'Service',
                booking.serviceName),
            if (booking.servicePersonnelId == null)
              _infoRow(Icons.person_outline, 'Caregiver', 'Assigning...'),
            _infoRow(Icons.calendar_today_outlined, 'Date',
                DateFormat('MMM dd, yyyy').format(booking.date)),
            _infoRow(Icons.access_time, 'Time', booking.time ?? 'N/A'),
            _infoRow(
                Icons.timer_outlined, 'Duration', booking.duration ?? 'N/A'),
            _infoRow(Icons.location_on_outlined, 'Address',
                booking.userLocationAddress ?? 'N/A'),
            if (booking.paymentStatus.isNotEmpty)
              _infoRow(
                Icons.payment_rounded,
                'Payment',
                _formatPaymentStatus(booking.paymentStatus),
              ),
            if (booking.transactionId != null &&
                booking.transactionId!.isNotEmpty)
              _infoRow(
                Icons.receipt_long_rounded,
                'Transaction ID',
                booking.transactionId!.length > 16
                    ? '${booking.transactionId!.substring(0, 16)}...'
                    : booking.transactionId!,
              ),
            // _infoRow(Icons.payments_outlined, 'Price', '₹${booking.price.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  void _showNoCaregiverDialog(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('No Caregiver Available'),
        content: const Text(
            'We apologize, but no caregiver is available at this time. We will cancel this booking and initiate a full refund process.'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // close dialog

              if (mounted) {
                _showBlockingLoader('Cancelling booking...');
              }

              try {
                await ref
                    .read(bookingRepositoryProvider)
                    .cancelBooking(booking.id);
                if (mounted) {
                  _hideBlockingLoader();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Booking cancelled.'),
                        backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _hideBlockingLoader();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: ${ErrorHandler.handle(e)}'),
                        backgroundColor: GCColors.destructive),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GCColors.destructive,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryPaymentCard(
      BuildContext context, WidgetRef ref, BookingModel booking,
      {required bool isPaymentLoading}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB8860B),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.payment_rounded,
            color: Color(0xFFB8860B),
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'Payment Pending',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete your payment to confirm this booking.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPaymentLoading
                  ? null
                  : () {
                      setState(() => _isPaymentInitiating = true);
                      _retryPayment(context, ref, booking);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8860B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isPaymentLoading || _isPaymentInitiating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Complete Payment',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryPayment(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) async {
    void stopInitiating() {
      if (mounted) {
        setState(() => _isPaymentInitiating = false);
      }
    }

    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) {
      stopInitiating();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in and try again.')),
      );
      return;
    }

    final user = ref.read(userModelProvider).value;
    final amount = booking.price;

    if (amount <= 0) {
      stopInitiating();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid booking amount for payment.')),
      );
      return;
    }

    final slotAvailable = await _isSlotStillAvailable(booking);
    if (!slotAvailable) {
      if (!mounted) return;
      await _showSlotUnavailableDialogAndCancel(context, ref, booking);
      stopInitiating();
      return;
    }

    try {
      await ref
          .read(paymentProvider.notifier)
          .recoverPendingContext(bookingId: booking.id);

      await ref.read(paymentProvider.notifier).initiatePayment(
            bookingId: booking.id,
            userEmail: authUser.email ?? '',
            userName: user?.name ?? booking.userName ?? 'User',
            userPhone: user?.phone ?? '',
            description:
                '${booking.serviceName} - ${booking.duration ?? 'Service'}',
            onSuccess: (paymentId, orderId, signature) {
              unawaited(
                _handleRetryPaymentSuccess(
                  booking: booking,
                  paymentId: paymentId,
                  orderId: orderId,
                  signature: signature,
                ),
              );
            },
            onFailure: (error) {
              if (!context.mounted) return;
              if (error.toLowerCase().contains('session expired')) {
                context.go('/auth/login?mode=signin&role=family');
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Payment failed: $error')),
              );
            },
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Unable to start payment: ${ErrorHandler.handle(e)}')),
      );
    } finally {
      stopInitiating();
    }
  }

  Future<void> _handleRetryPaymentSuccess({
    required BookingModel booking,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      await ref.read(paymentProvider.notifier).completePayment(
            bookingId: booking.id,
            paymentId: paymentId,
            orderId: orderId,
            signature: signature,
          );

      final paymentState = ref.read(paymentProvider).valueOrNull;
      if (paymentState == PaymentState.success && mounted) {
        try {
          _showBlockingLoader('Finalizing booking details...');
          await ref.read(bookingRepositoryProvider).assignRandomPersonnel(
                booking.id,
              );
          if (mounted) {
            _hideBlockingLoader();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment completed and caregiver randomly assigned!',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            _hideBlockingLoader();
            _showNoCaregiverDialog(context, ref, booking);
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[PAYMENT ERROR] _handleRetryPaymentSuccess error=$error');
      debugPrint(
          '[PAYMENT ERROR] _handleRetryPaymentSuccess stack=$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment succeeded but verification failed: ${ErrorHandler.handle(error)}',
          ),
        ),
      );
    }
  }

  Duration _bookingDuration(BookingModel booking) {
    final raw = (booking.duration ?? '').trim();
    if (raw.isEmpty) return const Duration(hours: 1);

    final parts = raw.split(RegExp(r'\s+'));
    final hours = int.tryParse(parts.first) ?? 1;
    return Duration(hours: hours.clamp(1, 24));
  }

  ({DateTime start, DateTime end})? _resolveBookingSlotWindow(
    BookingModel booking,
  ) {
    if (booking.startTime != null) {
      final start = booking.startTime!;
      final end = booking.endTime ?? start.add(_bookingDuration(booking));
      return (start: start, end: end);
    }

    final rawTime = booking.time;
    if (rawTime == null || rawTime.trim().isEmpty) return null;

    try {
      final parsed = DateFormat('hh:mm a').parse(rawTime.trim());
      final start = DateTime(
        booking.date.year,
        booking.date.month,
        booking.date.day,
        parsed.hour,
        parsed.minute,
      );
      final end = start.add(_bookingDuration(booking));
      return (start: start, end: end);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isSlotStillAvailable(BookingModel booking) async {
    final slot = _resolveBookingSlotWindow(booking);
    if (slot == null) {
      // If slot timing is missing, do not block payment retry.
      return true;
    }

    final caregivers =
        await ref.read(bookingRepositoryProvider).getServicePersonnel(
              startTime: slot.start,
              endTime: slot.end,
            );

    final assignedCaregiverId = booking.servicePersonnelId;
    if (assignedCaregiverId != null && assignedCaregiverId.isNotEmpty) {
      return caregivers.any((person) => person.id == assignedCaregiverId);
    }

    return caregivers.isNotEmpty;
  }

  Future<void> _showSlotUnavailableDialogAndCancel(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slot Unavailable'),
        content: const Text(
          'This slot is no longer available. Your pending booking will now be cancelled.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    _showBlockingLoader('Cancelling booking...');
    try {
      await ref.read(bookingRepositoryProvider).cancelBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking cancelled because slot is unavailable.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to cancel booking: ${ErrorHandler.handle(e)}')),
        );
      }
    } finally {
      _hideBlockingLoader();
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: GCColors.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GCTypography.bodySmall),
                Text(value, style: GCTypography.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOtpSection(BuildContext context, BookingModel booking) {
    bool isExpired = false;
    double minutesLeft = 5.0;

    if (booking.otpGeneratedAt != null) {
      final diff = DateTime.now().difference(booking.otpGeneratedAt!);
      isExpired = diff.inMinutes >= 5;
      minutesLeft = 5.0 - (diff.inSeconds / 60.0);
    } else {
      // If it doesn't have an exp time, force regeneration
      isExpired = true;
    }

    if (isExpired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: GCColors.destructive.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GCColors.destructive),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: GCColors.destructive, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Your OTP has expired.',
              style: TextStyle(
                  color: GCColors.destructive, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirestoreService().regenerateOtp(booking.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New OTP generated.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Error generating OTP: ${ErrorHandler.handle(e)}'),
                          backgroundColor: GCColors.destructive),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GCColors.destructive,
                foregroundColor: Colors.white,
              ),
              child: const Text('Regenerate OTP'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GCColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: GCColors.primary.withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completion OTP',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                'Expires in ${minutesLeft.ceil()} min',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            booking.completionOtp!,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share this with your caregiver\nonly after the service is completed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCompletionSection(BuildContext context, String bookingId) {
    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _showOtpDialog(context, bookingId),
            style: ElevatedButton.styleFrom(
              backgroundColor: GCColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Trip (Enter OTP)'),
          ),
        ),
      ],
    );
  }

  void _showOtpDialog(BuildContext context, String bookingId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Completion OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Ask the customer for the 4-digit OTP shown on their screen.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '0000',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final otp = controller.text;
              if (otp.length == 4) {
                try {
                  final success =
                      await FirestoreService().verifyBookingOtp(bookingId, otp);
                  if (success) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Trip completed successfully! 🎉')),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Invalid OTP. Please try again.'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    if (e.toString().contains('expired')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'The OTP has expired. Please ask the customer to generate a new one.'),
                            backgroundColor: Colors.orange),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error: ${ErrorHandler.handle(e)}'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              }
            },
            child: const Text('Verify & Complete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelSection(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _showCancelDialog(context, ref, booking),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          'Cancel Booking',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showCancelDialog(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    final isPaid = booking.paymentStatus == 'paid';
    final price = booking.price;
    final cancellationFee = price * 0.25;
    final refundAmount = price * 0.75;

    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPaid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB8860B).withAlpha(77),
                  ),
                ),
                child: Column(
                  children: [
                    _RefundRow(
                      label: 'Amount Paid',
                      value: 'INR ${price.toStringAsFixed(2)}',
                    ),
                    _RefundRow(
                      label: 'Cancellation Fee (25%)',
                      value: '-INR ${cancellationFee.toStringAsFixed(2)}',
                      valueColor: Colors.red,
                    ),
                    const Divider(height: 16),
                    _RefundRow(
                      label: 'Refund Amount',
                      value: 'INR ${refundAmount.toStringAsFixed(2)}',
                      valueColor: const Color(0xFF2E7D32),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Refund will be processed within 5-7 business days to your original payment method.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ] else ...[
              const Text(
                  'This booking will be cancelled. No charge has been made.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(_, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        await _processCancellation(context, booking);
      }
    });
  }

  Future<void> _processCancellation(
    BuildContext context,
    BookingModel booking,
  ) async {
    _showBlockingLoader('Cancelling booking...');

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('cancelBooking');
      final result = await callable.call({'bookingId': booking.id});
      final data = Map<String, dynamic>.from(result.data as Map);

      _hideBlockingLoader();

      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 48,
            ),
            title: const Text('Booking Cancelled'),
            content: Text(
              data['message'] as String? ?? 'Your booking has been cancelled.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(_);
                  Navigator.of(context).maybePop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB8860B),
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _hideBlockingLoader();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancellation failed: ${ErrorHandler.handle(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReviewSection(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    if (booking.servicePersonnelId == null) return const SizedBox();

    final personnelAsync =
        ref.watch(personnelStreamProvider(booking.servicePersonnelId!));

    return personnelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (personnel) {
        if (personnel == null) return const SizedBox.shrink();

        final myReview = _findMyReviewForBooking(
          personnel.reviews,
          bookingId: booking.id,
          userId: booking.userId,
        );

        if (myReview == null) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showReviewDialog(context, ref, booking),
              icon: const Icon(Icons.star),
              label: const Text('Rate Service'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: GCColors.goldDark,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        final reviewRating = (myReview['rating'] as num?)?.toDouble() ?? 5.0;
        final reviewComment = (myReview['comment'] as String?)?.trim() ?? '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GCColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Review', style: GCTypography.headlineSmall),
                  _buildRatingStars(reviewRating),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                reviewComment.isEmpty ? 'No comment added.' : reviewComment,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GCTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReviewDialog(
                    context,
                    ref,
                    booking,
                    initialRating: reviewRating,
                    initialComment: reviewComment,
                    isEditing: true,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit & Save Review'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReviewDialog(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking, {
    double initialRating = 5.0,
    String initialComment = '',
    bool isEditing = false,
  }) {
    final commentController = TextEditingController(text: initialComment);
    double rating = initialRating;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Review' : 'Rate Service'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was your experience?'),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: isSubmitting
                            ? null
                            : () => setState(() => rating = index + 1.0),
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: GCColors.goldDark,
                          size: 30,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      hintText: 'Leave a comment (optional, max 25 words)',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 4,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (booking.servicePersonnelId == null) {
                        Navigator.pop(context);
                        return;
                      }

                      setState(() => isSubmitting = true);

                      try {
                        await ref
                            .read(bookingRepositoryProvider)
                            .submitBookingReview(
                              bookingId: booking.id,
                              rating: rating,
                              comment:
                                  _trimToWordLimit(commentController.text, 25),
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'Your review has been updated.'
                                    : 'Thank you for your feedback!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Failed to submit review: ${ErrorHandler.handle(e)}'),
                                backgroundColor: GCColors.destructive),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Save' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _findMyReviewForBooking(
    List<Map<String, dynamic>> reviews, {
    required String bookingId,
    required String userId,
  }) {
    for (final review in reviews) {
      final reviewBookingId = review['bookingId']?.toString();
      final reviewUserId = review['userId']?.toString();
      if (reviewBookingId == bookingId && reviewUserId == userId) {
        return review;
      }
    }
    return null;
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final icon = index < rating.floor()
            ? Icons.star
            : (index < rating ? Icons.star_half : Icons.star_border);
        return Icon(icon, size: 18, color: GCColors.goldDark);
      }),
    );
  }

  String _trimToWordLimit(String input, int maxWords) {
    final words =
        input.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= maxWords) return input.trim();
    return words.take(maxWords).join(' ');
  }

  Widget _buildCaregiverSection(WidgetRef ref, String personnelId) {
    final personnelAsync = ref.watch(personnelStreamProvider(personnelId));
    final completedVisitsAsync =
        ref.watch(caregiverCompletedVisitsProvider(personnelId));
    String? expandedId;

    return personnelAsync.when(
      data: (personnel) {
        if (personnel == null) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Caregiver Details', style: GCTypography.headlineSmall),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setState) {
                return CaregiverCard(
                  personnel: personnel,
                  completedVisitsOverride: completedVisitsAsync.valueOrNull,
                  isSelected: false,
                  isExpanded: expandedId == personnel.id,
                  onTap: () {
                    setState(() {
                      expandedId =
                          expandedId == personnel.id ? null : personnel.id;
                    });
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
  }
}

final bookingStreamProvider =
    StreamProvider.family<BookingModel?, String>((ref, id) {
  return ref.watch(bookingRepositoryProvider).getBookingStream(id);
});

class _RefundRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _RefundRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

final personnelStreamProvider =
    StreamProvider.family<ServicePersonnelModel?, String>((ref, id) {
  return ref.watch(firestoreServiceProvider).getPersonnelStream(id);
});

final caregiverCompletedVisitsProvider =
    StreamProvider.family<int, String>((ref, personnelId) {
  return FirebaseFirestore.instance
      .collection('bookings')
      .where('servicePersonnelId', isEqualTo: personnelId)
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
