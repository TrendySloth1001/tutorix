import 'dart:async';
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';

/// Model for a log entry.
class LogEntry {
  final String id;
  final DateTime createdAt;
  final String type;
  final String level;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final List<String> userRoles;
  final String? method;
  final String? path;
  final int? statusCode;
  final double? duration;
  final String? ip;
  final String? userAgent;
  final String? message;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.level,
    this.userId,
    this.userEmail,
    this.userName,
    this.userRoles = const [],
    this.method,
    this.path,
    this.statusCode,
    this.duration,
    this.ip,
    this.userAgent,
    this.message,
    this.error,
    this.stackTrace,
    this.metadata,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: json['type'] as String,
      level: json['level'] as String,
      userId: json['userId'] as String?,
      userEmail: json['userEmail'] as String?,
      userName: json['userName'] as String?,
      userRoles:
          (json['userRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      method: json['method'] as String?,
      path: json['path'] as String?,
      statusCode: json['statusCode'] as int?,
      duration: (json['duration'] as num?)?.toDouble(),
      ip: json['ip'] as String?,
      userAgent: json['userAgent'] as String?,
      message: json['message'] as String?,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Model for log statistics.
class LogStats {
  final int totalLogs;
  final int errorCount;
  final int warnCount;
  final int apiRequestCount;
  final int apiErrorCount;
  final int frontendErrorCount;

  const LogStats({
    required this.totalLogs,
    required this.errorCount,
    required this.warnCount,
    required this.apiRequestCount,
    required this.apiErrorCount,
    required this.frontendErrorCount,
  });

  factory LogStats.fromJson(Map<String, dynamic> json) {
    return LogStats(
      totalLogs: json['totalLogs'] as int,
      errorCount: json['errorCount'] as int,
      warnCount: json['warnCount'] as int,
      apiRequestCount: json['apiRequestCount'] as int,
      apiErrorCount: json['apiErrorCount'] as int,
      frontendErrorCount: json['frontendErrorCount'] as int,
    );
  }
}

/// Service for admin logging operations.
class AdminLogsService {
  AdminLogsService._();
  static final AdminLogsService instance = AdminLogsService._();

  final ApiClient _api = ApiClient.instance;

  /// Get logs with optional filters.
  Future<Map<String, dynamic>> getLogs({
    String? type,
    String? level,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      if (type != null) 'type': type,
      if (level != null) 'level': level,
      if (userId != null) 'userId': userId,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final raw = await _api.getAuthenticated(
      '${ApiConstants.adminLogs}?$queryString',
    );

    final logs = (raw['logs'] as List<dynamic>)
        .map((e) => LogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return {'logs': logs, 'total': raw['total'] as int};
  }

  /// Get log statistics.
  Future<LogStats> getStats({DateTime? startDate, DateTime? endDate}) async {
    final params = <String, String>{
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final url = queryString.isEmpty
        ? ApiConstants.adminLogsStats
        : '${ApiConstants.adminLogsStats}?$queryString';

    final raw = await _api.getAuthenticated(url);
    return LogStats.fromJson(raw);
  }

  /// Clean up old logs.
  Future<Map<String, dynamic>> cleanupOldLogs({int days = 30}) async {
    final raw = await _api.deleteAuthenticated(
      '${ApiConstants.adminLogsCleanup}?days=$days',
    );
    return raw ? {'success': true} : {'success': false};
  }
}
