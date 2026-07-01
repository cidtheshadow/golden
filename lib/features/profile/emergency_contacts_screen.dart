import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  final List<_ContactFormData> _contacts = [];
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _loaded = true);
      }
      return;
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final existing = (doc.data()?['emergencyContacts'] as List? ?? [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    if (!mounted) return;
    setState(() {
      _contacts
        ..clear()
        ..addAll(
          existing.map(
            (contact) => _ContactFormData(
              name: contact['name'] as String? ?? '',
              phone: contact['phone'] as String? ??
                  contact['number'] as String? ??
                  '',
              relationship: contact['relationship'] as String? ??
                  contact['relation'] as String? ??
                  '',
            ),
          ),
        );
      if (_contacts.isEmpty) {
        _contacts.add(_ContactFormData());
      }
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final filledContacts = _contacts
        .where((contact) =>
            contact.nameCtrl.text.trim().isNotEmpty ||
            contact.phoneCtrl.text.trim().isNotEmpty ||
            contact.relationCtrl.text.trim().isNotEmpty)
        .toList();

    if (filledContacts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one emergency contact.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    var allValid = true;
    for (final contact in filledContacts) {
      final isValid = contact.formKey.currentState?.validate() ?? false;
      if (!isValid) {
        allValid = false;
      }
    }
    if (!allValid) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final payload = _contacts
          .where((contact) =>
              contact.nameCtrl.text.trim().isNotEmpty &&
              contact.phoneCtrl.text.trim().isNotEmpty &&
              contact.relationCtrl.text.trim().isNotEmpty)
          .map(
            (contact) => {
              'name': contact.nameCtrl.text.trim(),
              'phone': contact.phoneCtrl.text.trim(),
              'relationship': contact.relationCtrl.text.trim(),
              'relation': contact.relationCtrl.text.trim(),
            },
          )
          .toList();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'emergencyContacts': payload,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contacts saved successfully.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addContact() {
    setState(() => _contacts.add(_ContactFormData()));
  }

  void _removeContact(int index) {
    final contact = _contacts.removeAt(index);
    contact.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFB8860B),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFB8860B).withAlpha(102),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFB8860B),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'These contacts will be shared with your assigned caregiver in case of emergency. Add up to 3 contacts.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...List.generate(
                        _contacts.length,
                        (index) => _ContactForm(
                          key: ValueKey(index),
                          data: _contacts[index],
                          index: index,
                          canDelete: _contacts.length > 1,
                          onDelete: () => _removeContact(index),
                        ),
                      ),
                      if (_contacts.length < 3) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addContact,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Another Contact'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB8860B),
                            side: const BorderSide(color: Color(0xFFB8860B)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size(double.infinity, 0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB8860B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Emergency Contacts',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ContactFormData {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final relationCtrl = TextEditingController();

  _ContactFormData({
    String name = '',
    String phone = '',
    String relationship = '',
  }) {
    nameCtrl.text = name;
    phoneCtrl.text = phone;
    relationCtrl.text = relationship;
  }

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    relationCtrl.dispose();
  }
}

class _ContactForm extends StatelessWidget {
  final _ContactFormData data;
  final int index;
  final bool canDelete;
  final VoidCallback onDelete;

  const _ContactForm({
    super.key,
    required this.data,
    required this.index,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: data.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contact ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB8860B),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Phone is required';
                }
                if (value!.trim().length < 10) {
                  return 'Enter valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.relationCtrl,
              decoration: const InputDecoration(
                labelText: 'Relationship *',
                hintText: 'e.g. Son, Daughter, Spouse',
                prefixIcon: Icon(Icons.people_rounded),
              ),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? 'Relationship is required'
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
