import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinput/pinput.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../core/spacing.dart';
import '../../core/utils/permission_flow_helper.dart';
import '../../models/service_personnel_model.dart';
import '../../repositories/service_personnel_repository.dart';
import '../../repositories/user_repository.dart';
import '../../firebase/storage_service.dart';
import '../auth/auth_controller.dart';
import '../../utils/error_handler.dart';
import 'partner_providers.dart';

class PartnerRegistrationScreen extends ConsumerStatefulWidget {
  const PartnerRegistrationScreen({super.key});

  @override
  ConsumerState<PartnerRegistrationScreen> createState() =>
      _PartnerRegistrationScreenState();
}

class _PartnerRegistrationScreenState
    extends ConsumerState<PartnerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _languagesController = TextEditingController();
  final _skillsController = TextEditingController();
  final _streetController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();
  final _otpController = TextEditingController();

  String _selectedGender = 'Male';
  String? _selectedCity;
  String? _selectedState;
  bool _isLoading = false;

  // OTP state
  bool _otpSent = false;
  bool _isPhoneVerified = false;
  // ignore: unused_field
  String? _verificationId;

  // Photo state
  Uint8List? _selectedImageBytes;
  String? _selectedImageContentType;
  String? _uploadedImageUrl;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userModelProvider).value;
      if (user != null) {
        _nameController.text = user.name;
        _emailController.text = user.email;
        _phoneController.text = user.phone;
        if (user.phone.isNotEmpty) {
          _isPhoneVerified = true;
        }
      }

      // Pre-fill from existing (incomplete) personnel record if it exists
      final personnel = ref.read(currentPersonnelProvider).value;
      if (personnel != null) {
        if (personnel.name.isNotEmpty) _nameController.text = personnel.name;
        if (personnel.email.isNotEmpty) _emailController.text = personnel.email;
        if (personnel.phone.isNotEmpty) {
          _phoneController.text = personnel.phone;
          _isPhoneVerified = true;
        }
        if (personnel.age > 0) _ageController.text = personnel.age.toString();
        if (personnel.gender.isNotEmpty &&
            _genderOptions.contains(personnel.gender)) {
          _selectedGender = personnel.gender;
        }
        if (personnel.specialties.isNotEmpty) {
          _specialtiesController.text = personnel.specialties.join(', ');
        }
        if (personnel.languages.isNotEmpty) {
          _languagesController.text = personnel.languages.join(', ');
        }
        if (personnel.keySkills.isNotEmpty) {
          _skillsController.text = personnel.keySkills.join(', ');
        }
        if (personnel.street.isNotEmpty) {
          _streetController.text = personnel.street;
        }
        if (personnel.pincode.isNotEmpty) {
          _pincodeController.text = personnel.pincode;
        }
        if (personnel.experienceYears > 0) {
          _experienceController.text = personnel.experienceYears.toString();
        }
        if (personnel.bio.isNotEmpty) _bioController.text = personnel.bio;
        if (personnel.city.isNotEmpty && _cities.contains(personnel.city)) {
          _selectedCity = personnel.city;
        }
        if (personnel.state.isNotEmpty && _states.contains(personnel.state)) {
          _selectedState = personnel.state;
        }
        if (personnel.imageUrl.isNotEmpty) {
          _uploadedImageUrl = personnel.imageUrl;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _specialtiesController.dispose();
    _languagesController.dispose();
    _skillsController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
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
                '[PartnerReg] Auto-verify link conflict (${e.code}) — treating as verified');
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

  // ── Photo Methods ────────────────────────────────────────

  Future<void> _pickImage() async {
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
        feature: 'taking your partner profile photo',
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

    final bytes = await image.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageContentType = image.mimeType;
    });
  }

  // ── Submit ───────────────────────────────────────────────

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // FIX 1B: Profile photo is required
    if (_selectedImageBytes == null && _uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please upload a profile photo to continue')));
      return;
    }

    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please verify your phone number first')));
      return;
    }

    if (_selectedCity == null || _selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both City and State.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(userModelProvider).value;
      if (user == null) throw Exception('User not found');

      // Upload photo if selected
      if (_selectedImageBytes != null) {
        final url = await StorageService().uploadProfileImage(
          user.uid,
          _selectedImageBytes!,
          contentType: _selectedImageContentType,
        );
        if (url != null) _uploadedImageUrl = url;
      }

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

      final personnel = ServicePersonnelModel(
        id: user.uid,
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _selectedGender,
        rating: 0.0,
        specialties: specialties,
        imageUrl: _uploadedImageUrl ?? '',
        isOnline: true,
        visitsCompleted: 0,
        idVerified: false,
        languages: languages,
        keySkills: skills,
        email: user.email,
        phone: _phoneController.text.trim(),
        experienceYears: int.tryParse(_experienceController.text.trim()) ?? 0,
        bio: _bioController.text.trim(),
        street: _streetController.text.trim(),
        city: _selectedCity!,
        state: _selectedState!,
        pincode: _pincodeController.text.trim(),
        country: 'India',
      );

      await ref
          .read(servicePersonnelRepositoryProvider)
          .createServicePersonnel(personnel);

      // Also save address + name to user document for profile completeness
      final fullAddress =
          '${_streetController.text.trim()}, $_selectedCity, $_selectedState - ${_pincodeController.text.trim()}, India';
      await ref.read(userRepositoryProvider).updateUserProfile(user.uid, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': fullAddress,
        'street': _streetController.text.trim(),
        'city': _selectedCity,
        'state': _selectedState,
        'pincode': _pincodeController.text.trim(),
        'country': 'India',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful! Welcome.')));
        context.go('/partner/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${ErrorHandler.handle(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Registration'),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome to Golden Care Partner!',
                    style: GCTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete your profile to start accepting bookings.',
                    style: GCTypography.bodyMedium
                        .copyWith(color: GCColors.mutedForeground),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Profile Photo ─────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: GCColors.primary.withAlpha(30),
                            backgroundImage: _selectedImageBytes != null
                                ? MemoryImage(_selectedImageBytes!)
                                : null,
                            child: _selectedImageBytes == null
                                ? const Icon(Icons.person,
                                    size: 50, color: GCColors.primary)
                                : null,
                          ),
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: GCColors.primary,
                              radius: 16,
                              child: Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to upload your photo',
                    style: GCTypography.bodySmall
                        .copyWith(color: GCColors.mutedForeground),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedImageBytes == null &&
                      _uploadedImageUrl == null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '* Profile photo is required to register as a partner',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Name ──────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Full Name', border: OutlineInputBorder()),
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

                  // ── Email (Read-Only) ──────────────────────
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: 'Account Email',
                        border: OutlineInputBorder()),
                    enabled: false,
                  ),
                  const SizedBox(height: 16),

                  // ── Age + Gender ──────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageController,
                          decoration: const InputDecoration(
                              labelText: 'Age', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final age = int.tryParse(v);
                            if (age == null) return 'Invalid';
                            if (age < 21 || age > 80) {
                              return 'You must be at least 21 years old';
                            }
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
                          onChanged: (v) =>
                              setState(() => _selectedGender = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Phone + OTP ───────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            border: const OutlineInputBorder(),
                            suffixIcon: _isPhoneVerified
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                          ),
                          keyboardType: TextInputType.phone,
                          onChanged: (_) {
                            if (_isPhoneVerified) {
                              setState(() {
                                _isPhoneVerified = false;
                                _otpSent = false;
                              });
                            }
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
                      if (!_isPhoneVerified) ...[
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
                    Text('Enter the 6-digit OTP sent to your phone',
                        style: GCTypography.bodySmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
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

                  // ── Address Section ───────────────────
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
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCity,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                          items: _cities
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: _onCityChanged,
                          validator: (v) => v == null ? 'Required' : null,
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
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (!RegExp(r'^[0-9]{6}$').hasMatch(v)) {
                              return 'Must be 6 digits';
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
                        child: DropdownButtonFormField<String>(
                          value: _selectedState,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
                          ),
                          items: _states
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedState = val),
                          validator: (v) => v == null ? 'Required' : null,
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

                  // ── Professional Details ──────────────
                  Text('Professional Details',
                      style: GCTypography.headlineSmall),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _specialtiesController,
                    decoration: const InputDecoration(
                      labelText: 'Specialties (comma separated)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Elderly Care, Driving, Cooking',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _languagesController,
                    decoration: const InputDecoration(
                      labelText: 'Languages (comma separated)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. English, Hindi, Punjabi',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _skillsController,
                    decoration: const InputDecoration(
                      labelText: 'Key Skills (comma separated)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. CPR Certified, Patient, Good Listener',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'At least one skill is required'
                        : null,
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
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Years of experience is required';
                      }
                      final years = int.tryParse(v.trim());
                      if (years == null || years < 0) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Bio / Professional Summary',
                      border: OutlineInputBorder(),
                      hintText:
                          'Tell clients about yourself and your experience...',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 20) {
                        return 'Please write at least 20 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // ── Submit ────────────────────────────
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_selectedImageBytes != null ||
                                _uploadedImageUrl != null)
                            ? _submitForm
                            : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: GCColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Registration',
                            style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
