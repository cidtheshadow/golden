import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SlotStatus { available, highDemand }

class SlotAvailability {
  final String time; // e.g. "09:00"
  final SlotStatus status;
  final int availableCount;
  final int totalCaregivers;

  const SlotAvailability({
    required this.time,
    required this.status,
    required this.availableCount,
    required this.totalCaregivers,
  });
}

// All fixed time slots for a day (08:00–20:00)
const List<String> kDaySlots = [
  '08:00',
  '09:00',
  '10:00',
  '11:00',
  '12:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
  '18:00',
  '19:00',
  '20:00',
];

const Duration _istOffset = Duration(hours: 5, minutes: 30);

DateTime _toIst(DateTime value) => value.toUtc().add(_istOffset);

bool _isSameIstDate(DateTime a, DateTime b) {
  final aIst = _toIst(a);
  final bIst = _toIst(b);
  return aIst.year == bIst.year &&
      aIst.month == bIst.month &&
      aIst.day == bIst.day;
}

int _ceilHour(DateTime value) {
  if (value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0) {
    return value.hour;
  }
  return value.hour + 1;
}

/// Provider parameter: date + duration (duration needed for overlap calc)
typedef _SlotParams = ({DateTime date, Duration duration});

/// Computes slot availability for a given date and service duration.
///
/// Uses the real collections from this codebase:
///   - `servicePersonnel`  (isAvailable == true)
///   - `bookings`          (date Timestamp range, startTime/endTime Timestamps)
final slotAvailabilityProvider =
    FutureProvider.family<List<SlotAvailability>, _SlotParams>(
        (ref, params) async {
  final db = FirebaseFirestore.instance;
  final date = params.date;
  final duration = params.duration;
  const cooldown = Duration(minutes: 30);

  final now = DateTime.now();
  final isTodayInIst = _isSameIstDate(date, now);
  final cutoffHour = _ceilHour(_toIst(now).add(const Duration(minutes: 45)));

  final visibleSlots = kDaySlots.where((timeStr) {
    if (!isTodayInIst) return true;
    if (cutoffHour > 23) return false;
    final hour = int.parse(timeStr.split(':').first);
    return hour >= cutoffHour;
  }).toList();

  // --- 1. Count active caregivers ---
  final personnelSnap = await db
      .collection('servicePersonnel')
      .where('isAvailable', isEqualTo: true)
      .get();
  final totalCaregivers = personnelSnap.docs.length;

  debugPrint('[SlotAvailability] totalCaregivers=$totalCaregivers');

  if (totalCaregivers == 0) {
    return visibleSlots
        .map((time) => SlotAvailability(
              time: time,
              status: SlotStatus.highDemand,
              availableCount: 0,
              totalCaregivers: 0,
            ))
        .toList();
  }

  // --- 2. Fetch all bookings for this date ---
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = DateTime(date.year, date.month, date.day + 1);

  final bookingsSnap = await db
      .collection('bookings')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('date', isLessThan: Timestamp.fromDate(endOfDay))
      .get();

  final dayBookings = bookingsSnap.docs.map((d) => d.data()).toList();
  debugPrint('[SlotAvailability] bookings on date: ${dayBookings.length}');

  // --- 3. Build availability for each slot ---
  return visibleSlots.map((timeStr) {
    final parts = timeStr.split(':');
    final slotStart = DateTime(date.year, date.month, date.day,
        int.parse(parts[0]), int.parse(parts[1]));
    final slotEnd = slotStart.add(duration);

    int overlapping = 0;
    for (final data in dayBookings) {
      final status = data['status'] as String? ?? '';
      if (status == 'cancelled') continue;

      final rawStart = data['startTime'];
      final rawEnd = data['endTime'];
      if (rawStart == null || rawEnd == null) continue;

      final bStart = (rawStart as Timestamp).toDate();
      final bEnd = (rawEnd as Timestamp).toDate();
      final effectiveEnd = bEnd.add(cooldown);

      if (slotStart.isBefore(effectiveEnd) && slotEnd.isAfter(bStart)) {
        overlapping++;
      }
    }

    final available = (totalCaregivers - overlapping).clamp(0, totalCaregivers);

    final slotStatus =
        available > 0 ? SlotStatus.available : SlotStatus.highDemand;

    return SlotAvailability(
      time: timeStr,
      status: slotStatus,
      availableCount: available,
      totalCaregivers: totalCaregivers,
    );
  }).toList();
});
