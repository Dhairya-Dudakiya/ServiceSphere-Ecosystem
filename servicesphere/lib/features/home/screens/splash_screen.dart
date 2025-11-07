import 'dart:async';
import 'package:flutter/material.dart';
import 'package:servicesphere/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Set up the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 1.5 second fade-in
    );

    // 2. Set up the fade animation
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // 3. Start the animation
    _animationController.forward();

    // 4. Set up the timer to navigate after 2.5 seconds
    Timer(
      const Duration(milliseconds: 2500), // Total time on splash screen
      () {
        if (mounted) {
          // Navigate to AuthGate, which will decide where to go next
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AuthGate(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                // Fade out of the splash screen
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme data
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color logoColor =
        isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        // The FadeTransition now wraps the entire Column,
        // so everything fades in together.
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Your Logo
              Image.asset(
                'lib/assets/images/logo.png',
                height: 120,
                color: logoColor,
              ),
              const SizedBox(height: 24),

              // 2. Your App Name
              Text(
                'Service Sphere',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // 3. Your New Tagline
              Text(
                'Connect, select, and solve.',
                style: textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
