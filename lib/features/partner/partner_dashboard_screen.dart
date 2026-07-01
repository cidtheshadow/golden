import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../core/spacing.dart';
import '../../core/providers/availability_provider.dart';
import 'partner_providers.dart';

class PartnerDashboardScreen extends ConsumerWidget {
  const PartnerDashboardScreen({super.key});

  String _anonymousReviewer(Map<String, dynamic> review) {
    final raw = (review['userId'] ?? review['userName'] ?? 'guest').toString();
    final suffix = raw.isNotEmpty
        ? raw.codeUnits.fold<int>(0, (a, b) => (a + b) % 10000)
        : 0;
    return 'Family #${suffix.toString().padLeft(4, '0')}';
  }

  Widget _miniRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final icon = index < rating.floor()
            ? Icons.star
            : (index < rating ? Icons.star_half : Icons.star_border);
        return Icon(icon, size: 14, color: GCColors.goldDark);
      }),
    );
  }

  DateTime _scheduledDateTime(booking) {
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

  Widget _statusBadge(String status) {
    final colors = {
      'upcoming': GCColors.primary,
      'confirmed': GCColors.primary,
      'pending_payment': const Color(0xFFB8860B),
      'in_progress': GCColors.goldDark,
      'completion_requested': GCColors.goldDark,
      'completed': GCColors.accent,
      'cancelled': GCColors.destructive,
    };
    final color = colors[status.toLowerCase()] ?? GCColors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personnelAsync = ref.watch(currentPersonnelProvider);
    final availabilityState = ref.watch(availabilityProvider);
    final upcomingBookingsAsync = ref.watch(
      personnelBookingsByStatusProvider(
        const [
          'confirmed',
          'in_progress',
          'completion_requested',
          'pending_payment'
        ],
      ),
    );

    return personnelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (personnel) {
        if (personnel == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(GCSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Welcome & Stats ────────────────────────
                  Text(
                    'Welcome back, ${personnel.name.split(' ').first}!',
                    style: GCTypography.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Rating',
                          value: personnel.rating.toStringAsFixed(1),
                          icon: Icons.star,
                          color: GCColors.goldDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('bookings')
                              .where('servicePersonnelId',
                                  isEqualTo: personnel.id)
                              .where('status', isEqualTo: 'completed')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final completedFromBookings =
                                snapshot.data?.docs.length ?? 0;
                            final completedCount = completedFromBookings >
                                    personnel.visitsCompleted
                                ? completedFromBookings
                                : personnel.visitsCompleted;
                            return _StatCard(
                              title: 'Completed',
                              value: completedCount.toString(),
                              icon: Icons.check_circle_outline,
                              color: GCColors.primary,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Available For Booking Today',
                                  style: GCTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              availabilityState.isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Switch(
                                      value: availabilityState.isAvailable,
                                      onChanged: (value) => ref
                                          .read(availabilityProvider.notifier)
                                          .toggleAvailability(value),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Turns off bookings only for today and resets tomorrow.',
                            style: GCTypography.bodySmall.copyWith(
                              color: GCColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Performance Snapshot',
                              style: GCTypography.headlineSmall),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _TinyStat(
                                label: 'Avg Rating',
                                value: personnel.rating.toStringAsFixed(1),
                                icon: Icons.star_rounded,
                              ),
                              _TinyStat(
                                label: 'Total Reviews',
                                value: personnel.reviews.length.toString(),
                                icon: Icons.reviews_rounded,
                              ),
                              _TinyStat(
                                label: 'Experience',
                                value: '${personnel.experienceYears} yrs',
                                icon: Icons.workspace_premium_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('Anonymous Feedback',
                              style: GCTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 8),
                          if (personnel.reviews.isEmpty)
                            Text(
                              'No reviews yet. Complete a few sessions to build your feedback profile.',
                              style: GCTypography.bodySmall
                                  .copyWith(color: GCColors.mutedForeground),
                            )
                          else
                            Column(
                              children: personnel.reviews.reversed
                                  .take(3)
                                  .map((r) => Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F8F8),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: GCColors.border),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _anonymousReviewer(r),
                                                    style: GCTypography
                                                        .bodySmall
                                                        .copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    (r['comment'] ??
                                                            'Good service')
                                                        .toString(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        GCTypography.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _miniRating(
                                              (r['rating'] as num?)
                                                      ?.toDouble() ??
                                                  5,
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_busy_outlined),
                      title: Text('Manage Availability',
                          style: GCTypography.bodyLarge),
                      subtitle: const Text(
                          'Set days and dates when you are unavailable'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/partner/availability'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Upcoming Tasks ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Upcoming Tasks', style: GCTypography.headlineSmall),
                      TextButton(
                        onPressed: () {
                          // This could navigate to the full bookings tab if needed
                          DefaultTabController.of(context).animateTo(1);
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  upcomingBookingsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading tasks: $e',
                          style: const TextStyle(color: Colors.red)),
                    ),
                    data: (bookings) {
                      if (bookings.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                const Icon(Icons.event_available,
                                    size: 64, color: GCColors.mutedForeground),
                                const SizedBox(height: 16),
                                Text(
                                  "You don't have any upcoming tasks yet.",
                                  style: GCTypography.bodyMedium.copyWith(
                                      color: GCColors.mutedForeground),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final sortedBookings = [...bookings]..sort((a, b) =>
                          _scheduledDateTime(a)
                              .compareTo(_scheduledDateTime(b)));

                      // Show top 3 upcoming tasks
                      final displayBookings = sortedBookings.take(3).toList();

                      return Column(
                        children: displayBookings
                            .map((b) => Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    onTap: () => context.push(
                                        '/partner/booking-details/${b.id}'),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          GCColors.primary.withAlpha(25),
                                      child: const Icon(
                                          Icons.medical_services_outlined,
                                          color: GCColors.primary),
                                    ),
                                    title: Text(b.serviceName,
                                        style: GCTypography.bodyLarge.copyWith(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.person,
                                                size: 14,
                                                color:
                                                    GCColors.mutedForeground),
                                            const SizedBox(width: 4),
                                            Text(b.userName ?? 'Unknown User',
                                                style: GCTypography.bodyMedium),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time,
                                                size: 14,
                                                color:
                                                    GCColors.mutedForeground),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${DateFormat('MMM d').format(b.date)} at ${b.time}',
                                              style: GCTypography.bodySmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        _statusBadge(b.status),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TinyStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TinyStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GCColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: GCColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GCTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(label,
                    style: GCTypography.bodySmall
                        .copyWith(color: GCColors.mutedForeground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GCSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: GCTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: GCTypography.bodyMedium.copyWith(
                color: GCColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
