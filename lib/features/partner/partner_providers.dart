import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/service_personnel_model.dart';
import '../../models/booking_model.dart';
import '../../repositories/service_personnel_repository.dart';
import '../../repositories/booking_repository.dart';
import '../auth/auth_controller.dart';

/// Streams the current user's ServicePersonnel record (null if not registered).
final currentPersonnelProvider = StreamProvider<ServicePersonnelModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(servicePersonnelRepositoryProvider).getPersonnelStream(authUser.uid);
});

/// Family-parameterised future provider for fetching bookings by status list.
final personnelBookingsByStatusProvider =
    FutureProvider.family<List<BookingModel>, List<String>>((ref, statuses) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return [];
  return ref.watch(bookingRepositoryProvider).getPersonnelBookingsByStatus(authUser.uid, statuses);
});
