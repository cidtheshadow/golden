import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../core/spacing.dart';
import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../auth/auth_controller.dart';

class PartnerBookingsScreen extends ConsumerWidget {
  const PartnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) {
      return const Center(child: Text('Please log in'));
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: GCColors.card,
            child: const TabBar(
              labelColor: GCColors.primary,
              unselectedLabelColor: GCColors.mutedForeground,
              indicatorColor: GCColors.primary,
              tabs: [
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BookingListByStatus(
                  personnelId: authUser.uid,
                  statuses: const [
                    'confirmed',
                    'pending_payment',
                    'in_progress',
                    'completion_requested'
                  ],
                ),
                _BookingListByStatus(
                  personnelId: authUser.uid,
                  statuses: const ['completed'],
                ),
                _BookingListByStatus(
                  personnelId: authUser.uid,
                  statuses: const ['cancelled'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingListByStatus extends ConsumerStatefulWidget {
  final String personnelId;
  final List<String> statuses;

  const _BookingListByStatus({
    required this.personnelId,
    required this.statuses,
  });

  @override
  ConsumerState<_BookingListByStatus> createState() =>
      _BookingListByStatusState();
}

class _BookingListByStatusState extends ConsumerState<_BookingListByStatus> {
  static const int _pageSize = 12;

  final ScrollController _scrollController = ScrollController();
  final List<BookingModel> _bookings = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialPage();
  }

  @override
  void didUpdateWidget(covariant _BookingListByStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personnelId != widget.personnelId ||
        oldWidget.statuses.join(',') != widget.statuses.join(',')) {
      _loadInitialPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isUpcomingLikeStatus(String status) {
    const upcomingLike = {
      'upcoming',
      'confirmed',
      'pending_payment',
      'in_progress',
      'completion_requested',
    };
    return upcomingLike.contains(status.toLowerCase());
  }

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

  Future<void> _loadInitialPage() async {
    if (!mounted) return;

    setState(() {
      _bookings.clear();
      _lastDocument = null;
      _hasMore = true;
      _isInitialLoading = true;
      _isLoadingMore = false;
      _error = null;
    });

    try {
      final isUpcomingTab =
          widget.statuses.any((status) => _isUpcomingLikeStatus(status));

      final page = await ref
          .read(bookingRepositoryProvider)
          .getPersonnelBookingsByStatusPage(
            widget.personnelId,
            widget.statuses,
            limit: _pageSize,
            descendingByDate: !isUpcomingTab,
          );

      if (!mounted) return;

      setState(() {
        _bookings.addAll(page.bookings);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final isUpcomingTab =
          widget.statuses.any((status) => _isUpcomingLikeStatus(status));

      final page = await ref
          .read(bookingRepositoryProvider)
          .getPersonnelBookingsByStatusPage(
            widget.personnelId,
            widget.statuses,
            startAfter: _lastDocument,
            limit: _pageSize,
            descendingByDate: !isUpcomingTab,
          );

      if (!mounted) return;

      setState(() {
        _bookings.addAll(page.bookings);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent * 0.85;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  List<BookingModel> _sortedBookings() {
    final isUpcomingTab =
        widget.statuses.any((status) => _isUpcomingLikeStatus(status));
    final sorted = [..._bookings];
    sorted.sort((a, b) {
      final aSchedule = _scheduledDateTime(a);
      final bSchedule = _scheduledDateTime(b);
      if (isUpcomingTab) {
        return aSchedule.compareTo(bSchedule);
      }
      return bSchedule.compareTo(aSchedule);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(GCSpacing.md),
        itemCount: 5,
        itemBuilder: (_, __) => const _PartnerBookingSkeletonCard(),
      );
    }

    if (_error != null && _bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: GCColors.destructive),
            const SizedBox(height: 10),
            Text(
              'Unable to load bookings.',
              style: GCTypography.bodyMedium,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadInitialPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 48, color: GCColors.muted),
            const SizedBox(height: 12),
            Text('No bookings', style: GCTypography.headlineSmall),
            const SizedBox(height: 4),
            Text('Nothing to show here.', style: GCTypography.bodyMedium),
          ],
        ),
      );
    }

    final sortedBookings = _sortedBookings();

    return RefreshIndicator(
      onRefresh: _loadInitialPage,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(GCSpacing.md),
        itemCount: sortedBookings.length + (_hasMore || _isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= sortedBookings.length) {
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return Center(
              child: TextButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more bookings'),
              ),
            );
          }

          final booking = sortedBookings[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  context.push('/partner/booking-details/${booking.id}'),
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
                              style: GCTypography.headlineSmall
                                  .copyWith(fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('MMM d, yyyy').format(booking.date)}${booking.time != null ? ' • ${booking.time}' : ''}',
                            style: GCTypography.bodySmall,
                          ),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(booking.userId)
                                .snapshots(),
                            builder: (context, userSnap) {
                              final phone =
                                  userSnap.data?.data()?['phone'] as String? ??
                                      '';
                              if (phone.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: phone));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Number copied'),
                                              duration: Duration(seconds: 1),
                                              backgroundColor:
                                                  Color(0xFFB8860B),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 14),
                                        label: Text(
                                          phone,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF1A1A1A),
                                          side: BorderSide(
                                              color: Colors.grey.shade300),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                    ),
                                    if (!kIsWeb) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () async {
                                          final uri =
                                              Uri(scheme: 'tel', path: phone);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.call_rounded,
                                          color: Color(0xFF2E7D32),
                                        ),
                                        tooltip: 'Call customer',
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(booking.status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _statusBadge(String status) {
  final colors = {
    'upcoming': GCColors.primary,
    'confirmed': GCColors.primary,
    'in_progress': GCColors.goldDark,
    'completion_requested': GCColors.goldDark,
    'completed': GCColors.accent,
    'cancelled': GCColors.destructive,
  };
  final color = colors[status.toLowerCase()] ?? GCColors.primary;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(26),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      status.toUpperCase(),
      style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _PartnerBookingSkeletonCard extends StatelessWidget {
  const _PartnerBookingSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(GCSpacing.cardPadding),
        child: Row(
          children: [
            Container(width: 48, height: 48, color: GCColors.muted),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 150, color: GCColors.muted),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 210, color: GCColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
