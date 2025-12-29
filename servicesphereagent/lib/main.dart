import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart'; // Import the Splash Screen
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

      // CHANGE: Start with Splash Screen instead of logic
      home: const SplashScreen(),
    );
  }
}
