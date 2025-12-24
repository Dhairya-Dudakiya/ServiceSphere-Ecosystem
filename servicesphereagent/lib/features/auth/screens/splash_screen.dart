import 'dart:async';
import 'package:flutter/material.dart';
import 'package:servicesphereagent/features/auth/screens/agent_login_screen.dart';

class AgentSplashScreen extends StatefulWidget {
  const AgentSplashScreen({super.key});

  @override
  State<AgentSplashScreen> createState() => _AgentSplashScreenState();
}

class _AgentSplashScreenState extends State<AgentSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    // Navigate after 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            // TODO: Ideally replace this with 'AgentAuthGate' when you have one
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AgentLoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // You can use a different color here (e.g. Green) to distinguish the Agent App
    final Color logoColor = isDarkMode ? Colors.white : const Color(0xFF2F5C8A);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ensure you have added the logo to assets/images/logo.png in this project too!
              Image.asset(
                'lib/assets/images/logo.png',
                height: 100,
                color: logoColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Service Sphere',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Distinct branding for the Agent App
              Text(
                'PARTNER APP',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
