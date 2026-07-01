/// Join as Caregiver screen — replicates web screen at route /join-as-caregiver
/// Recruitment page with earnings info, what-we-do lists, apply CTA
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';

class JoinCaregiverScreen extends StatelessWidget {
  const JoinCaregiverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final horizontalPadding = isDesktop
        ? GCSpacing.pagePaddingDesktop
        : GCSpacing.pagePaddingMobile;

    return Scaffold(
      backgroundColor: GCColors.background,
      appBar: AppBar(
        title: const Text('Join as Caregiver'),
        leading: IconButton(
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                // Hero
                Text('Join GoldenCare as a Caregiver',
                    style: GCTypography.displayMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  'Make a difference in seniors\' lives while earning a flexible income.',
                  style: GCTypography.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Earnings highlight
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(GCSpacing.cardPadding),
                    child: Column(
                      children: [
                        Text('Earn ₹25,000+/month',
                            style: GCTypography.displaySmall.copyWith(
                                color: GCColors.primary)),
                        const SizedBox(height: 8),
                        Text(
                          'Flexible hours, meaningful work, and competitive pay.',
                          style: GCTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Services you will provide
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(GCSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Services You Will Provide',
                            style: GCTypography.headlineLarge),
                        const SizedBox(height: 24),
                        isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _whatWeDo()),
                                  const SizedBox(width: 32),
                                  Expanded(child: _whatWeDoNot()),
                                ],
                              )
                            : Column(
                                children: [
                                  _whatWeDo(),
                                  const SizedBox(height: 24),
                                  _whatWeDoNot(),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Apply CTA
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(GCSpacing.cardPadding),
                    child: Column(
                      children: [
                        Text('Ready to Start?',
                            style: GCTypography.headlineLarge,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          'The application takes less than 5 minutes. We will review your profile within 48 hours.',
                          style: GCTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/auth/login?mode=signup&role=caregiver'),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Apply Now'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _whatWeDo() {
    final items = [
      'Conversation & companionship',
      'Doctor/hospital visit accompaniment',
      'Shopping, groceries, medicine pickup',
      'Morning/evening walks & exercise',
      'Temple visits, movies, park outings',
      'Help with online activities',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: GCColors.accent),
            const SizedBox(width: 8),
            Text('What You Will Do',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GCColors.accent)),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: GCColors.accent),
                  const SizedBox(width: 8),
                  Flexible(child: Text(item, style: GCTypography.bodyMedium)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _whatWeDoNot() {
    final items = [
      'Overnight care or stay',
      'Medical/nursing care',
      'Personal hygiene assistance',
      'Clinical treatments',
      'Medication administration',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cancel, size: 16, color: GCColors.destructive),
            const SizedBox(width: 8),
            Text('What We Do NOT Provide',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GCColors.destructive)),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.close,
                      size: 16, color: GCColors.destructive),
                  const SizedBox(width: 8),
                  Flexible(child: Text(item, style: GCTypography.bodyMedium)),
                ],
              ),
            )),
      ],
    );
  }
}
