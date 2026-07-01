import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AvailabilityState {
  final bool isLoading;
  final bool isSaving;
  final bool isAvailable;
  final List<String> unavailableDates;
  final List<int> unavailableWeekdays;
  final List<String> bookedDates;
  final List<int> blockedWeekdays;
  final String todayKey;
  final String? error;

  const AvailabilityState({
    this.isLoading = false,
    this.isSaving = false,
    this.isAvailable = true,
    this.unavailableDates = const [],
    this.unavailableWeekdays = const [],
    this.bookedDates = const [],
    this.blockedWeekdays = const [],
    this.todayKey = '',
    this.error,
  });

  AvailabilityState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isAvailable,
    List<String>? unavailableDates,
    List<int>? unavailableWeekdays,
    List<String>? bookedDates,
    List<int>? blockedWeekdays,
    String? todayKey,
    String? error,
  }) {
    return AvailabilityState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isAvailable: isAvailable ?? this.isAvailable,
      unavailableDates: unavailableDates ?? this.unavailableDates,
      unavailableWeekdays: unavailableWeekdays ?? this.unavailableWeekdays,
      bookedDates: bookedDates ?? this.bookedDates,
      blockedWeekdays: blockedWeekdays ?? this.blockedWeekdays,
      todayKey: todayKey ?? this.todayKey,
      error: error,
    );
  }
}

class AvailabilityNotifier extends StateNotifier<AvailabilityState> {
  AvailabilityNotifier() : super(const AvailabilityState()) {
    load();
  }

  DocumentReference<Map<String, dynamic>> _usersRef(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _personnelRef(String uid) {
    return FirebaseFirestore.instance.collection('servicePersonnel').doc(uid);
  }

  Future<void> _setAvailabilityFields(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.set(_personnelRef(uid), data, SetOptions(merge: true));
    batch.set(_usersRef(uid), data, SetOptions(merge: true));
    await batch.commit();
  }

  static const _activeBookingStatuses = {
    'upcoming',
    'confirmed',
    'in_progress',
    'completion_requested',
    'pending_payment',
  };

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _istNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final snapshots = await Future.wait([
        _personnelRef(uid).get(),
        _usersRef(uid).get(),
      ]);
      final personnelDoc = snapshots[0];
      final userDoc = snapshots[1];

      if (!personnelDoc.exists && !userDoc.exists) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final nowIst = _istNow();
      final todayStr = _formatDateKey(nowIst);

      final personnelData = personnelDoc.data() ?? <String, dynamic>{};
      final userData = userDoc.data() ?? <String, dynamic>{};

      dynamic pick(String key) {
        if (personnelData.containsKey(key)) {
          return personnelData[key];
        }
        return userData[key];
      }

      final unavailableDates =
          List<String>.from((pick('unavailableDates') as List?) ?? const []);
      final unavailableWeekdays =
          List<int>.from((pick('unavailableWeekdays') as List?) ?? const []);
      final isAvailableStored = (pick('isAvailable') as bool?) ?? true;
      final overrideDate = (pick('isAvailableOverrideDate') as String?)?.trim();

      final needsAutoReset = !isAvailableStored &&
          overrideDate != null &&
          overrideDate != todayStr;

      // Future active bookings block those dates/weekdays from being set unavailable.
      QuerySnapshot<Map<String, dynamic>> bookingSnap;
      try {
        bookingSnap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('servicePersonnelId', isEqualTo: uid)
            .orderBy('date', descending: true)
            .limit(400)
            .get();
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition') {
          rethrow;
        }
        bookingSnap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('servicePersonnelId', isEqualTo: uid)
            .limit(400)
            .get();
      }

      final bookedDateSet = <String>{};
      for (final d in bookingSnap.docs) {
        final b = d.data();
        final status = (b['status'] as String? ?? '').toLowerCase();
        if (!_activeBookingStatuses.contains(status)) {
          continue;
        }
        final ts = b['date'];
        if (ts is! Timestamp) continue;
        final dt =
            ts.toDate().toUtc().add(const Duration(hours: 5, minutes: 30));
        final dateKey = _formatDateKey(dt);
        if (dateKey.compareTo(todayStr) < 0) {
          continue;
        }
        bookedDateSet.add(dateKey);
      }

