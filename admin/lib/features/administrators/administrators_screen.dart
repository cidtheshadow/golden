import 'package:flutter/material.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class AdministratorsScreen extends StatefulWidget {
  const AdministratorsScreen({super.key});

  @override
  State<AdministratorsScreen> createState() => _AdministratorsScreenState();
}

class _AdministratorsScreenState extends State<AdministratorsScreen> {
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;
  String? _error;
  bool _canManageAdmins = false;
  bool _isRootAdmin = false;
  String _callerAdminType = 'secondary';
  String _rootAdminEmail = 'admin@goldencares.in';

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AdminService.instance.listAdmins(limit: 200);
      final admins =
          List<Map<String, dynamic>>.from(result['admins'] as List? ?? []);
      if (!mounted) {
        return;
      }
      setState(() {
        _admins = admins;
        final caller =
            Map<String, dynamic>.from(result['caller'] as Map? ?? const {});
        _canManageAdmins = caller['canManageAdmins'] == true;
        _isRootAdmin = caller['isRoot'] == true;
        _callerAdminType =
            (caller['adminType'] as String? ?? 'secondary').toLowerCase();
        _rootAdminEmail =
            (result['rootAdminEmail'] as String? ?? 'admin@goldencares.in')
                .trim()
                .toLowerCase();
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

  Future<void> _showGrantAdminDialog({String initialType = 'secondary'}) async {
    final rootContext = context;
    final emailController = TextEditingController();
    final uidController = TextEditingController();
    String adminType = initialType;

    if (!_canManageAdmins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Only primary admins can create administrator accounts'),
        ),
      );
      emailController.dispose();
      uidController.dispose();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
                backgroundColor: AdminTheme.surface,
                title: const Text('Grant Admin Role'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                            labelText: 'Email (preferred)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: uidController,
                        decoration:
                            const InputDecoration(labelText: 'UID (optional)'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: adminType,
                        decoration:
                            const InputDecoration(labelText: 'Admin Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'primary', child: Text('Primary')),
                          DropdownMenuItem(
                              value: 'secondary', child: Text('Secondary')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setLocalState(() => adminType = value);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Dismiss')),
                  ElevatedButton(
                    onPressed: () async {
                      final email = emailController.text.trim();
                      final uid = uidController.text.trim();
                      Navigator.of(context).pop();

                      if (email.isEmpty && uid.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Provide an email or UID to continue')),
                        );
                        return;
                      }

                      try {
                        final result =
                            await AdminService.instance.grantAdminRole(
                          email: email.isEmpty ? null : email,
                          uid: uid.isEmpty ? null : uid,
                          adminType: adminType,
                        );
                        final createdEmail =
                            (result['email'] as String? ?? email).trim();
                        final temporaryPassword =
                            (result['temporaryPassword'] as String? ?? '')
                                .trim();
                        if (!rootContext.mounted) return;
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${adminType.toUpperCase()} administrator added')),
                        );
                        if (temporaryPassword.isNotEmpty) {
                          await _showGeneratedPasswordDialog(
                            rootContext,
                            createdEmail,
                            temporaryPassword,
                          );
                        }
                        _loadAdmins();
                      } catch (e) {
                        if (!rootContext.mounted) return;
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    },
                    child: const Text('Grant Access'),
                  ),
                ],
              )),
    );
    emailController.dispose();
    uidController.dispose();
  }

  Future<void> _showGeneratedPasswordDialog(
    BuildContext rootContext,
    String email,
    String password,
  ) async {
    await showDialog<void>(
      context: rootContext,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: const Text('Temporary Login Password'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email.isEmpty
                    ? 'A new administrator login was created.'
                    : 'A new administrator login was created for $email.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Share this password securely. It is shown only once.',
                style: TextStyle(color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              SelectableText(
                password,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ask the admin to change their password immediately after first login.',
                style: TextStyle(color: AdminTheme.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  bool _canRemoveAdmin(Map<String, dynamic> admin) {
    final email = (admin['email'] as String? ?? '').trim().toLowerCase();
    final isPrimary = admin['isPrimary'] == true;
    final isRoot = admin['isRoot'] == true || email == _rootAdminEmail;

    if (!_canManageAdmins) {
      return false;
    }
    if (isRoot) {
      return false;
    }
    if (isPrimary && !_isRootAdmin) {
      return false;
    }
    return true;
  }

  Future<void> _removeAdmin(String email) async {
    if (!_canManageAdmins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only primary admins can remove administrators'),
        ),
      );
      return;
    }

    try {
      await AdminService.instance.removeAdmin(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Administrator removed')));
      _loadAdmins();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Administrators',
      currentPath: '/administrators',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _canManageAdmins
                      ? () => _showGrantAdminDialog(initialType: 'primary')
                      : null,
                  icon:
                      const Icon(Icons.admin_panel_settings_rounded, size: 16),
                  label: const Text('Add Primary Admin'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _canManageAdmins
                      ? () => _showGrantAdminDialog(initialType: 'secondary')
                      : null,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Add Secondary Admin'),
                ),
                Chip(
                  avatar: const Icon(Icons.verified_user_rounded, size: 16),
                  label: Text(_callerAdminType == 'primary'
                      ? 'You are Primary Admin'
                      : 'You are Secondary Admin'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
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
                    : _admins.isEmpty
                        ? const Center(
                            child: Text(
                              'No active administrators',
                              style: TextStyle(color: AdminTheme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _admins.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: AdminTheme.border),
                            itemBuilder: (_, index) {
                              final admin = _admins[index];
                              final email =
                                  (admin['email'] as String? ?? '').trim();
                              final uid =
                                  (admin['uid'] as String? ?? '').trim();
                              final isPrimary = admin['isPrimary'] == true;
                              final isRoot = admin['isRoot'] == true;
                              final mustChangePassword =
                                  admin['mustChangePassword'] == true;
                              final canRemove = _canRemoveAdmin(admin);
                              return ListTile(
                                tileColor: AdminTheme.surface,
                                leading: const Icon(Icons.shield_rounded,
                                    color: AdminTheme.gold),
                                title: Text(
                                  email.isEmpty ? '(unknown email)' : email,
                                  style: const TextStyle(
                                      color: AdminTheme.textPrimary),
                                ),
                                subtitle: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      uid.isEmpty ? 'UID unavailable' : uid,
                                      style: const TextStyle(
                                          color: AdminTheme.textSecondary,
                                          fontSize: 12),
                                    ),
                                    Chip(
                                      label: Text(
                                          isPrimary ? 'Primary' : 'Secondary'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (isRoot)
                                      const Chip(
                                        label: Text('Root'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    if (mustChangePassword)
                                      const Chip(
                                        label: Text('Password Reset Pending'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: 'Remove administrator',
                                  onPressed: email.isEmpty || !canRemove
                                      ? null
                                      : () => _removeAdmin(email),
                                  icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: AdminTheme.error),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
