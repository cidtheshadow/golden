import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _isPrimaryAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authz = await AdminService.instance.getAdminAuthz();
      final isPrimary = authz['isPrimary'] == true;

      if (!isPrimary) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPrimaryAdmin = false;
          _logs = [];
          _loading = false;
        });
        return;
      }

      final result = await AdminService.instance.listAuditLogs(limit: 200);
      final logs =
          List<Map<String, dynamic>>.from(result['logs'] as List? ?? []);

      if (!mounted) {
        return;
      }
      setState(() {
        _isPrimaryAdmin = true;
        _logs = logs;
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

  DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is Map && value['_seconds'] is num) {
      final seconds = (value['_seconds'] as num).toInt();
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    try {
      final dynamic maybeDate = (value as dynamic).toDate();
      if (maybeDate is DateTime) {
        return maybeDate;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _stringifyJson(dynamic value) {
    const encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(value);
    } catch (_) {
      return value?.toString() ?? 'null';
    }
  }

  void _openEntryDetails(Map<String, dynamic> entry) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: const Text('Audit Entry Details'),
          content: SizedBox(
            width: 1000,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                        label:
                            Text((entry['actionCategory'] ?? '-').toString())),
                    Chip(
                        label: Text(
                            (entry['targetEntityType'] ?? '-').toString())),
                    Chip(
                        label:
                            Text((entry['targetEntityId'] ?? '-').toString())),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _JsonPane(
                          title: 'Previous State',
                          jsonText: _stringifyJson(entry['previousState']),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _JsonPane(
                          title: 'New State',
                          jsonText: _stringifyJson(entry['newState']),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy, hh:mm:ss a');

    return AdminShell(
      title: 'Audit Logs',
      currentPath: '/audit-logs',
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AdminTheme.gold),
            )
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
              : !_isPrimaryAdmin
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Card(
                          color: AdminTheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_person_rounded,
                                  size: 40,
                                  color: AdminTheme.gold,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Insufficient Permissions',
                                  style: TextStyle(
                                    color: AdminTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Audit logs can be viewed only by Primary Admins. '
                                  'Your current role does not include ledger access.',
                                  style: TextStyle(
                                      color: AdminTheme.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: () => context.go('/dashboard'),
                                      icon: const Icon(Icons.home_rounded,
                                          size: 16),
                                      label: const Text('Back To Dashboard'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _load,
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 16),
                                      label: const Text('Refresh Access'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : _logs.isEmpty
                      ? const Center(
                          child: Text(
                            'No audit entries yet',
                            style: TextStyle(color: AdminTheme.textSecondary),
                          ),
                        )
                      : Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalController,
                            padding: const EdgeInsets.all(12),
                            child: Scrollbar(
                              controller: _horizontalController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AdminTheme.surfaceHigh
                                        .withValues(alpha: 0.35),
                                  ),
                                  dataRowColor: WidgetStateProperty.all(
                                      AdminTheme.surface),
                                  columns: const [
                                    DataColumn(label: Text('Timestamp')),
                                    DataColumn(label: Text('Admin')),
                                    DataColumn(label: Text('Category')),
                                    DataColumn(label: Text('Target Type')),
                                    DataColumn(label: Text('Target ID')),
                                    DataColumn(label: Text('Details')),
                                  ],
                                  rows: _logs.map((entry) {
                                    final ts = _toDate(entry['timestamp']);
                                    final tsText = ts == null
                                        ? '-'
                                        : format.format(ts.toLocal());
                                    final adminEmail =
                                        (entry['adminEmail'] ?? '-').toString();
                                    final actionCategory =
                                        (entry['actionCategory'] ?? '-')
                                            .toString();
                                    final targetType =
                                        (entry['targetEntityType'] ?? '-')
                                            .toString();
                                    final targetId =
                                        (entry['targetEntityId'] ?? '-')
                                            .toString();

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(tsText)),
                                        DataCell(Text(adminEmail)),
                                        DataCell(Text(actionCategory)),
                                        DataCell(Text(targetType)),
                                        DataCell(SizedBox(
                                          width: 260,
                                          child: Text(
                                            targetId,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                        DataCell(
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _openEntryDetails(entry),
                                            icon: const Icon(
                                                Icons.compare_arrows_rounded,
                                                size: 16),
                                            label: const Text('View Diff'),
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
    );
  }
}

class _JsonPane extends StatelessWidget {
  const _JsonPane({
    required this.title,
    required this.jsonText,
  });

  final String title;
  final String jsonText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.bg,
        border: Border.all(color: AdminTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AdminTheme.border),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                jsonText,
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
