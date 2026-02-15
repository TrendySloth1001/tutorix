import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

/// Lightweight HTTP wrapper that automatically attaches Bearer tokens
/// and parses JSON responses.
///
/// Every feature-service delegates its HTTP calls here so that
/// auth-header logic and error handling live in one place.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final SecureStorageService _storage = SecureStorageService.instance;

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

  // ── Convenience verbs ──────────────────────────────────────────────────

  /// Authenticated GET → decoded JSON map.
  Future<Map<String, dynamic>> getAuthenticated(String url) async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse(url), headers: headers);
    return _handleResponse(response);
  }

  /// Authenticated GET → decoded JSON (could be list or map).
  Future<dynamic> getAuthenticatedRaw(String url) async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse(url), headers: headers);
    return _handleResponseRaw(response);
  }

  /// Public GET (no token) → decoded JSON map.
  Future<Map<String, dynamic>> getPublic(String url) async {
    final response = await http.get(Uri.parse(url), headers: _jsonHeaders);
    return _handleResponse(response);
  }

  /// Authenticated POST → decoded JSON map.
  Future<Map<String, dynamic>> postAuthenticated(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(url),
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
    final response = await http.post(
      Uri.parse(url),
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
    final response = await http.patch(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Authenticated DELETE → success boolean.
  Future<bool> deleteAuthenticated(String url) async {
    final headers = await _authHeaders();
    final response = await http.delete(Uri.parse(url), headers: headers);
    return response.statusCode == 200;
  }

  /// Authenticated multipart POST (single file upload).
  Future<Map<String, dynamic>> uploadFile(
    String url, {
    required String fieldName,
    required String filePath,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  /// Authenticated multipart POST (multiple files upload).
  Future<Map<String, dynamic>> uploadFiles(
    String url, {
    required String fieldName,
    required List<String> filePaths,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $token';

    for (final path in filePaths) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
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
    debugPrint('ApiClient error ${response.statusCode}: $message');
    debugPrint('Full response: ${response.body}');
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
    debugPrint('ApiClient error ${response.statusCode}: $message');
    throw Exception(message);
  }
}
