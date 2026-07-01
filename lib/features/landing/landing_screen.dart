/// Landing page — replicates web screen at route /
/// This is the FIRST screen users see. NOT login.
/// Contains: Nav, Hero, Stats, Services, How It Works, Platform Highlights, CTA, Footer
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../core/constants.dart';
import '../../core/widgets/gc_button.dart';
import '../../components/hero_section.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/service_model.dart';
import '../bookings/booking_screen.dart';
import '../auth/auth_controller.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;
  bool _mobileMenuOpen = false;

  // Scroll keys for anchor navigation
  final _servicesKey = GlobalKey();
  final _howItWorksKey = GlobalKey();
  final _platformHighlightsKey = GlobalKey();
  final _trustSafetyKey = GlobalKey();
  final _faqKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final isScrolled = _scrollController.offset > 50;
      if (isScrolled != _scrolled) {
        setState(() => _scrolled = isScrolled);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
    setState(() => _mobileMenuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1150;
    debugPrint(
        'Building LandingScreen: width=$screenWidth, isDesktop=$isDesktop');

    final horizontalPadding =
        isDesktop ? GCSpacing.pagePaddingDesktop : GCSpacing.pagePaddingMobile;

    return Scaffold(
      backgroundColor: GCColors.background,
      body: Stack(
        children: [
          // ── Main scrollable content ──────────────
          SingleChildScrollView(
            controller: _scrollController,
            physics:
                const AlwaysScrollableScrollPhysics(), // Ensure scrolling is always enabled
            child: Column(
              children: [
                // Space for fixed nav bar
                const SizedBox(height: 80),
                HeroSection(onOpenConsultation: () => context.push('/book')),
                _buildStatsSection(isDesktop, horizontalPadding),
                _buildTrustSafetySection(isDesktop, horizontalPadding),
                _buildProcessSection(isDesktop, horizontalPadding),
                _buildTestimonialsSection(isDesktop, horizontalPadding),
                _buildFAQSection(isDesktop, horizontalPadding),
                _buildFooter(isDesktop, horizontalPadding),
              ],
            ),
          ),

          // ── Fixed top nav bar ───────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildNavBar(isDesktop, horizontalPadding),
          ),

          // ── Mobile menu overlay ─────────────────
          if (_mobileMenuOpen && !isDesktop) _buildMobileMenu(),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // NAV BAR
  // from web: fixed top, transparent → bg on scroll, logo + links + CTAs
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildNavBar(bool isDesktop, double horizontalPadding) {
    return Container(
      decoration: BoxDecoration(
        color: GCColors.background,
        boxShadow: _scrolled
            ? [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4)]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Container(
            constraints:
                const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            height: isDesktop
                ? GCSpacing.navHeightDesktop
                : GCSpacing.navHeightMobile,
            child: Row(
              children: [
                // Logo
                GestureDetector(
                  onTap: () => _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                      ).animate().fade().scale(),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(GCConstants.appName,
                              style: GCTypography.headlineLarge),
                          Text("HOME & ELDER CARE",
                              style: GCTypography.bodySmall.copyWith(
                                fontSize: 8,
                                letterSpacing: 1.5,
                                color: GCColors.primary,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Desktop nav links
                if (isDesktop) ...[
                  _navLink('Services', () => _scrollToKey(_servicesKey)),
                  const SizedBox(width: 24),
                  _navLink('How It Works', () => _scrollToKey(_howItWorksKey)),
                  const SizedBox(width: 24),
                  _navLink('Trust & Safety', () => _scrollToKey(_trustSafetyKey)),
                  const SizedBox(width: 24),
                  _navLink('FAQ', () => _scrollToKey(_faqKey)),
                  const SizedBox(width: 48),

                  // Phone
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: GCColors.primary),
                      const SizedBox(width: 8),
                      Text("1800-123-4567", style: GCTypography.labelMedium.copyWith(color: GCColors.foreground, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Container(width: 1, height: 20, color: GCColors.border),
                  const SizedBox(width: 24),

                  // Conditional Auth Links
                  ref.watch(authStateProvider).when(
                        data: (user) {
                          if (user != null) {
                            return TextButton(
                              onPressed: () => context.go('/dashboard'),
                              child: Text('Dashboard',
                                  style: GCTypography.labelMedium.copyWith(
                                      color: GCColors.foreground)),
                            );
                          }
                          return InkWell(
                            onTap: () => context.go('/auth/login?mode=signin'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text("Sign In", style: GCTypography.labelMedium.copyWith(color: GCColors.mutedForeground)),
                            ),
                          );
                        },
                        loading: () => const SizedBox(width: 40),
                        error: (_, __) => const SizedBox(width: 40),
                      ),

                  const SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/book'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GCColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Text("Free Consultation", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],

                // Mobile hamburger
                if (!isDesktop)
                  IconButton(
                    icon: Icon(_mobileMenuOpen ? Icons.close : Icons.menu,
                        color: GCColors.foreground),
                    onPressed: () =>
                        setState(() => _mobileMenuOpen = !_mobileMenuOpen),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(label, style: GCTypography.labelMedium),
      ),
    );
  }

  Widget _buildMobileMenu() {
    return Positioned(
      top: GCSpacing.navHeightMobile + MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        color: GCColors.background,
        child: Padding(
          padding: const EdgeInsets.all(GCSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _mobileNavItem('Services', () => _scrollToKey(_servicesKey)),
              _mobileNavItem(
                  'How It Works', () => _scrollToKey(_howItWorksKey)),
              _mobileNavItem('Platform Highlights',
                  () => _scrollToKey(_platformHighlightsKey)),
              _mobileNavItem('Contact Us', () {
                setState(() => _mobileMenuOpen = false);
                context.push('/contact');
              }),
              _mobileNavItem('Terms & Conditions', () {
                setState(() => _mobileMenuOpen = false);
                context.push('/legal/terms');
              }),
              _mobileNavItem('Privacy Policy', () {
                setState(() => _mobileMenuOpen = false);
                context.push('/legal/privacy');
              }),
              _mobileNavItem('Data Collection Policy', () {
                setState(() => _mobileMenuOpen = false);
                context.push('/legal/data-collection');
              }),
              _mobileNavItem('Refund Policy', () {
                setState(() => _mobileMenuOpen = false);
                context.push('/legal/refunds');
              }),
              _mobileNavItem('Account Deletion', () {
                setState(() => _mobileMenuOpen = false);
                context.push('/legal/account-deletion');
              }),
              _mobileNavItem('Find Caregivers', () {
                setState(() => _mobileMenuOpen = false);
                context.push('/caregivers');
              }),
              const Divider(height: 24),

              // Conditional Auth section for mobile
              ref.watch(authStateProvider).when(
                    data: (user) {
                      if (user != null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _mobileNavItem('Dashboard', () {
                              setState(() => _mobileMenuOpen = false);
                              context.go('/dashboard');
                            }),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GCButton(
                                  label: 'Sign In',
                                  onPressed: () {
                                    setState(() => _mobileMenuOpen = false);
                                    context.go('/auth/login?mode=signin');
                                  },
                                  variant: GCButtonVariant.outline,
                                  icon: Icons.lock_outline,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GCButton(
                                  label: 'Sign Up',
                                  onPressed: () {
                                    setState(() => _mobileMenuOpen = false);
                                    context.go(
                                        '/auth/login?mode=signup&role=family');
                                  },
                                  variant: GCButtonVariant.primary,
                                  icon: Icons.person_add_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GCButton(
                                label: 'Sign In',
                                onPressed: () {
                                  setState(() => _mobileMenuOpen = false);
                                  context.go('/auth/login?mode=signin');
                                },
                                variant: GCButtonVariant.outline,
                                icon: Icons.lock_outline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GCButton(
                                label: 'Sign Up',
                                onPressed: () {
                                  setState(() => _mobileMenuOpen = false);
                                  context.go(
                                      '/auth/login?mode=signup&role=family');
                                },
                                variant: GCButtonVariant.primary,
                                icon: Icons.person_add_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

              const SizedBox(height: 12),
              GCButton(
                label: 'Book Care',
                onPressed: () {
                  setState(() => _mobileMenuOpen = false);
                  context.push('/book');
                },
                variant: GCButtonVariant.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileNavItem(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(label,
            style: GCTypography.headlineSmall.copyWith(fontSize: 16)),
      ),
    );
  }

  Widget _buildSupportDropdown(bool isDesktop) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'contact') context.push('/contact');
        if (value == 'terms') context.push('/legal/terms');
        if (value == 'privacy') context.push('/legal/privacy');
        if (value == 'dataCollection') context.push('/legal/data-collection');
        if (value == 'refunds') context.push('/legal/refunds');
        if (value == 'accountDeletion') context.push('/legal/account-deletion');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Support', style: GCTypography.labelMedium),
            const Icon(Icons.arrow_drop_down,
                size: 20, color: GCColors.foreground),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'contact',
          child: Text('Contact Us', style: GCTypography.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'terms',
          child: Text('Terms & Conditions', style: GCTypography.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'privacy',
          child: Text('Privacy Policy', style: GCTypography.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'dataCollection',
          child: Text('Data Collection Policy', style: GCTypography.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'refunds',
          child: Text('Refund Policy', style: GCTypography.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'accountDeletion',
          child: Text('Account Deletion', style: GCTypography.bodyMedium),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HERO SECTION
  // from web: badges, large serif heading, sub text, 2 CTAs, trust features
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHeroSection(bool isDesktop, double horizontalPadding) {
    return Container(
      constraints: const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isDesktop ? 80 : 40,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _heroContent(isDesktop),
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  flex: 4,
                  child: _heroImage(isDesktop),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ..._heroContent(isDesktop),
                const SizedBox(height: 40),
                _heroImage(isDesktop),
              ],
            ),
    );
  }

  List<Widget> _heroContent(bool isDesktop) {
    return [
      // Badges
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _badge(Icons.auto_awesome, 'Grandkids on demand', GCColors.primary),
          _badge(Icons.location_on,
              'Available in Chandigarh, Mohali & Panchkula', GCColors.accent),
        ],
      ).animate().fade(duration: 600.ms).slideX(begin: -0.2, end: 0),
      const SizedBox(height: 24),

      // Heading — "Compassionate Care for Your Loved Ones"
      Text.rich(
        TextSpan(
          style: GCTypography.displayLarge.copyWith(
            fontSize: isDesktop ? 52 : 36,
          ),
          children: const [
            TextSpan(text: 'Compassionate Care for Your '),
            TextSpan(
              text: 'Loved Ones',
              style: TextStyle(color: GCColors.primary),
            ),
          ],
        ),
        textAlign: isDesktop ? TextAlign.start : TextAlign.center,
      )
          .animate()
          .fade(delay: 200.ms, duration: 800.ms)
          .slideY(begin: 0.2, end: 0),
      const SizedBox(height: 24),

      // Sub text
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Text(
          'Connect with verified, trained caregivers who provide dignified and personalized senior care. Book in minutes, care starts within hours.',
          style: GCTypography.bodyLarge,
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
        ),
      )
          .animate()
          .fade(delay: 400.ms, duration: 800.ms)
          .slideY(begin: 0.2, end: 0),
      const SizedBox(height: 32),

      // CTAs
      ref.watch(authStateProvider).when(
            data: (user) {
              final isLogged = user != null;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment:
                    isDesktop ? WrapAlignment.start : WrapAlignment.center,
                children: [
                  if (isLogged)
                    GCButton(
                      label: 'Go to Dashboard',
                      onPressed: () => context.go('/dashboard'),
                      variant: GCButtonVariant.secondary,
                      icon: Icons.dashboard,
                    ),
                  GCButton(
                    label: 'Book a Caregiver',
                    onPressed: () => context.push('/book'),
                    variant: GCButtonVariant.primary,
                    icon: Icons.arrow_forward,
                  ),
                  GCButton(
                    label: 'Browse Caregivers',
                    onPressed: () => context.push('/caregivers'),
                    variant: GCButtonVariant.outline,
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
              children: [
                GCButton(
                  label: 'Book a Caregiver',
                  onPressed: () => context.push('/book'),
                  variant: GCButtonVariant.primary,
                  icon: Icons.arrow_forward,
                ),
                GCButton(
                  label: 'Browse Caregivers',
                  onPressed: () => context.push('/caregivers'),
                  variant: GCButtonVariant.outline,
                ),
              ],
            ),
          ),
      const SizedBox(height: 32),

      // Trust features
      Wrap(
        spacing: 24,
        runSpacing: 12,
        alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
        children: [
          _trustFeature(Icons.school_outlined, 'Caring Students'),
          _trustFeature(Icons.schedule, 'Flexible Scheduling'),
          _trustFeature(Icons.star_outline, 'Quality Guaranteed'),
        ],
      ),
    ];
  }

  Widget _heroImage(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GCSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: GCColors.primary.withAlpha(26),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GCSpacing.radiusXl),
        child: Image.asset(
          'assets/images/hero_premium.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: GCColors.muted,
            child: const AspectRatio(
              aspectRatio: 1,
              child: Icon(Icons.image_not_supported, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color, [Color? bgColor]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor ?? color.withAlpha(26),
        borderRadius: BorderRadius.circular(GCSpacing.radiusRound),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: GCTypography.badgeText.copyWith(color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _trustFeature(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: GCColors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              style: GCTypography.bodyMedium.copyWith(
                color: GCColors.mutedForeground,
              )),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STATS BAR
  // from web: "py-12 bg-primary/5 border-y" with 4 stats in grid
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildStatsSection(bool isDesktop, double horizontalPadding) {
    final stats = [
      {'value': '10k+', 'label': 'Happy Families', 'icon': Icons.people_outline},
      {'value': '100%', 'label': 'Police Verified', 'icon': Icons.verified_user_outlined},
      {'value': '500+', 'label': 'Trained Caregivers', 'icon': Icons.medical_services_outlined},
    ];

    return Container(
      width: double.infinity,
      color: GCColors.background,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          decoration: BoxDecoration(
            color: GCColors.secondary, // Sage green background
            borderRadius: BorderRadius.circular(40),
          ),
          child: isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: stats.map((stat) => _buildStatItem(stat)).toList(),
                )
              : Column(
                  children: stats
                      .map((stat) => Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: _buildStatItem(stat),
                          ))
                      .toList(),
                ),
        ),
      ),
    );
  }

  Widget _buildStatItem(Map<String, dynamic> stat) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(stat['icon'] as IconData, color: GCColors.foreground, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat['value'] as String,
                style: GCTypography.displayMedium.copyWith(
                  fontSize: 32,
                  color: GCColors.foreground,
                )),
            const SizedBox(height: 4),
            Text(stat['label'] as String,
                style: GCTypography.bodyMedium.copyWith(
                  color: GCColors.mutedForeground,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ],
    ).animate().fade(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TRUST & SAFETY
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTrustSafetySection(bool isDesktop, double horizontalPadding) {
    return Container(
      key: _trustSafetyKey,
      width: double.infinity,
      color: GCColors.foreground, // Dark Green Background
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 80),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _trustSafetyContent(isDesktop),
                      ),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 4,
                      child: _trustSafetyImage(),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._trustSafetyContent(isDesktop),
                    const SizedBox(height: 48),
                    _trustSafetyImage(),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _trustSafetyContent(bool isDesktop) {
    return [
      _badge(Icons.verified_user_outlined, 'Our Safety Promise', Colors.white, Colors.white24),
      const SizedBox(height: 24),
      RichText(
        text: TextSpan(
          style: GCTypography.displayMedium.copyWith(
            color: Colors.white,
            fontSize: isDesktop ? 48 : 36,
          ),
          children: [
            const TextSpan(text: "Trust isn't given.\n"),
            TextSpan(text: "It's verified.", style: TextStyle(color: GCColors.secondary)),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        "We understand the immense trust required to invite a caregiver into your home. That's why GoldenCare employs the most rigorous vetting process in India, ensuring your loved ones are in the safest possible hands.",
        style: GCTypography.bodyLarge.copyWith(color: Colors.white70),
      ),
      const SizedBox(height: 40),
      _trustFeatureRow(
        Icons.description_outlined,
        'Rigorous Background Checks',
        'Comprehensive 5-point verification including criminal records, permanent address verification, and strict reference checks from previous employers.',
      ),
      const SizedBox(height: 32),
      _trustFeatureRow(
        Icons.school_outlined,
        'Clinical & Empathy Training',
        'Only 4% of applicants pass our assessment. Hires undergo specialized training for geriatric care, dementia support, and compassionate communication.',
      ),
      const SizedBox(height: 32),
      _trustFeatureRow(
        Icons.favorite_border,
        'Ongoing Health Monitoring',
        'Our caregivers undergo regular health screenings and are supervised by senior nursing staff who conduct routine unannounced quality-check visits.',
      ),
    ];
  }

  Widget _trustFeatureRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(26),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GCTypography.headlineSmall.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(desc, style: GCTypography.bodyMedium.copyWith(color: Colors.white70, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trustSafetyImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Image.asset(
            'assets/images/hero_premium.png', // Reusing placeholder, assuming it represents this
            height: 500,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
        Positioned(
          bottom: 40,
          left: -20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GCColors.secondary.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: GCColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("100%", style: GCTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold)),
                    Text("POLICE VERIFIED", style: GCTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // THE GOLDENCARE PROCESS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildProcessSection(bool isDesktop, double horizontalPadding) {
    final steps = [
      {
        'step': '01',
        'title': 'Free Consultation',
        'desc': 'Consult with our care experts to discuss your needs and preferences.',
      },
      {
        'step': '02',
        'title': 'Customized Care Plan',
        'desc': 'Receive a tailored care plan designed specifically for your loved one.',
      },
      {
        'step': '03',
        'title': 'Caregiver Match',
        'desc': 'We select the best-suited caregiver based on skills, experience, and personality.',
      },
      {
        'step': '04',
        'title': 'Ongoing Support',
        'desc': 'Enjoy continuous support and flexible adjustments to the care plan as needed.',
      },
    ];

    return Container(
      key: _howItWorksKey,
      width: double.infinity,
      color: GCColors.background,
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
          child: Column(
            children: [
              Text('THE GOLDENCARE PROCESS',
                  style: GCTypography.bodySmall.copyWith(
                      color: GCColors.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 16),
              Text('Simple, Transparent, and Stress-Free',
                  style: GCTypography.displayMedium.copyWith(color: GCColors.foreground),
                  textAlign: TextAlign.center),
              const SizedBox(height: 64),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: steps
                          .map((step) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: _processCard(step),
                                ),
                              ))
                          .toList(),
                    )
                  : Column(
                      children: steps
                          .map((step) => Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _processCard(step),
                              ))
                          .toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _processCard(Map<String, String> step) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GCColors.border.withAlpha(128)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step['step']!,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 64,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: GCColors.secondary.withAlpha(128))),
          const SizedBox(height: 24),
          Text(step['title']!,
              style: GCTypography.headlineMedium.copyWith(color: GCColors.foreground)),
          const SizedBox(height: 12),
          Text(step['desc']!,
              style: GCTypography.bodyMedium.copyWith(color: GCColors.mutedForeground, height: 1.5)),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TESTIMONIALS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTestimonialsSection(bool isDesktop, double horizontalPadding) {
    final testimonials = [
      {
        'name': 'Priya Sharma',
        'relation': 'Daughter of patient',
        'avatar': 'PS',
        'text':
            'The level of care provided to my father has been exceptional. The caregiver is not just professional, but genuinely compassionate. GoldenCare gave us peace of mind when we needed it most.',
      },
      {
        'name': 'Rajiv Desai',
        'relation': 'Son of patient',
        'avatar': 'RD',
        'text':
            'After trying multiple agencies, GoldenCare stood out. Their rigorous background checks and continuous monitoring mean I never have to worry while I am at work.',
      },
      {
        'name': 'Anita Verma',
        'relation': 'Wife of patient',
        'avatar': 'AV',
        'text':
            'The booking process was incredibly smooth, and the care plan was tailored perfectly to my husband’s recovery needs. Truly a blessing for our family.',
      },
    ];

    return Container(
      width: double.infinity,
      color: GCColors.background,
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
          child: Column(
            children: [
              Text('Families Trust GoldenCare',
                  style: GCTypography.displayMedium.copyWith(color: GCColors.foreground),
                  textAlign: TextAlign.center),
              const SizedBox(height: 64),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: testimonials
                          .map((t) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: _testimonialCard(t),
                                ),
                              ))
                          .toList(),
                    )
                  : Column(
                      children: testimonials
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _testimonialCard(t),
                              ))
                          .toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testimonialCard(Map<String, String> testimonial) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GCColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                    5,
                    (_) => const Icon(Icons.star,
                        size: 20, color: Color(0xFFFBBF24))), // Yellow stars
              ),
              Icon(Icons.format_quote,
                  size: 48, color: GCColors.mutedForeground.withAlpha(51)),
            ],
          ),
          const SizedBox(height: 16),
          Text(testimonial['text']!,
              style: GCTypography.bodyLarge.copyWith(height: 1.6, color: GCColors.foreground)),
          const SizedBox(height: 32),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: GCColors.secondary,
                child: Text(testimonial['avatar']!,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: GCColors.foreground)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(testimonial['name']!,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GCColors.foreground)),
                  Text(testimonial['relation']!,
                      style: GCTypography.bodyMedium.copyWith(color: GCColors.mutedForeground)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FAQ SECTION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildFAQSection(bool isDesktop, double horizontalPadding) {
    final faqs = [
      {
        'q': 'How do you ensure the safety and background of your caregivers?',
        'a': 'We employ a rigorous 5-point verification process including criminal records, permanent address verification, and strict reference checks. All caregivers are 100% police verified.'
      },
      {
        'q': 'What happens if the regular caregiver is unavailable?',
        'a': 'We guarantee continuous care. In case of unexpected absence, we provide a temporary replacement with similar qualifications to ensure no disruption in care.'
      },
      {
        'q': 'Are your services covered by insurance?',
        'a': 'Many of our services are covered by long-term care insurance. We recommend checking with your specific insurance provider, and our team can assist with the necessary documentation.'
      },
      {
        'q': 'Can I change my caregiver if it\'s not a good match?',
        'a': 'Absolutely. The comfort of your loved one is our priority. If you feel the match isn\'t perfect, we will gladly assign a new caregiver at no additional cost.'
      },
    ];

    return Container(
      key: _faqKey,
      width: double.infinity,
      color: GCColors.background,
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Text('Frequently Asked Questions',
                  style: GCTypography.displayMedium.copyWith(color: GCColors.foreground),
                  textAlign: TextAlign.center),
              const SizedBox(height: 48),
              ...faqs.map((faq) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GCColors.border.withAlpha(128)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(faq['q']!,
                            style: GCTypography.headlineSmall.copyWith(fontSize: 18, color: GCColors.foreground)),
                        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          Text(faq['a']!,
                              style: GCTypography.bodyMedium.copyWith(color: GCColors.mutedForeground, height: 1.5)),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FOOTER
  // from web: dark bg (foreground color), 4-column grid, copyright
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildFooter(bool isDesktop, double horizontalPadding) {
    final footerTextStyle = GoogleFonts.inter(
        fontSize: 14, color: GCColors.background.withAlpha(179));
    final footerHeadingStyle = GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600, color: GCColors.background);

    return Container(
      width: double.infinity,
      color: GCColors.footerBackground,
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
          child: Column(
            children: [
              // Footer columns
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand
                        Expanded(flex: 2, child: _footerBrand(footerTextStyle)),
                        const SizedBox(width: 32),
                        Expanded(
                            child: _footerServices(
                                footerHeadingStyle, footerTextStyle)),
                        Expanded(
                            child: _footerCompany(
                                footerHeadingStyle, footerTextStyle)),
                        Expanded(
                            child: _footerPortals(
                                footerHeadingStyle, footerTextStyle)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _footerBrand(footerTextStyle),
                        const SizedBox(height: 32),
                        _footerServices(footerHeadingStyle, footerTextStyle),
                        const SizedBox(height: 24),
                        _footerCompany(footerHeadingStyle, footerTextStyle),
                        const SizedBox(height: 24),
                        _footerPortals(footerHeadingStyle, footerTextStyle),
                      ],
                    ),
              const SizedBox(height: 48),
              // Copyright
              Divider(color: GCColors.background.withAlpha(26)),
              const SizedBox(height: 32),
              isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(GCConstants.copyright,
                            style: footerTextStyle.copyWith(
                                color: GCColors.background.withAlpha(128))),
                        Row(
                          children: [
                            TextButton(
                                onPressed: () => context.push('/legal/privacy'),
                                child: Text('Privacy Policy',
                                    style: footerTextStyle.copyWith(
                                        color: GCColors.background
                                            .withAlpha(128)))),
                            const SizedBox(width: 24),
                            TextButton(
                                onPressed: () => context.push('/legal/terms'),
                                child: Text('Terms and Conditions',
                                    style: footerTextStyle.copyWith(
                                        color: GCColors.background
                                            .withAlpha(128)))),
                            const SizedBox(width: 24),
                            TextButton(
                                onPressed: () =>
                                    context.push('/legal/data-collection'),
                                child: Text('Data Collection',
                                    style: footerTextStyle.copyWith(
                                        color: GCColors.background
                                            .withAlpha(128)))),
                            const SizedBox(width: 24),
                            TextButton(
                                onPressed: () => context.push('/legal/refunds'),
                                child: Text('Refund Policy',
                                    style: footerTextStyle.copyWith(
                                        color: GCColors.background
                                            .withAlpha(128)))),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Text(GCConstants.copyright,
                            style: footerTextStyle.copyWith(
                                color: GCColors.background.withAlpha(128))),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerBrand(TextStyle textStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 8),
            Text(GCConstants.appName,
                style: GCTypography.displaySmall
                    .copyWith(fontSize: 20, color: GCColors.background)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Providing compassionate, professional care for seniors in ${GCConstants.region}.',
          style: textStyle,
        ),
        const SizedBox(height: 16),
        _footerContact(Icons.email, GCConstants.email, textStyle),
        const SizedBox(height: 8),
        _footerContact(Icons.location_on, GCConstants.region, textStyle),
      ],
    );
  }

  Widget _footerContact(IconData icon, String text, TextStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: GCColors.background.withAlpha(179)),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }

  Widget _footerServices(TextStyle heading, TextStyle text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Services', style: heading),
        const SizedBox(height: 16),
        _footerLink('Companionship', text, () => context.push('/book')),
        _footerLink('Outings & Visits', text, () => context.push('/book')),
        _footerLink('Daily Activities', text, () => context.push('/book')),
        _footerLink('Exercise & Walks', text, () => context.push('/book')),
      ],
    );
  }

  Widget _footerCompany(TextStyle heading, TextStyle text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Company', style: heading),
        const SizedBox(height: 16),
        _footerLink('About Us', text, () => context.push('/about')),
        _footerLink('Our Caregivers', text, () => context.push('/caregivers')),
        _footerLink('Contact', text, () => context.push('/contact')),
      ],
    );
  }

  Widget _footerPortals(TextStyle heading, TextStyle text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Portals', style: heading),
        const SizedBox(height: 16),
        _footerLinkIcon(Icons.people, 'Family Login', text,
            () => context.push('/auth/login')),
        _footerLinkIcon(Icons.work, 'Caregiver Login', text,
            () => context.push('/auth/login')),
      ],
    );
  }

  Widget _footerLink(String label, TextStyle style, [VoidCallback? onTap]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Text(label, style: style),
      ),
    );
  }

  Widget _footerLinkIcon(
      IconData icon, String label, TextStyle style, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: GCColors.background.withAlpha(179)),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: style)),
          ],
        ),
      ),
    );
  }
}
