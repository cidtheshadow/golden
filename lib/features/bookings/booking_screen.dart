/// Booking screen — replicates web screen at route /book
/// Multi-step booking flow: Service → Schedule → Details → Payment
/// Auth-gated: user must be logged in
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../core/widgets/gc_button.dart';
import '../../models/service_model.dart';
import '../../models/booking_model.dart';
import '../../models/service_personnel_model.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/booking_repository.dart';
import '../../firebase/firestore_service.dart';
import '../../firebase/config_service.dart';
import '../auth/auth_controller.dart';
import '../payment/payment_provider.dart';
import 'location_picker_screen.dart';
import '../caregivers/components/caregiver_card_detailed.dart';
import '../../utils/error_handler.dart';
import 'providers/slot_availability_provider.dart';
import 'widgets/slot_picker_widget.dart';

/// Provider that fetches all services from Firebase
final servicesProvider = StreamProvider<List<ServiceModel>>((ref) {
  return ref.watch(serviceRepositoryProvider).getServicesStream();
});

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _sessionRedirectScheduled = false;
  bool _isCancellingPendingBooking = false;
  bool _showBlockingOverlay = false;
  String _blockingOverlayMessage = 'Please wait...';

  void _showBlockingLoader(String message) {
    if (!mounted) return;
    setState(() {
      _blockingOverlayMessage = message;
      _showBlockingOverlay = true;
    });
  }

  void _hideBlockingLoader() {
    if (!mounted) return;
    setState(() => _showBlockingOverlay = false);
  }

  /// Returns the booking duration based on the selected service option.
  Duration get _bookingDuration {
    if (_selectedOption == null) return const Duration(hours: 1);
    final parts = _selectedOption!.duration.split(' ');
    return Duration(hours: int.tryParse(parts[0]) ?? 1);
  }

  int _currentStep = 0;
  int _serviceSubStep = 0; // 0: List, 1: About, 2: Summary/Duration
  ServiceModel? _selectedService;
  ServiceOption? _selectedOption;
  DateTime? _selectedDate;
  DateTime? _selectedSlot;
  List<ServicePersonnelModel>? _availablePersonnel;
  ServicePersonnelModel? _selectedPersonnel;
  bool _isLoadingPersonnel = false;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _agreedToTerms = false;
  bool _mapAutoOpened = false;
  String? _expandedCaregiverId;
  bool _emergencyContactChecked = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _elderNameController = TextEditingController();
  final _elderAgeController = TextEditingController();
  final _medicalConditionsController = TextEditingController();

  Future<void> _openMap() async {
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _addressController.text = result.address;
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  final _steps = [
    'Service',
    'Schedule',
    'Details',
    'Agreement',
    'Payment',
    'Caregiver'
  ];
  String? _bookingId;
  bool _detailsInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _elderNameController.dispose();
    _elderAgeController.dispose();
    _medicalConditionsController.dispose();
    super.dispose();
  }

  void _prefillDetails() {
    if (_detailsInitialized) return;
    final userAsync = ref.read(userModelProvider);
    userAsync.whenData((user) {
      if (user != null) {
        _nameController.text = user.name;
        _phoneController.text = user.phone;
        _addressController.text = user.address;
        _latitude = (user.latitude != null && user.latitude != 0)
            ? user.latitude
            : null;
        _longitude = (user.longitude != null && user.longitude != 0)
            ? user.longitude
            : null;
        // Prefill elder age from profile DOB when available. This defaults the
        // elder age field to the profile age so the user can adjust if needed.
        if (user.dob != null) {
          final now = DateTime.now();
          int age = now.year - user.dob!.year;
          if (now.month < user.dob!.month ||
              (now.month == user.dob!.month && now.day < user.dob!.day)) {
            age -= 1;
          }
          // Only set if the field is empty to avoid overwriting user edits.
          if (_elderAgeController.text.trim().isEmpty && age > 0) {
            _elderAgeController.text = age.toString();
          }
        }
        _detailsInitialized = true;
      }
    });
  }

  Future<bool> _checkEmergencyContact(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final contacts = doc.data()?['emergencyContacts'] as List? ?? [];

    final hasValid = contacts.any((contact) {
      final data = Map<String, dynamic>.from(contact as Map);
      return (data['name'] as String? ?? '').trim().isNotEmpty &&
          ((data['phone'] as String? ?? data['number'] as String? ?? ''))
              .trim()
              .isNotEmpty;
    });

    if (!hasValid && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Icon(
            Icons.emergency_rounded,
            color: Colors.red.shade400,
            size: 40,
          ),
          title: const Text(
            'Emergency Contact Required',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Please add at least one emergency contact before booking. This ensures your caregiver can reach your family in case of emergency.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/emergency-contacts');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8860B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Contact'),
            ),
          ],
        ),
      );
      return false;
    }

    _emergencyContactChecked = true;
    return true;
  }

  Future<String> _ensurePendingBooking() async {
    if (_bookingId != null && _bookingId!.isNotEmpty) {
      await ref
          .read(paymentProvider.notifier)
          .recoverPendingContext(bookingId: _bookingId!);
      return _bookingId!;
    }

    await _ensureFreshSession();

    final authUser = ref.read(authStateProvider).value;
    if (authUser == null ||
        _selectedService == null ||
        _selectedOption == null ||
        _selectedDate == null ||
        _selectedSlot == null) {
      throw Exception('Booking details are incomplete.');
    }

    final startTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedSlot!.hour,
      _selectedSlot!.minute,
    );

    final durationParts = _selectedOption!.duration.split(' ');
    final durationVal = int.tryParse(durationParts[0]) ?? 1;
    final duration = Duration(hours: durationVal);

    final docRef =
        ref.read(bookingRepositoryProvider).dbGetBookingReference('');
    final booking = BookingModel(
      id: docRef.id,
      userId: authUser.uid,
      userName: _nameController.text.trim(),
      serviceId: _selectedService!.id,
      serviceName: _selectedService!.title,
      date: _selectedDate!,
      time: DateFormat('hh:mm a').format(_selectedSlot!),
      duration: _selectedOption!.duration,
      status: 'pending_payment',
      price: _selectedOption!.price,
      completionOtp: null,
      otpGeneratedAt: null,
      startTime: startTime,
      endTime: startTime.add(duration),
      latitude: _latitude,
      longitude: _longitude,
      userLocationAddress: _addressController.text.trim(),
      paymentStatus: 'pending_payment',
      specialNeeds: _notesController.text.trim(),
      elderName: _elderNameController.text.trim(),
      elderAge: int.tryParse(_elderAgeController.text.trim()),
      medicalConditions: _medicalConditionsController.text.trim(),
    );

    try {
      await ref.read(bookingRepositoryProvider).createBooking(booking);
    } catch (error, stackTrace) {
      final unwrapped = _unwrapConvertedFutureError(error);
      final unwrappedStack = _unwrapConvertedFutureStack(error, stackTrace);
      debugPrint(
          '[BOOKING ERROR] createBooking raw=$error unwrapped=$unwrapped');
      debugPrint('[BOOKING ERROR] createBooking stack=$unwrappedStack');
      if (unwrapped is Exception) {
        throw unwrapped;
      }
      throw Exception(unwrapped.toString());
    }
    debugPrint('[BOOKING] Booking document created — id: ${docRef.id}');
    _bookingId = docRef.id;
    await ref
        .read(paymentProvider.notifier)
        .recoverPendingContext(bookingId: _bookingId!);
    return docRef.id;
  }

  Future<void> _ensureFreshSession() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Session expired. Please sign in again.');
    }

    try {
      await user.getIdToken(false).timeout(const Duration(seconds: 3));
    } on FirebaseAuthException catch (e) {
      const invalidCodes = {
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
        'user-token-expired',
        'requires-recent-login',
      };

      if (invalidCodes.contains(e.code)) {
        await ref.read(authControllerProvider.notifier).signOut();
      }
      throw Exception('Session expired. Please sign in again.');
    }
  }

  Future<void> _startPayment() async {
    if (_selectedOption == null) return;
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return;

    var currentStep = 'fetch_live_price';

    try {
      final previousPrice = _selectedOption!.price;
      final livePrice =
          await ref.read(bookingRepositoryProvider).fetchLiveServicePrice(
                serviceId: _selectedService!.id,
                duration: _selectedOption!.duration,
                fallbackPrice: previousPrice,
              );

      if ((livePrice - previousPrice).abs() >= 0.01) {
        if (!mounted) return;
        final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Price Updated'),
                content: Text(
                  'Price has been updated to INR ${livePrice.toStringAsFixed(0)}. Do you want to continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ) ??
            false;

        if (!shouldContinue) {
          return;
        }

        setState(() {
          _selectedOption = ServiceOption(
            duration: _selectedOption!.duration,
            price: livePrice,
          );
        });
      }

      currentStep = 'ensure_pending_booking';
      final bookingId = await _ensurePendingBooking();
      if (!mounted) return;

      debugPrint('[PAYMENT] Start requested');
      debugPrint('[PAYMENT] bookingId=$bookingId');
      debugPrint(
          '[PAYMENT] optionPrice=${_selectedOption!.price} (type=${_selectedOption!.price.runtimeType})');

      currentStep = 'recover_pending_context';
      await ref
          .read(paymentProvider.notifier)
          .recoverPendingContext(bookingId: bookingId);

      currentStep = 'initiate_payment';
      await ref.read(paymentProvider.notifier).initiatePayment(
            bookingId: bookingId,
            userEmail: authUser.email ?? '',
            userName: _nameController.text.trim(),
            userPhone: _phoneController.text.trim(),
            description:
                '${_selectedService?.title ?? "Service"} – ${_selectedOption!.duration}',
            onSuccess: (paymentId, orderId, signature) {
              unawaited(
                _handlePaymentSuccess(
                  bookingId: bookingId,
                  paymentId: paymentId,
                  orderId: orderId,
                  signature: signature,
                ),
              );
            },
            onFailure: (errorMessage) {
              if (!mounted) return;
              if (errorMessage.toLowerCase().contains('session expired')) {
                context.go('/auth/login?mode=signin&role=family');
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Payment failed: $errorMessage')),
              );
            },
          );
    } catch (e, st) {
      final normalizedError = _unwrapConvertedFutureError(e);
      final normalizedStack = _unwrapConvertedFutureStack(e, st);

      debugPrint('[PAYMENT ERROR] _startPayment step=$currentStep');
      debugPrint(
          '[PAYMENT ERROR] _startPayment type=${normalizedError.runtimeType}');
      debugPrint('[PAYMENT ERROR] _startPayment message=$normalizedError');
      debugPrint('[PAYMENT ERROR] _startPayment stack=$normalizedStack');

      final boxedDetails = _extractBoxedFutureDetails(e);
      if (boxedDetails != null) {
        debugPrint('[PAYMENT ERROR] _startPayment boxedError=$boxedDetails');
      }

      if (normalizedError is FirebaseFunctionsException &&
          normalizedError.details is Map &&
          (normalizedError.details as Map)['code'] == 'PRICE_CHANGED') {
        final details =
            Map<String, dynamic>.from(normalizedError.details as Map);
        final latestAmount = (details['latestAmount'] as num?)?.toDouble();
        if (latestAmount != null && mounted) {
          final shouldRetry = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Price Updated'),
                  content: Text(
                    'Price has been updated to INR ${latestAmount.toStringAsFixed(0)}. Do you want to continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (shouldRetry && mounted) {
            setState(() {
              _selectedOption = ServiceOption(
                duration: _selectedOption!.duration,
                price: latestAmount,
              );
            });
            await _startPayment();
            return;
          }
        }
      }

      final normalizedMessage = normalizedError.toString().toLowerCase();
      if (normalizedMessage.contains('slot_taken')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This slot was just taken. Please pick a different time.',
            ),
          ),
        );
        setState(() => _currentStep = 1);
        ref.invalidate(slotAvailabilityProvider);
        return;
      }

      if (normalizedMessage.contains('no_caregivers_available') ||
          normalizedMessage.contains('no caregivers are currently available')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No caregivers are currently available for this slot. Please choose another time.',
            ),
          ),
        );
        setState(() => _currentStep = 1);
        ref.invalidate(slotAvailabilityProvider);
        return;
      }

      if (normalizedMessage.contains('caregiver_taken')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This caregiver is no longer available at that time. Please select another caregiver or slot.',
            ),
          ),
        );
        setState(() => _currentStep = 5);
        return;
      }

      if (normalizedMessage.contains('session expired')) {
        if (!mounted) return;
        context.go('/auth/login?mode=signin&role=family');
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Unable to start payment: ${ErrorHandler.handle(normalizedError)}')),
      );
    }
  }

  Future<void> _handlePaymentSuccess({
    required String bookingId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      await ref.read(paymentProvider.notifier).completePayment(
            bookingId: bookingId,
            paymentId: paymentId,
            orderId: orderId,
            signature: signature,
          );

      if (!mounted) return;

      final paymentState = ref.read(paymentProvider);
      if (paymentState.valueOrNull == PaymentState.success) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment verification failed.')),
      );
    } catch (error, stackTrace) {
      debugPrint('[PAYMENT ERROR] _handlePaymentSuccess error=$error');
      debugPrint('[PAYMENT ERROR] _handlePaymentSuccess stack=$stackTrace');
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

  Object _unwrapConvertedFutureError(Object error) {
    try {
      final dynamic boxed = error;
      final innerError = boxed.error;
      if (innerError != null && innerError is Object) {
        return innerError;
      }
    } catch (_) {
      // Ignore dynamic access failures and fall back to original error.
    }
    return error;
  }

  StackTrace _unwrapConvertedFutureStack(
    Object error,
    StackTrace fallback,
  ) {
    try {
      final dynamic boxed = error;
      final innerStack = boxed.stack;
      if (innerStack is StackTrace) {
        return innerStack;
      }
      if (innerStack is String && innerStack.trim().isNotEmpty) {
        return StackTrace.fromString(innerStack);
      }
    } catch (_) {
      // Ignore dynamic access failures and use fallback stack.
    }
    return fallback;
  }

  String? _extractBoxedFutureDetails(Object error) {
    try {
      final dynamic boxed = error;
      final innerError = boxed.error;
      final innerStack = boxed.stack;
      if (innerError == null && innerStack == null) {
        return null;
      }
      return 'error=$innerError stack=$innerStack';
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmBooking() async {
    if (_bookingId == null || _bookingId!.isEmpty) {
      return;
    }

    if (ref.read(paymentProvider).valueOrNull != PaymentState.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Verified payment is required before confirming the booking.')),
      );
      setState(() => _currentStep = 4); // Go back to payment step
      return;
    }

    setState(() => _isSubmitting = true);
    _showBlockingLoader('Finalizing booking...');
    try {
      if (_selectedPersonnel == null) {
        await ref
            .read(bookingRepositoryProvider)
            .assignRandomPersonnel(_bookingId!);
      } else {
        await ref.read(bookingRepositoryProvider).updateBookingPersonnel(
              _bookingId!,
              _selectedPersonnel!.id,
              _selectedPersonnel!.name,
            );
      }

      debugPrint('[BOOKING] Confirm booking success — bookingId: $_bookingId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking confirmed! 🎉')),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[BOOKING ERROR] ══════════════════════════════════════');
        debugPrint('[BOOKING ERROR] Type: ${e.runtimeType}');
        debugPrint('[BOOKING ERROR] Message: $e');
        debugPrint('[BOOKING ERROR] BookingId: $_bookingId');
        debugPrint('[BOOKING ERROR] PersonnelId: ${_selectedPersonnel?.id}');
        debugPrint('[BOOKING ERROR] ══════════════════════════════════════');
        String errorMsg = 'Failed to create booking. Please try again.';
        if (e.toString().contains('caregiver_taken')) {
          errorMsg =
              'Sorry, the selected caregiver was just booked by someone else for this time. Please select another caregiver or time slot.';
          // Go back to the caregiver selection step
          setState(() {
            _currentStep = 5;
            _selectedPersonnel = null;
          });
        } else if (e.toString().contains('no_caregivers_available')) {
          errorMsg =
              'No caregivers are currently available. Please try another time slot.';
          setState(() {
            _currentStep = 1;
          });
          ref.invalidate(slotAvailabilityProvider);
        } else if (e.toString().contains('slot_taken')) {
          errorMsg =
              'Sorry, this time slot is no longer available. Please select a different time.';
          // Go back to the schedule step to pick a new slot
          setState(() {
            _currentStep = 1;
          });
          ref.invalidate(slotAvailabilityProvider);
        } else if (e.toString().contains('booking_missing_timing')) {
          errorMsg =
              'This booking is missing timing details. Please restart the booking flow.';
        } else if (e.toString().contains('booking_not_found')) {
          errorMsg =
              'This booking could not be found. Please start the booking again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
      _hideBlockingLoader();
    }
  }

  Future<void> _cancelPendingBookingAndRestart() async {
    if (_isCancellingPendingBooking) return;

    final pendingBookingId = _bookingId;
    if (pendingBookingId == null || pendingBookingId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _currentStep = 0;
        _serviceSubStep = 0;
      });
      return;
    }

    _showBlockingLoader('Cancelling booking and resetting flow...');
    _isCancellingPendingBooking = true;
    try {
      try {
        await ref
            .read(bookingRepositoryProvider)
            .cancelBooking(pendingBookingId);
      } catch (e) {
        // Fallback for client-allowed cancellation fields when callable fails.
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(pendingBookingId)
            .update({
          'status': 'cancelled',
          'cancelledBy': 'user',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await ref.read(paymentProvider.notifier).reset();

      if (!mounted) return;
      setState(() {
        _bookingId = null;
        _currentStep = 0;
        _serviceSubStep = 0;
        _selectedService = null;
        _selectedOption = null;
        _selectedDate = null;
        _selectedSlot = null;
        _availablePersonnel = null;
        _selectedPersonnel = null;
        _agreedToTerms = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pending booking cancelled. Please start your booking again.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel pending booking: $e')),
      );
    } finally {
      _isCancellingPendingBooking = false;
      _hideBlockingLoader();
    }
  }

  Future<void> _handleBackNavigation() async {
    final hasPendingBooking = _bookingId != null && _bookingId!.isNotEmpty;
    final paymentState = ref.read(paymentProvider).valueOrNull;

    if (_currentStep >= 4 &&
        hasPendingBooking &&
        paymentState != PaymentState.success) {
      await _cancelPendingBookingAndRestart();
      return;
    }

    if (_currentStep == 5) {
      _confirmBooking();
    } else if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else if (_currentStep == 0 && _serviceSubStep > 0) {
      setState(() => _serviceSubStep--);
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  String _paymentStatusFor(AsyncValue<PaymentState> paymentState) {
    if (paymentState.isLoading) {
      return 'processing';
    }
    if (paymentState.hasError) {
      return 'failed';
    }

    switch (paymentState.valueOrNull ?? PaymentState.idle) {
      case PaymentState.idle:
        return 'idle';
      case PaymentState.loading:
        return 'processing';
      case PaymentState.success:
        return 'success';
      case PaymentState.failed:
        return 'failed';
    }
  }

  Future<void> _fetchPersonnel() async {
    if (_selectedDate == null ||
        _selectedSlot == null ||
        _selectedOption == null) {
      return;
    }
    setState(() {
      _isLoadingPersonnel = true;
      _selectedPersonnel = null;
    });

    try {
      final startTime = DateTime(_selectedDate!.year, _selectedDate!.month,
          _selectedDate!.day, _selectedSlot!.hour, _selectedSlot!.minute);
      final durationParts = _selectedOption!.duration.split(' ');
      final durationVal = int.tryParse(durationParts[0]) ?? 1;
      final duration = Duration(hours: durationVal);
      final endTime = startTime.add(duration);

      final personnel = await FirestoreService().getServicePersonnel(
        startTime: startTime,
        endTime: endTime,
      );

      if (mounted) {
        setState(() {
          _availablePersonnel = personnel;
          _isLoadingPersonnel = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPersonnel = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error loading caregivers: ${ErrorHandler.handle(e)}')),
        );
      }
    }
  }

  bool _validateDetailsForm() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final elderName = _elderNameController.text.trim();
    final elderAgeText = _elderAgeController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name.')),
      );
      return false;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 10-digit phone number.')),
      );
      return false;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a service location.')),
      );
      return false;
    }

    if (elderName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the elder\'s name.')),
      );
      return false;
    }

    // Elder age is required. Default is filled from profile DOB when available.
    if (elderAgeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the elder\'s age.')),
      );
      return false;
    }

    final age = int.tryParse(elderAgeText);
    if (age == null || age < 1 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid elder age (1-120).')),
      );
      return false;
    }

    // Business rule: elders must be 50 years or older.
    if (age < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Elder must be 50 years or older to book this service.')),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(authSessionValidProvider);

    // Track payment state here so we can disable global back navigation
    // while the payment is in a successful state.
    final globalPaymentStatus = _paymentStatusFor(ref.watch(paymentProvider));

    if (sessionAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (sessionAsync.valueOrNull != true) {
      if (!_sessionRedirectScheduled) {
        _sessionRedirectScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/auth/login?mode=signin&role=family');
          }
        });
      }

      return const Scaffold(
        body: Center(child: Text('Session expired. Redirecting to login...')),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 768;
    final horizontalPadding =
        isDesktop ? GCSpacing.pagePaddingDesktop : GCSpacing.pagePaddingMobile;

    // Prefill details when entering step 2 (Details)
    if (_currentStep == 2) _prefillDetails();

    return PopScope(
      canPop: _currentStep == 0 && _serviceSubStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBackNavigation());
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: GCColors.background,
            appBar: AppBar(
              title: const Text('Book Care'),
              leading: globalPaymentStatus == 'success'
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () async {
                        await _handleBackNavigation();
                      },
                    ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: GCSpacing.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        Text('Book Care', style: GCTypography.displayMedium),
                        const SizedBox(height: 8),
                        Text('Select a service and schedule your care session.',
                            style: GCTypography.bodyLarge),
                        const SizedBox(height: 32),

                        // Progress stepper
                        _buildStepper(isDesktop),
                        const SizedBox(height: 32),

                        // Step content
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildStepContent()),
                              const SizedBox(width: 24),
                              Expanded(
                                  child: _buildSummaryCard(
                                      showPrice: _currentStep >= 4)),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildStepContent(),
                              const SizedBox(height: 24),
                              _buildSummaryCard(showPrice: _currentStep >= 4),
                            ],
                          ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showBlockingOverlay)
            Positioned.fill(
              child: Container(
                color: const Color.fromRGBO(255, 255, 255, 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFB8860B)),
                      const SizedBox(height: 12),
                      Text(
                        _blockingOverlayMessage,
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

  Widget _buildStepper(bool isDesktop) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Container(
              width: isDesktop ? 48 : 24,
              height: 2,
              color: index ~/ 2 < _currentStep
                  ? GCColors.primary
                  : GCColors.border,
            );
          }
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == _currentStep;
          final isCompleted = stepIndex < _currentStep;
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive || isCompleted ? GCColors.primary : GCColors.muted,
              border: isActive
                  ? Border.all(color: GCColors.primary, width: 2)
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('${stepIndex + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isActive ? Colors.white : GCColors.mutedForeground,
                      )),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildServiceSelection();
      case 1:
        return _buildScheduleSelection();
      case 2:
        return _buildDetailsForm();
      case 3:
        return _buildAgreementStep();
      case 4:
        return _buildPaymentStep();
      case 5:
        return _buildPersonnelSelection();
      default:
        return const SizedBox();
    }
  }

  Widget _buildServiceSelection() {
    if (_serviceSubStep == 0) return _buildServiceList();
    if (_serviceSubStep == 1) return _buildAboutService();
    if (_serviceSubStep == 2) return _buildServiceSummaryStep();
    return const SizedBox();
  }

  Widget _buildServiceList() {
    final servicesAsync = ref.watch(servicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a Service', style: GCTypography.headlineLarge),
        const SizedBox(height: 16),
        servicesAsync.when(
          data: (services) {
            if (services.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No services available.')),
              );
            }
            return Column(
              children: services
                  .map((service) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedService = service;
                            _selectedOption = service.options.isNotEmpty
                                ? service.options.first
                                : null;
                            _serviceSubStep = 1;
                          }),
                          borderRadius:
                              BorderRadius.circular(GCSpacing.radiusLg),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(GCSpacing.radiusLg),
                              side: BorderSide(
                                color: _selectedService?.id == service.id
                                    ? GCColors.primary
                                    : GCColors.border,
                                width:
                                    _selectedService?.id == service.id ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: GCColors.primary.withAlpha(26),
                                      borderRadius: BorderRadius.circular(
                                          GCSpacing.radiusLg),
                                    ),
                                    child: service.imageUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                GCSpacing.radiusLg),
                                            child: CachedNetworkImage(
                                              imageUrl: service.imageUrl,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color: GCColors.primary
                                                    .withAlpha(26),
                                                child: const Icon(
                                                  Icons
                                                      .medical_services_outlined,
                                                  color: GCColors.primary,
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  const Icon(
                                                Icons.medical_services_outlined,
                                                color: GCColors.primary,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.medical_services_outlined,
                                            color: GCColors.primary,
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(service.title,
                                            style: GCTypography.headlineSmall),
                                        const SizedBox(height: 4),
                                        Text(
                                          service.description,
                                          style: GCTypography.bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: GCColors.mutedForeground),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              Center(child: Text('Error loading services: $error')),
        ),
      ],
    );
  }

  Widget _buildAboutService() {
    if (_selectedService == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About ${_selectedService!.title}',
            style: GCTypography.headlineLarge),
        const SizedBox(height: 16),
        _buildServiceDetailsPanel(_selectedService!),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: GCButton(
                label: 'Change Service',
                onPressed: () => setState(() => _serviceSubStep = 0),
                variant: GCButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GCButton(
                label: 'Continue to Options',
                onPressed: () => setState(() => _serviceSubStep = 2),
                variant: GCButtonVariant.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceSummaryStep() {
    if (_selectedService == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Duration', style: GCTypography.headlineLarge),
        const SizedBox(height: 16),

        // Duration selection
        if (_selectedService!.options.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _selectedService!.options
                .map((opt) => ChoiceChip(
                      label: Text(opt.duration),
                      selected: _selectedOption == opt,
                      onSelected: (_) => setState(() => _selectedOption = opt),
                      selectedColor: GCColors.primary.withAlpha(51),
                      labelStyle: GoogleFonts.inter(
                        color: _selectedOption == opt
                            ? GCColors.primary
                            : GCColors.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
        ],

        Text('Service Summary', style: GCTypography.headlineSmall),
        const SizedBox(height: 12),
        _buildSummaryCard(showPrice: false),

        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: GCButton(
                label: 'Back',
                onPressed: () => setState(() => _serviceSubStep = 1),
                variant: GCButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GCButton(
                label: 'Proceed to Schedule',
                onPressed: _selectedOption != null
                    ? () async {
                        if (!_emergencyContactChecked) {
                          final canBook = await _checkEmergencyContact(context);
                          if (!canBook) return;
                        }
                        setState(() => _currentStep = 1);
                      }
                    : null,
                variant: GCButtonVariant.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '* Cancellation policy applies to all bookings',
            style: GCTypography.bodySmall
                .copyWith(color: GCColors.mutedForeground, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({bool showPrice = false}) {
    if (_selectedService == null) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _summaryRow('Service', _selectedService!.title),
            if (_selectedOption != null) ...[
              _summaryRow('Duration', _selectedOption!.duration),
              if (_selectedDate != null)
                _summaryRow(
                    'Date', DateFormat('MMM d, yyyy').format(_selectedDate!)),
              if (_selectedSlot != null)
                _summaryRow(
                    'Time', DateFormat('h:mm a').format(_selectedSlot!)),
              if (showPrice) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Estimated Price',
                        style:
                            GCTypography.headlineSmall.copyWith(fontSize: 16)),
                    Text('₹${_selectedOption!.price.toStringAsFixed(0)}',
                        style: GCTypography.headlineSmall
                            .copyWith(color: GCColors.primary)),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Schedule', style: GCTypography.headlineLarge),
        const SizedBox(height: 16),
        Text('Choose a date for your care session.',
            style: GCTypography.bodyMedium),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(GCSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date', style: GCTypography.headlineSmall),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        _selectedSlot = null;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: GCColors.border),
                      borderRadius: BorderRadius.circular(GCSpacing.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null
                              ? 'Select a date'
                              : DateFormat('MMM dd, yyyy')
                                  .format(_selectedDate!),
                          style: _selectedDate == null
                              ? GCTypography.bodyMedium
                                  .copyWith(color: GCColors.mutedForeground)
                              : GCTypography.bodyMedium,
                        ),
                        const Icon(Icons.calendar_today,
                            size: 20, color: GCColors.primary),
                      ],
                    ),
                  ),
                ),
                if (_selectedDate != null) ...[
                  const SizedBox(height: 24),
                  Text('Available Time Slots',
                      style: GCTypography.headlineSmall),
                  const SizedBox(height: 12),
                  SlotPickerWidget(
                    selectedDate: _selectedDate!,
                    duration: _bookingDuration,
                    selectedSlot: _selectedSlot == null
                        ? null
                        : '${_selectedSlot!.hour.toString().padLeft(2, '0')}:'
                            '${_selectedSlot!.minute.toString().padLeft(2, '0')}',
                    onSlotSelected: (slotStr) {
                      final parts = slotStr.split(':');
                      final hour = int.parse(parts[0]);
                      final minute = int.parse(parts[1]);
                      setState(() {
                        _selectedSlot = DateTime(
                            _selectedDate!.year,
                            _selectedDate!.month,
                            _selectedDate!.day,
                            hour,
                            minute);
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GCButton(
                label: 'Back',
                onPressed: () => setState(() => _currentStep = 0),
                variant: GCButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GCButton(
                label: 'Continue',
                onPressed: _selectedDate != null && _selectedSlot != null
                    ? () async {
                        _prefillDetails();
                        setState(() {
                          _currentStep = 2;
                        });

                        // Auto-open map if not yet opened for this booking
                        if (!_mapAutoOpened) {
                          _mapAutoOpened = true;
                          _openMap();
                        }
                      }
                    : null,
                variant: GCButtonVariant.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonnelSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select an Available Caregiver',
            style: GCTypography.headlineLarge),
        const SizedBox(height: 16),
        if (_isLoadingPersonnel)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ))
        else if (_availablePersonnel == null || _availablePersonnel!.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(GCSpacing.cardPadding),
              child: Column(
                children: [
                  const Icon(Icons.person_off_outlined,
                      size: 48, color: GCColors.muted),
                  const SizedBox(height: 16),
                  Text('No Caregivers Available',
                      style: GCTypography.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Please try a different slot or date.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          Column(
            children: _availablePersonnel!
                .map((personnel) => _buildCaregiverCard(personnel))
                .toList(),
          ),
        const SizedBox(height: 16),
        if (!_isLoadingPersonnel &&
            _availablePersonnel != null &&
            _availablePersonnel!.isNotEmpty)
          GCButton(
            label: 'Assign Any Available Caregiver',
            onPressed: _isSubmitting ? null : _confirmBooking,
            variant: GCButtonVariant.outline,
            icon: Icons.shuffle,
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Spacer(), // Back button removed per requirement
            const SizedBox(width: 16),
            Expanded(
              child: GCButton(
                label: 'Confirm Booking',
                onPressed: !_isSubmitting &&
                        (_selectedPersonnel != null ||
                            (_availablePersonnel?.isNotEmpty ?? false))
                    ? _confirmBooking
                    : null,
                variant: GCButtonVariant.primary,
                isLoading: _isSubmitting,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Details', style: GCTypography.headlineLarge),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(GCSpacing.cardPadding),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  readOnly: true,
                  maxLines: 2,
                  onTap: _openMap,
                  decoration: const InputDecoration(
                    labelText: 'Service Location',
                    hintText: 'Tap to pick location on map',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    suffixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Special Requirements',
                    hintText: 'Any specific needs we should know about?',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _elderNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Elder\'s Name',
                    hintText: 'Name of the person receiving care',
                    prefixIcon: Icon(Icons.elderly_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _elderAgeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Elder\'s Age',
                    hintText: 'Age in years',
                    prefixIcon: Icon(Icons.cake_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _medicalConditionsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Medical Conditions',
                    hintText: 'Any relevant medical conditions (optional)',
                    prefixIcon: Icon(Icons.medical_information_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GCButton(
                label: 'Back',
                onPressed: () => setState(() => _currentStep = 1),
                variant: GCButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GCButton(
                label: 'Continue to Agreement',
                onPressed: () {
                  if (!_validateDetailsForm()) {
                    return;
                  }

                  final address = _addressController.text.toLowerCase();
                  bool isValidLocation = address.contains('chandigarh') ||
                      address.contains('mohali') ||
                      address.contains('panchkula');

                  if (!isValidLocation) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Our services are currently limited to Chandigarh, Mohali, and Panchkula.')));
                    return;
                  }

                  setState(() => _currentStep = 3);
                },
                variant: GCButtonVariant.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    final paymentStatus = _paymentStatusFor(ref.watch(paymentProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Secure Payment', style: GCTypography.headlineLarge),
        const SizedBox(height: 16),
        _buildSummaryCard(showPrice: true),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(GCSpacing.cardPadding),
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Column(
                  key: ValueKey(paymentStatus),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (paymentStatus == 'idle') ...[
                      const Icon(Icons.payment,
                          size: 64, color: GCColors.primary),
                      const SizedBox(height: 16),
                      Text('Ready to Pay', style: GCTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Your payment will be processed securely.',
                        textAlign: TextAlign.center,
                      ),
                    ] else if (paymentStatus == 'processing') ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text('Processing Payment...',
                          style: GCTypography.headlineSmall),
                    ] else if (paymentStatus == 'success') ...[
                      const Icon(Icons.check_circle,
                          size: 64, color: GCColors.accent),
                      const SizedBox(height: 16),
                      Text('Payment Successful!',
                          style: GCTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('Now select your preferred caregiver.',
                          textAlign: TextAlign.center),
                    ] else if (paymentStatus == 'failed') ...[
                      const Icon(Icons.error_outline,
                          size: 64, color: GCColors.destructive),
                      const SizedBox(height: 16),
                      Text('Payment Failed',
                          style: GCTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('Please try again.',
                          textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: GCButton(
                label: 'Back',
                onPressed: paymentStatus == 'success'
                    ? null
                    : () async {
                        await _handleBackNavigation();
                      },
                variant: GCButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: paymentStatus == 'success'
                  ? GCButton(
                      label: 'Next: Choose Caregiver',
                      onPressed: () {
                        _fetchPersonnel();
                        setState(() => _currentStep = 5);
                      },
                      variant: GCButtonVariant.primary,
                    )
                  : GCButton(
                      label: paymentStatus == 'failed'
                          ? 'Retry Payment'
                          : 'Pay Now',
                      onPressed: paymentStatus == 'processing'
                          ? null
                          : () => _startPayment(),
                      variant: GCButtonVariant.primary,
                      icon: Icons.payment,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: GCTypography.bodyMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  GCTypography.bodyMedium.copyWith(color: GCColors.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetailsPanel(ServiceModel service) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ConfigService().getServiceDetails(service.id),
      builder: (context, snapshot) {
        final details = snapshot.data ?? {};
        final about = (details['about'] as String?) ?? service.description;
        final remoteIncludes =
            List<String>.from(details['includes'] ?? const []);
        final inclusions = service.includedItems.isNotEmpty
            ? service.includedItems
            : remoteIncludes;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: GCColors.primary.withAlpha(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GCSpacing.radiusLg),
                side: BorderSide(color: GCColors.primary.withAlpha(26)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: GCColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('About this service',
                            style: GCTypography.headlineSmall
                                .copyWith(color: GCColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(about, style: GCTypography.bodyMedium),
                    if (inclusions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('What\'s Included',
                          style: GCTypography.headlineSmall
                              .copyWith(fontSize: 16)),
                      const SizedBox(height: 12),
                      ...inclusions.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle,
                                    color: GCColors.accent, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(item,
                                        style: GCTypography.bodyMedium)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAgreementStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Terms & Policies', style: GCTypography.headlineLarge),
        const SizedBox(height: 16),
        Text('Please review and accept our terms before proceeding.',
            style: GCTypography.bodyMedium),
        const SizedBox(height: 24),

        // Cancellation Warning Card (Prominent)
        Card(
          color: Colors.amber.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GCSpacing.radiusMd),
            side: BorderSide(color: Colors.amber.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cancellation & Refund Policy',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(
                          'A 25% cancellation fee applies if you cancel an upcoming booking. Please ensure your schedule is confirmed.',
                          style: GCTypography.bodySmall
                              .copyWith(color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Included/Not Included Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Important Information',
                    style: GCTypography.headlineSmall),
                const Divider(height: 24),
                _agreementInfoRow(Icons.info_outline,
                    'Additional charges such as travel and transportation are to be paid directly to the caregiver.'),
                _agreementInfoRow(Icons.check_circle_outline,
                    'Service includes professional care and companionship for the selected duration.'),
                _agreementInfoRow(Icons.shield_outlined,
                    'Your data is handled securely as per our privacy policy.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Checkbox
        CheckboxListTile(
          value: _agreedToTerms,
          onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
          title: Wrap(
            children: [
              const Text('I agree to the '),
              InkWell(
                onTap: _showTermsDialog,
                child: const Text('Terms & Conditions',
                    style: TextStyle(
                        color: GCColors.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: GCButton(
                label: 'Back',
                onPressed: () => setState(() => _currentStep = 2),
                variant: GCButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GCButton(
                label: 'Continue to Payment',
                onPressed: _agreedToTerms
                    ? () => setState(() => _currentStep = 4)
                    : null,
                variant: GCButtonVariant.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _agreementInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: GCColors.mutedForeground),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GCTypography.bodySmall)),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Service Booking: Subject to availability.\n\n'
            '2. Payment: Full payment at time of booking.\n\n'
            '3. Cancellation: A 25% fee applies for cancellations.\n\n'
            '4. Additional Costs: Travel and incidental expenses are not covered by Golden Care and must be settled with the caregiver.\n\n'
            '5. Safety: Customers must provide a safe environment.\n\n'
            '6. Liability: Golden Care is a platform connecting users; we are not liable for person-to-person incidents but provide support for resolution.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard(ServicePersonnelModel personnel) {
    return CaregiverCard(
      personnel: personnel,
      isSelected: _selectedPersonnel?.id == personnel.id,
      isExpanded: _expandedCaregiverId == personnel.id,
      onTap: () {
        setState(() {
          _selectedPersonnel = personnel;
          _expandedCaregiverId =
              _expandedCaregiverId == personnel.id ? null : personnel.id;
        });
      },
    );
  }
}
