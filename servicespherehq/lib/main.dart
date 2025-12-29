import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart'; // Make sure this is generated

// Screens
import 'features/auth/screens/admin_login_screen.dart';
import 'features/dashboard/screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ServiceSphereAdminApp());
}

class ServiceSphereAdminApp extends StatelessWidget {
  const ServiceSphereAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiceSphere HQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5), // Professional Blue
          background: const Color(0xFFF4F7FC), // Grey Background
        ),
        useMaterial3: true,
        // Apply Google Font 'Inter' globally
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      // --- AUTH GATE LOGIC ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. Logged In -> Go to Dashboard
          if (snapshot.hasData) {
            return const AdminDashboardScreen();
          }

          // 3. Not Logged In -> Go to Login
          return const AdminLoginScreen();
        },
      ),
    );
  }
}
