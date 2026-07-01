import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinput/pinput.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../core/spacing.dart';
import '../../core/utils/permission_flow_helper.dart';
import '../../repositories/service_personnel_repository.dart';
import '../../repositories/user_repository.dart';
import '../../firebase/storage_service.dart';
import '../../firebase/firestore_service.dart';
import '../auth/auth_controller.dart';
import 'partner_providers.dart';
import '../../utils/error_handler.dart';

class PartnerProfileScreen extends ConsumerStatefulWidget {
  const PartnerProfileScreen({super.key});

  @override
  ConsumerState<PartnerProfileScreen> createState() =>
      _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends ConsumerState<PartnerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _specialtiesController;
  late TextEditingController _languagesController;
  late TextEditingController _skillsController;
  late TextEditingController _streetController;
  late TextEditingController _pincodeController;
  late TextEditingController _experienceController;
  late TextEditingController _bioController;
  final _otpController = TextEditingController();

  String _selectedGender = 'Male';
  String? _selectedCity;
  String? _selectedState;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _controllersInitialized = false;

  // OTP state
  bool _otpSent = false;
  bool _isPhoneVerified = true; // Starts verified (existing phone)
  String? _initialPhone;
  // ignore: unused_field
  String? _verificationId;

  final List<String> _genderOptions = ['Male', 'Female', 'Others'];
  final List<String> _cities = ['Chandigarh', 'Mohali', 'Panchkula'];
  final List<String> _states = ['Chandigarh', 'Punjab', 'Haryana'];

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

  void _initControllers() {
    final personnel = ref.read(currentPersonnelProvider).value;

    _nameController = TextEditingController(text: personnel?.name ?? '');
    _ageController =
        TextEditingController(text: personnel?.age.toString() ?? '');
    _phoneController = TextEditingController(text: personnel?.phone ?? '');
    _emailController = TextEditingController(text: personnel?.email ?? '');

    _specialtiesController =
        TextEditingController(text: personnel?.specialties.join(', ') ?? '');
    _languagesController =
        TextEditingController(text: personnel?.languages.join(', ') ?? '');
    _skillsController =
        TextEditingController(text: personnel?.keySkills.join(', ') ?? '');

    _streetController = TextEditingController(text: personnel?.street ?? '');
    _pincodeController = TextEditingController(text: personnel?.pincode ?? '');
    _experienceController = TextEditingController(
        text: (personnel?.experienceYears ?? 0) > 0
            ? personnel!.experienceYears.toString()
            : '');
    _bioController = TextEditingController(text: personnel?.bio ?? '');

    _selectedGender = personnel?.gender ?? 'Male';
    if (!_genderOptions.contains(_selectedGender)) {
      _selectedGender = 'Male';
    }
    _initialPhone = personnel?.phone ?? '';

    // Initialize address from personnel or user model
    _selectedCity = _cities
        .where((c) => c.toLowerCase() == (personnel?.city ?? '').toLowerCase())
        .firstOrNull;
    _selectedState = _states
        .where((s) => s.toLowerCase() == (personnel?.state ?? '').toLowerCase())
        .firstOrNull;

    // If personnel doesn't have address, try loading from user model
    if (_selectedCity == null && _streetController.text.isEmpty) {
      _loadAddressFromUser();
    }

    _controllersInitialized = true;
  }

  Future<void> _loadAddressFromUser() async {
    final user = ref.read(userModelProvider).value;
    if (user == null) return;
    setState(() {
      if (_streetController.text.isEmpty) {
        _streetController.text = user.street ?? '';
      }
      if (_pincodeController.text.isEmpty) {
        _pincodeController.text = user.pincode ?? '';
      }
      _selectedCity ??= _cities
          .where((c) => c.toLowerCase() == (user.city ?? '').toLowerCase())
          .firstOrNull;
      _selectedState ??= _states
          .where((s) => s.toLowerCase() == (user.state ?? '').toLowerCase())
          .firstOrNull;
    });
  }

  void _resetControllers() {
    final personnel = ref.read(currentPersonnelProvider).value;
    if (personnel == null) return;

    _nameController.text = personnel.name;
    _ageController.text = personnel.age.toString();
    _phoneController.text = personnel.phone;
    _emailController.text = personnel.email;
    _specialtiesController.text = personnel.specialties.join(', ');
    _languagesController.text = personnel.languages.join(', ');
    _skillsController.text = personnel.keySkills.join(', ');
    _streetController.text = personnel.street;
    _pincodeController.text = personnel.pincode;
    _experienceController.text = personnel.experienceYears > 0
        ? personnel.experienceYears.toString()
        : '';
    _bioController.text = personnel.bio;
    _selectedGender =
        _genderOptions.contains(personnel.gender) ? personnel.gender : 'Male';
    _initialPhone = personnel.phone;
    _isPhoneVerified = true;
    _otpSent = false;
    _otpController.clear();
    _selectedCity = _cities
        .where((c) => c.toLowerCase() == personnel.city.toLowerCase())
        .firstOrNull;
    _selectedState = _states
        .where((s) => s.toLowerCase() == personnel.state.toLowerCase())
        .firstOrNull;
  }

