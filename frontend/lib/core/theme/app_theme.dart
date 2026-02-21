import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Application-wide Material 3 theme built from the four-role [AppColors].
///
/// ColorScheme mapping (both modes):
///   primary       → brand   (actions, emphasis)
///   onPrimary     → surface (text on brand fills)
///   secondary     → muted   (structure, de-emphasis)
///   onSecondary   → surface
///   surface       → surface (backgrounds)
///   onSurface     → fore    (primary text)
///   onSurfaceVariant → muted (secondary text)
///   outline       → muted
///   outlineVariant → muted at 30 %
///   error         → fore    (no separate hue – use weight / icons)
///   onError       → surface
class AppTheme {
  AppTheme._();

  // ── Light ──────────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: AppColors.surface,
      secondary: AppColors.muted,
      onSecondary: AppColors.surface,
      tertiary: AppColors.muted,
      onTertiary: AppColors.fore,
      surface: AppColors.surface,
      onSurface: AppColors.fore,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.muted,
      outlineVariant: AppColors.muted.withValues(alpha: 0.3),
      error: AppColors.fore,
      onError: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'SF Pro',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,

      // Card
      cardTheme: CardThemeData(
        color: AppColors.muted.withValues(alpha: 0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.muted.withValues(alpha: 0.2)),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.muted.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.muted.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.muted.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.brand),
      ),

      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.fore,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.fore,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.fore,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.fore),
        bodyMedium: TextStyle(color: AppColors.fore),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fore,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // ── Dark ───────────────────────────────────────────────────────────────

  static const _scaffold = Color(0xFF141310); // slightly darker than surfaceD

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.brandD,
      onPrimary: AppColors.surfaceD,
      secondary: AppColors.mutedD,
      onSecondary: AppColors.foreD,
      tertiary: AppColors.mutedD,
      onTertiary: AppColors.foreD,
      surface: AppColors.surfaceD,
      onSurface: AppColors.foreD,
      onSurfaceVariant: AppColors.mutedD,
      outline: AppColors.mutedD,
      outlineVariant: AppColors.mutedD.withValues(alpha: 0.3),
      surfaceContainerHighest: const Color(0xFF252420),
      error: AppColors.foreD,
      onError: AppColors.surfaceD,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'SF Pro',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _scaffold,

      // Card
      cardTheme: CardThemeData(
        color: AppColors.surfaceD,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.mutedD.withValues(alpha: 0.2)),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandD,
          foregroundColor: AppColors.surfaceD,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreD,
          side: BorderSide(color: AppColors.foreD.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.mutedD.withValues(alpha: 0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.mutedD.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.mutedD.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandD, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.foreD),
      ),

      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.foreD,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.foreD,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.foreD,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.foreD),
        bodyMedium: TextStyle(color: AppColors.foreD),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _scaffold,
        foregroundColor: AppColors.foreD,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceD,
        selectedItemColor: AppColors.brandD,
        unselectedItemColor: AppColors.mutedD,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
