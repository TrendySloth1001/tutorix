import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../utils/device_info_helper.dart';
import '../../shared/services/secure_storage_service.dart';

// ── Log level enum ──────────────────────────────────────────────────────────

enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warn('WARN'),
  error('ERROR'),
  fatal('FATAL');

  const LogLevel(this.value);
  final String value;

  int get priority => index;
}

// ── Log category enum ───────────────────────────────────────────────────────

enum LogCategory {
  api('API'),
  auth('AUTH'),
  navigation('NAV'),
  ui('UI'),
  lifecycle('LIFECYCLE'),
  storage('STORAGE'),
  network('NETWORK'),
  system('SYSTEM');

  const LogCategory(this.value);
  final String value;
}

// ── In-memory log entry (for local ring buffer) ─────────────────────────────

class LocalLogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic>? metadata;

  const LocalLogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.error,
    this.stackTrace,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.value,
        'category': category.value,
        'message': message,
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (metadata != null) 'metadata': metadata,
      };
}

// ── Main service ────────────────────────────────────────────────────────────

/// Comprehensive logging service for the entire app.
///
/// Features:
/// - Multiple log levels: DEBUG, INFO, WARN, ERROR, FATAL
/// - Categories: API, AUTH, NAV, UI, LIFECYCLE, STORAGE, NETWORK, SYSTEM
/// - Local in-memory ring buffer (last 500 entries) for in-app viewing
/// - Automatic device info collection
/// - Fire-and-forget backend syncing (never blocks the UI)
/// - Batched sending for efficiency
class ErrorLoggerService {
  ErrorLoggerService._();
  static final ErrorLoggerService instance = ErrorLoggerService._();

  // Use direct HTTP to avoid circular logging (ApiClient logs everything)
  final SecureStorageService _storage = SecureStorageService.instance;

  // ── Ring buffer ─────────────────────────────────────────────────────────

  static const int _maxLocalEntries = 500;
  final Queue<LocalLogEntry> _localLogs = Queue<LocalLogEntry>();

  /// Read-only view of local log entries (newest first).
  List<LocalLogEntry> get localLogs => _localLogs.toList().reversed.toList();

  /// Total count of locally buffered logs.
  int get localLogCount => _localLogs.length;

  // ── Device info (cached) ────────────────────────────────────────────────

  String? _deviceDescription;
  String? _osVersion;
  String? _platform;

  Future<void> _ensureDeviceInfo() async {
    if (_deviceDescription != null) return;
    try {
      _deviceDescription = await DeviceInfoHelper.getDeviceDescription();
      _platform = Platform.operatingSystem;
      _osVersion = Platform.operatingSystemVersion;
    } catch (_) {
      _deviceDescription = 'unknown';
      _platform = 'unknown';
      _osVersion = 'unknown';
    }
  }

  // ── Minimum level to send to backend ────────────────────────────────────

  LogLevel _minRemoteLevel = LogLevel.info;

  /// Set the minimum log level that gets sent to the backend.
  /// Logs below this level are only stored locally.
  set minRemoteLevel(LogLevel level) => _minRemoteLevel = level;

  // ── Batch queue ─────────────────────────────────────────────────────────

  final List<Map<String, dynamic>> _pendingBatch = [];
  Timer? _batchTimer;
  static const int _batchSize = 10;
  static const Duration _batchInterval = Duration(seconds: 5);

  // ── Public API ──────────────────────────────────────────────────────────