  @override
  void dispose() {
    if (_controllersInitialized) {
      _nameController.dispose();
      _ageController.dispose();
      _phoneController.dispose();
      _emailController.dispose();
      _specialtiesController.dispose();
      _languagesController.dispose();
      _skillsController.dispose();
      _streetController.dispose();
      _pincodeController.dispose();
      _experienceController.dispose();
      _bioController.dispose();
    }
    _otpController.dispose();
    super.dispose();
  }

  // ── OTP Methods ──────────────────────────────────────────

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid 10-digit phone number')));
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('OTP sent!')));
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ErrorHandler.handle(error))));
        },
        onAutoVerified: (credential) async {
          if (!mounted) return;
          try {
            final user = ref.read(authServiceProvider).currentUser;
            if (user != null) {
              await user.linkWithCredential(credential);
            }
          } on FirebaseAuthException catch (e) {
            // Linking conflicts are fine — the OTP was still valid
            if (e.code != 'credential-already-in-use' &&
                e.code != 'account-exists-with-different-credential' &&
                e.code != 'provider-already-linked') {
              if (!mounted) return;
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Auto-verification failed: ${ErrorHandler.handle(e)}')));
              return;
            }
            debugPrint(
                '[PartnerProfile] Auto-verify link conflict (${e.code}) — treating as verified');
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Auto-verification failed: ${ErrorHandler.handle(e)}')));
            return;
          }
          if (!mounted) return;
          setState(() {
            _isPhoneVerified = true;
            _otpSent = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone verified automatically!')));
        },
      );
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ErrorHandler.handle(e)}')));
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter 6-digit OTP')));
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number verified!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('OTP verification failed: ${ErrorHandler.handle(e)}')));
    }
  }

  // ── Image Upload ─────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    final storage = StorageService();
    final picker = ImagePicker();

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose Image Source'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Row(children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 8),
              Text('Take a Photo')
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Row(children: [
              Icon(Icons.photo_library),
              SizedBox(width: 8),
              Text('Choose from Gallery')
            ]),
          ),
        ],
      ),
    );

    if (source == null) return;
    if (!mounted) return;

    if (source == ImageSource.camera) {
      final cameraAllowed = await PermissionFlowHelper.ensureCameraPermission(
        context,
        feature: 'capturing your updated profile photo',
      );
      if (!mounted) return;
      if (!cameraAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera permission is required to take a photo. Please allow and try again.',
            ),
          ),
        );
        return;
      }
    }

    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    setState(() => _isLoading = true);

    final personnel = ref.read(currentPersonnelProvider).value;
    if (personnel == null) return;

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final url = await storage.uploadProfileImage(
      authUid ?? personnel.id,
      await image.readAsBytes(),
      contentType: image.mimeType,
    );

    if (!mounted) return;

    if (url != null) {
      await FirestoreService()
          .updateServicePersonnel(personnel.id, {'imageUrl': url});
      // Invalidate the provider so the avatar refreshes
      if (mounted) {
        ref.invalidate(currentPersonnelProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated!')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Save Profile ─────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please verify your phone number first')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final personnel = ref.read(currentPersonnelProvider).value;
      if (personnel == null) return;

      List<String> specialties = _specialtiesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      List<String> languages = _languagesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      List<String> skills = _skillsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updatedData = {
        'name': _nameController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'gender': _selectedGender,
        'phone': _phoneController.text.trim(),
        'specialties': specialties,
        'languages': languages,
        'keySkills': skills,
        'street': _streetController.text.trim(),
        'city': _selectedCity ?? '',
        'state': _selectedState ?? '',
        'pincode': _pincodeController.text.trim(),
        'country': 'India',
        'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
        'bio': _bioController.text.trim(),
      };

      await ref
          .read(servicePersonnelRepositoryProvider)
          .updateServicePersonnel(personnel.id, updatedData);

      // Also update user document with address
      final fullAddress =
          '${_streetController.text.trim()}, ${_selectedCity ?? ''}, ${_selectedState ?? ''} - ${_pincodeController.text.trim()}, India';
      await ref.read(userRepositoryProvider).updateUserProfile(personnel.id, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': fullAddress,
        'street': _streetController.text.trim(),
        'city': _selectedCity ?? '',
        'state': _selectedState ?? '',
        'pincode': _pincodeController.text.trim(),
        'country': 'India',
      });

      setState(() {
        _isEditing = false;
        _isLoading = false;
        _initialPhone = _phoneController.text.trim();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final personnelAsync = ref.watch(currentPersonnelProvider);

    return personnelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: ${ErrorHandler.handle(e)}')),
      data: (personnel) {
        if (personnel == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!_controllersInitialized) {
          _initControllers();
        }

        final bool isPhoneChanged =
            _phoneController.text.trim() != _initialPhone;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(GCSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Edit toggle
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(_isEditing ? Icons.close : Icons.edit),
                        onPressed: () {
                          if (_isEditing) {
                            _resetControllers();
                          }
                          setState(() => _isEditing = !_isEditing);
                        },
                      ),
                    ),

                    // ── Profile Image ───────────────────
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            child: ClipOval(
                              child: personnel.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: personnel.imageUrl,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          const Icon(Icons.person, size: 50),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.person, size: 50),
                                    )
                                  : const Icon(Icons.person, size: 50),
                            ),
                          ),
                          if (_isLoading)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                            ),
                          if (_isEditing && !_isLoading)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: const CircleAvatar(
                                  backgroundColor: GCColors.primary,
                                  radius: 16,
                                  child: Icon(Icons.camera_alt,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Name ────────────────────────────
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'Full Name', border: OutlineInputBorder()),
                      enabled: _isEditing,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v)) {
                          return 'Name must contain only letters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Email (Read-Only) ───────────────
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                          labelText: 'Account Email',
                          border: OutlineInputBorder()),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // ── Age + Gender ────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            decoration: const InputDecoration(
                                labelText: 'Age', border: OutlineInputBorder()),
                            enabled: _isEditing,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final age = int.tryParse(v);
                              if (age == null) return 'Invalid';
                              if (age < 18 || age > 80) return '18-80';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder()),
                            items: _genderOptions
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: _isEditing
                                ? (v) => setState(() => _selectedGender = v!)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Phone + OTP ─────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              border: const OutlineInputBorder(),
                              suffixIcon: isPhoneChanged && !_isPhoneVerified
                                  ? const Icon(Icons.warning_amber,
                                      color: Colors.orange)
                                  : _isPhoneVerified
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green)
                                      : null,
                            ),
                            enabled: _isEditing,
                            keyboardType: TextInputType.phone,
                            onChanged: (v) {
                              setState(() {
                                _isPhoneVerified = v.trim() == _initialPhone;
                                if (!_isPhoneVerified) _otpSent = false;
                              });
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) {
                                return 'Phone must be exactly 10 digits';
                              }
                              return null;
                            },
                          ),
                        ),
                        if (_isEditing &&
                            isPhoneChanged &&
                            !_isPhoneVerified) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GCColors.primary,
                                foregroundColor: Colors.white,
                              ),
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
                              fontSize: 18, fontWeight: FontWeight.w600),
                          decoration: BoxDecoration(
                            border: Border.all(color: GCColors.muted),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: _sendOtp, child: const Text('Resend OTP')),
                    ],
                    const SizedBox(height: 16),

                    // ── Email (read-only) ───────────────
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                      enabled: false,
                    ),
                    const SizedBox(height: 24),

                    // ── Address Section ─────────────────
                    Text('Address', style: GCTypography.headlineSmall),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: (_selectedCity != null &&
                                    _cities.contains(_selectedCity))
                                ? _selectedCity
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            items: _cities
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: _isEditing ? _onCityChanged : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Pincode',
                              border: OutlineInputBorder(),
                            ),
                            enabled: _isEditing,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: (_selectedState != null &&
                                    _states.contains(_selectedState))
                                ? _selectedState
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                            items: _states
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: _isEditing
                                ? (val) => setState(() => _selectedState = val)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            enabled: false,
                            initialValue: 'India',
                            decoration: InputDecoration(
                              labelText: 'Country',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: GCColors.muted.withAlpha(51),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Professional Details ────────────
                    Text('Professional Details',
                        style: GCTypography.headlineSmall),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _specialtiesController,
                      decoration: const InputDecoration(
                        labelText: 'Specialties',
                        border: OutlineInputBorder(),
                        hintText: 'Comma separated',
                      ),
                      enabled: _isEditing,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _languagesController,
                      decoration: const InputDecoration(
                        labelText: 'Languages',
                        border: OutlineInputBorder(),
                        hintText: 'Comma separated',
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _skillsController,
                      decoration: const InputDecoration(
                        labelText: 'Key Skills',
                        border: OutlineInputBorder(),
                        hintText: 'Comma separated',
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work_outline, size: 20),
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Bio / Professional Summary',
                        border: OutlineInputBorder(),
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 32),

                    // ── Save ────────────────────────────
                    if (_isEditing)
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveProfile,
                        icon: const Icon(Icons.save),
                        label: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: GCColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Sign Out ────────────────────────
                    if (!_isEditing)
                      ListTile(
                        leading: const Icon(Icons.logout,
                            color: GCColors.destructive),
                        title: Text('Sign Out',
                            style: GCTypography.bodyLarge
                                .copyWith(color: GCColors.destructive)),
                        onTap: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                          if (context.mounted) context.go('/');
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
