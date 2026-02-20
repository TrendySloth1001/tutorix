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
      error: Colors.redAccent,
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

  static ThemeData get darkTheme {
  const colorScheme = ColorScheme.dark(
    primary: Color(0xFF66BB6A),
    onPrimary: Color(0xFF0F110F),

    secondary: AppColors.mutedOlive,
    onSecondary: Color(0xFF101210),

    surface: Color(0xFF1B1E1A),
    onSurface: Color(0xFFE6E5C8),

    background: Color(0xFF121412),
    onBackground: Color(0xFFE6E5C8),

    error: Colors.redAccent,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'SF Pro',
    colorScheme: colorScheme,

    scaffoldBackgroundColor: const Color(0xFF121412),

    cardTheme: CardThemeData(
      color: const Color(0xFF1B1E1A),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.mutedOlive.withValues(alpha: 0.15),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF66BB6A),
        foregroundColor: const Color(0xFF0F110F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1F221E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.mutedOlive.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF66BB6A),
          width: 2,
        ),
      ),
    ),
  );
}

}
