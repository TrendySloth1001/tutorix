import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InvitationService {
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

  /// Lookup a user by phone or email
  Future<Map<String, dynamic>> lookupContact(
    String coachingId,
    String contact,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/coaching/$coachingId/invite/lookup'),
      headers: _authHeaders(token),
      body: jsonEncode({'contact': contact}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Lookup failed');
    }
  }

  /// Send an invitation
  Future<Map<String, dynamic>> sendInvitation({
    required String coachingId,
    required String role,
    String? userId,
    String? wardId,
    String? invitePhone,
    String? inviteEmail,
    String? inviteName,
    String? message,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final body = <String, dynamic>{'role': role};
    if (userId != null) body['userId'] = userId;
    if (wardId != null) body['wardId'] = wardId;
    if (invitePhone != null) body['invitePhone'] = invitePhone;
    if (inviteEmail != null) body['inviteEmail'] = inviteEmail;
    if (inviteName != null) body['inviteName'] = inviteName;
    if (message != null) body['message'] = message;

    final response = await http.post(
      Uri.parse('$baseUrl/coaching/$coachingId/invite'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to send invitation');
    }
  }

  /// Get all invitations for a coaching (admin view)
  Future<List<Map<String, dynamic>>> getCoachingInvitations(
    String coachingId,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/coaching/$coachingId/invitations'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch invitations');
    }
  }

  /// Get pending invitations for the current user
  Future<List<Map<String, dynamic>>> getMyInvitations() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/user/invitations'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch invitations');
    }
  }

  /// Respond to an invitation (accept/decline)
  Future<Map<String, dynamic>> respondToInvitation(
    String invitationId,
    bool accept,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/user/invitations/$invitationId/respond'),
      headers: _authHeaders(token),
      body: jsonEncode({'accept': accept}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to respond to invitation');
    }
  }

  /// Cancel an invitation (admin action)
  Future<void> cancelInvitation(String coachingId, String invitationId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/coaching/$coachingId/invitations/$invitationId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to cancel invitation');
    }
  }
}
