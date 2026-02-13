import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class UploadService {
  final _storage = const FlutterSecureStorage();
  final String baseUrl = 'https://qjhcp0ph-3010.inc1.devtunnels.ms';

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<UserModel?> uploadAvatar(File file) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/avatar'),
    );

    request.headers.addAll({'Authorization': 'Bearer $token'});

    request.files.add(await http.MultipartFile.fromPath('avatar', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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
      throw Exception(error['message'] ?? 'Failed to upload avatar');
    }
  }
}
