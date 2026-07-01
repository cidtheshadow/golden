import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../models/user_model.dart';
import '../auth/auth_controller.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/service_personnel_repository.dart';
import 'package:pinput/pinput.dart';
import '../../utils/error_handler.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedCity;
  String? _selectedState;

  final List<String> _states = ['Chandigarh', 'Punjab', 'Haryana'];

  final List<String> _cities = ['Chandigarh', 'Mohali', 'Panchkula'];

  void _onCityChanged(String? city) {
    setState(() {
      _selectedCity = city;
      if (city == 'Chandigarh') {
        _selectedState = 'Chandigarh';
      } else if (city == 'Mohali') {
        _selectedState = 'Punjab';
      } else if (city == 'Panchkula') {
        _selectedState = 'Haryana';
      }
    });
  }

  String _gender = 'Male';
  List<String> _selectedSpecialties = [];
  final List<String> _specialties = [
    'Elderly Care',
    'Post-Surgical Care',
    'Physiotherapy',
    'Nursing',
    'Dementia Care',
    'Palliative Care',
    'Baby Care',
  ];

  bool _isSaving = false;
  bool _initialized = false;
  String? _uid;
  String? _initialPhone;

  // Verification state
  bool _otpSent = false;
  bool _isPhoneVerified = true;
  // ignore: unused_field
  String? _verificationId;
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _isSaving = true);
    debugPrint('[ProfileScreen] _sendOtp called for +91$phone');
    try {
      await ref.read(authControllerProvider.notifier).verifyPhone(
        '+91$phone',
        onCodeSent: (verificationId) {
          debugPrint('[ProfileScreen] onCodeSent callback received');
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isSaving = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('OTP sent!')));
        },
        onError: (error) {
          debugPrint('[ProfileScreen] onError callback: $error');
          if (!mounted) return;
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.handle(error))),
          );
        },
        onAutoVerified: (credential) async {
          debugPrint(
            '[ProfileScreen] onAutoVerified callback - phone verified automatically!',
          );
          if (!mounted) return;
          try {
            // Auto-link the credential
            final user = ref.read(authServiceProvider).currentUser;
            if (user != null) {
              await user.linkWithCredential(credential);
            }
          } on FirebaseAuthException catch (e) {
            // Linking conflicts are fine — the OTP was still valid
            if (e.code != 'credential-already-in-use' &&
                e.code != 'account-exists-with-different-credential' &&
                e.code != 'provider-already-linked') {
              debugPrint(
                '[ProfileScreen] Auto-verify linkWithCredential error: $e',
              );
              if (!mounted) return;
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Auto-verification failed: ${ErrorHandler.handle(e)}',
                  ),
                ),
              );
              return;
            }
            debugPrint(
              '[ProfileScreen] Auto-verify link conflict (${e.code}) — treating as verified',
            );
          } catch (e) {
            debugPrint(
              '[ProfileScreen] Auto-verify linkWithCredential error: $e',
            );
            if (!mounted) return;
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Auto-verification failed: ${ErrorHandler.handle(e)}',
                ),
              ),
            );
            return;
          }
          if (!mounted) return;
          setState(() {
            _isPhoneVerified = true;
            _otpSent = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number verified automatically!'),
            ),
          );
        },
      );
      // Safety: if _isSaving is still true after the call returns and 2 seconds pass,
      // it means something is wrong - release the state. On Android, verifyPhoneNumber
      // returns immediately and the callback fires later.
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _isSaving) {
          debugPrint(
            '[ProfileScreen] Safety timeout: releasing _isSaving after 30s',
          );
          setState(() => _isSaving = false);
        }
      });
    } catch (e) {
      debugPrint('[ProfileScreen] _sendOtp exception: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${ErrorHandler.handle(e)}')),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter 6-digit OTP')));
      return;
    }

    setState(() => _isSaving = true);
    debugPrint('[ProfileScreen] _verifyOtp called with OTP');
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(otp);
      if (!mounted) return;
      // If verifyOtp didn't throw, the OTP was correct (regardless of return value).
      debugPrint('[ProfileScreen] verifyOtp succeeded');
      setState(() {
        _isPhoneVerified = true;
        _otpSent = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number verified!')));
    } catch (e) {
      debugPrint('[ProfileScreen] verifyOtp error: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP verification failed: ${ErrorHandler.handle(e)}'),
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_uid == null) return;
    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your phone number first')),
      );
      return;
    }

    if (_selectedCity == null || _selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both City and State.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final fullAddress =
          '${_streetController.text.trim()}, $_selectedCity, $_selectedState - ${_pincodeController.text.trim()}, India';
      final updates = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dobController.text.trim(),
        'address': fullAddress,
        'street': _streetController.text.trim(),
        'city': _selectedCity,
        'state': _selectedState,
        'pincode': _pincodeController.text.trim(),
        'country': 'India',
      };

      await ref.read(userRepositoryProvider).updateUserProfile(_uid!, updates);

      // If role is caregiver, also update servicePersonnel
      final user = ref.read(userModelProvider).value;
      if (user?.role == 'caregiver') {
        await ref
            .read(servicePersonnelRepositoryProvider)
            .updateServicePersonnel(_uid!, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'age': int.tryParse(_ageController.text) ?? 0,
          'gender': _gender,
          'bio': _bioController.text.trim(),
          'specialties': _selectedSpecialties,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        _initialPhone = _phoneController.text.trim();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${ErrorHandler.handle(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmController = TextEditingController();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final typed = confirmController.text.trim().toUpperCase();
            final canDelete = typed == 'DELETE';

            return AlertDialog(
              title: const Text('Delete Account?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is permanent. Your account access will be removed and data may be deleted or anonymized according to policy. Active bookings must be completed or cancelled first.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Type DELETE to confirm.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: GCColors.destructive,
                  ),
                  onPressed: canDelete
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );
    confirmController.dispose();

    if (shouldDelete != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(userRepositoryProvider).requestAccountDeletion();
      if (!mounted) return;

      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.handle(e))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsyncValue = ref.watch(userModelProvider);

    return userAsyncValue.when(
      data: (UserModel? user) {
        if (user == null) {
          return const Center(
            child: Text('Please log in to view your profile.'),
          );
        }
        if (!_initialized) {
          _uid = user.uid;
          _nameController.text = user.name;
          _emailController.text = user.email;
          _phoneController.text = user.phone;
          _initialPhone = user.phone;
          if (user.dob != null) {
            _dobController.text = DateFormat('dd/MM/yyyy').format(user.dob!);
          }
          _streetController.text = user.street ?? '';
          _selectedCity = _cities
              .where((c) => c.toLowerCase() == user.city?.trim().toLowerCase())
              .firstOrNull;
          _selectedState = _states
              .where((s) => s.toLowerCase() == user.state?.trim().toLowerCase())
              .firstOrNull;
          _pincodeController.text = user.pincode ?? '';

          // Initialize caregiver fields if applicable
          if (user.role == 'caregiver') {
            _loadCaregiverData(user.uid);
          }

          _initialized = true;
        }

        bool isPhoneChanged = _phoneController.text.trim() != _initialPhone;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GCSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
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
                    // Avatar
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: GCColors.primary.withAlpha(51),
                      child: ClipOval(
                        child: (user.profileImage != null &&
                                user.profileImage!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: user.profileImage!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: GCColors.primary,
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: GCColors.primary,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 48,
                                color: GCColors.primary,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name.isNotEmpty ? user.name : 'No Name',
                      style: GCTypography.headlineLarge,
                    ),
                    Text(user.email, style: GCTypography.bodyMedium),
                    const SizedBox(height: 32),

                    // Profile form
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(GCSpacing.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Information',
                              style: GCTypography.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Account Email',
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      prefixIcon: const Icon(
                                        Icons.phone_outlined,
                                        size: 20,
                                      ),
                                      suffixIcon:
                                          isPhoneChanged && !_isPhoneVerified
                                              ? const Icon(
                                                  Icons.warning_amber,
                                                  color: Colors.orange,
                                                )
                                              : null,
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        _isPhoneVerified =
                                            v.trim() == _initialPhone;
                                      });
                                    },
                                  ),
                                ),
                                if (isPhoneChanged && !_isPhoneVerified) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _sendOtp,
                                      child: const Text('Verify'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_otpSent) ...[
                              const SizedBox(height: 16),
                              Pinput(
                                length: 6,
                                controller: _otpController,
                                onCompleted: (_) => _verifyOtp(),
                                defaultPinTheme: PinTheme(
                                  width: 48,
                                  height: 48,
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: GCColors.muted),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _sendOtp,
                                child: const Text('Resend OTP'),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextField(
                              controller: _dobController,
                              readOnly: true,
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: user.dob ?? DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() {
                                    _dobController.text = DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(date);
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth',
                                prefixIcon: Icon(Icons.cake_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _streetController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Street Address',
                                prefixIcon: Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDropdownField(
                                    value: _selectedCity,
                                    items: _cities,
                                    label: 'City',
                                    onChanged: _onCityChanged,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _pincodeController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Pincode',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDropdownField(
                                    value: _selectedState,
                                    items: _states,
                                    label: 'State',
                                    onChanged: (val) =>
                                        setState(() => _selectedState = val),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    enabled: false,
                                    decoration: InputDecoration(
                                      labelText: 'Country',
                                      filled: true,
                                      fillColor: GCColors.muted.withAlpha(51),
                                    ),
                                    controller: _countryController,
                                  ),
                                ),
                              ],
                            ),
                            if (user.role == 'caregiver') ...[
                              const SizedBox(height: 32),
                              Text(
                                'Caregiver Settings',
                                style: GCTypography.headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Age',
                                  prefixIcon: Icon(
                                    Icons.calendar_month,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _gender,
                                decoration: const InputDecoration(
                                  labelText: 'Gender',
                                  prefixIcon: Icon(Icons.wc, size: 20),
                                ),
                                items: ['Male', 'Female', 'Other']
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _gender = v!),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Specialties',
                                style: GCTypography.labelMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _specialties.map((specialty) {
                                  final isSelected =
                                      _selectedSpecialties.contains(specialty);
                                  return FilterChip(
                                    label: Text(specialty),
                                    selected: isSelected,
                                    selectedColor: GCColors.primary.withAlpha(
                                      51,
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedSpecialties.add(specialty);
                                        } else {
                                          _selectedSpecialties.remove(
                                            specialty,
                                          );
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _bioController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Bio / Professional Summary',
                                  prefixIcon: Icon(
                                    Icons.description_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                child: _isSaving
                                    ? const CircularProgressIndicator()
                                    : const Text('Save Profile'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.emergency_rounded,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Emergency Contacts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Manage contacts for caregivers',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final saved =
                              await context.pushNamed('emergencyContacts');
                          final didSave = saved == true ||
                              (saved is Map && saved['saved'] == true);
                          if (didSave && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Emergency contacts saved successfully.'),
                                backgroundColor: Color(0xFF2E7D32),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.privacy_tip_outlined),
                            title: const Text('Data Collection Policy'),
                            subtitle: const Text(
                              'See what data we collect and how it is used.',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/legal/data-collection'),
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.delete_outline_rounded,
                                color: GCColors.destructive),
                            title: const Text('Delete Account'),
                            subtitle: const Text(
                              'Permanently remove your account and request data deletion.',
                            ),
                            trailing: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                            onTap: _isSaving ? null : _confirmDeleteAccount,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign out
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                          if (context.mounted) {
                            context.go('/');
                          }
                        },
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text('Log Out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GCColors.destructive,
                          side: const BorderSide(color: GCColors.destructive),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error: ${ErrorHandler.handle(err)}')),
    );
  }

  Future<void> _loadCaregiverData(String uid) async {
    try {
      final personnel = await ref
          .read(servicePersonnelRepositoryProvider)
          .getPersonnelStream(uid)
          .first;
      if (personnel != null) {
        setState(() {
          _ageController.text = personnel.age.toString();
          _gender = personnel.gender;
          _selectedSpecialties = List.from(personnel.specialties);
          _bioController.text = personnel.bio;
        });
      }
    } catch (e) {
      debugPrint('Error loading caregiver data: $e');
    }
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
      items: items
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