      final blockedWeekdays = bookedDateSet
          .map((d) => DateTime.parse(d).weekday % 7)
          .toSet()
          .toList()
        ..sort();

      final isAvailableToday = !unavailableDates.contains(todayStr) &&
          (isAvailableStored || overrideDate != todayStr);

      if (needsAutoReset) {
        await _setAvailabilityFields(uid, {
          'isAvailable': true,
          'isAvailableOverrideDate': null,
        });
      }

      state = state.copyWith(
        isLoading: false,
        isAvailable: isAvailableToday,
        unavailableDates: unavailableDates,
        unavailableWeekdays: unavailableWeekdays,
        bookedDates: bookedDateSet.toList()..sort(),
        blockedWeekdays: blockedWeekdays,
        todayKey: todayStr,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleAvailability(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (!value && state.bookedDates.contains(state.todayKey)) {
      state = state.copyWith(
        error:
            'You already have a booking today, so availability cannot be turned off for today.',
      );
      return;
    }

    final updatedDates = List<String>.from(state.unavailableDates);
    if (value) {
      updatedDates.remove(state.todayKey);
    } else if (!updatedDates.contains(state.todayKey)) {
      updatedDates.add(state.todayKey);
      updatedDates.sort();
    }

    state = state.copyWith(isAvailable: value, isSaving: true, error: null);

    try {
      await _setAvailabilityFields(uid, {
        'isAvailable': value,
        'isAvailableOverrideDate': value ? null : state.todayKey,
        'unavailableDates': updatedDates,
      });

      state = state.copyWith(
        isSaving: false,
        unavailableDates: updatedDates,
      );
    } catch (e) {
      state = state.copyWith(
          isAvailable: !value, isSaving: false, error: e.toString());
    }
  }

  Future<void> toggleUnavailableDate(String date) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updated = List<String>.from(state.unavailableDates);
    final isRemoving = updated.contains(date);

    if (!isRemoving && state.bookedDates.contains(date)) {
      state = state.copyWith(
        error:
            'You already have a booking on $date, so that date cannot be marked unavailable.',
      );
      return;
    }

    if (isRemoving) {
      updated.remove(date);
    } else {
      updated.add(date);
      updated.sort();
    }

    state =
        state.copyWith(unavailableDates: updated, isSaving: true, error: null);

    try {
      final togglesToday = date == state.todayKey;
      final availableToday = togglesToday ? isRemoving : state.isAvailable;

      await _setAvailabilityFields(uid, {
        'unavailableDates': updated,
        if (togglesToday) 'isAvailable': availableToday,
        if (togglesToday)
          'isAvailableOverrideDate': availableToday ? null : state.todayKey,
      });

      state = state.copyWith(
        isSaving: false,
        isAvailable: availableToday,
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> toggleUnavailableWeekday(int weekday) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updated = List<int>.from(state.unavailableWeekdays);
    final isRemoving = updated.contains(weekday);

    if (!isRemoving && state.blockedWeekdays.contains(weekday)) {
      state = state.copyWith(
        error:
            'You already have upcoming bookings on this weekday. Remove those bookings first or set specific future dates instead.',
      );
      return;
    }

    if (isRemoving) {
      updated.remove(weekday);
    } else {
      updated.add(weekday);
      updated.sort();
    }

    state = state.copyWith(
        unavailableWeekdays: updated, isSaving: true, error: null);

    try {
      await _setAvailabilityFields(uid, {
        'unavailableWeekdays': updated,
      });

      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }
}

final availabilityProvider =
    StateNotifierProvider.autoDispose<AvailabilityNotifier, AvailabilityState>(
  (ref) => AvailabilityNotifier(),
);
