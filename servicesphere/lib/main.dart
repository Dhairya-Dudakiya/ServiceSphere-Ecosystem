import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicesphere/auth_gate.dart';
import 'firebase_options.dart';

// --- YOUR NEW BRAND COLOR ---
const Color primaryBlue = Color(0xFF0057FF);
const Color lightBlue = Color(0xFFF0F5FF);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- CREATING THE THEME ---
    final baseTheme = ThemeData(brightness: Brightness.light);
    final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme);

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        surface: Colors.white,
        background: Colors.white,
      ),
      textTheme: textTheme.apply(
        bodyColor: const Color(0xFF333333),
        displayColor: const Color(0xFF111111),
      ),
      // --- Consistent Button Style ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // --- Consistent Text Field Style ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightBlue,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.grey[700],
        ),
      ),
    );

    // --- (Optional) Dark Theme for a professional touch ---
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        surface: const Color(0xFF121212),
        background: const Color(0xFF121212),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFE0E0E0),
        displayColor: Colors.white,
      ),
      elevatedButtonTheme: lightTheme.elevatedButtonTheme,
      inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFF222222),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.grey[400],
        ),
      ),
    );

    return MaterialApp(
      title: 'Service Sphere',
      theme: lightTheme, // <-- Set your light theme
      darkTheme: darkTheme, // <-- Set your dark theme
      themeMode: ThemeMode.system, // Automatically switch
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
