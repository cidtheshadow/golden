import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import '../models/booking_model.dart';
import '../models/service_personnel_model.dart';
import 'notification_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<ServiceModel>> getServices() async {
    final snapshot = await _db.collection('services').get();
    return snapshot.docs
        .map((doc) => ServiceModel.fromFirestore(doc))
        .where((service) => service.isActive)
        .toList();
  }

  Stream<List<ServiceModel>> getServicesStream() {
    return _db.collection('services').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ServiceModel.fromFirestore(doc))
              .where((service) => service.isActive)
              .toList(),
        );
  }

  Future<List<ServiceModel>> getServicesByCategory(String category) async {
    if (category == 'All') return getServices();
    final snapshot = await _db
        .collection('services')
        .where('category', isEqualTo: category)
        .get();
    return snapshot.docs
        .map((doc) => ServiceModel.fromFirestore(doc))
        .where((service) => service.isActive)
        .toList();
  }

  Stream<List<ServiceModel>> getPopularServices() {
    return _db
        .collection('services')
        .where('isPopular', isEqualTo: true)
        .orderBy('isPopular', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromFirestore(doc))
            .where((service) => service.isActive)
            .toList());
  }

  Future<double> fetchLiveServicePrice({
    required String serviceId,
    required String duration,
    required double fallbackPrice,
  }) async {
    try {
      final serviceDoc = await _db.collection('services').doc(serviceId).get();
      if (!serviceDoc.exists) {
        return fallbackPrice;
      }

      final service = ServiceModel.fromFirestore(serviceDoc);
      final normalizedDuration = duration.trim().toLowerCase();
      ServiceOption? matchedOption;
      for (final option in service.options) {
        if (option.duration.trim().toLowerCase() == normalizedDuration) {
          matchedOption = option;
          break;
        }
      }

      return matchedOption?.price ?? fallbackPrice;
    } catch (e) {
      debugPrint('Error fetching live service price: $e');
      return fallbackPrice;
    }
  }

  // Users
  Future<void> createOrUpdateUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> updateEmergencyContacts(
      String uid, List<Map<String, dynamic>> contacts) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'emergencyContacts': contacts});
  }

  Future<bool> isPhoneNumberInUse(String phoneNumber,
      {String? excludeUid}) async {
    try {
      // Check in users collection
      var userQuery =
          _db.collection('users').where('phone', isEqualTo: phoneNumber);
      if (excludeUid != null) {
        userQuery =
            userQuery.where(FieldPath.documentId, isNotEqualTo: excludeUid);
      }
      final userDocs = await userQuery.limit(1).get();
      if (userDocs.docs.isNotEmpty) return true;

      // Check in servicePersonnel collection
      var personnelQuery = _db
          .collection('servicePersonnel')
          .where('phone', isEqualTo: phoneNumber);
      if (excludeUid != null) {
        personnelQuery = personnelQuery.where(FieldPath.documentId,
            isNotEqualTo: excludeUid);
      }
      final personnelDocs = await personnelQuery.limit(1).get();
      if (personnelDocs.docs.isNotEmpty) return true;

      return false;
    } catch (e) {
      debugPrint('Error checking phone number use: $e');
      return false;
    }
  }

  // ── Admin Helper Methods ─────────────────────────

  /// Returns the total count of bookings in the system.
  Future<int> getAllBookingsCount() async {
    try {
      final snapshot = await _db.collection('bookings').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting all bookings count: $e');
      return 0;
    }
  }

  /// Returns the count of active bookings awaiting completion.
  Future<int> getPendingBookingsCount() async {
    try {
      final snapshot = await _db
          .collection('bookings')
          .where('status', whereIn: ['confirmed', 'completion_requested'])
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting pending bookings count: $e');
      return 0;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    if (data.containsKey('dob') && data['dob'] is DateTime) {
      data['dob'] = Timestamp.fromDate(data['dob']);
    }
    await _db.collection('users').doc(uid).update(data);
  }

  static const _pendingPaymentHoldWindow = Duration(minutes: 20);
  static const _bookingCooldownWindow = Duration(minutes: 30);
  static const _personnelBookingsScanLimit = 800;

  bool _isCapacityBlockingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
      case 'upcoming':
      case 'confirmed':
      case 'in_progress':
      case 'completion_requested':
        return true;
      default:
        return false;
    }
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _isPendingPaymentHoldActive(
    Map<String, dynamic> bookingData,
    DateTime now,
  ) {
    final createdAt = _asDateTime(bookingData['createdAt']);
    if (createdAt == null) {
      // Keep unknown legacy pending docs blocking to avoid overbooking.
      return true;
    }
    return now.difference(createdAt) <= _pendingPaymentHoldWindow;
  }

  DateTime _bookingSortAnchor(BookingModel booking) {
    return booking.startTime ?? booking.date;
  }

  List<BookingModel> _sortBookingsBySchedule(
    Iterable<BookingModel> bookings, {
    required bool descending,
  }) {
    final sorted = bookings.toList();
    sorted.sort((a, b) {
      final aDate = _bookingSortAnchor(a);
      final bDate = _bookingSortAnchor(b);
      return descending ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
    return sorted;
  }

  Set<String> _normalizeStatuses(List<String> statuses) {
    return statuses.map((s) => s.trim().toLowerCase()).toSet();
  }

  bool _matchesStatus(BookingModel booking, Set<String> normalizedStatuses) {
    return normalizedStatuses.contains(booking.status.trim().toLowerCase());
  }

  // Bookings
  Future<void> createBooking(BookingModel booking) async {
    final docRef =
        _db.collection('bookings').doc(booking.id.isEmpty ? null : booking.id);
    final bookingWithId = booking.copyWith(id: docRef.id);

    // Keep read/query flow outside transaction for web reliability and clearer
    // errors. The old path could surface opaque boxed-future exceptions.
    final allPersonnel = await _fetchAvailablePersonnel();
    final allPersonnelCount = allPersonnel.length;
    if (allPersonnelCount == 0) {
      throw Exception('no_caregivers_available');
    }

    final slotStart = booking.startTime;
    final slotEnd = booking.endTime;
    if (slotStart == null || slotEnd == null) {
      throw Exception('booking_missing_timing');
    }

    final startTimeOfDay =
        DateTime(booking.date.year, booking.date.month, booking.date.day);
    final endTimeOfDay =
        DateTime(booking.date.year, booking.date.month, booking.date.day + 1);

    final bookingsQuery = await _db
        .collection('bookings')
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startTimeOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endTimeOfDay))
        .get();

    final now = DateTime.now();
    int overlappingBookingsCount = 0;
    bool requestedCaregiverTaken = false;

    for (final doc in bookingsQuery.docs) {
      final bookingData = doc.data();
      final status = (bookingData['status'] as String? ?? '').toLowerCase();
      if (!_isCapacityBlockingStatus(status)) {
        continue;
      }

      // Ignore expired/abandoned pending holds and the same user's pending
      // booking attempts so retries do not lock their own slot.
      if (status == 'pending_payment') {
        if (bookingData['userId'] == booking.userId) {
          continue;
        }
        if (!_isPendingPaymentHoldActive(bookingData, now)) {
          continue;
        }
      }

      final bStart = _asDateTime(bookingData['startTime']);
      final bEnd = _asDateTime(bookingData['endTime']);
      if (bStart == null || bEnd == null) {
        continue;
      }

      final effectiveEnd = bEnd.add(_bookingCooldownWindow);
      if (slotStart.isBefore(effectiveEnd) && slotEnd.isAfter(bStart)) {
        overlappingBookingsCount++;

        if (booking.servicePersonnelId != null &&
            bookingData['servicePersonnelId'] == booking.servicePersonnelId) {
          requestedCaregiverTaken = true;
        }
      }
    }

    if (requestedCaregiverTaken) {
      throw Exception('caregiver_taken');
    }

    if (overlappingBookingsCount >= allPersonnelCount) {
      throw Exception('slot_taken');
    }

    await docRef.set(bookingWithId.toMap());

    // Only send notification if transaction succeeds
    if (booking.servicePersonnelId != null) {
      await NotificationService().sendNotification(
        userId: booking.servicePersonnelId!,
        title: 'New Booking Request',
        body:
            'You have a new booking for ${booking.serviceName} on ${booking.date},',
        type: 'booking',
        targetId: docRef.id,
        collection: 'servicePersonnel',
      );
    }
  }

  DocumentReference dbGetBookingReference(String id) {
    if (id.isEmpty) {
      return _db.collection('bookings').doc();
    }
    return _db.collection('bookings').doc(id);
  }

  Stream<BookingModel?> getBookingStream(String id) {
    return _db
        .collection('bookings')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? BookingModel.fromFirestore(doc) : null);
  }

  Stream<List<BookingModel>> getUserBookings(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromFirestore(doc))
            .toList());
  }

  Future<PaginatedBookingsResult> getUserBookingsPage(
    String uid, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return PaginatedBookingsResult(
      bookings:
          snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList(),
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : startAfter,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<void> cancelBooking(String bookingId) async {
    final callable = FirebaseFunctions.instance.httpsCallable('cancelBooking');
    await callable.call({'bookingId': bookingId});
  }

  Future<List<ServicePersonnelModel>> _fetchAvailablePersonnel() async {
    try {
      final filteredSnapshot = await _db
          .collection('servicePersonnel')
          .where('isAvailable', isEqualTo: true)
          .where('isProfileComplete', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      if (filteredSnapshot.docs.isNotEmpty) {
        return filteredSnapshot.docs
            .map((doc) => ServicePersonnelModel.fromFirestore(doc))
            .toList();
      }

      // Some environments have legacy records without isProfileComplete/isActive
      // persisted on the document. Fall back to broad fetch + model-based checks.
      final availableOnlySnapshot = await _db
          .collection('servicePersonnel')
          .where('isAvailable', isEqualTo: true)
          .get();

      final fallbackPersonnel = availableOnlySnapshot.docs
          .map((doc) => ServicePersonnelModel.fromFirestore(doc))
          .where((p) => p.isProfileComplete && p.isActive)
          .toList();

      if (fallbackPersonnel.isNotEmpty) {
        return fallbackPersonnel;
      }

      // Final fallback: include legacy documents where isAvailable is absent.
      final broadSnapshot = await _db.collection('servicePersonnel').get();
      return broadSnapshot.docs
          .map((doc) => ServicePersonnelModel.fromFirestore(doc))
          .where((p) => p.isAvailable && p.isProfileComplete && p.isActive)
          .toList();
    } catch (e) {
      // Fallback for environments without a composite index for all filters.
      final fallbackSnapshot = await _db
          .collection('servicePersonnel')
          .where('isAvailable', isEqualTo: true)
          .get();

      final fallbackPersonnel = fallbackSnapshot.docs
          .map((doc) => ServicePersonnelModel.fromFirestore(doc))
          .where((p) => p.isProfileComplete && p.isActive)
          .toList();

      if (fallbackPersonnel.isNotEmpty) {
        return fallbackPersonnel;
      }

      final broadSnapshot = await _db.collection('servicePersonnel').get();
      return broadSnapshot.docs
          .map((doc) => ServicePersonnelModel.fromFirestore(doc))
          .where((p) => p.isAvailable && p.isProfileComplete && p.isActive)
          .toList();
    }
  }

  // Service Personnel
  Future<List<ServicePersonnelModel>> getServicePersonnel(
      {DateTime? startTime, DateTime? endTime}) async {
    try {
      final allPersonnel = await _fetchAvailablePersonnel();

      if (startTime == null || endTime == null) return allPersonnel;

      final queryStart =
          DateTime(startTime.year, startTime.month, startTime.day);
      final queryEnd = queryStart.add(const Duration(days: 1));

      final bookingsSnapshot = await _db
          .collection('bookings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
          .where('date', isLessThan: Timestamp.fromDate(queryEnd))
          .get();

      final conflictingPersonnelIds = <String>{};
      const cooldown = Duration(minutes: 30);

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        if (data['servicePersonnelId'] == null ||
            data['status'] == 'cancelled') {
          continue;
        }

        final bookingStart = (data['startTime'] as Timestamp).toDate();
        final bookingEnd = (data['endTime'] as Timestamp).toDate();
        final effectiveEnd = bookingEnd.add(cooldown);

        if (startTime.isBefore(effectiveEnd) && endTime.isAfter(bookingStart)) {
          conflictingPersonnelIds.add(data['servicePersonnelId']);
        }
      }

      return allPersonnel
          .where((p) => !conflictingPersonnelIds.contains(p.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching service personnel: $e');
      return [];
    }
  }

  Future<Map<DateTime, String>> getAvailableSlots(
      DateTime date, Duration duration) async {
    final slots = <DateTime, String>{};
    try {
      int startHour = 9; // Default to 9:00 AM
      int startMinute = 0;
      int endHour = 18; // Default to 6:00 PM
      int endMinute = 0;

      try {
        final configDoc = await _db.collection('config').doc('system').get();
        if (configDoc.exists) {
          final data = configDoc.data();
          if (data != null) {
            startHour = data['bookingStartHour'] ?? startHour;
            startMinute = data['bookingStartMinute'] ?? startMinute;
            endHour = data['bookingEndHour'] ?? endHour;
            endMinute = data['bookingEndMinute'] ?? endMinute;
          }
        }
      } catch (e) {
        debugPrint('Error reading system config: $e');
      }

      final allPersonnel = await _fetchAvailablePersonnel();

      debugPrint(
          'Found ${allPersonnel.length} available personnel for slot calculation');

      final startTimeOfDay = DateTime(date.year, date.month, date.day);
      final endTimeOfDay = DateTime(date.year, date.month, date.day + 1);
      final bookingsSnapshot = await _db
          .collection('bookings')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startTimeOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endTimeOfDay))
          .get();

      final dayBookings =
          bookingsSnapshot.docs.map((doc) => doc.data()).toList();

      var currentTime =
          DateTime(date.year, date.month, date.day, startHour, startMinute);
      final dayEndTime =
          DateTime(date.year, date.month, date.day, endHour, endMinute);
      const cooldown = Duration(minutes: 30);

      // If no personnel at all, generate all slots as FULL (High Demand)
      if (allPersonnel.isEmpty) {
        debugPrint('No available personnel — showing all slots as High Demand');
        while (currentTime.isBefore(dayEndTime)) {
          slots[currentTime] = 'FULL';
          currentTime = currentTime.add(const Duration(hours: 1));
        }
        return slots;
      }

      while (currentTime.isBefore(dayEndTime)) {
        final slotStart = currentTime;
        final slotEnd = currentTime.add(duration);
        int overlappingBookingsCount = 0;

        for (var bookingData in dayBookings) {
          if (bookingData['status'] == 'cancelled' ||
              bookingData['startTime'] == null ||
              bookingData['endTime'] == null) {
            continue;
          }

          final bStart = (bookingData['startTime'] as Timestamp).toDate();
          final bEnd = (bookingData['endTime'] as Timestamp).toDate();
          final effectiveEnd = bEnd.add(cooldown);

          if (slotStart.isBefore(effectiveEnd) && slotEnd.isAfter(bStart)) {
            overlappingBookingsCount++;
          }
        }

        final availableCount = allPersonnel.length - overlappingBookingsCount;
        final totalPersonnel = allPersonnel.length;

        if (availableCount <= 0) {
          slots[currentTime] = 'FULL';
        } else if (availableCount == 1 && totalPersonnel > 1) {
          slots[currentTime] = 'HIGH_DEMAND';
        } else if (availableCount <= totalPersonnel * 0.3) {
          slots[currentTime] = 'HIGH_DEMAND';
        } else {
          slots[currentTime] = 'AVAILABLE';
        }
        currentTime = currentTime.add(const Duration(hours: 1));
      }
    } catch (e) {
      debugPrint('Error calculating available slots: $e');
    }
    return slots;
  }

  Future<void> updateBookingPersonnel(
      String bookingId, String personnelId, String personnelName) async {
    debugPrint(
        '[BOOKING] updateBookingPersonnel — bookingId: $bookingId, personnelId: $personnelId');
    try {
      await _db.collection('bookings').doc(bookingId).update({
        'servicePersonnelId': personnelId,
        'servicePersonnelName': personnelName,
      });
      debugPrint('[BOOKING] updateBookingPersonnel — success');
    } catch (e) {
      debugPrint(
          '[BOOKING ERROR] updateBookingPersonnel failed: ${e.runtimeType}: $e');
      rethrow;
    }
  }

  Future<void> assignRandomPersonnel(String bookingId) async {
    try {
      debugPrint('[BOOKING] assignRandomPersonnel — bookingId: $bookingId');
      await _db.runTransaction((transaction) async {
        final bookingDocRef = _db.collection('bookings').doc(bookingId);
        final bookingDoc = await transaction.get(bookingDocRef);
        if (!bookingDoc.exists) {
          throw Exception('booking_not_found');
        }

        final bookingData = bookingDoc.data()!;
        if (bookingData['startTime'] == null ||
            bookingData['endTime'] == null) {
          throw Exception('booking_missing_timing');
        }

        // 1. Fetch available personnel directly inside the transaction
        List<ServicePersonnelModel> allPersonnel;
        try {
          final filteredQuery = await _db
              .collection('servicePersonnel')
              .where('isAvailable', isEqualTo: true)
              .where('isProfileComplete', isEqualTo: true)
              .where('isActive', isEqualTo: true)
              .get();
          allPersonnel = filteredQuery.docs
              .map((doc) => ServicePersonnelModel.fromFirestore(doc))
              .toList();
        } catch (_) {
          final fallbackQuery = await _db
              .collection('servicePersonnel')
              .where('isAvailable', isEqualTo: true)
              .get();
          allPersonnel = fallbackQuery.docs
              .map((doc) => ServicePersonnelModel.fromFirestore(doc))
              .where((p) => p.isActive && p.isProfileComplete)
              .toList();
        }

        if (allPersonnel.isEmpty) {
          throw Exception('no_caregivers_available');
        }

        // 2. Fetch conflicting bookings
        final startTime = (bookingData['startTime'] as Timestamp).toDate();
        final endTime = (bookingData['endTime'] as Timestamp).toDate();

        final startTimeOfDay =
            DateTime(startTime.year, startTime.month, startTime.day);
        final endTimeOfDay =
            DateTime(startTime.year, startTime.month, startTime.day + 1);

        final bookingsQuery = await _db
            .collection('bookings')
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startTimeOfDay))
            .where('date', isLessThan: Timestamp.fromDate(endTimeOfDay))
            .get();

        final conflictingPersonnelIds = <String>{};
        const cooldown = Duration(minutes: 30);

        for (var doc in bookingsQuery.docs) {
          final data = doc.data();
          if (data['servicePersonnelId'] == null ||
              data['status'] == 'cancelled') {
            continue;
          }

          final bStart = (data['startTime'] as Timestamp).toDate();
          final bEnd = (data['endTime'] as Timestamp).toDate();
          final effectiveEnd = bEnd.add(cooldown);

          if (startTime.isBefore(effectiveEnd) && endTime.isAfter(bStart)) {
            conflictingPersonnelIds.add(data['servicePersonnelId']);
          }
        }

        // 3. Filter available caregivers
        final availablePersonnel = allPersonnel
            .where((p) => !conflictingPersonnelIds.contains(p.id))
            .toList();

        if (availablePersonnel.isEmpty) {
          throw Exception('slot_taken');
        }

        // 4. Randomize and apply
        availablePersonnel.shuffle();
        final selected = availablePersonnel.first;

        transaction.update(bookingDocRef, {
          'servicePersonnelId': selected.id,
          'servicePersonnelName': selected.name,
        });
        debugPrint(
            '[BOOKING] assignRandomPersonnel — selected caregiver: ${selected.id}');
      });
      debugPrint('[BOOKING] assignRandomPersonnel — success');
    } catch (e) {
      debugPrint(
          '[BOOKING ERROR] assignRandomPersonnel failed: ${e.runtimeType}: $e');
      rethrow;
    }
  }

  // Personnel Specific Methods
  Stream<ServicePersonnelModel?> getPersonnelStream(String uid) {
    return _db.collection('servicePersonnel').doc(uid).snapshots().map(
        (doc) => doc.exists ? ServicePersonnelModel.fromFirestore(doc) : null);
  }

  Future<void> updatePersonnelStatus(String uid, bool isOnline) async {
    await _db
        .collection('servicePersonnel')
        .doc(uid)
        .update({'isOnline': isOnline});
  }

  Future<void> createServicePersonnel(ServicePersonnelModel personnel) async {
    await _db
        .collection('servicePersonnel')
        .doc(personnel.id)
        .set(personnel.toMap(), SetOptions(merge: true));
  }

  Future<void> updateServicePersonnel(
      String uid, Map<String, dynamic> data) async {
    await _db.collection('servicePersonnel').doc(uid).update(data);
  }

  Stream<List<BookingModel>> getPersonnelBookings(String personnelId) {
    return _db
        .collection('bookings')
        .where('servicePersonnelId', isEqualTo: personnelId)
        .limit(_personnelBookingsScanLimit)
        .snapshots()
        .map((snapshot) {
      final bookings =
          snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
      final sorted = _sortBookingsBySchedule(bookings, descending: true);
      return sorted.take(50).toList();
    });
  }

  Future<List<BookingModel>> getPersonnelBookingsByStatus(
      String personnelId, List<String> statuses) async {
    if (statuses.isEmpty) return [];

    final normalizedStatuses = _normalizeStatuses(statuses);
    final snapshot = await _db
        .collection('bookings')
        .where('servicePersonnelId', isEqualTo: personnelId)
        .limit(_personnelBookingsScanLimit)
        .get();

    final filtered = snapshot.docs
        .map((doc) => BookingModel.fromFirestore(doc))
        .where((booking) => _matchesStatus(booking, normalizedStatuses));

    final sorted = _sortBookingsBySchedule(filtered, descending: true);
    return sorted.take(30).toList();
  }

  Future<PaginatedBookingsResult> getPersonnelBookingsByStatusPage(
    String personnelId,
    List<String> statuses, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
    bool descendingByDate = true,
  }) async {
    if (statuses.isEmpty) {
      return const PaginatedBookingsResult(
        bookings: [],
        lastDocument: null,
        hasMore: false,
      );
    }

    final normalizedStatuses = _normalizeStatuses(statuses);
    final snapshot = await _db
        .collection('bookings')
        .where('servicePersonnelId', isEqualTo: personnelId)
        .limit(_personnelBookingsScanLimit)
        .get();

    final docsById = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      docsById[doc.id] = doc;
    }

    final filtered = snapshot.docs
        .map((doc) => BookingModel.fromFirestore(doc))
        .where((booking) => _matchesStatus(booking, normalizedStatuses));

    final sorted =
        _sortBookingsBySchedule(filtered, descending: descendingByDate);

    var startIndex = 0;
    if (startAfter != null) {
      final previousIndex = sorted.indexWhere((b) => b.id == startAfter.id);
      if (previousIndex >= 0) {
        startIndex = previousIndex + 1;
      }
    }

    final pageBookings = sorted.skip(startIndex).take(limit).toList();
    final hasMore = startIndex + pageBookings.length < sorted.length;

    DocumentSnapshot<Map<String, dynamic>>? lastDocument;
    if (pageBookings.isNotEmpty) {
      lastDocument = docsById[pageBookings.last.id];
    }

    return PaginatedBookingsResult(
      bookings: pageBookings,
      lastDocument: lastDocument,
      hasMore: hasMore,
    );
  }

  Stream<List<BookingModel>> getPersonnelBookingsByStatusStream(
      String personnelId, List<String> statuses) {
    if (statuses.isEmpty) {
      return Stream<List<BookingModel>>.value(const []);
    }

    final normalizedStatuses = _normalizeStatuses(statuses);

    return _db
        .collection('bookings')
        .where('servicePersonnelId', isEqualTo: personnelId)
        .limit(_personnelBookingsScanLimit)
        .snapshots()
        .map((snapshot) {
      final filtered = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .where((booking) => _matchesStatus(booking, normalizedStatuses));
      final sorted = _sortBookingsBySchedule(filtered, descending: true);
      return sorted.take(30).toList();
    });
  }

  Future<bool> verifyBookingOtp(String bookingId, String otp) async {
    final doc = await _db.collection('bookings').doc(bookingId).get();
    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>;
    if (data['completionOtp'] == otp) {
      final Timestamp? generatedAt = data['otpGeneratedAt'];
      if (generatedAt != null) {
        final generatedTime = generatedAt.toDate();
        final diff = DateTime.now().difference(generatedTime).inMinutes;
        if (diff >= 5) {
          throw Exception('expired');
        }
      }

      await _db.collection('bookings').doc(bookingId).update({
        'status': 'completed',
        'isVerifiedComplete': true,
      });

      final personnelId = data['servicePersonnelId'];
      if (personnelId != null) {
        await _db.collection('servicePersonnel').doc(personnelId).update({
          'visitsCompleted': FieldValue.increment(1),
        });
      }
      return true;
    }
    return false;
  }

  Future<void> startBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'in_progress',
      'isVerifiedStart': true,
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _generateSecureOtp() {
    final rng = Random.secure();
    return (1000 + rng.nextInt(9000)).toString();
  }

  Future<void> regenerateOtp(String bookingId) async {
    final newOtp = _generateSecureOtp();
    await _db.collection('bookings').doc(bookingId).update({
      'completionOtp': newOtp,
      'otpGeneratedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestBookingCompletion(String bookingId) async {
    await _db
        .collection('bookings')
        .doc(bookingId)
        .update({'status': 'completion_requested'});
  }

  Future<void> submitReview(
      String personnelId, Map<String, dynamic> review) async {
    await _db.collection('servicePersonnel').doc(personnelId).update({
      'reviews': FieldValue.arrayUnion([review]),
    });
  }

  Future<void> submitBookingReview({
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'submitBookingReview',
    );
    await callable.call({
      'bookingId': bookingId,
      'rating': rating,
      'comment': (comment ?? '').trim(),
    });
  }
}
