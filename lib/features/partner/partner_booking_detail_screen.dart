import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../core/spacing.dart';
import '../../models/booking_model.dart';
import '../bookings/widgets/otp_section.dart';
import '../../repositories/booking_repository.dart';
import '../../firebase/notification_service.dart';
import '../../utils/error_handler.dart';

class PartnerBookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const PartnerBookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PartnerBookingDetailScreen> createState() =>
      _PartnerBookingDetailScreenState();
}

class _PartnerBookingDetailScreenState
    extends ConsumerState<PartnerBookingDetailScreen> {
  bool _isVerifying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookingDoc = snapshot.data!;
          if (!bookingDoc.exists) {
            return const Center(child: Text('Booking not found'));
          }

          final booking = BookingModel.fromFirestore(bookingDoc);
          final canStartBooking =
              booking.status == 'upcoming' || booking.status == 'confirmed';
          final canRequestCompletion = booking.status == 'in_progress' ||
              booking.status == 'completion_requested';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(GCSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Service Info ────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(GCSpacing.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(booking.serviceName,
                                style: GCTypography.headlineMedium),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 16, color: GCColors.mutedForeground),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${DateFormat('MMMM d, yyyy').format(booking.date)} at ${booking.time ?? 'N/A'}',
                                    style: GCTypography.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.timer,
                                    size: 16, color: GCColors.mutedForeground),
                                const SizedBox(width: 8),
                                Text(booking.duration ?? 'Duration N/A',
                                    style: GCTypography.bodyLarge),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _statusChip(booking.status),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (booking.status == 'completed')
                      Center(
                        child: Text(
                          'Job Completed Successfully',
                          style: GCTypography.headlineSmall.copyWith(
                            color: GCColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Customer Details ────────────────
                    Text('Customer Details', style: GCTypography.headlineSmall),
                    const SizedBox(height: 8),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(booking.userId)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(Icons.person)),
                              title: Text('Loading customer details...'),
                            ),
                          );
                        }

                        final userData = userSnapshot.data?.data();
                        final name = (userData?['name'] as String?)?.trim();
                        final phone = (userData?['phone'] as String?)?.trim();
                        final email = (userData?['email'] as String?)?.trim();
                        final photoUrl =
                            (userData?['profileImage'] as String?)?.trim();
                        final displayName = (name != null && name.isNotEmpty)
                            ? name
                            : (booking.userName ?? 'Customer');
                        final emergencyContacts =
                            (userData?['emergencyContacts'] as List? ?? [])
                                .whereType<Map>()
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor:
                                              const Color(0xFFB8860B)
                                                  .withAlpha(38),
                                          child: ClipOval(
                                            child: (photoUrl != null &&
                                                    photoUrl.isNotEmpty)
                                                ? CachedNetworkImage(
                                                    imageUrl: photoUrl,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) =>
                                                        Text(
                                                      displayName.isNotEmpty
                                                          ? displayName[0]
                                                              .toUpperCase()
                                                          : '?',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            Color(0xFFB8860B),
                                                      ),
                                                    ),
                                                    errorWidget: (_, __, ___) =>
                                                        Text(
                                                      displayName.isNotEmpty
                                                          ? displayName[0]
                                                              .toUpperCase()
                                                          : '?',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            Color(0xFFB8860B),
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    displayName.isNotEmpty
                                                        ? displayName[0]
                                                            .toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFFB8860B),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                              ),
                                              if (email != null &&
                                                  email.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 2),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.email_rounded,
                                                          size: 13,
                                                          color: Colors
                                                              .grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          email,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .grey.shade600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (phone != null && phone.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.phone_rounded,
                                                size: 16,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                phone,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                Clipboard.setData(
                                                    ClipboardData(text: phone));
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Phone number copied'),
                                                    duration:
                                                        Duration(seconds: 1),
                                                    backgroundColor:
                                                        Color(0xFFB8860B),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 18),
                                              tooltip: 'Copy number',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 8),
                                            if (!kIsWeb)
                                              IconButton(
                                                onPressed: () async {
                                                  final uri = Uri(
                                                      scheme: 'tel',
                                                      path: phone);
                                                  if (await canLaunchUrl(uri)) {
                                                    await launchUrl(uri);
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.call_rounded,
                                                  size: 18,
                                                  color: Color(0xFF2E7D32),
                                                ),
                                                tooltip: 'Call customer',
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (userSnapshot.hasError)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Could not fully load profile details.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (_hasCareDetails(booking)) ...[
                              const SizedBox(height: 20),
                              const Text(
                                'Care Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (booking.elderName != null &&
                                        booking.elderName!.isNotEmpty)
                                      _CareDetailRow(
                                        icon: Icons.elderly_rounded,
                                        label: 'Elder\'s Name',
                                        value: booking.elderName!,
                                        color: const Color(0xFFB8860B),
                                      ),
                                    if (booking.elderAge != null &&
                                        booking.elderAge! > 0)
                                      _CareDetailRow(
                                        icon: Icons.cake_rounded,
                                        label: 'Age',
                                        value: '${booking.elderAge} years',
                                        color: const Color(0xFFB8860B),
                                      ),
                                    if (booking.medicalConditions != null &&
                                        booking.medicalConditions!.isNotEmpty)
                                      _CareDetailRow(
                                        icon: Icons.medical_information_rounded,
                                        label: 'Medical Conditions',
                                        value: booking.medicalConditions!,
                                        color: Colors.red.shade600,
                                      ),
                                    if (booking.specialNeeds != null &&
                                        booking.specialNeeds!.isNotEmpty)
                                      _CareDetailRow(
                                        icon: Icons.note_alt_rounded,
                                        label: 'Special Requirements',
                                        value: booking.specialNeeds!,
                                        color: const Color(0xFF1565C0),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const Text(
                              'Payment Info',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  _CareDetailRow(
                                    icon: Icons.payment_rounded,
                                    label: 'Payment Status',
                                    value: _formatPaymentStatus(
                                        booking.paymentStatus),
                                    color: booking.paymentStatus == 'paid'
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFB8860B),
                                  ),
                                  if (booking.paymentId != null &&
                                      booking.paymentId!.isNotEmpty)
                                    _CareDetailRow(
                                      icon: Icons.receipt_rounded,
                                      label: 'Payment ID',
                                      value: booking.paymentId!,
                                      color: Colors.grey,
                                    ),
                                ],
                              ),
                            ),
                            if (emergencyContacts.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Text(
                                'Emergency Contacts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...emergencyContacts.map((contact) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.red.shade100),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.emergency_rounded,
                                              color: Colors.red.shade400,
                                              size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                contact['name'] as String? ??
                                                    'Contact',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (contact['phone'] != null ||
                                                  contact['number'] !=
                                                      null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  contact['phone'] as String? ??
                                                      contact['number']
                                                          as String? ??
                                                      '',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                              if (contact['relation'] != null ||
                                                  contact['relationship'] !=
                                                      null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  contact['relation']
                                                          as String? ??
                                                      contact['relationship']
                                                          as String? ??
                                                      '',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            final contactPhone =
                                                contact['phone'] as String? ??
                                                    contact['number']
                                                        as String? ??
                                                    '';
                                            if (contactPhone.isEmpty) return;
                                            Clipboard.setData(ClipboardData(
                                                text: contactPhone));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Contact number copied'),
                                                duration: Duration(seconds: 1),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          },
                                          icon: Icon(Icons.copy_rounded,
                                              size: 16,
                                              color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Service Location ────────────────
                    Text('Service Location', style: GCTypography.headlineSmall),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(GCSpacing.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: GCColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    booking.userLocationAddress ??
                                        'Address not provided',
                                    style: GCTypography.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                            if (booking.latitude != null &&
                                booking.longitude != null &&
                                booking.latitude != 0) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openMap(
                                      booking.latitude!, booking.longitude!),
                                  icon: const Icon(Icons.map),
                                  label: const Text('NAVIGATE TO CUSTOMER'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: GCColors.primary,
                                    side: const BorderSide(
                                        color: GCColors.primary),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Action Buttons ──────────────────
                    if (canStartBooking || canRequestCompletion) ...[
                      CaregiverOtpSection(booking: booking),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
      case 'confirmed':
        return GCColors.primary;
      case 'completed':
        return GCColors.accent;
      case 'cancelled':
        return GCColors.destructive;
      case 'in_progress':
      case 'completion_requested':
        return GCColors.goldDark;
      default:
        return GCColors.mutedForeground;
    }
  }

  bool _hasCareDetails(BookingModel booking) {
    return (booking.elderName?.isNotEmpty ?? false) ||
        (booking.elderAge != null && booking.elderAge! > 0) ||
        (booking.medicalConditions?.isNotEmpty ?? false) ||
        (booking.specialNeeds?.isNotEmpty ?? false);
  }

  String _formatPaymentStatus(String status) {
    switch (status) {
      case 'paid':
        return '✓ Paid';
      case 'pending_payment':
        return 'Pending';
      case 'refunded':
        return 'Refunded';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  // ignore: unused_element
  void _showOtpDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Completion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Ask the customer for the 4-digit OTP shown in their app.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '0000',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _verifyOtp(otpController.text),
            child: const Text('Verify & Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtp(String otp) async {
    if (_isVerifying) return;

    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a 4-digit OTP')));
      return;
    }

    setState(() => _isVerifying = true);
    Navigator.pop(context); // Close Dialog

    try {
      final bookingRepo = ref.read(bookingRepositoryProvider);
      final success = await bookingRepo.verifyBookingOtp(widget.bookingId, otp);

      if (success) {
        // Send completion notification to user
        try {
          // Re-fetch booking to get userId
          final bookingStream = bookingRepo.getBookingStream(widget.bookingId);
          final booking = await bookingStream.first;
          if (booking != null) {
            await NotificationService().sendNotification(
              userId: booking.userId,
              title: 'Service Completed',
              body:
                  'Your ${booking.serviceName} service has been completed successfully!',
              type: 'booking',
              targetId: widget.bookingId,
              collection: 'users',
            );
          }
        } catch (e) {
          debugPrint('Error sending completion notification: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Job verification successful!')));
          context.pop();
        }
      } else {
        if (mounted) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid OTP. Please try again.')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${ErrorHandler.handle(e)}')));
      }
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final String googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final String appleMapsUrl = "https://maps.apple.com/?q=$lat,$lng";

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(Uri.parse(appleMapsUrl),
          mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open map.')));
      }
    }
  }

  // ignore: unused_element
  Future<void> _requestCompletion(BookingModel booking) async {
    setState(() => _isVerifying = true);

    try {
      final bookingRepo = ref.read(bookingRepositoryProvider);
      await bookingRepo.requestBookingCompletion(widget.bookingId);

      // Send OTP request notification to user
      try {
        await NotificationService().sendNotification(
          userId: booking.userId,
          title: 'Service Completion Requested',
          body:
              'Your service provider has requested completion. Please check your OTP.',
          type: 'booking',
          targetId: widget.bookingId,
          collection: 'users',
        );
      } catch (e) {
        debugPrint('Error sending OTP request notification: $e');
      }

      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Completion requested! Ask user for OTP.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${ErrorHandler.handle(e)}')));
      }
    }
  }

  // ignore: unused_element
  Future<void> _startBooking(BookingModel booking) async {
    setState(() => _isVerifying = true);

    try {
      final bookingRepo = ref.read(bookingRepositoryProvider);
      await bookingRepo.startBooking(widget.bookingId);

      try {
        await NotificationService().sendNotification(
          userId: booking.userId,
          title: 'Service Started',
          body: 'Your ${booking.serviceName} booking has started.',
          type: 'booking',
          targetId: widget.bookingId,
          collection: 'users',
        );
      } catch (e) {
        debugPrint('Error sending booking started notification: $e');
      }

      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking marked as in progress.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ErrorHandler.handle(e)}')),
        );
      }
    }
  }
}

class _CareDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CareDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
