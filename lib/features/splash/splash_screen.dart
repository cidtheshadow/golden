import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Wait for the full animation to complete
    await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 500));
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GCColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left Hand
                  Icon(Icons.pan_tool, size: 64, color: const Color(0xFFD4AF37)) // Golden
                      .animate()
                      .slideX(
                          begin: -5,
                          end: -0.6,
                          duration: 1.seconds,
                          curve: Curves.easeOutBack)
                      .fadeOut(delay: 1200.ms, duration: 400.ms),

                  // Right Hand (Flipped)
                  Transform.flip(
                    flipX: true,
                    child: Icon(Icons.pan_tool,
                        size: 64, color: const Color(0xFFD4AF37)), // Golden
                  )
                      .animate()
                      .slideX(
                          begin: 5,
                          end: 0.6,
                          duration: 1.seconds,
                          curve: Curves.easeOutBack)
                      .fadeOut(delay: 1200.ms, duration: 400.ms),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Text Animation
            const Text(
              'GoldenCare',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair Display',
                color: GCColors.primary,
                letterSpacing: 1.2,
              ),
            )
                .animate(delay: 1800.ms)
                .fade(duration: 800.ms)
                .slideY(
                    begin: 0.3,
                    end: 0,
                    duration: 800.ms,
                    curve: Curves.easeOutCubic),

            const SizedBox(height: 12),

            const Text(
              'Compassionate Care at Home',
              style: TextStyle(
                fontSize: 14,
                color: GCColors.mutedForeground,
                letterSpacing: 0.5,
              ),
            ).animate(delay: 2200.ms).fade(duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