  /// Log a debug message (local only by default).
  void debug(
    String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      level: LogLevel.debug,
      category: category,
      message: message,
      metadata: metadata,
    );
  }

  /// Log an informational message.
  void info(
    String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      level: LogLevel.info,
      category: category,
      message: message,
      metadata: metadata,
    );
  }

  /// Log a warning.
  void warn(
    String message, {
    LogCategory category = LogCategory.system,
    String? error,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      level: LogLevel.warn,
      category: category,
      message: message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Log an error.
  void error(
    String message, {
    LogCategory category = LogCategory.system,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      level: LogLevel.error,
      category: category,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      metadata: metadata,
    );
  }

  /// Log a fatal / unrecoverable error.
  void fatal(
    String message, {
    LogCategory category = LogCategory.system,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      level: LogLevel.fatal,
      category: category,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      metadata: metadata,
    );
  }

  // ── Convenience: API request logging ────────────────────────────────────

  /// Log an outgoing API request start.
  void apiRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) {
    final path = url.replaceFirst(ApiConstants.baseUrl, '');
    _log(
      level: LogLevel.debug,
      category: LogCategory.api,
      message: '$method $path',
      metadata: {
        'method': method,
        'url': url,
        'path': path,
        if (body != null) 'bodyKeys': body.keys.toList(),
      },
    );
  }

  /// Log a completed API response.
  void apiResponse(
    String method,
    String url, {
    required int statusCode,
    required Duration duration,
  }) {
    final path = url.replaceFirst(ApiConstants.baseUrl, '');
    final level = statusCode >= 400 ? LogLevel.error : LogLevel.info;
    _log(
      level: level,
      category: LogCategory.api,
      message: '$method $path → $statusCode (${duration.inMilliseconds}ms)',
      metadata: {
        'method': method,
        'path': path,
        'statusCode': statusCode,
        'durationMs': duration.inMilliseconds,
      },
    );
  }

  /// Log a failed API call (network error, timeout, etc.).
  void apiError(
    String method,
    String url, {
    required Object error,
    StackTrace? stackTrace,
    Duration? duration,
  }) {
    final path = url.replaceFirst(ApiConstants.baseUrl, '');
    _log(
      level: LogLevel.error,
      category: LogCategory.api,
      message:
          '$method $path failed${duration != null ? ' after ${duration.inMilliseconds}ms' : ''}',
      error: error.toString(),
      stackTrace: stackTrace?.toString(),
      metadata: {
        'method': method,
        'path': path,
        if (duration != null) 'durationMs': duration.inMilliseconds,
      },
    );
  }

  // ── Convenience: Navigation logging ─────────────────────────────────────

  void navigationPush(String routeName) {
    _log(
      level: LogLevel.info,
      category: LogCategory.navigation,
      message: 'Pushed → $routeName',
    );
  }

  void navigationPop(String routeName) {
    _log(
      level: LogLevel.debug,
      category: LogCategory.navigation,
      message: 'Popped ← $routeName',
    );
  }

  void navigationReplace(String oldRoute, String newRoute) {
    _log(
      level: LogLevel.info,
      category: LogCategory.navigation,
      message: 'Replaced $oldRoute → $newRoute',
    );
  }

  // ── Convenience: Lifecycle logging ──────────────────────────────────────

  void lifecycleChange(String state) {
    _log(
      level: LogLevel.info,
      category: LogCategory.lifecycle,
      message: 'App lifecycle → $state',
    );
  }

  // ── Convenience: Auth logging ───────────────────────────────────────────

  void authEvent(String event, {Map<String, dynamic>? metadata}) {
    _log(
      level: LogLevel.info,
      category: LogCategory.auth,
      message: event,
      metadata: metadata,
    );
  }

  // ── Legacy compatibility ────────────────────────────────────────────────

  /// Backward-compatible error logging method.
  Future<void> logError({
    required String message,
    required String error,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    this.error(
      message,
      category: LogCategory.system,
      error: error,
      stackTrace:
          stackTrace != null ? StackTrace.fromString(stackTrace) : null,
      metadata: metadata,
    );
  }

  // ── Core logging engine ─────────────────────────────────────────────────

  void _log({
    required LogLevel level,
    required LogCategory category,
    required String message,
    String? error,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final entry = LocalLogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );

    // Always add to local ring buffer
    _localLogs.add(entry);
    while (_localLogs.length > _maxLocalEntries) {
      _localLogs.removeFirst();
    }

    // Debug print in dev mode
    if (kDebugMode) {
      final tag = '[${level.value}][${category.value}]';
      debugPrint('$tag $message${error != null ? '\n  ↳ $error' : ''}');
    }

    // Queue for backend if level meets threshold
    if (level.priority >= _minRemoteLevel.priority) {
      _queueForBackend(entry);
    }
  }

  void _queueForBackend(LocalLogEntry entry) {
    _pendingBatch.add(entry.toJson());

    if (_pendingBatch.length >= _batchSize) {
      _flushBatch();
    } else {
      _batchTimer ??= Timer(_batchInterval, _flushBatch);
    }
  }

  void _flushBatch() {
    _batchTimer?.cancel();
    _batchTimer = null;

    if (_pendingBatch.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_pendingBatch);
    _pendingBatch.clear();

    for (final logData in batch) {
      unawaited(_sendToBackend(logData));
    }
  }

  Future<void> _sendToBackend(Map<String, dynamic> logData) async {
    try {
      await _ensureDeviceInfo();
      final token = await _storage.getToken();
      if (token == null) return; // Not logged in, skip backend sync

      // Use direct http.post to avoid infinite logging loop
      // (ApiClient logs every request, which would trigger more logs)
      await http.post(
        Uri.parse(ApiConstants.logFrontendError),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': logData['message'] ?? '',
          'error': logData['error'] ?? logData['message'] ?? '',
          if (logData['stackTrace'] != null)
            'stackTrace': logData['stackTrace'],
          'metadata': {
            ...?logData['metadata'] as Map<String, dynamic>?,
            'level': logData['level'],
            'category': logData['category'],
            'device': _deviceDescription,
            'platform': _platform,
            'osVersion': _osVersion,
            'clientTimestamp': logData['timestamp'],
          },
        }),
      );
    } catch (_) {
      // Silently fail — logging should never crash the app
    }
  }

  /// Force flush any pending logs (call on app pause/exit).
  void flush() => _flushBatch();

  /// Clear local log buffer.
  void clearLocalLogs() => _localLogs.clear();
}
