import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requiresPasswordChange =
          await AdminService.instance.signIn(_email.text, _password.text);
      if (!mounted) return;
      context.go(requiresPasswordChange ? '/change-password' : '/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final desktop = width >= 980;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF070D1F),
              Color(0xFF101A35),
              Color(0xFF17213E),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -120,
              left: -60,
              child: _GlowOrb(size: 320, color: Color(0x33D4A017)),
            ),
            const Positioned(
              bottom: -100,
              right: -40,
              child: _GlowOrb(size: 280, color: Color(0x334B6CB7)),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: desktop
                        ? Row(
                            children: [
                              Expanded(child: _buildBrandPanel()),
                              const SizedBox(width: 20),
                              SizedBox(width: 430, child: _buildLoginCard()),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildBrandPanel(compact: true),
                                const SizedBox(height: 16),
                                _buildLoginCard(),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandPanel({bool compact = false}) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 220 : 520),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AdminTheme.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AdminTheme.gold.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.shield_rounded,
                color: AdminTheme.gold, size: 30),
          ),
          const SizedBox(height: 18),
          const Text(
            'GoldenCare Admin Console',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            compact
                ? 'Secure operations panel for managing caregivers, bookings, pricing, and support flows.'
                : 'Secure operations panel for approvals, live booking oversight, pricing controls, and platform analytics.',
            style: const TextStyle(
              color: Color(0xFFB6C3E0),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          if (!compact) ...[
            const Spacer(),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoTag(
                    icon: Icons.security_rounded, label: 'Role-gated access'),
                _InfoTag(icon: Icons.auto_graph_rounded, label: 'Live stats'),
                _InfoTag(
                    icon: Icons.manage_accounts_rounded,
                    label: 'User moderation'),
                _InfoTag(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Pricing controls'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131D38),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign in',
            style: TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use an authorized admin account to continue.',
            style: TextStyle(color: Color(0xFF98A8CB), fontSize: 14),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Admin Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
              ),
            ),
            onSubmitted: (_) {
              if (!_loading) {
                _submit();
              }
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AdminTheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AdminTheme.error.withValues(alpha: 0.35)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AdminTheme.goldLight,
                foregroundColor: const Color(0xFF121212),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Continue to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFCEE0FF)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD5E1FA),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
