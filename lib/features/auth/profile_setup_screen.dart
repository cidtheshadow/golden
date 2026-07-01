import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pinput/pinput.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../core/utils/permission_flow_helper.dart';
import '../../firebase/storage_service.dart';
import '../../repositories/user_repository.dart';
import '../auth/auth_controller.dart';
import '../../models/user_model.dart';
import '../../utils/error_handler.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  // Structured Address Controllers
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');

  // Caregiver Specific Controllers
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  String _gender = 'Male';
  final List<String> _selectedSpecialties = [];

  DateTime? _selectedDob;
  String? _profileImageUrl;
  bool _isLoading = false;

  // Verification state
  bool _otpSent = false;
  bool _isPhoneVerified = false;
  // ignore: unused_field
  String? _verificationId;
  bool _isInitialized = false;

  final List<String> _states = ['Chandigarh', 'Punjab', 'Haryana'];

  final List<String> _cities = ['Chandigarh', 'Mohali', 'Panchkula'];

  final List<String> _allSpecialties = [
    'Companion Care',
    'Post-Surgical Care',
    'Dementia Care',
    'Assisted Living',
    'Physical Therapy',
    'Nursing',
    'Palliative Care',
  ];

  String? _selectedState;
  String? _selectedCity;

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

  @override
  void initState() {
    super.initState();
  }

  void _initializeData(UserModel user) {
    if (_isInitialized) return;

    _nameController.text = user.name;
    _phoneController.text = user.phone;
    if (user.phone.isNotEmpty) {
      _isPhoneVerified = true;
    }
    _streetController.text = user.street ?? '';
    _pincodeController.text = user.pincode ?? '';

    if (user.city != null) {
      _selectedCity = _cities
          .where((c) => c.toLowerCase() == user.city!.toLowerCase())
          .firstOrNull;
    }
    if (user.state != null) {
      _selectedState = _states
          .where((s) => s.toLowerCase() == user.state!.toLowerCase())
          .firstOrNull;
    }

    _selectedDob = user.dob;
    _profileImageUrl = user.profileImage;

    _isInitialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose Image Source'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Row(
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 8),
                Text('Camera'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Row(
              children: [
                Icon(Icons.photo_library),
                SizedBox(width: 8),
                Text('Gallery'),
              ],
            ),
          ),
        ],
      ),
    );

    if (source == null) return;
    if (!mounted) return;

    if (source == ImageSource.camera) {
      final cameraAllowed = await PermissionFlowHelper.ensureCameraPermission(
        context,
        feature: 'taking your profile photo',
      );
      if (!mounted) return;
      if (!cameraAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera permission is required to take a photo. You can try again from the camera option.',
            ),
          ),
        );
        return;
      }
    }

    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(userModelProvider).value;
      if (user != null) {
        final url = await StorageService().uploadProfileImage(
          user.uid,
          await image.readAsBytes(),
          contentType: image.mimeType,
        );
        if (mounted && url != null) {
          setState(() {
            _profileImageUrl = url;
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Photo uploaded!')));
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: ${ErrorHandler.handle(e)}')),
        );
      }
    }
  }

  Future<void> _pickPhoneNumber() async {
    // Removed phone_number_hint due to crashes on certain Android versions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter your phone number manually')),
    );
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyPhone(
        '+91$phone',
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OTP sent to +91$phone')));
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.handle(error))),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.handle(e))));
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

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(otp);
      if (!mounted) return;
      // If verifyOtp didn't throw, the OTP was correct (regardless of return value).
      setState(() {
        _isPhoneVerified = true;
        _otpSent = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number verified!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP verification failed: ${ErrorHandler.handle(e)}'),
        ),
      );
    }
  }

  Future<void> _completeProfile() async {
    if (_formKey.currentState!.validate()) {
      if (!_isPhoneVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify your phone number first'),
          ),
        );
        return;
      }
      if (_selectedDob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your Date of Birth')),
        );
        return;
      }

      // Validate minimum age of 21
      final today = DateTime.now();
      final minBirthDate = DateTime(today.year - 21, today.month, today.day);
      if (_selectedDob!.isAfter(minBirthDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be at least 21 years old to register'),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final city = _selectedCity ?? _cityController.text.trim();
        final state = _selectedState ?? _stateController.text.trim();
        final fullAddress =
            '${_streetController.text.trim()}, $city, $state - ${_pincodeController.text.trim()}, India';

        final user = ref.read(userModelProvider).value;
        if (user != null) {
          final updatedUser = user.copyWith(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: fullAddress,
            street: _streetController.text.trim(),
            city: city,
            state: state,
            pincode: _pincodeController.text.trim(),
            dob: _selectedDob,
            profileImage: _profileImageUrl ?? user.profileImage,
          );

          await ref
              .read(userRepositoryProvider)
              .createOrUpdateUser(updatedUser);

          // For caregivers, do NOT create a skeleton personnel doc here.
          // The PartnerRegistrationScreen handles the full personnel profile.
          // The router will redirect caregivers to /partner/register after user profile is saved.

          if (mounted) {
            context.go('/'); // Redirection will be handled by router
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(ErrorHandler.handle(e))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userModelProvider);
    final isCaregiver = userAsync.value?.role == 'caregiver';

    // Reactively initialize data when available
    userAsync.whenData((user) {
      if (user != null) _initializeData(user);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: GCColors.destructive),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GCSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                isCaregiver
                    ? 'Complete your caregiver profile to start taking jobs.'
                    : 'Please provide your details to continue using Golden Care.',
                style: const TextStyle(
                  fontSize: 16,
                  color: GCColors.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 64,
                      backgroundColor: GCColors.muted,
                      child: ClipOval(
                        child: _profileImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _profileImageUrl!,
                                width: 128,
                                height: 128,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: GCColors.mutedForeground,
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: GCColors.mutedForeground,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 60,
                                color: GCColors.mutedForeground,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: GCColors.primary,
                        radius: 20,
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                _nameController,
                'Full Name',
                Icons.person_outline,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 3) return 'Too short';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_isPhoneVerified,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.contact_phone_outlined,
                            size: 18,
                          ),
                          onPressed: _isPhoneVerified ? null : _pickPhoneNumber,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) {
                          return 'Enter 10 digits';
                        }
                        return null;
                      },
                      onChanged: (v) {
                        if (_isPhoneVerified) {
                          setState(() => _isPhoneVerified = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_isPhoneVerified)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Verify'),
                      ),
                    )
                  else
                    const SizedBox(
                      height: 56,
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                ],
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                Text(
                  'Enter 6-digit OTP sent to +91${_phoneController.text}',
                  style: GCTypography.bodySmall,
                ),
                const SizedBox(height: 8),
                Pinput(
                  length: 6,
                  controller: _otpController,
                  onCompleted: (_) => _verifyOtp(),
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 20,
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
              if (isCaregiver) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _ageController,
                        'Age',
                        Icons.calendar_month_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                        value: _gender,
                        items: ['Male', 'Female', 'Other'],
                        label: 'Gender',
                        onChanged: (val) => setState(() => _gender = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _bioController,
                  'Short Bio',
                  Icons.info_outline,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Specialties',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _allSpecialties.map((s) {
                    final isSelected = _selectedSpecialties.contains(s);
                    return FilterChip(
                      label: Text(s),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSpecialties.add(s);
                          } else {
                            _selectedSpecialties.remove(s);
                          }
                        });
                      },
                      selectedColor: GCColors.primary.withAlpha(51),
                      checkmarkColor: GCColors.primary,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              _buildTextField(
                _streetController,
                'Street Address',
                Icons.home_outlined,
                maxLines: 2,
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
                    child: _buildTextField(
                      _pincodeController,
                      'Pincode',
                      null,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!RegExp(r'^[0-9]{6}$').hasMatch(v)) {
                          return 'Enter 6 digits';
                        }
                        if (_selectedCity == 'Chandigarh' &&
                            !v.startsWith('160')) {
                          return 'Pin must start with 160';
                        }
                        if (_selectedCity == 'Mohali' &&
                            !(v.startsWith('140') || v.startsWith('160'))) {
                          return 'Invalid Mohali Pin';
                        }
                        if (_selectedCity == 'Panchkula' &&
                            !v.startsWith('134')) {
                          return 'Pin must start with 134';
                        }
                        return null;
                      },
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
                      onChanged: (val) => setState(() => _selectedState = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      _countryController,
                      'Country',
                      null,
                      enabled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final max21YearsAgo =
                      DateTime(now.year - 21, now.month, now.day);
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDob != null &&
                            _selectedDob!.isBefore(max21YearsAgo)
                        ? _selectedDob!
                        : max21YearsAgo,
                    firstDate: DateTime(1900),
                    lastDate: max21YearsAgo,
                  );
                  if (picked != null) {
                    setState(() => _selectedDob = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.cake_outlined, size: 20),
                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                  ),
                  child: Text(
                    _selectedDob != null
                        ? DateFormat('MMM dd, yyyy').format(_selectedDob!)
                        : 'Select Date',
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Complete Setup',
                            style: TextStyle(fontSize: 18),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ?? (v) => v!.isEmpty ? 'Required' : null,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: !enabled,
        fillColor: enabled ? null : GCColors.muted.withAlpha(51),
      ),
    );
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
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}
