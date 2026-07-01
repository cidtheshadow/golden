import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../auth/auth_controller.dart';
import '../../utils/error_handler.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  static const int _pageSize = 12;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(authSessionValidProvider);
    if (sessionAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (sessionAsync.valueOrNull != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/auth/login?mode=signin&role=family');
        }
      });

      return const Scaffold(
        body: Center(child: Text('Session expired. Redirecting to login...')),
      );
    }

    final userAsync = ref.watch(userModelProvider);
    final user = userAsync.value;

    if (user == null) {
      return Scaffold(
        backgroundColor: GCColors.background,
        appBar: AppBar(title: const Text('My Bookings')),
        body: const Center(child: Text('Please log in to view bookings.')),
      );
    }

    return Scaffold(
      backgroundColor: GCColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: SafeArea(
        child: _PagedUserBookingsList(
          userId: user.uid,
          pageSize: _pageSize,
        ),
      ),
    );
  }
}

class _PagedUserBookingsList extends ConsumerStatefulWidget {
  final String userId;
  final int pageSize;

  const _PagedUserBookingsList({
    required this.userId,
    required this.pageSize,
  });

  @override
  ConsumerState<_PagedUserBookingsList> createState() =>
      _PagedUserBookingsListState();
}

class _PagedUserBookingsListState
    extends ConsumerState<_PagedUserBookingsList> {
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
  void didUpdateWidget(covariant _PagedUserBookingsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadInitialPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPage() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _error = null;
      _bookings.clear();
      _lastDocument = null;
    });

    try {
      final page =
          await ref.read(bookingRepositoryProvider).getUserBookingsPage(
                widget.userId,
                limit: widget.pageSize,
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
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final page =
          await ref.read(bookingRepositoryProvider).getUserBookingsPage(
                widget.userId,
                startAfter: _lastDocument,
                limit: widget.pageSize,
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
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;

    final threshold = _scrollController.position.maxScrollExtent * 0.85;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  Future<void> _onRefresh() => _loadInitialPage();

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const _BookingSkeletonCard(),
      );
    }

    if (_error != null && _bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: GCColors.destructive, size: 36),
              const SizedBox(height: 10),
              Text(
                'Unable to load bookings right now.',
                style: GCTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadInitialPage,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today,
                size: 64,
                color: GCColors.mutedForeground.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No bookings yet',
              style: GCTypography.headlineSmall
                  .copyWith(color: GCColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/book'),
              child: const Text('Book a Service'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length + (_hasMore || _isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _bookings.length) {
            return _BookingCard(booking: _bookings[index]);
          }

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
        },
      ),
    );
  }
}

class _BookingSkeletonCard extends StatelessWidget {
  const _BookingSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 12, width: 110, color: GCColors.muted),
            const SizedBox(height: 10),
            Container(height: 18, width: 180, color: GCColors.muted),
            const SizedBox(height: 12),
            Container(height: 12, width: 220, color: GCColors.muted),
            const SizedBox(height: 8),
            Container(height: 12, width: 140, color: GCColors.muted),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final BookingModel booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isUpcoming =
        booking.status == 'upcoming' || booking.status == 'confirmed';

    Color statusColor;
    switch (booking.status.toLowerCase()) {
      case 'completed':
        statusColor = GCColors.goldDark;
        break;
      case 'cancelled':
        statusColor = GCColors.destructive;
        break;
      case 'upcoming':
        statusColor = GCColors.primary;
        break;
      case 'confirmed':
        statusColor = GCColors.accent;
        break;
      case 'pending_payment':
        statusColor = const Color(0xFFB8860B);
        break;
      case 'in_progress':
        statusColor = GCColors.goldDark;
        break;
      case 'completion_requested':
        statusColor = GCColors.goldDark;
        break;
      default:
        statusColor = GCColors.mutedForeground;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/booking-details/${booking.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'ID: ${booking.id.length > 6 ? booking.id.substring(booking.id.length - 6) : booking.id}',
                      style: GCTypography.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (booking.createdAt != null)
                    Text(DateFormat('MMM d, h:mm a').format(booking.createdAt!),
                        style: GCTypography.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.serviceName,
                      style: GCTypography.headlineSmall.copyWith(fontSize: 18),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: GCColors.mutedForeground),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(booking.date),
                    style: GCTypography.bodyMedium,
                  ),
                  if (booking.time != null) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time,
                        size: 16, color: GCColors.mutedForeground),
                    const SizedBox(width: 8),
                    Text(
                      booking.time!,
                      style: GCTypography.bodyMedium,
                    ),
                  ],
                ],
              ),
              if (booking.duration != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timelapse,
                        size: 16, color: GCColors.mutedForeground),
                    const SizedBox(width: 8),
                    Text(
                      booking.duration!,
                      style: GCTypography.bodyMedium,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 16, color: GCColors.mutedForeground),
                  const SizedBox(width: 8),
                  Text(
                    '₹${booking.price.toStringAsFixed(2)}',
                    style: GCTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (booking.servicePersonnelName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 16, color: GCColors.mutedForeground),
                    const SizedBox(width: 8),
                    Text(
                      'Personnel: ${booking.servicePersonnelName}',
                      style: GCTypography.bodyMedium,
                    ),
                  ],
                ),
              ],
              if (isUpcoming) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showCancelDialog(context, ref, booking),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GCColors.destructive,
                        side: const BorderSide(color: GCColors.destructive),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this booking?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A cancellation fee of ₹${(booking.price * 0.25).toStringAsFixed(2)} (25%) applies to this booking.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Text('Cancelling booking...')),
                    ],
                  ),
                ),
              );

              try {
                await ref
                    .read(bookingRepositoryProvider)
                    .cancelBooking(booking.id);
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Booking cancelled successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${ErrorHandler.handle(e)}'),
                      backgroundColor: GCColors.destructive,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GCColors.destructive,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }
}
