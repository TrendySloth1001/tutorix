import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Centralized alert/dialog system. Never expose raw exceptions to users.
class AppAlert {
  AppAlert._();

  /// Clean an exception message — strip 'Exception:', stack traces, etc.
  static String _cleanMessage(dynamic error) {
    String msg = error.toString();
    // Remove "Exception: " prefix
    msg = msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
    // Remove "FormatException: " prefix
    msg = msg.replaceFirst(RegExp(r'^FormatException:\s*'), '');
    // Truncate if too long
    if (msg.length > 200) msg = '${msg.substring(0, 200)}…';
    // If it looks like a technical error (stacktrace, etc.), replace
    if (msg.contains('Stack Trace') ||
        msg.contains('at ') ||
        msg.contains('#0') ||
        msg.contains('dart:') ||
        msg.contains('package:')) {
      return 'Something went wrong. Please try again.';
    }
    return msg;
  }

  /// Show a simple error snackbar with a user-friendly message.
  static void error(BuildContext context, dynamic error, {String? fallback}) {
    if (!context.mounted) return;
    final message = fallback ?? _cleanMessage(error);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: Spacing.sp12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          margin: const EdgeInsets.all(Spacing.sp16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Show a success snackbar.
  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: Spacing.sp12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          margin: const EdgeInsets.all(Spacing.sp16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Show a warning snackbar.
  static void warning(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: Spacing.sp12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          margin: const EdgeInsets.all(Spacing.sp16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Show a confirmation dialog and return true if the user confirmed.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        icon: icon != null
            ? Icon(
                icon,
                size: 32,
                color: confirmColor ?? Theme.of(context).colorScheme.error,
              )
            : null,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: FontSize.title,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  confirmColor ?? Theme.of(context).colorScheme.error,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show a simple info dialog.
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: FontSize.title,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
