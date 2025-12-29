import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicesphereagent/features/auth/screens/agent_login_screen.dart';
// IMPORTANT: Make sure this import points to your actual Dashboard/Home file
import 'package:servicesphereagent/features/dashboard/agent_home_screen.dart';

class AgentAuthGate extends StatelessWidget {
  const AgentAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If connection is waiting (loading)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If logged in -> Go to Dashboard
        if (snapshot.hasData) {
          return const AgentHomeScreen();
        }

        // 3. Otherwise -> Go to Login
        return const AgentLoginScreen();
      },
    );
  }
}
