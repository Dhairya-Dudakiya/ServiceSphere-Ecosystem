import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicesphere/core/services/notification_service.dart';
import 'package:servicesphere/features/splash/splash_screen.dart';
import 'firebase_options.dart';

// --- 1. A NEW, PROFESSIONAL COLOR PALETTE ---
// This is a more sophisticated, less saturated blue
const Color kPrimaryColor = Color(0xFF2F5C8A);
const Color kLightBlue = Color(0xFFEDF2F7);

// --- Light Theme Colors ---
const Color kLightBackground = Color(0xFFF8F9FA);
const Color kLightSurface = Color(0xFFFFFFFF);
const Color kLightOnSurface = Color(0xFF212529); // Dark grey, not black

// --- Dark Theme Colors ---
const Color kDarkBackground = Color(0xFF1C1E22); // Off-black
const Color kDarkSurface = Color(0xFF25282D); // Lighter grey for cards
const Color kDarkOnSurface = Color(0xFFE3E3E3); // Off-white

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initNotifications();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- 2. DEFINE THE SHARED STYLES ---

    // A consistent border radius for all components
    final BorderRadius kBorderRadius = BorderRadius.circular(12);

    // A consistent text theme
    final TextTheme kBaseTextTheme =
        GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    // --- 3. CREATE THE LIGHT THEME ---
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: kPrimaryColor,
        onPrimary: kLightSurface,
        secondary: kPrimaryColor, // Can be a different accent
        onSecondary: kLightSurface,
        error: Colors.red,
        onError: kLightSurface,
        background: kLightBackground,
        onBackground: kLightOnSurface,
        surface: kLightSurface,
        onSurface: kLightOnSurface,
        outline: Colors.grey,
        surfaceVariant: kLightBlue, // Used for input fill
      ),
      textTheme: kBaseTextTheme,
      scaffoldBackgroundColor: kLightBackground,

      // --- 4. STYLE ALL COMPONENTS TO BE "IN SYNC" ---

      // --- AppBar Theme ---
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent, // Blends with scaffold
        foregroundColor: kLightOnSurface, // Icons and text
        titleTextStyle: kBaseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: kLightOnSurface,
        ),
      ),

      // --- Card Theme (Fixed with CardThemeData) ---
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
      ),

      // --- Text Field Theme ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kLightBlue,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: kBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: kBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: kBorderRadius,
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
        labelStyle: kBaseTextTheme.bodyMedium?.copyWith(
          color: Colors.grey[700],
        ),
      ),

      // --- Button Themes ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          backgroundColor: kPrimaryColor,
          foregroundColor: kLightSurface,
          shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
          textStyle: kBaseTextTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
          side: const BorderSide(color: Colors.grey),
          foregroundColor: kLightOnSurface,
        ),
      ),

      // --- ListTile Theme (for All Categories page) ---
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
      ),
    );

    // --- 5. CREATE THE DARK THEME ---
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: kPrimaryColor,
        onPrimary: kLightSurface,
        secondary: kPrimaryColor,
        onSecondary: kLightSurface,
        error: Colors.red,
        onError: kLightSurface,
        background: kDarkBackground,
        onBackground: kDarkOnSurface,
        surface: kDarkSurface, // Cards
        onSurface: kDarkOnSurface, // Text on cards
        outline: Colors.grey,
        surfaceVariant: kDarkSurface, // Used for input fill
      ),
      textTheme: kBaseTextTheme.apply(
        bodyColor: kDarkOnSurface,
        displayColor: kDarkOnSurface,
      ),
      scaffoldBackgroundColor: kDarkBackground,

      // --- 6. STYLE ALL DARK COMPONENTS ---
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: kDarkOnSurface,
        titleTextStyle: kBaseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: kDarkOnSurface,
        ),
      ),
      // --- Fixed dark theme card ---
      cardTheme: lightTheme.cardTheme.copyWith(
        color: kDarkSurface,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
        fillColor: kDarkSurface,
        labelStyle: kBaseTextTheme.bodyMedium?.copyWith(
          color: Colors.grey[400],
        ),
      ),
      elevatedButtonTheme: lightTheme.elevatedButtonTheme,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
          side: const BorderSide(color: Colors.grey),
          foregroundColor: kDarkOnSurface,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
      ),
    );

    // --- 7. RETURN THE MATERIAL APP ---
    return MaterialApp(
      title: 'Service Sphere',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // Automatically switches
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // <-- Starts with the SplashScreen
    );
  }
}
