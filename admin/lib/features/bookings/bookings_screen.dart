import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _caregivers = [];
  bool _loading = true;
  String? _error;
  String? _lastId;
  bool _hasMore = false;
  String? _statusFilter;
  String? _bookingIdFilter;
  String? _userIdFilter;
  String? _servicePersonnelIdFilter;

  final List<String?> _statuses = const [
    null,
    'confirmed',
    'in_progress',
    'completion_requested',
    'completed',
    'cancelled',
    'pending_payment',
  ];

  num _toNum(dynamic value, {num fallback = 0}) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  String _pickText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) {
        continue;
      }
      final value = raw.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncFiltersFromRoute();
      _load();
      _loadCaregivers();
    });
  }

  void _syncFiltersFromRoute() {
    final params = GoRouterState.of(context).uri.queryParameters;
    _statusFilter = _normalizeFilter(params['status']);
    _bookingIdFilter = _normalizeFilter(params['bookingId']);
    _userIdFilter = _normalizeFilter(params['userId']);
    _servicePersonnelIdFilter = _normalizeFilter(params['servicePersonnelId']);
  }

  String? _normalizeFilter(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void _openFiltered(String path, Map<String, String?> params) {
    final qp = <String, String>{};
    for (final entry in params.entries) {
      final value = _normalizeFilter(entry.value);
      if (value != null) {
        qp[entry.key] = value;
      }
    }
    final uri = Uri(path: path, queryParameters: qp.isEmpty ? null : qp);
    context.go(uri.toString());
  }

  Future<void> _loadCaregivers() async {
    try {
      final result = await AdminService.instance.listUsers(role: 'caregiver');
      final list =
          List<Map<String, dynamic>>.from(result['users'] as List? ?? []);
      if (!mounted) {
        return;
      }
      setState(() => _caregivers = list);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load caregivers: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }

  Future<T> _runWithLoading<T>(Future<T> Function() action) async {
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
            Expanded(child: Text('Processing...')),
          ],
        ),
      ),
    );

    try {
      return await action();
    } finally {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _lastId = null;
      });
    }
    try {
      final result = await AdminService.instance.listBookings(
        status: _statusFilter,
        bookingId: _bookingIdFilter,
        userId: _userIdFilter,
        servicePersonnelId: _servicePersonnelIdFilter,
        limit: 20,
        startAfter: reset ? null : _lastId,
      );
      final list =
          List<Map<String, dynamic>>.from(result['bookings'] as List? ?? []);
      if (!mounted) {
        return;
      }
      setState(() {
        _bookings = reset ? list : [..._bookings, ...list];
        _lastId = result['lastId'] as String?;
        _hasMore = result['hasMore'] as bool? ?? false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      case 'pending_payment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
    return AdminShell(
      title: 'Bookings',
      currentPath: '/bookings',
      child: Column(
        children: [
          if (_bookingIdFilter != null ||
              _userIdFilter != null ||
              _servicePersonnelIdFilter != null ||
              _statusFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_bookingIdFilter != null)
                    Chip(label: Text('Booking: $_bookingIdFilter')),
                  if (_userIdFilter != null)
                    Chip(label: Text('User: $_userIdFilter')),
                  if (_servicePersonnelIdFilter != null)
                    Chip(label: Text('Caregiver: $_servicePersonnelIdFilter')),
                  if (_statusFilter != null)
                    Chip(label: Text('Status: $_statusFilter')),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/bookings'),
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _statuses
                  .map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status ?? 'All',
                            style: const TextStyle(fontSize: 12)),
                        selected: _statusFilter == status,
                        onSelected: (_) {
                          setState(() => _statusFilter = status);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AdminTheme.gold))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AdminTheme.error)))
                    : _bookings.isEmpty
                        ? const Center(
                            child: Text('No bookings',
                                style:
                                    TextStyle(color: AdminTheme.textSecondary)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _bookings.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              if (index == _bookings.length) {
                                return TextButton(
                                  onPressed: () => _load(reset: false),
                                  child: const Text('Load more'),
                                );
                              }

                              final booking = _bookings[index];
                              final status = booking['status'] as String? ?? '';
                              final color = _statusColor(status);
                              final price = _toNum(
                                booking['price'] ??
                                    booking['amount'] ??
                                    booking['totalAmount'],
                              );
                              final bookingId = booking['id'] as String? ?? '';
                              final userId =
                                  _pickText(booking, ['userId', 'familyId']);
                              final servicePersonnelId = _pickText(booking,
                                  ['servicePersonnelId', 'caregiverId']);
                              final servicePersonnelName = _pickText(booking, [
                                'servicePersonnelName',
                                'caregiverName',
                                'caregiver',
                              ]);
                              final serviceName = _pickText(booking, [
                                'serviceName',
                                'serviceTitle',
                                'service',
                              ]);
                              final locationText = [
                                booking['address']?.toString() ?? '',
                                booking['city']?.toString() ?? '',
                                booking['state']?.toString() ?? '',
                              ]
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(', ');

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AdminTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AdminTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                serviceName.isEmpty
                                                    ? 'Service'
                                                    : serviceName,
                                                style: const TextStyle(
                                                  color: AdminTheme.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                bookingId,
                                                style: const TextStyle(
                                                  color:
                                                      AdminTheme.textSecondary,
                                                  fontSize: 11,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                color.withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Price: ${money.format(price)}',
                                      style: const TextStyle(
                                        color: AdminTheme.gold,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'User: ${userId.isEmpty ? '-' : userId}',
                                      style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Caregiver: ${servicePersonnelName.isNotEmpty ? servicePersonnelName : (servicePersonnelId.isEmpty ? '-' : servicePersonnelId)}',
                                      style: const TextStyle(
                                        color: AdminTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (locationText.isNotEmpty)
                                      Text(
                                        'Location: $locationText',
                                        style: const TextStyle(
                                          color: AdminTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _BookingActionButton(
                                          label: 'Transactions',
                                          icon: Icons.receipt_long_rounded,
                                          color: Colors.indigo,
                                          onTap: () => _openFiltered(
                                            '/transactions',
                                            {'bookingId': bookingId},
                                          ),
                                        ),
                                        if (userId.isNotEmpty)
                                          _BookingActionButton(
                                            label: 'User',
                                            icon: Icons.person_search_rounded,
                                            color: Colors.blueGrey,
                                            onTap: () => _openFiltered(
                                              '/users',
                                              {'userId': userId},
                                            ),
                                          ),
                                        if (servicePersonnelId.isNotEmpty)
                                          _BookingActionButton(
                                            label: 'Caregiver',
                                            icon:
                                                Icons.medical_services_rounded,
                                            color: Colors.orange,
                                            onTap: () => _openFiltered(
                                              '/caregivers',
                                              {'userId': servicePersonnelId},
                                            ),
                                          ),
                                        _BookingActionButton(
                                          label: 'Force Status',
                                          icon: Icons.sync_alt_rounded,
                                          color: Colors.blue,
                                          onTap: () => _showStatusDialog(
                                              bookingId, status),
                                        ),
                                        _BookingActionButton(
                                          label: 'Reassign',
                                          icon: Icons.swap_horiz_rounded,
                                          color: Colors.teal,
                                          onTap: () =>
                                              _showReassignDialog(bookingId),
                                        ),
                                        _BookingActionButton(
                                          label: 'Override Price',
                                          icon: Icons.price_change_rounded,
                                          color: AdminTheme.gold,
                                          onTap: () => _showPriceOverrideDialog(
                                              bookingId, price.toDouble()),
                                        ),
                                        if (!['completed', 'cancelled']
                                            .contains(status))
                                          _BookingActionButton(
                                            label: 'Cancel',
                                            icon: Icons.cancel_rounded,
                                            color: AdminTheme.error,
                                            onTap: () =>
                                                _showCancelDialog(bookingId),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog(String bookingId) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: const Text('Cancel Booking',
            style: TextStyle(color: AdminTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AdminTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Reason',
            labelStyle: TextStyle(color: AdminTheme.textSecondary),
            filled: true,
            fillColor: AdminTheme.bg,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _runWithLoading(() => AdminService.instance
                    .cancelBooking(bookingId, controller.text.trim()));
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking cancelled')));
                _load();
              } catch (e) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AdminTheme.error),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showStatusDialog(String bookingId, String currentStatus) async {
    const statuses = [
      'pending_payment',
      'confirmed',
      'in_progress',
      'completion_requested',
      'completed',
      'cancelled',
    ];
    final rootContext = context;
    String selected =
        statuses.contains(currentStatus) ? currentStatus : 'confirmed';

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: const Text('Force Booking Status',
              style: TextStyle(color: AdminTheme.textPrimary)),
          content: DropdownButtonFormField<String>(
            value: selected,
            items: statuses
                .map((status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setLocalState(() => selected = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Status'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(rootContext).pop(),
                child: const Text('Dismiss')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(rootContext).pop();
                try {
                  await _runWithLoading(() => AdminService.instance
                      .updateBooking(bookingId, {'status': selected}));
                  if (!rootContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text('Booking status updated')),
                  );
                  _load();
                } catch (e) {
                  if (!rootContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReassignDialog(String bookingId) async {
    final rootContext = context;
    if (_caregivers.isEmpty) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('No caregivers available for assignment')),
      );
      return;
    }

    final reasonController = TextEditingController();
    String selectedId = _caregivers.first['id'] as String? ?? '';

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: const Text('Reassign Caregiver',
              style: TextStyle(color: AdminTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                items: _caregivers
                    .map(
                      (caregiver) => DropdownMenuItem<String>(
                        value: caregiver['id'] as String? ?? '',
                        child: Text(caregiver['name'] as String? ??
                            caregiver['id'] as String? ??
                            'Caregiver'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedId = value);
                  }
                },
                decoration: const InputDecoration(labelText: 'New Caregiver'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(rootContext).pop(),
                child: const Text('Dismiss')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(rootContext).pop();
                try {
                  await _runWithLoading(
                      () => AdminService.instance.reassignCaregiver(
                            bookingId,
                            selectedId,
                            reasonController.text.trim(),
                          ));
                  if (!rootContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text('Caregiver reassigned')),
                  );
                  _load();
                } catch (e) {
                  if (!rootContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );

    reasonController.dispose();
  }

  Future<void> _showPriceOverrideDialog(
      String bookingId, double currentPrice) async {
    final rootContext = context;
    final controller =
        TextEditingController(text: currentPrice.toStringAsFixed(0));
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: const Text('Override Booking Price',
            style: TextStyle(color: AdminTheme.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(rootContext).pop(),
              child: const Text('Dismiss')),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim());
              Navigator.of(rootContext).pop();
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid price')),
                );
                return;
              }

              try {
                await _runWithLoading(() => AdminService.instance
                    .updateBooking(bookingId, {'price': value}));
                if (!rootContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                      content: Text('Price overridden successfully')),
                );
                _load();
              } catch (e) {
                if (!rootContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(rootContext)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _BookingActionButton extends StatelessWidget {
  const _BookingActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.55)),
        backgroundColor: color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
