import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import 'core/theme/app_theme.dart';
import 'features/auth/screens/agent_login_screen.dart';
import 'features/dashboard/agent_dashboard_screen.dart'; // Import Dashboard
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ServiceSphereAgentApp());
}

class ServiceSphereAgentApp extends StatelessWidget {
  const ServiceSphereAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiceSphere Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // THIS IS THE NEW PART:
      // It checks if the user is logged in or out automatically.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. If connection is waiting (loading)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. If we have a user data -> Go to Dashboard
          if (snapshot.hasData) {
            return const AgentDashboardScreen();
          }

          // 3. Otherwise -> Go to Login
          return const AgentLoginScreen();
        },
      ),
    );
  }
}
