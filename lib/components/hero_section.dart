import 'package:flutter/material.dart';

class HeroSection extends StatelessWidget {
  final VoidCallback onOpenConsultation;

  const HeroSection({
    super.key,
    required this.onOpenConsultation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAF6EE), // exact beige from screenshot
      padding: const EdgeInsets.only(
        top: 64,
        bottom: 64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 11, child: _buildTextContent(context)),
                      const SizedBox(width: 64),
                      Expanded(flex: 10, child: _buildImageContent()),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextContent(context),
                      const SizedBox(height: 64),
                      _buildImageContent(),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3ECE1), // Light sage green
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF5A6844).withAlpha(30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF5A6844)),
              const SizedBox(width: 8),
              Text(
                "India's Most Trusted Care Network",
                style: const TextStyle(
                  color: Color(0xFF5A6844),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Headline
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Playfair Display', // Serif font from screenshot
              color: Color(0xFF2D3325),
              height: 1.1,
              fontWeight: FontWeight.w800,
              fontSize: 64, // Large display size
            ),
            children: [
              TextSpan(text: "Compassionate\nelder care,\n"),
              TextSpan(text: "right at home.", style: TextStyle(color: Color(0xFF5A6844))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Subheadline
        const Text(
          "We provide vetted, trained caregivers and nursing support so your aging parents can live safely and with dignity in the comfort of their own home.",
          style: TextStyle(
            color: Color(0xFF5C6450),
            height: 1.6,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 40),
        
        // CTA Buttons
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ElevatedButton(
              onPressed: onOpenConsultation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A6844),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text("Book a free consultation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF2D3325)),
              label: const Text("1800-123-4567", style: TextStyle(color: Color(0xFF2D3325), fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2D3325),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                elevation: 0, // Flat outline style like screenshot
                side: const BorderSide(color: Color(0xFFE7DFD4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 48),
        
        // Trust indicators
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF5A6844)),
            const SizedBox(width: 8),
            const Text(
              "100% Police Verified",
              style: TextStyle(color: Color(0xFF5C6450), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 24),
            const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF5A6844)),
            const SizedBox(width: 8),
            const Text(
              "Nurse Supervised",
              style: TextStyle(color: Color(0xFF5C6450), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageContent() {
    return Padding(
      padding: const EdgeInsets.only(right: 32, top: 32),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Offset Background Blob (shifted right and up as seen in screenshot)
          Positioned(
            top: -32,
            bottom: -64,
            left: 48,
            right: -120, // Extends far to the right edge
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFE3ECE1), // Light sage green
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(64),
                  bottomLeft: Radius.circular(64),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
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
              height: 550,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFD1E0CE),
                width: double.infinity,
                height: 550,
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
