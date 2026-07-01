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
    // Wait exactly for the 1.6s animation to finish
    await Future<void>.delayed(const Duration(milliseconds: 1600));
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

          ],
        ),
      ),
    );
  }
}
