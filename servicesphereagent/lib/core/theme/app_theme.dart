import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- AGENT BRAND COLORS ---
  static const Color kPrimaryColor = Color(0xFF2E7D32); // Professional Green
  static const Color kLightGreenTint = Color(
    0xFFF1F8E9,
  ); // Light green for inputs

  // --- Light Theme Colors ---
  static const Color kLightBackground = Color(0xFFF8F9FA);
  static const Color kLightSurface = Color(0xFFFFFFFF);
  static const Color kLightOnSurface = Color(0xFF212529);

  // --- Dark Theme Colors ---
  static const Color kDarkBackground = Color(0xFF1C1E22);
  static const Color kDarkSurface = Color(0xFF25282D);
  static const Color kDarkOnSurface = Color(0xFFE3E3E3);

  static final BorderRadius kBorderRadius = BorderRadius.circular(12);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: kPrimaryColor,
        onPrimary: kLightSurface,
        secondary: kPrimaryColor,
        onSecondary: kLightSurface,
        error: Colors.red,
        onError: kLightSurface,
        background: kLightBackground,
        onBackground: kLightOnSurface,
        surface: kLightSurface,
        onSurface: kLightOnSurface,
        outline: Colors.grey,
        surfaceVariant: kLightGreenTint,
      ),
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: kLightBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: kLightOnSurface,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: kLightOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        color: kLightSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kLightGreenTint,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: kBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: kBorderRadius,
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          backgroundColor: kPrimaryColor,
          foregroundColor: kLightSurface,
          shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );
    final baseLight = lightTheme;

    return ThemeData(
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
        surface: kDarkSurface,
        onSurface: kDarkOnSurface,
        outline: Colors.grey,
        surfaceVariant: kDarkSurface,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: kDarkOnSurface,
        displayColor: kDarkOnSurface,
      ),
      scaffoldBackgroundColor: kDarkBackground,
      appBarTheme: baseLight.appBarTheme.copyWith(
        foregroundColor: kDarkOnSurface,
      ),
      cardTheme: baseLight.cardTheme.copyWith(color: kDarkSurface),
      inputDecorationTheme: baseLight.inputDecorationTheme.copyWith(
        fillColor: kDarkSurface,
      ),
      elevatedButtonTheme: baseLight.elevatedButtonTheme,
    );
  }
}
