import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/error_sanitizer.dart';

/// Centralized alert/dialog system. Never expose raw exceptions to users.
class AppAlert {
  AppAlert._();

  /// Show a simple error snackbar with a user-friendly message.
  ///
  /// Pass a [fallback] from `error_strings.dart` to guarantee a clean
  /// message regardless of what the raw exception contains.
  static void error(BuildContext context, dynamic error, {String? fallback}) {
    if (!context.mounted) return;
    final message = ErrorSanitizer.sanitize(error, fallback: fallback);
    _show(context, message: message, type: _AlertType.error);
  }

  /// Show a success snackbar.
  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(context, message: message, type: _AlertType.success);
  }

  /// Show a warning snackbar.
  static void warning(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(context, message: message, type: _AlertType.warning);
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

  // ── Private ─────────────────────────────────────────────────────────

  static void _show(
    BuildContext context, {
    required String message,
    required _AlertType type,
  }) {
    final theme = Theme.of(context);

    final (IconData icon, Color bg, int seconds) = switch (type) {
      _AlertType.error => (
        Icons.error_outline_rounded,
        theme.colorScheme.error,
        4,
      ),
      _AlertType.success => (
        Icons.check_circle_outline_rounded,
        theme.colorScheme.primary,
        2,
      ),
      _AlertType.warning => (
        Icons.warning_amber_rounded,
        theme.colorScheme.tertiary,
        3,
      ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: Spacing.sp20),
              const SizedBox(width: Spacing.sp12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: FontSize.body,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          margin: const EdgeInsets.all(Spacing.sp16),
          duration: Duration(seconds: seconds),
        ),
      );
  }
}

enum _AlertType { error, success, warning }

// ═══════════════════════════════════════════════════════════════════════
// Shared inline error + retry widget — replaces all private _ErrorRetry
// ═══════════════════════════════════════════════════════════════════════

/// Full-screen-center error state with icon, friendly message, and retry.
///
/// Use this inside any screen body when `_error != null`.
/// ```dart
/// _error != null
///     ? ErrorRetry(message: _error!, onRetry: _load)
///     : _buildContent(),
/// ```
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sectionGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: Spacing.sp48,
            ),
            const SizedBox(height: Spacing.sp16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: FontSize.body,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: Spacing.sp20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: Spacing.sp16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
