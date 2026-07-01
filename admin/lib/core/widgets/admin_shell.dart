import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../services/admin_service.dart';
import '../theme/admin_theme.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.title,
    required this.currentPath,
    required this.child,
    this.floatingActionButton,
  });

  final String title;
  final String currentPath;
  final Widget child;
  final Widget? floatingActionButton;

  static const _baseNavItems = [
    _NavItem('/dashboard', Icons.dashboard_rounded, 'Dashboard'),
    _NavItem('/bookings', Icons.calendar_month_rounded, 'Bookings'),
    _NavItem('/users', Icons.people_rounded, 'Users'),
    _NavItem('/administrators', Icons.admin_panel_settings_rounded,
        'Administrators'),
    _NavItem('/caregivers', Icons.medical_services_rounded, 'Caregivers'),
    _NavItem('/pricing', Icons.currency_rupee_rounded, 'Pricing'),
    _NavItem('/transactions', Icons.receipt_long_rounded, 'Transactions'),
  ];

  static const _auditLogsNavItem =
      _NavItem('/audit-logs', Icons.shield_rounded, 'Audit Logs');

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static bool _persistedCollapsed = false;
  bool _isPrimaryAdmin = false;
  StreamSubscription<User?>? _authSubscription;

  bool get _collapsed => _persistedCollapsed;

  @override
  void initState() {
    super.initState();
    _loadAuthz();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      _loadAuthz();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAuthz() async {
    try {
      final authz = await AdminService.instance.getAdminAuthz();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPrimaryAdmin = authz['isPrimary'] == true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPrimaryAdmin = false;
      });
    }
  }

  List<_NavItem> get _navItems {
    final items = List<_NavItem>.of(AdminShell._baseNavItems);
    // Always show Audit Logs in navigation for clear discoverability.
    // Non-primary admins see it disabled with an explanatory message.
    items.add(AdminShell._auditLogsNavItem);
    return items;
  }

  bool get _canAccessAuditLogs => _isPrimaryAdmin;

  void _toggleCollapsed() {
    setState(() {
      _persistedCollapsed = !_persistedCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final useSidebar = width > 700;

    if (useSidebar) {
      return Scaffold(
        backgroundColor: AdminTheme.bg,
        body: Row(
          children: [
            _Sidebar(
              currentPath: widget.currentPath,
              navItems: _navItems,
              canAccessAuditLogs: _canAccessAuditLogs,
              collapsed: _collapsed,
              onToggleCollapse: _toggleCollapsed,
            ),
            Expanded(
              child: Scaffold(
                backgroundColor: AdminTheme.bg,
                appBar: AppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title),
                      const Text(
                        'Master Control Console',
                        style: TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AdminTheme.surface,
                  foregroundColor: AdminTheme.textPrimary,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                ),
                body: widget.child,
                floatingActionButton: widget.floatingActionButton,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AdminTheme.bg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AdminTheme.surface,
        foregroundColor: AdminTheme.textPrimary,
        elevation: 0,
      ),
      body: widget.child,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AdminTheme.surface,
        selectedIndex: _selectedIndex(widget.currentPath, _navItems),
        indicatorColor: AdminTheme.gold.withValues(alpha: 0.2),
        destinations: _navItems
            .map((item) =>
                NavigationDestination(icon: Icon(item.icon), label: item.label))
            .toList(),
        onDestinationSelected: (index) => context.go(_navItems[index].path),
      ),
    );
  }

  int _selectedIndex(String path, List<_NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (path.startsWith(items[i].path)) {
        return i;
      }
    }
    return 0;
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentPath,
    required this.navItems,
    required this.canAccessAuditLogs,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  final String currentPath;
  final List<_NavItem> navItems;
  final bool canAccessAuditLogs;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'admin@console';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: collapsed ? 84 : 244,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2747), Color(0xFF131D35), Color(0xFF0F172A)],
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 104,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!collapsed)
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Golden Care',
                            style: TextStyle(
                              color: AdminTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    if (collapsed)
                      Image.asset(
                        'assets/images/logo.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    IconButton(
                      tooltip: collapsed ? 'Expand menu' : 'Collapse menu',
                      onPressed: onToggleCollapse,
                      icon: Icon(
                        collapsed
                            ? Icons.keyboard_double_arrow_right_rounded
                            : Icons.keyboard_double_arrow_left_rounded,
                        color: AdminTheme.textSecondary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                if (!collapsed) ...[
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: navItems.map((item) {
                  final active = currentPath.startsWith(item.path);
                  final isAuditLogs = item.path == '/audit-logs';
                  final disabled = isAuditLogs && !canAccessAuditLogs;
                  final tile = ListTile(
                    dense: true,
                    selected: active && !disabled,
                    selectedTileColor: AdminTheme.gold.withValues(alpha: 0.14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    leading: Icon(
                      item.icon,
                      size: 18,
                      color: disabled
                          ? AdminTheme.textMuted.withValues(alpha: 0.78)
                          : (active ? AdminTheme.gold : AdminTheme.textMuted),
                    ),
                    title: collapsed
                        ? null
                        : Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: disabled
                                  ? AdminTheme.textMuted.withValues(alpha: 0.78)
                                  : (active
                                      ? AdminTheme.gold
                                      : AdminTheme.textSecondary),
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                    horizontalTitleGap: collapsed ? 0 : 12,
                    minLeadingWidth: 18,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 22 : 12,
                      vertical: 0,
                    ),
                    onTap: () {
                      if (disabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Audit Logs are available only to Primary Admins'),
                          ),
                        );
                      }
                      context.go(item.path);
                    },
                  );
                  if (!collapsed) {
                    return tile;
                  }
                  return Tooltip(
                    message: disabled
                        ? 'Audit Logs (Primary Admin only)'
                        : item.label,
                    child: tile,
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AdminTheme.border)),
            ),
            child: () {
              final tile = ListTile(
                dense: true,
                leading: const Icon(Icons.logout_rounded,
                    color: AdminTheme.error, size: 18),
                title: collapsed
                    ? null
                    : const Text('Sign Out',
                        style:
                            TextStyle(color: AdminTheme.error, fontSize: 13)),
                horizontalTitleGap: collapsed ? 0 : 12,
                minLeadingWidth: 18,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 22 : 12,
                  vertical: 0,
                ),
                onTap: () async {
                  await AdminService.instance.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              );
              if (!collapsed) {
                return tile;
              }
              return Tooltip(message: 'Sign Out', child: tile);
            }(),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}
