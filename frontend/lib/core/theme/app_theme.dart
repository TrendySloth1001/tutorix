import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Application-wide Material 3 theme built from [AppColors].
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.darkOlive,
      onPrimary: AppColors.cream,
      secondary: AppColors.mutedOlive,
      onSecondary: AppColors.cream,
      tertiary: AppColors.softGrey,
      onTertiary: AppColors.darkOlive,
      surface: AppColors.cream,
      onSurface: AppColors.darkOlive,
      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'SF Pro',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,

      // Card
      cardTheme: CardThemeData(
        color: AppColors.softGrey.withValues(alpha: 0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.mutedOlive.withValues(alpha: 0.2)),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkOlive,
          foregroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkOlive,
          side: const BorderSide(color: AppColors.darkOlive, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.softGrey.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.mutedOlive.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.mutedOlive.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkOlive, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.darkOlive),
      ),

      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.darkOlive,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.darkOlive,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.darkOlive,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.darkOlive),
        bodyMedium: TextStyle(color: AppColors.darkOlive),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.darkOlive,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cream,
        selectedItemColor: AppColors.darkOlive,
        unselectedItemColor: AppColors.mutedOlive,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // ── Dark-mode palette tokens ───────────────────────────────────────────
  static const _darkPrimary = Color(0xFF66BB6A);
  static const _darkOnPrimary = Color(0xFF0F110F);
  static const _darkSurface = Color(0xFF1B1E1A);
  static const _darkOnSurface = Color(0xFFE6E5C8);
  static const _darkScaffold = Color(0xFF121412);
  static const _darkInputFill = Color(0xFF1F221E);

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: _darkPrimary,
      onPrimary: _darkOnPrimary,
      secondary: AppColors.mutedOlive,
      onSecondary: _darkOnPrimary,
      tertiary: Color(0xFF3A3D39),
      onTertiary: _darkOnSurface,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      surfaceContainerHighest: Color(0xFF252825),
      error: AppColors.error,
      onError: Colors.white,
      outline: Color(0xFF4A4D48),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'SF Pro',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkScaffold,

      // Card
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.mutedOlive.withValues(alpha: 0.15),
          ),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkOnSurface,
          side: BorderSide(color: _darkOnSurface.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.mutedOlive.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.mutedOlive.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: _darkOnSurface),
      ),

      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: _darkOnSurface,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: _darkOnSurface,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: _darkOnSurface,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: _darkOnSurface),
        bodyMedium: TextStyle(color: _darkOnSurface),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkScaffold,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: AppColors.mutedOlive,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

}
