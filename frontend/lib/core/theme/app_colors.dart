import 'package:flutter/material.dart';

/// Design-token palette for the Tutorix brand.
///
/// Consumed by [AppTheme] – screens should use `Theme.of(context).colorScheme`
/// rather than referencing these directly.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color cream = Color(0xFFFDFBD4);
  static const Color softGrey = Color(0xFFD9D7B6);
  static const Color mutedOlive = Color(0xFF878672);
  static const Color darkOlive = Color(0xFF545333);
  static const Color primaryGreen = Color(0xFF4CAF50);

  // ── Surfaces ───────────────────────────────────────────────────────────
  static const Color offWhite = Color(0xFFF7F6F2);

  // ── Status / Semantic ──────────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF81C784);
  static const Color successBg = Color(0xFFE8F5E9);

  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFEF9A9A);
  static const Color errorBg = Color(0xFFFFEBEE);

  static const Color info = Color(0xFF1565C0);
  static const Color infoBg = Color(0xFFE3F2FD);

  static const Color warning = Color(0xFFE65100);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningBg = Color(0xFFFFF3E0);

  static const Color purple = Color(0xFF7B1FA2);

  // ── Deep accents (used sparingly) ──────────────────────────────────────
  static const Color deepGreen = Color(0xFF1B5E20);
  static const Color deepOrange = Color(0xFFBF360C);
  static const Color deepTeal = Color(0xFF004D40);
  static const Color brown = Color(0xFF5D4037);
  static const Color amberBorder = Color(0xFFFFB300);

  // ── Role colours ───────────────────────────────────────────────────────
  static const Color roleAdmin = Color(0xFF6B5B95);
  static const Color roleTeacher = Color(0xFF4A90A4);
  static const Color roleStudent = Color(0xFF5B8C5A);
  static const Color rolePending = Color(0xFFC48B3F);
  static const Color roleParent = Color(0xFFE65100);
  static const Color roleMember = Color(0xFF455A64);
  static const Color roleAdminAlt = Color(0xFF6A1B9A);

  // ── File-type colours ──────────────────────────────────────────────────
  static const Color filePdf = Color(0xFFE53935);
  static const Color fileImage = Color(0xFF8E24AA);
  static const Color fileDoc = Color(0xFF1E88E5);
  static const Color fileLink = Color(0xFF00897B);

  /// Resolves a MIME type / extension to its colour.
  static Color fileTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('pdf')) return filePdf;
    if (t.contains('image') || t.contains('jpg') || t.contains('png')) {
      return fileImage;
    }
    if (t.contains('doc') ||
        t.contains('word') ||
        t.contains('text') ||
        t.contains('xls') ||
        t.contains('csv') ||
        t.contains('ppt')) {
      return fileDoc;
    }
    return fileLink;
  }

  // ── Notice-type colours ────────────────────────────────────────────────
  static const Color noticeGeneral = Color(0xFF3B82F6);
  static const Color noticeTimetable = Color(0xFF8B5CF6);
  static const Color noticeEvent = Color(0xFF10B981);
  static const Color noticeExam = Color(0xFFEF4444);
  static const Color noticeHoliday = Color(0xFFF59E0B);
  static const Color noticeAssignment = Color(0xFF0EA5E9);

  /// Resolve a notice type string to its colour.
  static Color noticeTypeColor(String type) => switch (type.toUpperCase()) {
    'GENERAL' => noticeGeneral,
    'TIMETABLE_CHANGE' || 'TIMETABLE' => noticeTimetable,
    'EVENT' => noticeEvent,
    'EXAM' => noticeExam,
    'HOLIDAY' => noticeHoliday,
    'ASSIGNMENT' => noticeAssignment,
    _ => noticeGeneral,
  };

  // ── Priority colours ──────────────────────────────────────────────────
  static const Color priorityLow = Color(0xFF9E9E9E);
  static const Color priorityNormal = Color(0xFF42A5F5);
  static const Color priorityHigh = Color(0xFFFFA726);
  static const Color priorityUrgent = Color(0xFFEF5350);

  /// Resolve a priority string to its colour.
  static Color priorityColor(String priority) =>
      switch (priority.toUpperCase()) {
        'LOW' => priorityLow,
        'NORMAL' => priorityNormal,
        'HIGH' => priorityHigh,
        'URGENT' => priorityUrgent,
        _ => priorityNormal,
      };

  // ── Batch / Status (Tailwind-ish) ──────────────────────────────────────
  static const Color activeGreen = Color(0xFF10B981);
  static const Color pendingAmber = Color(0xFFF59E0B);
  static const Color activeBlue = Color(0xFF3B82F6);

  // ── Debug/Admin screen (HTTP status codes, log levels) ────────────────
  static const Color debugError = Color(0xFFD32F2F);
  static const Color debugSuccess = Color(0xFF388E3C);
  static const Color debugWarning = Color(0xFFF57C00);
  static const Color debugInfo = Color(0xFF1976D2);
  static const Color debugPurple = Color(0xFF7B1FA2);
  static const Color debugTeal = Color(0xFF00796B);
  static const Color debugBlueGrey = Color(0xFF455A64);
  static const Color debugBrown = Color(0xFF5D4037);
  static const Color debugLightBlue = Color(0xFF0288D1);
  static const Color debugGrey = Color(0xFF90A4AE);
  static const Color debugPink = Color(0xFF880E4F);
}
