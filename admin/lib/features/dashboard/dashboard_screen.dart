import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await AdminService.instance.getStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
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

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  num _toNum(dynamic value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Dashboard',
      currentPath: '/dashboard',
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AdminTheme.gold),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AdminTheme.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: _buildContent(context),
                  ),
                ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bookings = (_stats?['bookings'] as Map?) ?? {};
    final users = (_stats?['users'] as Map?) ?? {};
    final revenue = (_stats?['revenue'] as Map?) ?? {};

    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);

    final kpis = [
      _KpiData(
        title: 'Bookings Today',
        value: '${_toInt(bookings['today'])}',
        subtitle: '${_toInt(bookings['active'])} active right now',
        icon: Icons.today_rounded,
        color: Colors.blue,
      ),
      _KpiData(
        title: 'Total Bookings',
        value: '${_toInt(bookings['total'])}',
        subtitle: '${_toInt(bookings['completed'])} completed',
        icon: Icons.assignment_turned_in_rounded,
        color: Colors.teal,
      ),
      _KpiData(
        title: 'Families',
        value: '${_toInt(users['families'])}',
        subtitle:
            '${_toInt(users['caregivers'])} caregivers, ${_toInt(users['pendingApproval'])} pending',
        icon: Icons.people_alt_rounded,
        color: Colors.deepPurple,
      ),
      _KpiData(
        title: 'Revenue Today',
        value: currency.format(_toNum(revenue['today'])),
        subtitle: 'Total: ${currency.format(_toNum(revenue['total']))}',
        icon: Icons.currency_rupee_rounded,
        color: Colors.orange,
      ),
    ];

    final isWide = MediaQuery.of(context).size.width > 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeaderBand(
          title: 'Operations Overview',
          subtitle:
              'Live control center for bookings, users, service operations, and revenue.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((item) => _KpiCard(data: item)).toList(),
        ),
        const SizedBox(height: 20),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MetricPanel(
                  title: 'Booking Health',
                  icon: Icons.calendar_month_rounded,
                  rows: [
                    _MetricItem('Today', '${_toInt(bookings['today'])}'),
                    _MetricItem('Active', '${_toInt(bookings['active'])}'),
                    _MetricItem(
                        'Completed', '${_toInt(bookings['completed'])}'),
                    _MetricItem('Total', '${_toInt(bookings['total'])}'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricPanel(
                  title: 'Workforce & Users',
                  icon: Icons.groups_rounded,
                  rows: [
                    _MetricItem('Families', '${_toInt(users['families'])}'),
                    _MetricItem('Caregivers', '${_toInt(users['caregivers'])}'),
                    _MetricItem(
                        'Active Now', '${_toInt(users['activeCaregivers'])}'),
                    _MetricItem('Pending Approval',
                        '${_toInt(users['pendingApproval'])}'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricPanel(
                  title: 'Revenue Pulse',
                  icon: Icons.insights_rounded,
                  rows: [
                    _MetricItem(
                        'Today', currency.format(_toNum(revenue['today']))),
                    _MetricItem(
                        'Total', currency.format(_toNum(revenue['total']))),
                    _MetricItem('Platform Fees',
                        currency.format(_toNum(revenue['platformFees']))),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _MetricPanel(
            title: 'Booking Health',
            icon: Icons.calendar_month_rounded,
            rows: [
              _MetricItem('Today', '${_toInt(bookings['today'])}'),
              _MetricItem('Active', '${_toInt(bookings['active'])}'),
              _MetricItem('Completed', '${_toInt(bookings['completed'])}'),
              _MetricItem('Total', '${_toInt(bookings['total'])}'),
            ],
          ),
          const SizedBox(height: 12),
          _MetricPanel(
            title: 'Workforce & Users',
            icon: Icons.groups_rounded,
            rows: [
              _MetricItem('Families', '${_toInt(users['families'])}'),
              _MetricItem('Caregivers', '${_toInt(users['caregivers'])}'),
              _MetricItem('Active Now', '${_toInt(users['activeCaregivers'])}'),
              _MetricItem(
                  'Pending Approval', '${_toInt(users['pendingApproval'])}'),
            ],
          ),
          const SizedBox(height: 12),
          _MetricPanel(
            title: 'Revenue Pulse',
            icon: Icons.insights_rounded,
            rows: [
              _MetricItem('Today', currency.format(_toNum(revenue['today']))),
              _MetricItem('Total', currency.format(_toNum(revenue['total']))),
              _MetricItem('Platform Fees',
                  currency.format(_toNum(revenue['platformFees']))),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const _SectionTitle('Quick Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionTile(
              label: 'Open Bookings',
              icon: Icons.calendar_month_rounded,
              onTap: () => context.go('/bookings'),
            ),
            _ActionTile(
              label: 'Manage Caregivers',
              icon: Icons.how_to_reg_rounded,
              onTap: () => context.go('/caregivers'),
            ),
            _ActionTile(
              label: 'Edit Pricing',
              icon: Icons.currency_rupee_rounded,
              onTap: () => context.go('/pricing'),
            ),
            _ActionTile(
              label: 'Open Users',
              icon: Icons.people_rounded,
              onTap: () => context.go('/users'),
            ),
            _ActionTile(
              label: 'View Transactions',
              icon: Icons.receipt_long_rounded,
              onTap: () => context.go('/transactions'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminTheme.surfaceHigh.withValues(alpha: 0.75),
            AdminTheme.surface.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AdminTheme.surfaceHigh.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AdminTheme.surfaceHigh.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    color: AdminTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value);

  final String label;
  final String value;
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_MetricItem> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AdminTheme.surfaceHigh.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminTheme.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < rows.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].label,
                    style: const TextStyle(color: AdminTheme.textSecondary),
                  ),
                ),
                Text(
                  rows[i].value,
                  style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (i != rows.length - 1)
              Divider(
                height: 16,
                color: AdminTheme.surfaceHigh.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: AdminTheme.textSecondary,
        fontSize: 12,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 210,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AdminTheme.surfaceHigh.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AdminTheme.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AdminTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
