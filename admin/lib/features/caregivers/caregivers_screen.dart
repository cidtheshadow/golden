import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class CaregiversScreen extends StatefulWidget {
  const CaregiversScreen({super.key});

  @override
  State<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  List<Map<String, dynamic>> _personnel = [];
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;
  bool _isPrimaryAdmin = false;
  String? _error;

  Future<void> _uploadImage({
    required String entityType,
    required String entityId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to read image')));
      return;
    }

    final extension = (file.extension ?? '').toLowerCase();
    String contentType = 'image/jpeg';
    if (extension == 'png') {
      contentType = 'image/png';
    } else if (extension == 'webp') {
      contentType = 'image/webp';
    } else if (extension == 'gif') {
      contentType = 'image/gif';
    }

    try {
      await AdminService.instance.uploadEntityImage(
        entityType: entityType,
        entityId: entityId,
        bytes: bytes,
        contentType: contentType,
        fileName: file.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

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
      final authzResult = await AdminService.instance.getAdminAuthz();
      final personnelResult =
          await AdminService.instance.listServicePersonnel();
      final partnersResult = await AdminService.instance.listPartners();
      final personnel = List<Map<String, dynamic>>.from(
          personnelResult['personnel'] as List? ?? []);
      final partners = List<Map<String, dynamic>>.from(
          partnersResult['partners'] as List? ?? []);

      if (!mounted) {
        return;
      }
      setState(() {
        _personnel = personnel;
        _partners = partners;
        _isPrimaryAdmin = authzResult['isPrimary'] == true;
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

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Caregivers',
      currentPath: '/caregivers',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAllowListDialog,
        backgroundColor: AdminTheme.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add To Allow List'),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AdminTheme.surfaceHigh.withValues(alpha: 0.6),
                ),
              ),
              child: const Text(
                'Caregiver source of truth: servicePersonnel collection only. Allow List controls partner email access.',
                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
              ),
            ),
            const TabBar(
              indicatorColor: AdminTheme.gold,
              labelColor: AdminTheme.gold,
              unselectedLabelColor: AdminTheme.textSecondary,
              tabs: [
                Tab(text: 'Caregiver Personnel'),
                Tab(text: 'Allow List'),
              ],
            ),
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
                      : TabBarView(
                          children: [
                            _buildPersonnelTab(),
                            _buildAllowListTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelTab() {
    if (_personnel.isEmpty) {
      return const Center(
        child: Text('No caregiver personnel profiles',
            style: TextStyle(color: AdminTheme.textSecondary)),
      );
    }

    return ListView.separated(
      itemCount: _personnel.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AdminTheme.border),
      itemBuilder: (_, index) {
        final person = _personnel[index];
        final id = person['id'] as String? ?? '';
        final name = person['name'] as String? ?? id;
        final isActive = person['isActive'] as bool? ?? true;
        final isAvailable = person['isAvailable'] as bool? ?? false;
        final visitsCompleted = _toInt(person['visitsCompleted']);
        final experienceYears = _toNum(person['experienceYears']);
        final reviews = _extractReviews(person['reviews']);
        final imageUrl = (person['profileImage'] as String? ??
                person['imageUrl'] as String? ??
                '')
            .trim();

        return ListTile(
          tileColor: AdminTheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.teal.withValues(alpha: 0.2),
            backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
            child: imageUrl.isEmpty
                ? const Icon(Icons.person_rounded, color: Colors.teal)
                : null,
          ),
          title:
              Text(name, style: const TextStyle(color: AdminTheme.textPrimary)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID: $id • ${isAvailable ? 'Available' : 'Unavailable'} • ${isActive ? 'Active' : 'Inactive'}',
                style: const TextStyle(
                    color: AdminTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                'Visits: $visitsCompleted • Experience: ${experienceYears.toStringAsFixed(experienceYears % 1 == 0 ? 0 : 1)} yrs • Reviews: ${reviews.length}',
                style: const TextStyle(
                    color: AdminTheme.textSecondary, fontSize: 12),
              ),
              _HorizontalActions(
                actions: [
                  _InlineAction(
                    label: 'Reviews',
                    icon: Icons.reviews_rounded,
                    color: Colors.purple,
                    onTap: () => _showPersonnelReviewsDialog(person),
                  ),
                  if (_isPrimaryAdmin)
                    _InlineAction(
                      label: 'Edit Stats',
                      icon: Icons.edit_note_rounded,
                      color: Colors.amber,
                      onTap: () => _showEditStatsDialog(person),
                    ),
                  _InlineAction(
                    label: 'Photo',
                    icon: Icons.image_rounded,
                    color: Colors.blueGrey,
                    onTap: () => _uploadImage(
                      entityType: 'service_personnel',
                      entityId: id,
                    ),
                  ),
                  _InlineAction(
                    label: 'Bookings',
                    icon: Icons.calendar_month_rounded,
                    color: Colors.teal,
                    onTap: () => _openFiltered(
                      '/bookings',
                      {'servicePersonnelId': id},
                    ),
                  ),
                  _InlineAction(
                    label: 'Transactions',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.indigo,
                    onTap: () => _openFiltered(
                      '/transactions',
                      {'servicePersonnelId': id},
                    ),
                  ),
                  _InlineAction(
                    label: isAvailable ? 'Unavailable' : 'Available',
                    icon: Icons.person_pin_circle_rounded,
                    color: isAvailable ? Colors.orange : Colors.green,
                    onTap: () => _togglePersonnelAvailability(id, isAvailable),
                  ),
                  _InlineAction(
                    label: 'Deactivate',
                    icon: Icons.block_rounded,
                    color: AdminTheme.error,
                    onTap: () => _deactivatePersonnel(id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllowListTab() {
    if (_partners.isEmpty) {
      return const Center(
        child: Text('No allow-list entries',
            style: TextStyle(color: AdminTheme.textSecondary)),
      );
    }

    return ListView.separated(
      itemCount: _partners.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AdminTheme.border),
      itemBuilder: (_, index) {
        final partner = _partners[index];
        final email =
            (partner['email'] as String?) ?? (partner['id'] as String? ?? '');
        final isActive = partner['isActive'] as bool? ?? true;

        return ListTile(
          tileColor: AdminTheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Icon(
            isActive ? Icons.verified_rounded : Icons.block_rounded,
            color: isActive ? Colors.green : AdminTheme.error,
            size: 18,
          ),
          title: Text(email,
              style:
                  const TextStyle(color: AdminTheme.textPrimary, fontSize: 13)),
          subtitle: _HorizontalActions(
            actions: [
              _InlineAction(
                label: isActive ? 'Disable' : 'Enable',
                icon: isActive
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: isActive ? Colors.orange : Colors.green,
                onTap: () => _togglePartner(email, isActive),
              ),
              _InlineAction(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                color: AdminTheme.error,
                onTap: () => _deletePartner(email),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _togglePersonnelAvailability(
      String personnelId, bool isAvailable) async {
    try {
      await AdminService.instance.updateServicePersonnel(
          personnelId, {'isAvailable': !isAvailable, 'isActive': true});
      if (!mounted) {
        return;
      }
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(!isAvailable
                ? 'Personnel marked available'
                : 'Personnel marked unavailable')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deactivatePersonnel(String personnelId) async {
    try {
      await AdminService.instance.deleteServicePersonnel(personnelId);
      if (!mounted) {
        return;
      }
      _load();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Personnel deactivated')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _togglePartner(String email, bool isActive) async {
    try {
      await AdminService.instance.upsertPartner(email, !isActive);
      if (!mounted) {
        return;
      }
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(!isActive ? 'Allow-list enabled' : 'Allow-list disabled')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deletePartner(String email) async {
    try {
      await AdminService.instance.deletePartner(email);
      if (!mounted) {
        return;
      }
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allow-list entry deleted')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showAddAllowListDialog() async {
    final emailController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: const Text('Add Allow-List Email',
            style: TextStyle(color: AdminTheme.textPrimary)),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Partner email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim().toLowerCase();
              Navigator.of(context).pop();
              if (email.isEmpty) {
                return;
              }
              try {
                await AdminService.instance.upsertPartner(email, true);
                if (!mounted) {
                  return;
                }
                _load();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Allow-list entry added')));
              } catch (e) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    emailController.dispose();
  }

  List<Map<String, dynamic>> _extractReviews(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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

  double _toNum(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
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

  String _formatDate(dynamic value) {
    final date = _toDate(value);
    if (date == null) {
      return 'Date unavailable';
    }
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  Future<void> _showEditStatsDialog(Map<String, dynamic> person) async {
    if (!_isPrimaryAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Only Primary Admins can update visits completed and experience years'),
        ),
      );
      return;
    }

    final id = person['id'] as String? ?? '';
    final visitsController = TextEditingController(
        text: _toInt(person['visitsCompleted']).toString());
    final yearsController = TextEditingController(
      text: _toNum(person['experienceYears']).toString(),
    );

    final rootContext = context;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: const Text('Edit Caregiver Stats',
            style: TextStyle(color: AdminTheme.textPrimary)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: visitsController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Visits Completed'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: yearsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Experience Years'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () async {
              final visits = int.tryParse(visitsController.text.trim());
              final years = double.tryParse(yearsController.text.trim());
              if (visits == null || visits < 0 || years == null || years < 0) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Enter valid non-negative numbers for visits and years'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop();
              try {
                await AdminService.instance.updateServicePersonnel(id, {
                  'visitsCompleted': visits,
                  'experienceYears': years,
                });
                if (!rootContext.mounted) {
                  return;
                }
                _load();
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('Caregiver stats updated')),
                );
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

    visitsController.dispose();
    yearsController.dispose();
  }

  Future<void> _showPersonnelReviewsDialog(Map<String, dynamic> person) async {
    final name =
        (person['name'] as String? ?? person['id'] as String? ?? '').trim();
    final reviews = _extractReviews(person['reviews']);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: Text('Reviews: ${name.isEmpty ? 'Caregiver' : name}',
            style: const TextStyle(color: AdminTheme.textPrimary)),
        content: SizedBox(
          width: 760,
          child: reviews.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No reviews yet. Reviews are visible here in read-only mode.',
                    style: TextStyle(color: AdminTheme.textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AdminTheme.border, height: 14),
                  itemBuilder: (_, index) {
                    final review = reviews[index];
                    final rating = _toNum(review['rating']);
                    final comment = (review['comment'] as String? ?? '').trim();
                    final reviewer =
                        (review['userName'] as String? ?? 'User').trim();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.star_rounded,
                                  size: 14, color: Colors.amber),
                              label: Text(rating
                                  .toStringAsFixed(rating % 1 == 0 ? 0 : 1)),
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              reviewer,
                              style: const TextStyle(
                                  color: AdminTheme.textPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _formatDate(review['createdAt']),
                              style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment.isEmpty ? '(No comment)' : comment,
                          style:
                              const TextStyle(color: AdminTheme.textSecondary),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
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
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.55)),
        backgroundColor: color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
    );
  }
}

class _HorizontalActions extends StatelessWidget {
  const _HorizontalActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions
            .map((action) => Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: action,
                ))
            .toList(),
      ),
    );
  }
}
