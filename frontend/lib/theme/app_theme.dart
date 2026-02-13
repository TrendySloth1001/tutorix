import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Color palette constants
  static const Color cream = Color(0xFFFDFBD4);
  static const Color softGrey = Color(0xFFD9D7B6);
  static const Color mutedOlive = Color(0xFF878672);
  static const Color darkOlive = Color(0xFF545333);

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = const ColorScheme.light(
      primary: darkOlive,
      onPrimary: cream,
      secondary: mutedOlive,
      onSecondary: cream,
      tertiary: softGrey,
      onTertiary: darkOlive,
      surface: cream,
      onSurface: darkOlive,
      error: Colors.redAccent,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'SF Pro',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cream,

      // Card Theme
      cardTheme: CardThemeData(
        color: softGrey.withValues(alpha: 0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: mutedOlive.withValues(alpha: 0.2)),
        ),
      ),

      // Button Themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkOlive,
          foregroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkOlive,
          side: const BorderSide(color: darkOlive, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softGrey.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mutedOlive.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mutedOlive.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkOlive, width: 2),
        ),
        labelStyle: const TextStyle(color: darkOlive),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkOlive, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: darkOlive, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: darkOlive, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkOlive),
        bodyMedium: TextStyle(color: darkOlive),
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: darkOlive,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cream,
        selectedItemColor: darkOlive,
        unselectedItemColor: mutedOlive,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
