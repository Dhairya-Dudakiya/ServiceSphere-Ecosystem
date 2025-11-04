import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:servicesphere/features/auth/screens/login_screen.dart';
import 'package:servicesphere/features/home/screens/home_screen.dart'; // You need to create this

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is logged in, show the HomeScreen
        if (snapshot.hasData) {
          // You must create this HomeScreen. It's the main screen of your app.
          return const HomeScreen();
        }

        // User is not logged in, show the LoginScreen
        return const LoginScreen();
      },
    );
  }
}
