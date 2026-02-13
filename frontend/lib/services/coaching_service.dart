import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class CoachingService {
  final _storage = const FlutterSecureStorage();
  final String baseUrl = 'https://qjhcp0ph-3010.inc1.devtunnels.ms';

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Create a new coaching
  Future<CoachingModel?> createCoaching({
    required String name,
    String? description,
    String? logo,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/coaching'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'name': name,
        'description': description,
        'logo': logo,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return CoachingModel.fromJson(data['coaching']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create coaching');
    }
  }

  /// Get current user's coachings
  Future<List<CoachingModel>> getMyCoachings() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/coaching/my'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> coachingsList = data['coachings'];
      return coachingsList
          .map((e) => CoachingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch coachings');
    }
  }

  /// Get coaching by ID
  Future<CoachingModel?> getCoachingById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/coaching/$id'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return CoachingModel.fromJson(data['coaching']);
    } else {
      return null;
    }
  }

  /// Update coaching
  Future<CoachingModel?> updateCoaching({
    required String id,
    String? name,
    String? description,
    String? logo,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.patch(
      Uri.parse('$baseUrl/coaching/$id'),
      headers: _authHeaders(token),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (logo != null) 'logo': logo,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return CoachingModel.fromJson(data['coaching']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to update coaching');
    }
  }

  /// Delete coaching
  Future<bool> deleteCoaching(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/coaching/$id'),
      headers: _authHeaders(token),
    );

    return response.statusCode == 200;
  }

  /// Check if slug is available
  Future<bool> isSlugAvailable(String slug) async {
    final response = await http.get(
      Uri.parse('$baseUrl/coaching/check-slug/$slug'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['available'] as bool;
    }
    return false;
  }
}
