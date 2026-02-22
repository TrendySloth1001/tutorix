import 'dart:io';

import 'package:flutter/foundation.dart';
import '../constants/error_strings.dart';

/// Converts raw exceptions into user-friendly messages.
///
/// In **debug mode** (`kDebugMode`) the sanitized message includes the
/// original technical detail in parentheses so developers can triage
/// quickly. In release builds users only see the friendly text.
///
/// Usage:
/// ```dart
/// try { ... } catch (e) {
///   AppAlert.error(context, e, fallback: FeeErrors.loadFailed);
/// }
/// ```
/// The `AppAlert.error()` method calls `ErrorSanitizer.sanitize(error)` if
/// no `fallback` is provided.
class ErrorSanitizer {
  ErrorSanitizer._();

  /// Return a clean, user-visible message for any error.
  ///
  /// If [fallback] is supplied it is used as the base friendly message.
  /// Otherwise the method inspects the exception type & content to choose
  /// the best generic message from [Errors].
  static String sanitize(dynamic error, {String? fallback}) {
    final raw = _rawString(error);

    // 1. Map by exception type / content.
    final friendly = fallback ?? _classify(raw, error);

    // 2. In debug mode append the raw message for developer visibility.
    if (kDebugMode) {
      final trimmed = raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
      return '$friendly\n[$trimmed]';
    }

    return friendly;
  }

  // ── Internal helpers ────────────────────────────────────────────────

  /// Extract a plain string from any error object.
  static String _rawString(dynamic error) {
    String msg = error.toString();
    // Strip common prefixes
    msg = msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
    msg = msg.replaceFirst(RegExp(r'^FormatException:\s*'), '');
    // Trim whitespace
    return msg.trim();
  }

  /// Map well-known error patterns to friendly constants.
  static String _classify(String raw, dynamic error) {
    final lower = raw.toLowerCase();

    // ── Network / connectivity ──
    if (error is SocketException ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('no address associated') ||
        lower.contains('network is unreachable')) {
      return Errors.offline;
    }
    if (lower.contains('connection closed') ||
        lower.contains('connection reset')) {
      return Errors.serverDown;
    }
    if (error is HttpException || lower.contains('httpexception')) {
      return Errors.serverDown;
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return Errors.timeout;
    }

    // ── HTTP status patterns (from ApiClient throws) ──
    if (lower.contains('401') || lower.contains('not authenticated')) {
      return Errors.unauthorized;
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return Errors.forbidden;
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return Errors.notFound;
    }
    if (lower.contains('429') || lower.contains('too many requests')) {
      return Errors.tooManyRequests;
    }
    if (lower.contains('500') ||
        lower.contains('internal server') ||
        lower.contains('502 bad gateway') ||
        lower.contains('503 service unavailable')) {
      return Errors.serverError;
    }

    // ── Stack trace / technical noise ──
    if (raw.contains('Stack Trace') ||
        raw.contains('#0') ||
        raw.contains('dart:') ||
        raw.contains('package:')) {
      return Errors.fallback;
    }

    // ── If the server sent a clean message (< 100 chars, no stack) ──
    if (raw.length < 100 && !raw.contains('\n')) {
      return raw;
    }

    return Errors.fallback;
  }
}
