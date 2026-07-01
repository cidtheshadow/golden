import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String? _error;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  String? _transactionIdFilter;
  String? _bookingIdFilter;
  String? _userIdFilter;
  String? _servicePersonnelIdFilter;

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
    });
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _syncFiltersFromRoute() {
    final params = GoRouterState.of(context).uri.queryParameters;
    _transactionIdFilter = _normalizeFilter(params['transactionId']);
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

  Future<void> _clearFilters() async {
    context.go('/transactions');
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await AdminService.instance.listTransactions(
        transactionId: _transactionIdFilter,
        bookingId: _bookingIdFilter,
        userId: _userIdFilter,
        servicePersonnelId: _servicePersonnelIdFilter,
        limit: 100,
      );
      final txs = List<Map<String, dynamic>>.from(
          result['transactions'] as List? ?? []);
      if (!mounted) {
        return;
      }
      setState(() {
        _transactions = txs;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    final format =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);

    return AdminShell(
      title: 'Transactions',
      currentPath: '/transactions',
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AdminTheme.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AdminTheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions',
                          style: TextStyle(color: AdminTheme.textSecondary)),
                    )
                  : Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_transactionIdFilter != null ||
                                _bookingIdFilter != null ||
                                _userIdFilter != null ||
                                _servicePersonnelIdFilter != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (_transactionIdFilter != null)
                                      Chip(
                                          label: Text(
                                              'Transaction: $_transactionIdFilter')),
                                    if (_bookingIdFilter != null)
                                      Chip(
                                          label: Text(
                                              'Booking: $_bookingIdFilter')),
                                    if (_userIdFilter != null)
                                      Chip(label: Text('User: $_userIdFilter')),
                                    if (_servicePersonnelIdFilter != null)
                                      Chip(
                                          label: Text(
                                              'Caregiver: $_servicePersonnelIdFilter')),
                                    OutlinedButton.icon(
                                      onPressed: _clearFilters,
                                      icon: const Icon(
                                          Icons.filter_alt_off_rounded,
                                          size: 16),
                                      label: const Text('Clear Filters'),
                                    ),
                                  ],
                                ),
                              ),
                            LayoutBuilder(
                              builder: (context, constraints) =>
                                  ScrollConfiguration(
                                behavior:
                                    const MaterialScrollBehavior().copyWith(
                                  dragDevices: {
                                    PointerDeviceKind.touch,
                                    PointerDeviceKind.mouse,
                                    PointerDeviceKind.trackpad,
                                    PointerDeviceKind.stylus,
                                  },
                                ),
                                child: Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  interactive: true,
                                  notificationPredicate: (notification) =>
                                      notification.depth == 0,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    primary: false,
                                    physics: const ClampingScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(AdminTheme
                                                .surfaceHigh
                                                .withValues(alpha: 0.35)),
                                        dataRowColor: WidgetStateProperty.all(
                                            AdminTheme.surface),
                                        columns: const [
                                          DataColumn(
                                              label: Text('Transaction ID')),
                                          DataColumn(label: Text('Booking')),
                                          DataColumn(label: Text('Service')),
                                          DataColumn(label: Text('User')),
                                          DataColumn(label: Text('Caregiver')),
                                          DataColumn(label: Text('Hours')),
                                          DataColumn(label: Text('Status')),
                                          DataColumn(
                                              label: Text('Payment Status')),
                                          DataColumn(label: Text('Amount')),
                                          DataColumn(
                                              label: Text('Platform Fee')),
                                          DataColumn(
                                              label: Text('Provider Payment')),
                                          DataColumn(label: Text('Links')),
                                        ],
                                        rows: _transactions.map((tx) {
                                          final txId =
                                              tx['id'] as String? ?? '';
                                          final bookingId = _pickText(
                                              tx, ['bookingId', 'referenceId']);
                                          final serviceName = _pickText(tx, [
                                            'serviceName',
                                            'serviceTitle',
                                            'service',
                                            'serviceType',
                                          ]);
                                          final userId = _pickText(
                                              tx, ['userId', 'familyId']);
                                          final servicePersonnelId = _pickText(
                                              tx, [
                                            'servicePersonnelId',
                                            'caregiverId'
                                          ]);
                                          final amount = _toNum(
                                            tx['displayAmount'] ??
                                                tx['amountDisplay'] ??
                                                tx['amount'] ??
                                                tx['totalAmount'] ??
                                                tx['bookingAmount'] ??
                                                tx['paidAmount'],
                                          );
                                          final fee = _toNum(
                                            tx['displayPlatformFee'] ??
                                                tx['platformFeeDisplay'] ??
                                                tx['platformFee'] ??
                                                tx['fee'] ??
                                                tx['serviceFee'],
                                          );
                                          final status =
                                              tx['status'] as String? ?? '';
                                          final hours = _toNum(
                                            tx['displayDurationHours'] ??
                                                tx['durationHours'] ??
                                                tx['serviceDurationHours'] ??
                                                tx['hours'] ??
                                                tx['serviceHours'],
                                            fallback: -1,
                                          );
                                          final hoursText = (hours <= 0)
                                              ? '-'
                                              : hours % 1 == 0
                                                  ? '${hours.toInt()}h'
                                                  : '${hours.toStringAsFixed(1)}h';

                                          return DataRow(
                                            cells: [
                                              DataCell(SizedBox(
                                                width: 170,
                                                child: Text(
                                                  txId,
                                                  style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontSize: 12),
                                                ),
                                              )),
                                              DataCell(Text(bookingId.isEmpty
                                                  ? '-'
                                                  : bookingId)),
                                              DataCell(SizedBox(
                                                width: 180,
                                                child: Text(
                                                  serviceName.isEmpty
                                                      ? '-'
                                                      : serviceName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )),
                                              DataCell(Text(userId.isEmpty
                                                  ? '-'
                                                  : userId)),
                                              DataCell(Text(
                                                  servicePersonnelId.isEmpty
                                                      ? '-'
                                                      : servicePersonnelId)),
                                              DataCell(Text(hoursText)),
                                              DataCell(Text(status)),
                                              DataCell(Text(
                                                  (tx['paymentStatus'] ?? '-')
                                                      .toString())),
                                              DataCell(
                                                  Text(format.format(amount))),
                                              DataCell(
                                                  Text(format.format(fee))),
                                              DataCell(Text(
                                                  (tx['providerPaymentId'] ??
                                                          '-')
                                                      .toString())),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Open booking',
                                                      onPressed: bookingId
                                                              .isEmpty
                                                          ? null
                                                          : () => _openFiltered(
                                                                  '/bookings', {
                                                                'bookingId':
                                                                    bookingId
                                                              }),
                                                      icon: const Icon(
                                                          Icons
                                                              .calendar_month_rounded,
                                                          color: Colors.teal),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Open user',
                                                      onPressed: userId.isEmpty
                                                          ? null
                                                          : () => _openFiltered(
                                                                  '/users', {
                                                                'userId': userId
                                                              }),
                                                      icon: const Icon(
                                                          Icons
                                                              .person_search_rounded,
                                                          color: Colors.indigo),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Open caregiver',
                                                      onPressed: servicePersonnelId
                                                              .isEmpty
                                                          ? null
                                                          : () => _openFiltered(
                                                                  '/caregivers',
                                                                  {
                                                                    'userId':
                                                                        servicePersonnelId,
                                                                  }),
                                                      icon: const Icon(
                                                          Icons
                                                              .medical_services_rounded,
                                                          color: Colors.orange),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
