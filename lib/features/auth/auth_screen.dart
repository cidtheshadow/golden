/// Auth screen — replicates web screen at route /auth/login
/// Features role tabs (Family / Caregiver / Admin), Google sign-in, email fields
/// Supports both Sign In and Sign Up (Register) modes.
/// Android equivalent: LoginScreen
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../core/constants.dart';
import '../../core/widgets/gc_button.dart';
import 'auth_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/error_handler.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String? initialMode;
  final String? initialRole;

  const AuthScreen({
    super.key,
    this.initialMode,
    this.initialRole,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// true = Sign In mode, false = Sign Up mode
  bool _isSignIn = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Role selection index: 0=family, 1=caregiver
  int _roleIndex = 0;

  static const _roles = ['family', 'caregiver'];

  @override
  void initState() {
    super.initState();

    // Initialize mode based on parameters
    if (widget.initialMode == 'signup') {
      _isSignIn = false;
    }

    // Initialize role based on parameters
    if (widget.initialRole == 'caregiver') {
      _roleIndex = 1;
    } else if (widget.initialRole == 'family') {
      _roleIndex = 0;
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _roleIndex,
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _roleIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: GCColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GCSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),

                // Auth card
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(GCSpacing.cardPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/');
                                    }
                                  },
                                ),
                              ),
                              // Logo
                              Image.asset(
                                'assets/images/logo.png',
                                width: 64,
                                height: 64,
                              ).animate().fade().scale(curve: Curves.easeOutBack),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isSignIn
                                ? 'Welcome to ${GCConstants.appName}'
                                : 'Create an Account',
                            style: GCTypography.headlineLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSignIn
                                ? 'Sign in to continue'
                                : 'Join ${GCConstants.appName} today',
                            style: GCTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Role tabs - Hide if role is pre-selected for signup
                          if (widget.initialRole == null || _isSignIn)
                            Container(
                              decoration: BoxDecoration(
                                color: GCColors.muted,
                                borderRadius:
                                    BorderRadius.circular(GCSpacing.radiusMd),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicator: BoxDecoration(
                                  color: GCColors.card,
                                  borderRadius:
                                      BorderRadius.circular(GCSpacing.radiusMd),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(13),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                labelColor: GCColors.foreground,
                                unselectedLabelColor: GCColors.mutedForeground,
                                labelStyle: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                                dividerColor: Colors.transparent,
                                tabs: const [
                                  Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.people, size: 14),
                                        SizedBox(width: 4),
                                        Text('Family'),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.work, size: 14),
                                        SizedBox(width: 4),
                                        Text('Caregiver'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (widget.initialRole == null || _isSignIn)
                            const SizedBox(height: 24),

                          // ── Name field (sign-up only) ──────────────────
                          if (!_isSignIn) ...[
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                hintText: 'Enter your full name',
                                prefixIcon:
                                    Icon(Icons.person_outline, size: 20),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email field
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            obscureText: _obscurePassword,
                          ),

                          // ── Confirm password (sign-up only) ───────────
                          if (!_isSignIn) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                hintText: 'Re-enter your password',
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Primary action button
                          GCButton(
                            label: _isSignIn ? 'Sign In' : 'Create Account',
                            onPressed: isLoading
                                ? null
                                : (_isSignIn ? _handleSignIn : _handleRegister),
                            variant: GCButtonVariant.primary,
                            isLoading: isLoading,
                          ),
                          // Toggle Sign In / Sign Up
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isSignIn
                                    ? "Don't have an account? "
                                    : 'Already have an account? ',
                                style: GCTypography.bodySmall,
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isSignIn = !_isSignIn;
                                    _emailController.clear();
                                    _passwordController.clear();
                                    _nameController.clear();
                                    _confirmPasswordController.clear();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _isSignIn ? 'Sign Up' : 'Sign In',
                                  style: GCTypography.bodySmall.copyWith(
                                    color: GCColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_roles[_roleIndex] == 'caregiver')
                            const SizedBox(height: 16),
                          const SizedBox(height: 24),

                          // Divider
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child:
                                    Text('or', style: GCTypography.bodySmall),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Google sign in
                          GCButton(
                            label: 'Continue with Google',
                            onPressed: isLoading ? null : _handleGoogleSignIn,
                            variant: GCButtonVariant.outline,
                            icon: Icons.g_mobiledata,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fade(delay: 200.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields.');
      return;
    }

    final role = _roles[_roleIndex];
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email, password, role);
      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (mounted) _showSnack(ErrorHandler.handle(e));
    }
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      return;
    }

    final role = _roles[_roleIndex];
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(name, email, password, role);
    } catch (e) {
      if (mounted) _showSnack(ErrorHandler.handle(e));
    }
  }

  void _handleGoogleSignIn() async {
    final role = _roles[_roleIndex];
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle(role);
      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (mounted) _showSnack(ErrorHandler.handle(e));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
