import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/services/error_logger_service.dart';
import 'secure_storage_service.dart';

/// Lightweight HTTP wrapper that automatically attaches Bearer tokens,
/// parses JSON responses, and logs every request/response.
///
/// Every feature-service delegates its HTTP calls here so that
/// auth-header logic, error handling, and observability live in one place.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final SecureStorageService _storage = SecureStorageService.instance;
  // Lazy access to break circular dependency with ErrorLoggerService
  ErrorLoggerService get _logger => ErrorLoggerService.instance;

  // ── Headers ────────────────────────────────────────────────────────────

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
    final token = await _storage.getToken();
    if (token == null) throw Exception('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  // ── Instrumented HTTP helpers ──────────────────────────────────────────

  Future<http.Response> _trackedGet(
    String url, {
    required Map<String, String> headers,
  }) async {
    _logger.apiRequest('GET', url);
    final sw = Stopwatch()..start();
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      sw.stop();
      _logger.apiResponse(
        'GET',
        url,
        statusCode: response.statusCode,
        duration: sw.elapsed,
      );
      return response;
    } catch (e, stack) {
      sw.stop();
      _logger.apiError(
        'GET',
        url,
        error: e,
        stackTrace: stack,
        duration: sw.elapsed,
      );
      rethrow;
    }
  }

  Future<http.Response> _trackedPost(
    String url, {
    required Map<String, String> headers,
    String? body,
  }) async {
    _logger.apiRequest('POST', url);
    final sw = Stopwatch()..start();
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      sw.stop();
      _logger.apiResponse(
        'POST',
        url,
        statusCode: response.statusCode,
        duration: sw.elapsed,
      );
      return response;
    } catch (e, stack) {
      sw.stop();
      _logger.apiError(
        'POST',
        url,
        error: e,
        stackTrace: stack,
        duration: sw.elapsed,
      );
      rethrow;
    }
  }

  Future<http.Response> _trackedPatch(
    String url, {
    required Map<String, String> headers,
    String? body,
  }) async {
    _logger.apiRequest('PATCH', url);
    final sw = Stopwatch()..start();
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      sw.stop();
      _logger.apiResponse(
        'PATCH',
        url,
        statusCode: response.statusCode,
        duration: sw.elapsed,
      );
      return response;
    } catch (e, stack) {
      sw.stop();
      _logger.apiError(
        'PATCH',
        url,
        error: e,
        stackTrace: stack,
        duration: sw.elapsed,
      );
      rethrow;
    }
  }

  Future<http.Response> _trackedDelete(
    String url, {
    required Map<String, String> headers,
  }) async {
    _logger.apiRequest('DELETE', url);
    final sw = Stopwatch()..start();
    try {
      final response = await http.delete(Uri.parse(url), headers: headers);
      sw.stop();
      _logger.apiResponse(
        'DELETE',
        url,
        statusCode: response.statusCode,
        duration: sw.elapsed,
      );
      return response;
    } catch (e, stack) {
      sw.stop();
      _logger.apiError(
        'DELETE',
        url,
        error: e,
        stackTrace: stack,
        duration: sw.elapsed,
      );
      rethrow;
    }
  }

  // ── Convenience verbs ──────────────────────────────────────────────────

  /// Authenticated GET → decoded JSON map.
  Future<Map<String, dynamic>> getAuthenticated(String url) async {
    final headers = await _authHeaders();
    final response = await _trackedGet(url, headers: headers);
    return _handleResponse(response);
  }

  /// Authenticated GET → decoded JSON (could be list or map).
  Future<dynamic> getAuthenticatedRaw(String url) async {
    final headers = await _authHeaders();
    final response = await _trackedGet(url, headers: headers);
    return _handleResponseRaw(response);
  }

  /// Public GET (no token) → decoded JSON map.
  Future<Map<String, dynamic>> getPublic(String url) async {
    final response = await _trackedGet(url, headers: _jsonHeaders);
    return _handleResponse(response);
  }

  /// Authenticated POST → decoded JSON map.
  Future<Map<String, dynamic>> postAuthenticated(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _authHeaders();
    final response = await _trackedPost(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Public POST → decoded JSON map (returns the raw parsed body).
  Future<Map<String, dynamic>> postPublic(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = {..._jsonHeaders, ...?extraHeaders};
    final response = await _trackedPost(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Authenticated PATCH → decoded JSON map.
  Future<Map<String, dynamic>> patchAuthenticated(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _authHeaders();
    final response = await _trackedPatch(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Authenticated DELETE → success boolean.
  Future<bool> deleteAuthenticated(String url) async {
    final headers = await _authHeaders();
    final response = await _trackedDelete(url, headers: headers);
    return response.statusCode == 200;
  }

  /// Authenticated multipart POST (single file upload).
  Future<Map<String, dynamic>> uploadFile(
    String url, {
    required String fieldName,
    required String filePath,
  }) async {
    _logger.apiRequest('UPLOAD', url);
    final sw = Stopwatch()..start();
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('Not authenticated');

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(fieldName, filePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      sw.stop();
      _logger.apiResponse(
        'UPLOAD',
        url,
        statusCode: response.statusCode,
        duration: sw.elapsed,
      );
      return _handleResponse(response);
    } catch (e, stack) {
      sw.stop();
      _logger.apiError(
        'UPLOAD',
        url,
        error: e,
        stackTrace: stack,
        duration: sw.elapsed,
      );
      rethrow;
    }
  }

  /// Authenticated multipart POST (multiple files upload).
  Future<Map<String, dynamic>> uploadFiles(
    String url, {
    required String fieldName,
    required List<String> filePaths,
  }) async {
    _logger.apiRequest('UPLOAD_MULTI', url);
    final sw = Stopwatch()..start();
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('Not authenticated');

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token';

      for (final path in filePaths) {
        request.files.add(await http.MultipartFile.fromPath(fieldName, path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      sw.stop();
      _logger.apiResponse(
        'UPLOAD_MULTI',
        url,
        statusCode: response.statusCode,
        duration: sw.elapsed,
      );
      return _handleResponse(response);
    } catch (e, stack) {
      sw.stop();
      _logger.apiError(
        'UPLOAD_MULTI',
        url,
        error: e,
        stackTrace: stack,
        duration: sw.elapsed,
      );
      rethrow;
    }
  }

  // ── Response handling ──────────────────────────────────────────────────

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    // Check both 'message' and 'error' fields (backend uses both)
    final message =
        data['message'] ??
        data['error'] ??
        'Request failed (${response.statusCode})';
    throw Exception(message);
  }

  dynamic _handleResponseRaw(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = data is Map
        ? (data['message'] ?? 'Request failed (${response.statusCode})')
        : 'Request failed (${response.statusCode})';
    throw Exception(message);
  }
}
