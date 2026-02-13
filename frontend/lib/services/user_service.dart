import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class UserService {
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

  /// Get current user profile
  Future<UserModel?> getMe() async {
    final token = await _getToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/user/me'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson(data['user']);
    }
    return null;
  }

  /// Update current user profile
  Future<UserModel?> updateProfile({
    String? name,
    String? phone,
    String? picture,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.patch(
      Uri.parse('$baseUrl/user/me'),
      headers: _authHeaders(token),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (picture != null) 'picture': picture,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = UserModel.fromJson(data['user']);

      // Update stored user profile
      await _storage.write(
        key: 'user_profile',
        value: jsonEncode(user.toJson()),
      );

      return user;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to update profile');
    }
  }

  /// Update user roles
  Future<UserModel?> updateRoles({
    bool? isAdmin,
    bool? isTeacher,
    bool? isParent,
    bool? isWard,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.patch(
      Uri.parse('$baseUrl/user/me/roles'),
      headers: _authHeaders(token),
      body: jsonEncode({
        if (isAdmin != null) 'isAdmin': isAdmin,
        if (isTeacher != null) 'isTeacher': isTeacher,
        if (isParent != null) 'isParent': isParent,
        if (isWard != null) 'isWard': isWard,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = UserModel.fromJson(data['user']);

      // Update stored user profile
      await _storage.write(
        key: 'user_profile',
        value: jsonEncode(user.toJson()),
      );

      return user;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to update roles');
    }
  }

  /// Complete onboarding
  Future<UserModel?> completeOnboarding() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/user/me/onboarding'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = UserModel.fromJson(data['user']);

      // Update stored user profile
      await _storage.write(
        key: 'user_profile',
        value: jsonEncode(user.toJson()),
      );

      return user;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to complete onboarding');
    }
  }
}
