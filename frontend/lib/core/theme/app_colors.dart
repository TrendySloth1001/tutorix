import 'package:flutter/material.dart';

/// Design-token palette for the Tutorix brand.
///
/// Consumed by [AppTheme] – screens should use `Theme.of(context).colorScheme`
/// rather than referencing these directly.
class AppColors {
  AppColors._();

  static const Color cream = Color(0xFFFDFBD4);
  static const Color softGrey = Color(0xFFD9D7B6);
  static const Color mutedOlive = Color(0xFF878672);
  static const Color darkOlive = Color(0xFF545333);
  static const Color primaryGreen = Color(0xFF4CAF50);
}
