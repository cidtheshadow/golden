/// Post-login dashboard — role-aware view for family / caregiver / admin.
/// family  → quick actions + upcoming bookings
/// caregiver → assigned bookings + online status
/// admin   → summary stats (bookings, pending)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../core/widgets/gc_button.dart';
import '../../models/booking_model.dart';
import '../auth/auth_controller.dart';
import '../../repositories/booking_repository.dart';
import '../../firebase/firestore_service.dart';

/// Stream of the current user's bookings
final userBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value([]);
  return ref.watch(bookingRepositoryProvider).getUserBookings(authUser.uid);
});

/// Stream of assignments where the caregiver IS the service personnel
final caregiverAssignmentsProvider = StreamProvider<List<BookingModel>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value([]);
  return ref
      .watch(bookingRepositoryProvider)
      .getPersonnelBookings(authUser.uid);
});

/// Count of all bookings — used by admin view
final allBookingsCountProvider = FutureProvider<int>((ref) async {
  return FirestoreService().getAllBookingsCount();
});

/// Count of pending/upcoming bookings — used by admin view
final pendingBookingsCountProvider = FutureProvider<int>((ref) async {
  return FirestoreService().getPendingBookingsCount();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userModelProvider);

    final userName = userAsync.when(
      data: (user) => user?.name ?? 'User',
      loading: () => 'User',
      error: (_, __) => 'User',
    );
    final role = userAsync.when(
      data: (user) => user?.role ?? 'family',
      loading: () => 'family',
      error: (_, __) => 'family',
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GCSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Navigation & Greeting ─────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Landing Screen',
                  onPressed: () => context.go('/'),
                ),
              ),
              Text('Welcome back, $userName!',
                  style: GCTypography.displaySmall),
              const SizedBox(height: 4),
              _roleSubtitle(role),
              const SizedBox(height: 24),

              // ── Role-specific content ─────────────────────
              if (role == 'family') _FamilyView(),
              if (role == 'caregiver') _CaregiverView(),
              if (role == 'admin') _AdminView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleSubtitle(String role) {
    final texts = {
      'family': "Here's what's happening with your care.",
      'caregiver': "Here are your upcoming care assignments.",
      'admin': "Here's an overview of the platform.",
    };
    return Text(
      texts[role] ?? "Here's your dashboard.",
      style: GCTypography.bodyLarge,
    );
  }
}

