import 'package:flutter/material.dart';

import '../core/colors.dart';
import '../core/spacing.dart';

class HeroSection extends StatelessWidget {
  final VoidCallback onOpenConsultation;

  const HeroSection({
    super.key,
    required this.onOpenConsultation,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: GCColors.background,
      padding: const EdgeInsets.symmetric(
        horizontal: 32, // Better padding for max-width
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 11, child: _buildTextContent(context, textTheme)),
                    const SizedBox(width: 64),
                    Expanded(flex: 10, child: _buildImageContent()),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextContent(context, textTheme),
                    const SizedBox(height: 64),
                    _buildImageContent(),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: GCColors.secondary,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: GCColors.primary.withAlpha(51)), // 20% opacity
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: GCColors.primary),
              const SizedBox(width: 8),
              Text(
                "India's Most Trusted Care Network",
                style: textTheme.labelSmall?.copyWith(
                  color: GCColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GCSpacing.lg),
        
        // Headline
        RichText(
          text: TextSpan(
            style: textTheme.displayMedium?.copyWith(
              color: GCColors.foreground,
              height: 1.1,
              fontWeight: FontWeight.w700,
              fontSize: 56, // Large display size
            ),
            children: const [
              TextSpan(text: "Compassionate\nelder care,\n"),
              TextSpan(text: "right at home.", style: TextStyle(color: GCColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: GCSpacing.lg),
        
        // Subheadline
        Text(
          "We provide vetted, trained caregivers and nursing support so your aging parents can live safely and with dignity in the comfort of their own home.",
          style: textTheme.bodyLarge?.copyWith(
            color: GCColors.mutedForeground,
            height: 1.5,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: GCSpacing.xl),
        
        // CTA Buttons
        Wrap(
          spacing: GCSpacing.md,
          runSpacing: GCSpacing.md,
          children: [
            ElevatedButton(
              onPressed: onOpenConsultation,
              style: ElevatedButton.styleFrom(
                backgroundColor: GCColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text("Book a free consultation", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.phone_outlined, size: 20, color: GCColors.foreground),
              label: Text("1800-123-4567", style: TextStyle(color: GCColors.foreground, fontWeight: FontWeight.w600, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: GCColors.foreground,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                elevation: 1,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: GCSpacing.xl),
        
        // Trust indicators
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: GCColors.accent),
            const SizedBox(width: 8),
            Text(
              "100% Police Verified",
              style: textTheme.labelSmall?.copyWith(color: GCColors.mutedForeground),
            ),
            const SizedBox(width: 24),
            Icon(Icons.shield_outlined, size: 16, color: GCColors.accent),
            const SizedBox(width: 8),
            Text(
              "Nurse Supervised",
              style: textTheme.labelSmall?.copyWith(color: GCColors.mutedForeground),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageContent() {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Offset Background Blob
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: GCColors.secondary,
                  borderRadius: BorderRadius.circular(48),
                ),
              ),
            ),
          ),
          // Main Image
          ClipRRect(
            borderRadius: BorderRadius.circular(48),
            child: Image.asset(
              'assets/images/hero_premium.png',
              width: double.infinity,
              height: 500,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: GCColors.muted,
                width: double.infinity,
                height: 500,
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
