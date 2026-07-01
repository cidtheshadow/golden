import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  List<Map<String, dynamic>> _familyUsers = [];
  bool _loading = true;
  String? _error;
  String? _userIdFilter;
  bool _canDeleteAccounts = false;
  String _adminType = 'secondary';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncFiltersFromRoute();
      _loadFamilyUsers();
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
    final userId = params['userId']?.trim() ?? '';
    _userIdFilter = userId.isEmpty ? null : userId;
  }

  void _openFiltered(String path, Map<String, String?> params) {
    final qp = <String, String>{};
    for (final entry in params.entries) {
      final value = entry.value?.trim() ?? '';
      if (value.isNotEmpty) {
        qp[entry.key] = value;
      }
    }
    final uri = Uri(path: path, queryParameters: qp.isEmpty ? null : qp);
    context.go(uri.toString());
  }

  Future<void> _loadFamilyUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authzResult = await AdminService.instance.getAdminAuthz();
      final permissions =
          Map<String, dynamic>.from(authzResult['permissions'] as Map? ?? {});

      final result = await AdminService.instance.listUsers(
        role: 'family',
        userId: _userIdFilter,
        limit: 200,
      );
      final users =
          List<Map<String, dynamic>>.from(result['users'] as List? ?? []);
      if (!mounted) {
        return;
      }
      setState(() {
        _canDeleteAccounts = permissions['canDeleteAccounts'] == true;
        _adminType = (authzResult['adminType'] as String? ?? 'secondary')
            .trim()
            .toLowerCase();
        _familyUsers = users;
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

  Future<void> _toggleUserActive(String userId, bool isActive) async {
    try {
      await AdminService.instance.updateUser(userId, {'isActive': !isActive});
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(!isActive ? 'User activated' : 'User deactivated')),
      );
      _loadFamilyUsers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final rootContext = context;
    final userId = user['id'] as String? ?? '';
    final nameController =
        TextEditingController(text: user['name'] as String? ?? '');
    final emailController =
        TextEditingController(text: user['email'] as String? ?? '');
    final phoneController =
        TextEditingController(text: user['phone'] as String? ?? '');
    final cityController =
        TextEditingController(text: user['city'] as String? ?? '');
    final stateController =
        TextEditingController(text: user['state'] as String? ?? '');
    final addressController =
        TextEditingController(text: user['address'] as String? ?? '');
    bool isActive = user['isActive'] as bool? ?? true;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: Text('Edit Family User ($userId)',
              style: const TextStyle(color: AdminTheme.textPrimary)),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: 'Role'),
                          child: Text(
                            'family',
                            style: TextStyle(
                                color: AdminTheme.textSecondary, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityController,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: stateController,
                          decoration: const InputDecoration(labelText: 'State'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    dense: true,
                    value: isActive,
                    onChanged: (value) => setLocalState(() => isActive = value),
                    title: const Text('Active'),
                  ),
                ],
              ),
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
                  await AdminService.instance.updateUser(userId, {
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'city': cityController.text.trim(),
                    'state': stateController.text.trim(),
                    'address': addressController.text.trim(),
                    'isActive': isActive,
                  });
                  if (!rootContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(content: Text('User updated')));
                  _loadFamilyUsers();
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
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    stateController.dispose();
    addressController.dispose();
  }

  Future<void> _deleteUser(String userId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: const Text('Delete User',
            style: TextStyle(color: AdminTheme.textPrimary)),
        content: const Text(
          'This anonymizes profile data and removes auth access. Continue?',
          style: TextStyle(color: AdminTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await AdminService.instance.deleteUser(userId);
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted')));
                _loadFamilyUsers();
              } catch (e) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Users',
      currentPath: '/users',
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
              : _familyUsers.isEmpty
                  ? const Center(
                      child: Text(
                        'No family users',
                        style: TextStyle(color: AdminTheme.textSecondary),
                      ),
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
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Chip(
                                avatar: const Icon(Icons.verified_user_rounded,
                                    size: 16),
                                label: Text(
                                  _adminType == 'primary'
                                      ? 'Primary Admin'
                                      : 'Secondary Admin',
                                ),
                              ),
                            ),
                            if (_userIdFilter != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(label: Text('User: $_userIdFilter')),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go('/users'),
                                      icon: const Icon(
                                          Icons.filter_alt_off_rounded,
                                          size: 16),
                                      label: const Text('Clear Filter'),
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
                                          DataColumn(label: Text('Name')),
                                          DataColumn(label: Text('Email')),
                                          DataColumn(label: Text('Phone')),
                                          DataColumn(label: Text('City')),
                                          DataColumn(label: Text('State')),
                                          DataColumn(label: Text('Active')),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                        rows: _familyUsers.map((user) {
                                          final name =
                                              user['name'] as String? ??
                                                  'Unknown';
                                          final email =
                                              user['email'] as String? ?? '';
                                          final isActive =
                                              user['isActive'] as bool? ?? true;
                                          final userId =
                                              user['id'] as String? ?? '';
                                          final phone =
                                              user['phone'] as String? ?? '-';
                                          final city =
                                              user['city'] as String? ?? '-';
                                          final state =
                                              user['state'] as String? ?? '-';

                                          return DataRow(
                                            cells: [
                                              DataCell(Text(name)),
                                              DataCell(SizedBox(
                                                  width: 220,
                                                  child: Text(email))),
                                              DataCell(Text(phone)),
                                              DataCell(Text(city)),
                                              DataCell(Text(state)),
                                              DataCell(Text(
                                                  isActive ? 'Yes' : 'No')),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: isActive
                                                          ? 'Deactivate user'
                                                          : 'Activate user',
                                                      onPressed: () =>
                                                          _toggleUserActive(
                                                              userId, isActive),
                                                      icon: Icon(
                                                        isActive
                                                            ? Icons
                                                                .person_off_rounded
                                                            : Icons
                                                                .verified_user_rounded,
                                                        color: isActive
                                                            ? Colors.orange
                                                            : Colors.green,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      tooltip:
                                                          'Open user bookings',
                                                      onPressed: () =>
                                                          _openFiltered(
                                                        '/bookings',
                                                        {'userId': userId},
                                                      ),
                                                      icon: const Icon(
                                                          Icons
                                                              .calendar_month_rounded,
                                                          color: Colors.teal),
                                                    ),
                                                    IconButton(
                                                      tooltip:
                                                          'Open user transactions',
                                                      onPressed: () =>
                                                          _openFiltered(
                                                        '/transactions',
                                                        {'userId': userId},
                                                      ),
                                                      icon: const Icon(
                                                          Icons
                                                              .receipt_long_rounded,
                                                          color: Colors.indigo),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Edit user',
                                                      onPressed: () =>
                                                          _editUser(user),
                                                      icon: const Icon(
                                                          Icons.edit_rounded,
                                                          color: Colors.blue),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Delete user',
                                                      onPressed:
                                                          _canDeleteAccounts
                                                              ? () =>
                                                                  _deleteUser(
                                                                      userId)
                                                              : null,
                                                      icon: const Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          color:
                                                              AdminTheme.error),
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
