import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';
import '../models/service_personnel_model.dart';
import '../firebase/firestore_service.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(FirestoreService());
});

class BookingRepository {
  final FirestoreService _firestoreService;

  BookingRepository(this._firestoreService);

  Future<void> createBooking(BookingModel booking) =>
      _firestoreService.createBooking(booking);

  Future<double> fetchLiveServicePrice({
    required String serviceId,
    required String duration,
    required double fallbackPrice,
  }) =>
      _firestoreService.fetchLiveServicePrice(
        serviceId: serviceId,
        duration: duration,
        fallbackPrice: fallbackPrice,
      );

  DocumentReference dbGetBookingReference(String id) =>
      _firestoreService.dbGetBookingReference(id);

  Stream<BookingModel?> getBookingStream(String id) =>
      _firestoreService.getBookingStream(id);

  Stream<List<BookingModel>> getUserBookings(String uid) =>
      _firestoreService.getUserBookings(uid);

  Future<PaginatedBookingsResult> getUserBookingsPage(
    String uid, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) =>
      _firestoreService.getUserBookingsPage(
        uid,
        startAfter: startAfter,
        limit: limit,
      );

  Future<void> cancelBooking(String bookingId) =>
      _firestoreService.cancelBooking(bookingId);

  Future<void> updateBookingPersonnel(
          String bookingId, String personnelId, String personnelName) =>
      _firestoreService.updateBookingPersonnel(
          bookingId, personnelId, personnelName);

  Future<void> assignRandomPersonnel(String bookingId) =>
      _firestoreService.assignRandomPersonnel(bookingId);

  Future<List<ServicePersonnelModel>> getServicePersonnel({
    DateTime? startTime,
    DateTime? endTime,
  }) =>
      _firestoreService.getServicePersonnel(
          startTime: startTime, endTime: endTime);

  Future<Map<DateTime, String>> getAvailableSlots(
          DateTime date, Duration duration) =>
      _firestoreService.getAvailableSlots(date, duration);

  Stream<List<BookingModel>> getPersonnelBookings(String personnelId) =>
      _firestoreService.getPersonnelBookings(personnelId);

  Future<List<BookingModel>> getPersonnelBookingsByStatus(
          String personnelId, List<String> statuses) =>
      _firestoreService.getPersonnelBookingsByStatus(personnelId, statuses);

  Future<PaginatedBookingsResult> getPersonnelBookingsByStatusPage(
    String personnelId,
    List<String> statuses, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
    bool descendingByDate = true,
  }) =>
      _firestoreService.getPersonnelBookingsByStatusPage(
        personnelId,
        statuses,
        startAfter: startAfter,
        limit: limit,
        descendingByDate: descendingByDate,
      );

  Stream<List<BookingModel>> getPersonnelBookingsByStatusStream(
          String personnelId, List<String> statuses) =>
      _firestoreService.getPersonnelBookingsByStatusStream(
          personnelId, statuses);

  Future<bool> verifyBookingOtp(String bookingId, String otp) =>
      _firestoreService.verifyBookingOtp(bookingId, otp);

  Future<void> startBooking(String bookingId) =>
      _firestoreService.startBooking(bookingId);

  Future<void> requestBookingCompletion(String bookingId) =>
      _firestoreService.requestBookingCompletion(bookingId);

  Future<void> submitReview(String personnelId, Map<String, dynamic> review) =>
      _firestoreService.submitReview(personnelId, review);

  Future<void> submitBookingReview({
    required String bookingId,
    required double rating,
    String? comment,
  }) =>
      _firestoreService.submitBookingReview(
        bookingId: bookingId,
        rating: rating,
        comment: comment,
      );
}