// ─────────────────────────────────────────────
// FAMILY DASHBOARD
// ─────────────────────────────────────────────
class _FamilyView extends ConsumerWidget {
  DateTime _scheduledDateTime(BookingModel booking) {
    final rawTime = booking.time;
    if (rawTime == null || rawTime.isEmpty) return booking.date;
    try {
      final parsed = DateFormat('hh:mm a').parse(rawTime);
      return DateTime(
        booking.date.year,
        booking.date.month,
        booking.date.day,
        parsed.hour,
        parsed.minute,
      );
    } catch (_) {
      return booking.date;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick actions grid
        Text('Quick Actions', style: GCTypography.headlineMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: _quickActionCols(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _actionCard(context, Icons.add_circle_outline, 'Book Care',
                GCColors.primary, () => context.push('/book')),
            _actionCard(context, Icons.people, 'Find Caregivers',
                GCColors.accent, () => context.push('/caregivers')),
            _actionCard(context, Icons.calendar_today, 'My Bookings',
                GCColors.goldDark, () => context.push('/bookings')),
            _actionCard(context, Icons.person, 'My Profile',
                GCColors.mutedForeground, () => context.go('/profile')),
          ],
        ),
        const SizedBox(height: 32),

        // Upcoming bookings
        Text('Upcoming Bookings', style: GCTypography.headlineMedium),
        const SizedBox(height: 12),
        bookingsAsync.when(
          data: (bookings) {
            final upcoming = bookings
                .where((b) =>
                    b.status == 'upcoming' ||
                    b.status == 'confirmed' ||
                    b.status == 'in_progress' ||
                    b.status == 'completion_requested' ||
                    b.status == 'pending_payment')
                .toList()
              ..sort((a, b) =>
                  _scheduledDateTime(a).compareTo(_scheduledDateTime(b)));
            if (upcoming.isEmpty) return _emptyBookings(context);
            return Column(
              children: upcoming
                  .take(5)
                  .map((b) => _bookingCard(context, b))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error loading bookings: $e'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  int _quickActionCols(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 600) return 4;
    return 2;
  }
}

// ─────────────────────────────────────────────
// CAREGIVER DASHBOARD
// ─────────────────────────────────────────────
class _CaregiverView extends ConsumerWidget {
  DateTime _scheduledDateTime(BookingModel booking) {
    final rawTime = booking.time;
    if (rawTime == null || rawTime.isEmpty) return booking.date;
    try {
      final parsed = DateFormat('hh:mm a').parse(rawTime);
      return DateTime(
        booking.date.year,
        booking.date.month,
        booking.date.day,
        parsed.hour,
        parsed.minute,
      );
    } catch (_) {
      return booking.date;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(caregiverAssignmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(GCSpacing.cardPadding),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GCColors.accent.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.work_outline,
                      color: GCColors.accent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Caregiver Dashboard',
                          style: GCTypography.headlineSmall),
                      Text('Manage your assignments below.',
                          style: GCTypography.bodyMedium),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: GCColors.accent.withAlpha(26),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: GCColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Quick actions
        Text('Quick Actions', style: GCTypography.headlineMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: _quickActionCols(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _actionCard(context, Icons.calendar_today, 'Assignments',
                GCColors.goldDark, () => context.push('/bookings')),
            _actionCard(context, Icons.person, 'My Profile',
                GCColors.mutedForeground, () => context.go('/profile')),
            _actionCard(context, Icons.help_outline, 'Support', GCColors.accent,
                () => context.push('/contact')),
          ],
        ),
        const SizedBox(height: 32),

        Text('My Assignments', style: GCTypography.headlineMedium),
        const SizedBox(height: 12),
        assignmentsAsync.when(
          data: (assignments) {
            final active = assignments
                .where((b) =>
                    b.status == 'upcoming' ||
                    b.status == 'confirmed' ||
                    b.status == 'in_progress' ||
                    b.status == 'completion_requested')
                .toList()
              ..sort((a, b) =>
                  _scheduledDateTime(a).compareTo(_scheduledDateTime(b)));
            if (active.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(GCSpacing.cardPadding),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 48, color: GCColors.accent),
                      const SizedBox(height: 12),
                      Text('No upcoming assignments',
                          style: GCTypography.headlineSmall),
                      const SizedBox(height: 4),
                      Text('You\'re all caught up!',
                          style: GCTypography.bodyMedium),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: active.map((b) => _bookingCard(context, b)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error loading assignments: $e'),
        ),
      ],
    );
  }

  int _quickActionCols(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 600) return 4;
    return 2;
  }
}

// ─────────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────────
class _AdminView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allBookingsCountProvider);
    final pendingAsync = ref.watch(pendingBookingsCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Platform Overview', style: GCTypography.headlineMedium),
        const SizedBox(height: 12),

        // Stats cards
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2,
          children: [
            _statCard(
              'Total Bookings',
              allAsync.when(
                  data: (n) => '$n', loading: () => '…', error: (_, __) => '—'),
              Icons.calendar_month_outlined,
              GCColors.primary,
              onTap: () => context.push('/bookings'),
            ),
            _statCard(
              'Pending / Upcoming',
              pendingAsync.when(
                  data: (n) => '$n', loading: () => '…', error: (_, __) => '—'),
              Icons.pending_actions_outlined,
              GCColors.goldDark,
              onTap: () => context.push('/bookings'),
            ),
            _statCard(
              'Manage Caregivers',
              'View All',
              Icons.manage_accounts_outlined,
              GCColors.accent,
              onTap: () => context.push('/caregivers'),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Admin quick actions
        Text('Admin Actions', style: GCTypography.headlineMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _actionCard(context, Icons.people, 'Caregivers', GCColors.accent,
                () => context.push('/caregivers')),
            _actionCard(context, Icons.person_add_outlined, 'Add Caregiver',
                GCColors.primary, () => context.push('/join-as-caregiver')),
            _actionCard(context, Icons.book_outlined, 'All Bookings',
                GCColors.goldDark, () => context.push('/bookings')),
            _actionCard(context, Icons.person, 'My Profile',
                GCColors.mutedForeground, () => context.go('/profile')),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GCSpacing.radiusLg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(GCSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(value,
                        style: GCTypography.statValue
                            .copyWith(fontSize: 22, color: color)),
                    Text(label, style: GCTypography.statLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────
Widget _emptyBookings(BuildContext context) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(GCSpacing.cardPadding),
      child: Column(
        children: [
          const Icon(Icons.calendar_today, size: 48, color: GCColors.muted),
          const SizedBox(height: 12),
          Text('No upcoming bookings', style: GCTypography.headlineSmall),
          const SizedBox(height: 4),
          Text('Book a care session to see it here.',
              style: GCTypography.bodyMedium),
          const SizedBox(height: 16),
          GCButton(
            label: 'Book Now',
            onPressed: () => context.push('/book'),
            variant: GCButtonVariant.primary,
          ),
        ],
      ),
    ),
  );
}

Widget _bookingCard(BuildContext context, BookingModel booking) {
  final dateStr = DateFormat('MMM dd, yyyy').format(booking.date);
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/booking-details/${booking.id}'),
      child: Padding(
        padding: const EdgeInsets.all(GCSpacing.cardPadding),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: GCColors.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medical_services_outlined,
                  color: GCColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.serviceName,
                      style: GCTypography.headlineSmall.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                      '$dateStr${booking.time != null ? ' at ${booking.time}' : ''}',
                      style: GCTypography.bodySmall),
                  if (booking.servicePersonnelName != null)
                    Text('Caregiver: ${booking.servicePersonnelName}',
                        style: GCTypography.bodySmall),
                ],
              ),
            ),
            _statusBadge(booking.status),
          ],
        ),
      ),
    ),
  );
}

Widget _statusBadge(String status) {
  final colors = {
    'upcoming': GCColors.primary,
    'confirmed': GCColors.accent,
    'pending_payment': const Color(0xFFB8860B),
    'in_progress': GCColors.goldDark,
    'completion_requested': GCColors.goldDark,
    'completed': GCColors.mutedForeground,
    'cancelled': GCColors.destructive,
  };
  final color = colors[status] ?? GCColors.primary;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(26),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      status.toUpperCase(),
      style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

Widget _actionCard(BuildContext context, IconData icon, String label,
    Color color, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(GCSpacing.radiusLg),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GCColors.foreground),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
